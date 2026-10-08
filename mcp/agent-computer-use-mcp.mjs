#!/usr/bin/env node
// agent-computer-use MCP stdio server.
// Verbatim port of Alma's Resources/cli/alma-computer-use-mcp.mjs tool surface
// (23 registerTool sites, byte-identical across .153/.164), with the Alma host
// HTTP side-calls kept best-effort fail-open and a hand-rolled stdio transport
// (Alma bundles the SDK; behavior identical either way).
//
// Chain: MCP client ──stdio──> this ──unix socket──> agent-computer-use daemon
// Side calls (ALMA_API-equivalent, fail-open): CU_HOST_URL env (default off).

import { spawn } from "node:child_process";
import { createConnection } from "node:net";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { randomBytes, createHash } from "node:crypto";
import * as path from "node:path";
import * as os from "node:os";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ---------- host side-calls (fail-open, verbatim semantics) ----------
const CU_HOST = process.env.AGENT_CU_HOST_URL || process.env.ALMA_API_URL || "";

async function checkApproval(bundle, appName) {
  if (!bundle) return { approved: true, strictMode: false };
  if (!CU_HOST) return { approved: true, strictMode: false };
  try {
    const url = new URL(`${CU_HOST}/api/computer-use/check_approval`);
    url.searchParams.set("bundle", bundle);
    if (appName) url.searchParams.set("app_name", appName);
    const res = await fetch(url.toString());
    if (!res.ok) return { approved: true, strictMode: false };
    const body = await res.json();
    return {
      approved: body.approved === true,
      strictMode: body.strict_mode === true,
      autoApproved: body.auto_approved === true
    };
  } catch {
    return { approved: true, strictMode: false };
  }
}

async function notePipActivity(entry) {
  if (!CU_HOST) return;
  try {
    await fetch(`${CU_HOST}/api/pip/computer-use-activity`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ tool_name: entry.toolName, bundle: entry.bundle, pid: entry.pid })
    });
  } catch {}
}

let focusGuardChecked = 0;
let focusGuardWarned = false;
const FOCUS_GUARD_WARNING = "WARNING: focus-steal protection is not active on this Mac, so this action may have pulled the user's frontmost window or keyboard focus away from what they were doing. Tell the user, and ask them to re-grant Accessibility for the Alma Computer Use helper in Settings → Computer Use (macOS resets that grant for each new build).";
async function focusGuardWarning() {
  if (!CU_HOST) return null;
  const now = Date.now();
  if (now - focusGuardChecked < 3e4) {
    return focusGuardWarned ? FOCUS_GUARD_WARNING : null;
  }
  focusGuardChecked = now;
  try {
    const res = await fetch(`${CU_HOST}/api/computer-use/permissions`);
    const body = await res.json();
    focusGuardWarned = (body.focus_guard?.arm_failures ?? 0) > 0;
  } catch {
    focusGuardWarned = false;
  }
  return focusGuardWarned ? FOCUS_GUARD_WARNING : null;
}

async function logAction(entry) {
  if (!CU_HOST) return;
  try {
    await fetch(`${CU_HOST}/api/computer-use/action_log`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        tool_name: entry.toolName,
        bundle_id: entry.bundleId,
        pid: entry.pid,
        args: entry.args,
        duration_ms: entry.durationMs,
        error_code: entry.errorCode
      })
    });
  } catch {}
}

// ---------- daemon client (verbatim) ----------

function resolveHelperBinary() {
  const override = process.env.AGENT_CU_HELPER;
  if (override && existsSync(override)) return override;
  const candidates = [];
  const self = process.argv[1] || "";
  if (self) {
    const dir = path.dirname(path.resolve(self));
    candidates.push(path.join(dir, "..", "bin", "agent-computer-use"));
    candidates.push(path.join(dir, "..", ".build", "release", "agent-computer-use"));
    candidates.push(path.join(dir, "..", ".build", "debug", "agent-computer-use"));
    candidates.push(path.join(dir, "..", "..", "bin", "agent-computer-use"));
  }
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

function defaultSocketPath() {
  const base = path.join(os.homedir(), "Library", "Application Support", "agent-computer-use");
  mkdirSync(base, { recursive: true });
  const helper = resolveHelperBinary();
  if (!helper) return path.join(base, "computer-use.sock");
  const tag = createHash("sha1").update(helper).digest("hex").slice(0, 8);
  return path.join(base, `computer-use-${tag}.sock`);
}

class DaemonClient {
  sock = null;
  child = null;
  readBuffer = Buffer.alloc(0);
  pending = new Map();
  connecting = null;
  socketPath = defaultSocketPath();

  async call(cmd, args = {}, timeoutMs = 2e4) {
    await this.ensureConnected();
    return new Promise((resolve, reject) => {
      const id = randomBytes(8).toString("hex");
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`computer-use ${cmd} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      const payload = JSON.stringify({ id, cmd, args }) + "\n";
      try {
        this.sock.write(payload);
      } catch (err) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(err);
      }
    });
  }

  async ensureConnected() {
    if (this.sock && !this.sock.destroyed) return;
    if (this.connecting) return this.connecting;
    this.connecting = (async () => {
      try {
        await this.connectOnce();
        return;
      } catch {}
      const helper = resolveHelperBinary();
      if (!helper) {
        throw new Error("agent-computer-use helper not found. Run scripts/build.sh first.");
      }
      this.spawnDaemon(helper);
      const deadline = Date.now() + 4e3;
      let lastErr = null;
      while (Date.now() < deadline) {
        try {
          await this.connectOnce();
          return;
        } catch (e) {
          lastErr = e;
          await new Promise((r) => setTimeout(r, 100));
        }
      }
      throw new Error(`Failed to connect to computer-use daemon at ${this.socketPath}: ${String(lastErr)}`);
    })().finally(() => {
      this.connecting = null;
    });
    return this.connecting;
  }

  connectOnce() {
    return new Promise((resolve, reject) => {
      const s = createConnection({ path: this.socketPath });
      const onError = (err) => {
        s.removeAllListeners();
        s.destroy();
        reject(err);
      };
      s.once("error", onError);
      s.once("connect", () => {
        s.removeListener("error", onError);
        this.sock = s;
        this.wireSocket(s);
        resolve();
      });
    });
  }

  wireSocket(s) {
    s.on("data", (chunk) => {
      this.readBuffer = Buffer.concat([this.readBuffer, Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)]);
      let nl = this.readBuffer.indexOf(10);
      while (nl !== -1) {
        const line = this.readBuffer.subarray(0, nl);
        this.readBuffer = this.readBuffer.subarray(nl + 1);
        if (line.length) this.handleLine(line);
        nl = this.readBuffer.indexOf(10);
      }
    });
    s.on("close", () => {
      this.sock = null;
      const err = new Error("computer-use daemon disconnected");
      for (const [id, p] of this.pending) {
        clearTimeout(p.timer);
        p.reject(err);
        this.pending.delete(id);
      }
    });
    s.on("error", () => {});
  }

  handleLine(line) {
    let resp;
    try {
      resp = JSON.parse(line.toString("utf8"));
    } catch {
      return;
    }
    const pending = this.pending.get(resp.id);
    if (!pending) return;
    clearTimeout(pending.timer);
    this.pending.delete(resp.id);
    if (resp.ok) pending.resolve(resp.data);
    else pending.reject(Object.assign(new Error(resp.error?.message || "daemon error"), { code: resp.error?.code, hint: resp.error?.hint }));
  }

  spawnDaemon(binary) {
    try {
      const child = spawn(
        binary,
        // Same contract as Alma: whichever process starts the daemon sets
        // its lifetime for both.
        ["daemon", "--socket", this.socketPath, "--idle-seconds", "900"],
        { stdio: ["ignore", "pipe", "pipe"], detached: false }
      );
      child.stderr?.on("data", (buf) => process.stderr.write(buf));
      child.on("exit", (code, sig) => {
        if (this.child === child) this.child = null;
        if (code !== 0 && code !== null) {
          process.stderr.write(`[computer-use-mcp] daemon exited code=${code} sig=${sig}\n`);
        }
      });
      this.child = child;
    } catch (e) {
      throw new Error(`Failed to spawn computer-use daemon: ${String(e)}`);
    }
  }
}
const daemon = new DaemonClient();

// ---------- shared helpers (verbatim) ----------

function normalizeTarget(args) {
  return {
    bundle: typeof args.bundle === "string" && args.bundle.length > 0 ? args.bundle : void 0,
    pid: typeof args.pid === "number" && args.pid > 0 ? Math.floor(args.pid) : void 0,
    window_id: typeof args.window_id === "number" && args.window_id > 0 ? Math.floor(args.window_id) : void 0
  };
}
const posIntOr = (v, defaultVal) => {
  return typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.floor(v) : defaultVal;
};

async function screenshotTarget(target) {
  try {
    const state = await daemon.call(
      "get_app_state",
      {
        bundle: target.bundle,
        pid: target.pid,
        window_id: target.window_id,
        include_screenshot: true,
        interactive_only: true,
        depth: 0,
        screenshot_max_width: 1280
      },
      3e4
    );
    const shotPath = state.screenshot?.path;
    if (!shotPath) return { type: "text", text: "Post-action screenshot unavailable." };
    const buf = await import("node:fs/promises").then((m) => m.readFile(shotPath));
    return { type: "image", data: buf.toString("base64"), mimeType: "image/jpeg" };
  } catch (e) {
    return { type: "text", text: `Post-action screenshot failed: ${e instanceof Error ? e.message : String(e)}` };
  }
}
function textBlock(text) {
  return { type: "text", text };
}
async function respond(summary, target) {
  const content = [textBlock(summary)];
  const shot = await screenshotTarget(target);
  if (shot) {
    if (shot.type === "image") content.push({ type: "image", data: shot.data, mimeType: shot.mimeType });
    else content.push(textBlock(shot.text));
  }
  return { content };
}

async function gated(toolName, args, inner) {
  const approval = await checkApproval(args.bundle);
  if (!approval.approved) {
    return {
      content: [
        textBlock(
          `Alma has not yet been approved to drive ${args.bundle}. Ask the user to open Settings → Computer Use and approve "${args.bundle}", then retry. (Strict-approval mode is currently on.)`
        )
      ]
    };
  }
  void notePipActivity({ toolName, bundle: args.bundle, pid: args.pid });
  const t0 = Date.now();
  try {
    const r = await inner();
    void logAction({ toolName, bundleId: args.bundle, pid: args.pid, args, durationMs: Date.now() - t0 });
    const warning = await focusGuardWarning();
    if (warning) return { content: [...r.content, textBlock(warning)] };
    return r;
  } catch (e) {
    void logAction({
      toolName,
      bundleId: args.bundle,
      pid: args.pid,
      args,
      durationMs: Date.now() - t0,
      errorCode: e instanceof Error ? e.message : String(e)
    });
    throw e;
  }
}

// ---------- sky-compat layer (verbatim) ----------

const KEYSYM_TO_ALMA = {
  control_l: "ctrl", control_r: "ctrl", control: "ctrl", ctrl: "ctrl",
  alt_l: "opt", alt_r: "opt", alt: "opt", option: "opt", opt: "opt",
  meta_l: "cmd", meta_r: "cmd", super_l: "cmd", super_r: "cmd",
  super: "cmd", command: "cmd", cmd: "cmd",
  shift_l: "shift", shift_r: "shift", shift: "shift",
  return: "return", enter: "return", tab: "tab",
  escape: "esc", esc: "esc", space: "space",
  backspace: "delete", delete: "delete",
  prior: "pageup", next: "pagedown",
  page_up: "pageup", page_down: "pagedown",
  home: "home", end: "end",
  up: "up", down: "down", left: "left", right: "right"
};
function normalizeKeyChord(key) {
  return key.split("+").map((part) => part.trim()).filter(Boolean)
    .map((part) => KEYSYM_TO_ALMA[part.toLowerCase()] ?? part.toLowerCase())
    .join("+");
}
function normalizeMouseButton(b) {
  switch (b) {
    case "r": case "right": return "right";
    case "m": case "middle": return "middle";
    default: return "left";
  }
}
function normalizeDirection(d) {
  switch (d) {
    case "u": case "up": return "up";
    case "d": case "down": return "down";
    case "l": case "left": return "left";
    default: return "right";
  }
}

class PlaybookOnce {
  sent = new Set();
  shouldSend(appKey) {
    if (this.sent.has(appKey)) return false;
    this.sent.add(appKey);
    return true;
  }
  reset() { this.sent.clear(); }
}

function renderAppStateText(elements, opts = {}) {
  const refByIndex = [...opts.carryOver ?? []];
  const indexOfRef = new Map();
  refByIndex.forEach((r, i) => indexOfRef.set(r, i));
  const lines = [];
  for (const el of elements) {
    const ref = typeof el.ref === "string" ? el.ref : void 0;
    if (!ref) continue;
    let index = indexOfRef.get(ref);
    if (index === void 0) {
      index = refByIndex.length;
      refByIndex.push(ref);
      indexOfRef.set(ref, index);
    }
    const role = String(el.role ?? "AXUnknown").replace(/^AX/, "");
    const label = [el.title, el.description, el.value, el.role_description]
      .map((v) => typeof v === "string" ? v.trim() : "")
      .find((v) => v.length > 0);
    const bounds = el.bounds;
    const pos = bounds ? ` @${Math.round(bounds.x ?? 0)},${Math.round(bounds.y ?? 0)} ${Math.round(bounds.w ?? 0)}x${Math.round(bounds.h ?? 0)}` : "";
    const flags = [el.focused === true ? "focused" : "", el.enabled === false ? "disabled" : ""].filter(Boolean).join(",");
    lines.push(`[${index}] ${role}${label ? ` "${label}"` : ""}${pos}${flags ? ` (${flags})` : ""}`);
  }
  const parts = [];
  if (opts.instructions) parts.push(`<app_specific_instructions>\n${opts.instructions}\n</app_specific_instructions>`);
  if (opts.diffNote) parts.push(opts.diffNote);
  parts.push(lines.join("\n"));
  return { text: parts.join("\n"), refByIndex };
}

const PLAYBOOK_BUNDLES = {
  "com.apple.Music": "AppleMusic",
  "com.spotify.client": "Spotify",
  "notion.id": "Notion",
  "com.apple.clock": "Clock",
  "com.apple.iWork.Numbers": "Numbers",
  "com.netease.163music": "NetEaseMusic",
  "com.apple.ScreenContinuity": "IPhoneMirroring"
};
const playbookCache = new Map();
function playbookFor(bundle) {
  if (!bundle) return null;
  const name = PLAYBOOK_BUNDLES[bundle];
  if (!name) return null;
  if (!playbookCache.has(name)) {
    try {
      playbookCache.set(name, readFileSync(path.join(__dirname, "playbooks", `${name}.md`), "utf8"));
    } catch {
      playbookCache.set(name, null);
    }
  }
  return playbookCache.get(name);
}

const playbookOnce = new PlaybookOnce();
const skyIndexMap = new Map();
function skyRefFor(app, index) {
  const refs = skyIndexMap.get(app);
  if (!refs || index < 0 || index >= refs.length) {
    throw new Error(`element_index ${index} is not valid for "${app}" — call sky_get_app_state first, then use an index from its text.`);
  }
  return refs[index];
}

// ---------- tool definitions (verbatim names/descriptions/schemas/handlers) ----------

const targetShape = {
  bundle: { type: "string", description: "Bundle id (com.apple.Music). Either bundle or pid is required." },
  pid: { type: "integer", description: "Process id. Either bundle or pid is required." },
  window_id: { type: "integer", description: "Specific CGWindowID (optional)." }
};

const tools = [];

function defTool(name, description, properties, required, handler) {
  tools.push({
    name, description,
    inputSchema: { type: "object", properties, required },
    handler
  });
}

defTool(
  "launch_app",
  "Launch an app by bundle id WITHOUT bringing it to the foreground. The user's frontmost app stays put; the launched app opens in the background so Alma can drive it. A running app is NEVER touched: there is no way to make this tool bring an app to the foreground, because Alma must never take the foreground away from the user. `activates` only reaches macOS's own cold-launch flag, exactly as double-clicking an app would, and does nothing for an app already running. `get_app_state` auto-launches too, so you usually do not need to call this explicitly.",
  {
    bundle: { type: "string", description: "Bundle id, e.g. com.netease.163music." },
    activates: { type: "boolean", description: "macOS's own cold-launch activation flag, and only that. Default false. It has no effect on a running app, and nothing here can move the foreground away from the user — do not reach for it to make an action work." }
  },
  ["bundle"],
  async (args) => gated("launch_app", args, async () => {
    const res = await daemon.call("launch_app", { bundle: args.bundle, activates: args.activates ?? false });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  })
);

defTool(
  "list_apps",
  "List running apps plus any used in the last N days (default 14), with usage frequency. Use this when picking which app to drive.",
  {
    days: { type: "integer", maximum: 90, description: "Lookback window for recency (days). Default 14." }
  },
  [],
  async (args) => {
    const res = await daemon.call("list_apps", { days: posIntOr(args.days, 14) });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "get_app_state",
  "Snapshot the target app: returns the AX tree + a window screenshot. Call this at the start of every turn before acting. On apps with no AX tree (Qt / custom-drawn) the elements list is empty but the screenshot is still captured so you can click by pixel. AUTO-LAUNCH: if `bundle` is given and the app is not running, it is launched in the BACKGROUND — the user's frontmost app stays put. Pass `auto_launch: false` to disable.",
  {
    ...targetShape,
    depth: { type: "integer", maximum: 20, description: "AX tree depth. Default 6." },
    interactive_only: { type: "boolean", description: "Limit to interactive elements. Default true." },
    screenshot_max_width: { type: "integer", description: "Downsample width for the screenshot (default 1280)." },
    auto_launch: { type: "boolean", description: "Auto-launch the app in the background if not running. Default true." }
  },
  [],
  async (args) => {
    const res = await daemon.call(
      "get_app_state",
      {
        bundle: args.bundle,
        pid: posIntOr(args.pid, void 0),
        window_id: typeof args.window_id === "number" && args.window_id > 0 ? args.window_id : void 0,
        depth: typeof args.depth === "number" && args.depth >= 0 ? Math.floor(args.depth) : 6,
        interactive_only: args.interactive_only ?? true,
        include_screenshot: true,
        screenshot_max_width: posIntOr(args.screenshot_max_width, 1280),
        auto_launch: args.auto_launch ?? true
      },
      3e4
    );
    const content = [];
    const playbook = playbookFor(args.bundle ?? res.app?.bundle);
    if (playbook) {
      content.push(textBlock(`## App playbook (auto-injected)\n\n${playbook}`));
    }
    const body = { ...res };
    delete body.screenshot;
    content.push(textBlock(JSON.stringify(body, null, 2)));
    if (res.screenshot?.path) {
      try {
        const buf = await import("node:fs/promises").then((m) => m.readFile(res.screenshot.path));
        content.push({ type: "image", data: buf.toString("base64"), mimeType: "image/jpeg" });
      } catch (e) {
        content.push(textBlock(`screenshot read failed: ${e instanceof Error ? e.message : String(e)}`));
      }
    } else if (res.screenshot_error) {
      content.push(textBlock(`screenshot error: ${res.screenshot_error}`));
    }
    return { content };
  }
);

defTool(
  "click",
  "Click an element by ref (from get_app_state) or at absolute pixel (x, y) coordinates. Returns a post-action screenshot of the target app so you can see the result.",
  {
    ref: { type: "string", description: 'Element ref from get_app_state (e.g. "e7"). Either ref or {x, y} is required.' },
    x: { type: "number", description: "X coordinate (screenshot pixel by default; see coord_space)." },
    y: { type: "number", description: "Y coordinate (screenshot pixel by default; see coord_space)." },
    coord_space: { type: "string", enum: ["screenshot", "screen"], description: '"screenshot" (default) — coords are pixels in the last get_app_state screenshot. "screen" — raw screen points.' },
    button: { type: "string", enum: ["left", "right", "middle"], description: "Mouse button. Default left." },
    click_count: { type: "integer", maximum: 3, description: "1=single, 2=double, 3=triple. Default 1." },
    strategy: { type: "string", enum: ["auto", "physical", "ax"], description: "auto (default) prefers CGEvent if bounds known." },
    ...targetShape
  },
  [],
  async (args) => gated("click", args, async () => {
    const target = normalizeTarget(args);
    const payload = {
      button: args.button ?? "left",
      click_count: posIntOr(args.click_count, 1),
      strategy: args.strategy ?? "auto",
      show_cursor: true
    };
    if (args.ref) payload.ref = args.ref;
    else if (args.x !== void 0 && args.y !== void 0) {
      payload.x = args.x;
      payload.y = args.y;
      payload.coord_space = args.coord_space ?? "screenshot";
      if (target.pid !== void 0) payload.pid = target.pid;
      if (target.bundle !== void 0) payload.bundle = target.bundle;
    } else {
      throw new Error("click requires either `ref` or both `x` and `y`");
    }
    await daemon.call("click", payload);
    return respond(`click ok (${args.ref ?? `${args.x},${args.y}`})`, target);
  })
);

defTool(
  "perform_secondary_action",
  "Right-click / open context menu on an element or at a pixel. Returns a post-action screenshot.",
  {
    ref: { type: "string" },
    x: { type: "number", description: "X coordinate (screenshot pixel by default)." },
    y: { type: "number", description: "Y coordinate (screenshot pixel by default)." },
    coord_space: { type: "string", enum: ["screenshot", "screen"] },
    ...targetShape
  },
  [],
  async (args) => gated("perform_secondary_action", args, async () => {
    const target = normalizeTarget(args);
    const payload = { show_cursor: true };
    if (args.ref) payload.ref = args.ref;
    else if (args.x !== void 0 && args.y !== void 0) {
      payload.x = args.x;
      payload.y = args.y;
      payload.coord_space = args.coord_space ?? "screenshot";
      if (target.pid !== void 0) payload.pid = target.pid;
      if (target.bundle !== void 0) payload.bundle = target.bundle;
    } else {
      throw new Error("perform_secondary_action requires either `ref` or both `x` and `y`");
    }
    await daemon.call("perform_secondary_action", payload);
    return respond(`secondary click ok`, target);
  })
);

defTool(
  "drag",
  'Mouse drag from one point to another. Coordinates default to screenshot pixels; pass coord_space="screen" for raw points. Returns a post-action screenshot.',
  {
    start_x: { type: "number" },
    start_y: { type: "number" },
    end_x: { type: "number" },
    end_y: { type: "number" },
    coord_space: { type: "string", enum: ["screenshot", "screen"] },
    button: { type: "string", enum: ["left", "right", "middle"] },
    ...targetShape
  },
  ["start_x", "start_y", "end_x", "end_y"],
  async (args) => gated("drag", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("drag", {
      start_x: args.start_x,
      start_y: args.start_y,
      end_x: args.end_x,
      end_y: args.end_y,
      coord_space: args.coord_space ?? "screenshot",
      button: args.button ?? "left",
      pid: target.pid,
      bundle: target.bundle,
      show_cursor: true
    });
    return respond(`drag ok (${args.start_x},${args.start_y} → ${args.end_x},${args.end_y})`, target);
  })
);

defTool(
  "type_text",
  "Text entry into the target app. By default this uses AX insertion when ref is provided, physical key events translated from the current keyboard layout, and Unicode CGEvents as fallback. Target must already have keyboard focus — click it first. Returns a post-action screenshot.",
  {
    text: { type: "string" },
    ref: { type: "string", description: "Optional text-field ref from get_app_state. When present, auto mode inserts via AX instead of keystrokes." },
    input_method: { type: "string", enum: ["auto", "physical", "unicode", "ax"], description: "auto (default), physical key events, unicode CGEvents, or AX insertion when ref is provided." },
    ...targetShape
  },
  ["text"],
  async (args) => gated("type_text", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("type_text", {
      text: args.text,
      ref: args.ref,
      input_method: args.input_method ?? "auto",
      pid: target.pid,
      bundle: target.bundle
    });
    return respond(`typed ${args.text.length} chars`, target);
  })
);

defTool(
  "press_key",
  "Press a key or combo in xdotool syntax — cmd+s, ctrl+shift+t, Return, Escape, F1, cmd+opt+esc. Modifiers: cmd|command|meta, ctrl|control, shift, opt|option|alt, fn.",
  {
    key: { type: "string", description: 'xdotool-style key combo, e.g. "cmd+s" or "Return"' },
    ...targetShape
  },
  ["key"],
  async (args) => gated("press_key", args, async () => {
    const target = normalizeTarget(args);
    const res = await daemon.call("press_key", { key: args.key, pid: target.pid, bundle: target.bundle });
    if (res?.delivered === false) {
      const note = res.delivery_note ?? "the target app did not accept the key event";
      return respond(`NOT delivered: pressed ${args.key} was suppressed — ${note}`, target);
    }
    if (res?.via === "menu_ax_press") {
      return respond(`pressed ${args.key} (invoked its menu item in the background; the user's focus was untouched)`, target);
    }
    return respond(`pressed ${args.key}`, target);
  })
);

defTool(
  "scroll",
  "Scroll an element (AX-based). Returns a post-action screenshot.",
  {
    ref: { type: "string" },
    direction: { type: "string", enum: ["up", "down", "left", "right"] },
    pages: { type: "integer", maximum: 20 },
    ...targetShape
  },
  ["ref", "direction"],
  async (args) => gated("scroll", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("scroll", {
      ref: args.ref,
      direction: args.direction,
      pages: posIntOr(args.pages, 1),
      show_cursor: true
    });
    return respond(`scrolled ${args.direction} ×${posIntOr(args.pages, 1)}`, target);
  })
);

defTool(
  "set_value",
  "Directly set AXValue on an element (sliders, steppers, text fields). Skips keystroke simulation. Value can be a string, number, or boolean.",
  {
    ref: { type: "string" },
    value: { description: "string, number, or boolean" },
    ...targetShape
  },
  ["ref", "value"],
  async (args) => gated("set_value", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("set_value", { ref: args.ref, value: args.value });
    return respond(`set ${args.ref} = ${JSON.stringify(args.value)}`, target);
  })
);

defTool(
  "select_text",
  "Select a run of text inside an editable element — or place the cursor immediately before/after it — without touching the rest of the field. Use this instead of set_value when the user's existing text must survive, and instead of faking a selection with key chords. Pass prefix/suffix when the same text appears more than once.",
  {
    ref: { type: "string", description: "Element index/ref from the latest get_app_state." },
    text: { type: "string", description: "Text to locate within the editable element." },
    prefix: { type: "string", description: "Text immediately before the target, to disambiguate repeats." },
    suffix: { type: "string", description: "Text immediately after the target, to disambiguate repeats." },
    selection_type: { type: "string", enum: ["text", "cursor_before", "cursor_after"], description: "Select the text itself (default), or collapse the cursor before/after it." },
    ...targetShape
  },
  ["ref", "text"],
  async (args) => gated("select_text", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("select_text", {
      ref: args.ref,
      text: args.text,
      prefix: args.prefix,
      suffix: args.suffix,
      selection_type: args.selection_type ?? "text"
    });
    return respond(`selected ${JSON.stringify(args.text)} in ${args.ref}`, target);
  })
);

// --- sky_* Codex-compatible surface ---

defTool(
  "sky_list_apps",
  "Codex-compatible: list apps that can be targeted by the window API. Returns {id, displayName, isRunning, lastUsedDate, useCount}.",
  {},
  [],
  async () => {
    const res = await daemon.call("list_apps", {});
    const apps = (res.apps ?? []).map((a) => ({
      id: a.bundle || a.name || "unknown",
      displayName: a.name,
      isRunning: a.running ?? a.active,
      lastUsedDate: a.last_used_at ?? void 0,
      useCount: a.use_count ?? void 0
    }));
    return { content: [textBlock(JSON.stringify(apps, null, 2))] };
  }
);

defTool(
  "sky_get_app_state",
  "Codex-compatible: capture the current state, screenshot and accessibility text for an app window. Returns {app, screenshot:{url}|null, text}; the text numbers each element so you can pass element_index to the other sky_ verbs.",
  {
    app: { type: "string", description: "App id, display name or process name from sky_list_apps." },
    disableDiff: { type: "boolean", description: "Return the full accessibility tree instead of a diff from the previous tree." }
  },
  ["app"],
  async (args) => gated("sky_get_app_state", { bundle: args.app }, async () => {
    const haveIndices = (skyIndexMap.get(args.app)?.length ?? 0) > 0;
    const raw = await daemon.call("get_app_state", {
      bundle: args.app,
      disable_diff: args.disableDiff === true || !haveIndices
    });
    const elements = raw.elements ?? [];
    const bundle = raw.app?.bundle || args.app;
    const instructions = playbookOnce.shouldSend(bundle) ? playbookFor(bundle) ?? void 0 : void 0;
    const diffNote = raw.elements_are_diff === true ? `(diff: ${elements.length} changed, ${raw.unchanged_element_count ?? 0} unchanged. Indices below are stable; elements not listed are unchanged since your last read. Pass disableDiff for the full tree.)` : void 0;
    const { text, refByIndex } = renderAppStateText(elements, {
      instructions,
      diffNote,
      carryOver: raw.elements_are_diff === true ? skyIndexMap.get(args.app) : void 0
    });
    skyIndexMap.set(args.app, refByIndex);
    const shot = raw.screenshot;
    const url = shot?.data_url ?? shot?.url;
    return {
      content: [textBlock(JSON.stringify({ app: args.app, screenshot: url ? { url } : null, text }, null, 2))]
    };
  })
);

defTool(
  "sky_click",
  "Codex-compatible: click an indexed element from the latest sky_get_app_state, or a coordinate in the app window.",
  {
    app: { type: "string" },
    element_index: { type: "integer" },
    x: { type: "number", description: "X coordinate in the app-window screenshot." },
    y: { type: "number", description: "Y coordinate in the app-window screenshot." },
    click_count: { type: "integer" },
    mouse_button: { type: "string", enum: ["left", "right", "middle", "l", "r", "m"] }
  },
  ["app"],
  async (args) => gated("sky_click", { bundle: args.app }, async () => {
    const button = normalizeMouseButton(args.mouse_button);
    if (typeof args.element_index === "number") {
      await daemon.call("click", { ref: skyRefFor(args.app, args.element_index), button, click_count: args.click_count ?? 1 });
    } else if (typeof args.x === "number" && typeof args.y === "number") {
      await daemon.call("click", { x: args.x, y: args.y, bundle: args.app, coord_space: "screenshot", button, click_count: args.click_count ?? 1 });
    } else {
      throw new Error("sky_click needs element_index, or both x and y.");
    }
    return respond("clicked", normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "sky_press_key",
  "Codex-compatible: press a `+`-separated keysym chord (Return, Tab, Control_L+a, Super_L+d) in an app window.",
  { app: { type: "string" }, key: { type: "string" } },
  ["app", "key"],
  async (args) => gated("sky_press_key", { bundle: args.app }, async () => {
    const res = await daemon.call("press_key", { key: normalizeKeyChord(args.key), bundle: args.app });
    const target = normalizeTarget({ bundle: args.app });
    if (res?.delivered === false) {
      const note = res.delivery_note ?? "the target app did not accept the key event";
      return respond(`NOT delivered: pressed ${args.key} was suppressed — ${note}`, target);
    }
    if (res?.via === "menu_ax_press") {
      return respond(`pressed ${args.key} (invoked its menu item in the background; the user's focus was untouched)`, target);
    }
    return respond(`pressed ${args.key}`, target);
  })
);

defTool(
  "sky_type_text",
  "Codex-compatible: type text into the current focus in an app window.",
  { app: { type: "string" }, text: { type: "string" } },
  ["app", "text"],
  async (args) => gated("sky_type_text", { bundle: args.app }, async () => {
    await daemon.call("type_text", { text: args.text, bundle: args.app });
    return respond(`typed ${args.text.length} chars`, normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "sky_scroll",
  "Codex-compatible: scroll an indexed element in an app window.",
  {
    app: { type: "string" },
    element_index: { type: "integer" },
    direction: { type: "string", enum: ["up", "down", "left", "right", "u", "d", "l", "r"] },
    pages: { type: "number" }
  },
  ["app", "element_index", "direction"],
  async (args) => gated("sky_scroll", { bundle: args.app }, async () => {
    await daemon.call("scroll", {
      ref: skyRefFor(args.app, args.element_index),
      direction: normalizeDirection(args.direction),
      pages: args.pages ?? 1
    });
    return respond("scrolled", normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "sky_set_value",
  "Codex-compatible: replace the value of an indexed editable element.",
  { app: { type: "string" }, element_index: { type: "integer" }, value: { type: "string" } },
  ["app", "element_index", "value"],
  async (args) => gated("sky_set_value", { bundle: args.app }, async () => {
    await daemon.call("set_value", { ref: skyRefFor(args.app, args.element_index), value: args.value });
    return respond("set value", normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "sky_drag",
  "Codex-compatible: drag from one app-window coordinate to another.",
  {
    app: { type: "string" },
    from_x: { type: "number" }, from_y: { type: "number" },
    to_x: { type: "number" }, to_y: { type: "number" }
  },
  ["app", "from_x", "from_y", "to_x", "to_y"],
  async (args) => gated("sky_drag", { bundle: args.app }, async () => {
    await daemon.call("drag", {
      start_x: args.from_x,
      start_y: args.from_y,
      end_x: args.to_x,
      end_y: args.to_y,
      bundle: args.app,
      coord_space: "screenshot"
    });
    return respond("dragged", normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "sky_perform_secondary_action",
  "Codex-compatible: invoke a secondary accessibility action on an indexed element.",
  { app: { type: "string" }, element_index: { type: "integer" }, action: { type: "string" } },
  ["app", "element_index", "action"],
  async (args) => gated("sky_perform_secondary_action", { bundle: args.app }, async () => {
    await daemon.call("perform_secondary_action", { ref: skyRefFor(args.app, args.element_index), action: args.action });
    return respond(`performed ${args.action}`, normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "sky_select_text",
  "Codex-compatible: select matching text in an indexed editable element, or place the cursor before/after it.",
  {
    app: { type: "string" },
    element_index: { type: "integer" },
    text: { type: "string" },
    prefix: { type: "string" },
    suffix: { type: "string" },
    selection_type: { type: "string", enum: ["text", "cursor_before", "cursor_after"] }
  },
  ["app", "element_index", "text"],
  async (args) => gated("sky_select_text", { bundle: args.app }, async () => {
    await daemon.call("select_text", {
      ref: skyRefFor(args.app, args.element_index),
      text: args.text,
      prefix: args.prefix,
      suffix: args.suffix,
      selection_type: args.selection_type ?? "text"
    });
    return respond(`selected ${JSON.stringify(args.text)}`, normalizeTarget({ bundle: args.app }));
  })
);

defTool(
  "permissions",
  "Check whether Alma Computer Use has Accessibility + Screen Recording permissions.",
  {},
  [],
  async () => {
    const res = await daemon.call("permissions");
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "grant",
  "Trigger the macOS Accessibility permission dialog. Caller should poll `permissions` after.",
  {},
  [],
  async () => {
    const res = await daemon.call("grant");
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

// ---------- minimal MCP stdio transport ----------
// Auto-detects framing like the SDK's StdioServerTransport: accepts both
// Content-Length headers and bare newline-delimited JSON (what codex sends),
// and replies in the framing the client used.

const SERVER_INFO = { name: "agent-computer-use", version: "1.0.0" };
const INSTRUCTIONS = [
  "Drive native macOS apps via the Accessibility API and CGEvent.",
  "Start every turn with `get_app_state <bundle|pid>` — it returns a",
  "screenshot + AX tree. Subsequent action tools automatically return",
  "a fresh post-action screenshot so you can see the effect.",
  'Prefer element refs (e.g. "e7") when the AX tree has them; fall',
  "back to pixel coordinates when elements is empty (Qt/custom apps).",
  "HARD RULE: never take the user's foreground app, key window, or cursor — not even momentarily,",
  "and never by bringing a window forward and putting it back. Every verb works on a background app; nothing here needs the foreground.",
  "Never activate, raise, or otherwise front an app on your own initiative. If an action reports it could not be delivered, tell the user — do not reach for the foreground to force it through."
].join(" ");

const toolsByName = new Map(tools.map((t) => [t.name, t]));

let outFraming = "jsonl"; // detect from first inbound frame
function writeMessage(msg) {
  const body = Buffer.from(JSON.stringify(msg), "utf8");
  if (outFraming === "headers") {
    process.stdout.write(`Content-Length: ${body.length}\r\n\r\n`);
    process.stdout.write(body);
  } else {
    process.stdout.write(body);
    process.stdout.write("\n");
  }
}

function rpcResult(id, result) { writeMessage({ jsonrpc: "2.0", id, result }); }
function rpcError(id, code, message) { writeMessage({ jsonrpc: "2.0", id, error: { code, message } }); }

async function handleMessage(msg) {
  const { id, method, params } = msg;
  if (id === void 0 || id === null) {
    // notification — nothing to answer
    return;
  }
  try {
    switch (method) {
      case "initialize":
        rpcResult(id, {
          protocolVersion: params?.protocolVersion ?? "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: SERVER_INFO,
          instructions: INSTRUCTIONS
        });
        return;
      case "ping":
        rpcResult(id, {});
        return;
      case "tools/list": {
        rpcResult(id, {
          tools: tools.map((t) => ({
            name: t.name,
            description: t.description,
            inputSchema: t.inputSchema
          }))
        });
        return;
      }
      case "tools/call": {
        const name = params?.name;
        const tool = toolsByName.get(name);
        if (!tool) {
          rpcResult(id, { isError: true, content: [textBlock(`Unknown tool: ${name}`)] });
          return;
        }
        try {
          const result = await tool.handler(params?.arguments ?? {});
          rpcResult(id, result);
        } catch (e) {
          rpcResult(id, { isError: true, content: [textBlock(e instanceof Error ? e.message : String(e))] });
        }
        return;
      }
      case "resources/list":
        rpcResult(id, { resources: [] });
        return;
      case "prompts/list":
        rpcResult(id, { prompts: [] });
        return;
      case "logging/setLevel":
        rpcResult(id, {});
        return;
      default:
        rpcError(id, -32601, `Method not found: ${method}`);
    }
  } catch (e) {
    rpcError(id, -32603, e instanceof Error ? e.message : String(e));
  }
}

function main() {
  let buf = Buffer.alloc(0);
  let framing = null; // "headers" | "jsonl" once seen
  process.stdin.on("data", (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (true) {
      if (framing === null) {
        // Peek: JSONL messages start with '{'; headered with 'C'ontent-Length
        const i = buf.findIndex((b) => b !== 10 && b !== 13 && b !== 32 && b !== 9);
        if (i === -1) { buf = Buffer.alloc(0); return; }
        if (i > 0) buf = buf.subarray(i);
        framing = buf[0] === 0x7b ? "jsonl" : "headers";
        outFraming = framing;
      }
      if (framing === "jsonl") {
        const nl = buf.indexOf(10);
        if (nl === -1) return;
        const line = buf.subarray(0, nl);
        buf = buf.subarray(nl + 1);
        if (!line.length) continue;
        try {
          const msg = JSON.parse(line.toString("utf8"));
          void handleMessage(msg);
        } catch {}
        continue;
      }
      const headerEnd = buf.indexOf("\r\n\r\n");
      if (headerEnd === -1) return;
      const header = buf.subarray(0, headerEnd).toString("utf8");
      const m = header.match(/Content-Length: (\d+)/i);
      if (!m) { buf = buf.subarray(headerEnd + 4); continue; }
      const len = parseInt(m[1], 10);
      if (buf.length < headerEnd + 4 + len) return;
      const body = buf.subarray(headerEnd + 4, headerEnd + 4 + len);
      buf = buf.subarray(headerEnd + 4 + len);
      try {
        const msg = JSON.parse(body.toString("utf8"));
        void handleMessage(msg);
      } catch {}
    }
  });
  process.stderr.write("[agent-cu-mcp] ready on stdio\n");
}
main();
