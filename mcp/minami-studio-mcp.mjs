#!/usr/bin/env node
// minami-studio MCP stdio server.
// Verbatim port of Alma's Resources/cli/alma-computer-use-mcp.mjs tool surface
// (23 registerTool sites, byte-identical across .153/.164), with the Alma host
// HTTP side-calls kept best-effort fail-open and a hand-rolled stdio transport
// (Alma bundles the SDK; behavior identical either way).
//
// Chain: MCP client ──stdio──> this ──unix socket──> minami-studio daemon
// Side calls (ALMA_API-equivalent, fail-open): CU_HOST_URL env (default off).

import { spawn } from "node:child_process";
import { createConnection } from "node:net";
import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { randomBytes, createHash } from "node:crypto";
import * as path from "node:path";
import * as os from "node:os";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ---------- host side-calls (fail-open, verbatim semantics) ----------
const CU_HOST = process.env.MINAMI_CU_HOST_URL ?? process.env.AGENT_CU_HOST_URL ?? process.env.ALMA_API_URL ?? "";

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
  const override = process.env.MINAMI_CU_HELPER ?? process.env.ALMA_CU_HELPER ?? process.env.AGENT_CU_HELPER;
  if (override && existsSync(override)) return override;
  const candidates = [];
  const almaRel = path.join("Alma Computer Use.app", "Contents", "MacOS", "AlmaComputerUse");
  const resources = process.env.MINAMI_CU_RESOURCES_PATH ?? process.env.ALMA_RESOURCES_PATH;
  if (resources) {
    candidates.push(path.join(resources, almaRel));
  }
  const self = process.argv[1] || "";
  if (self) {
    const dir = path.dirname(path.resolve(self));
    candidates.push(path.join(dir, "..", "computer-use", almaRel));
    candidates.push(path.join(dir, "..", "..", "computer-use", almaRel));
    candidates.push(path.join(dir, "..", "..", "..", "computer-use", almaRel));
    // our own repo layout
    candidates.push(path.join(dir, "..", "bin", "minami-studio"));
    candidates.push(path.join(dir, "..", ".build", "release", "minami-studio"));
    candidates.push(path.join(dir, "..", ".build", "debug", "minami-studio"));
    candidates.push(path.join(dir, "..", "..", "bin", "minami-studio"));
  }
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

function defaultSocketPath() {
  const base = path.join(os.homedir(), "Library", "Application Support", "minami-studio");
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
        throw new Error("Alma Computer Use helper not found. Run `pnpm build:computer-use` or reinstall Alma.");
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
  // [ALMA] ref-only / no-target actions return null — the original action
  // content ships alone, without a doomed get_app_state({}) screenshot.
  if (!target?.bundle && !target?.pid) return null;
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
    _listSchema: null,
    handler
  });
}


// [ALMA] tools/list emits the SDK-serialized draft-07 schemas
// verbatim (safe-int bounds, $schema key, required omitted when empty)
// plus execution:{taskSupport:"forbidden"} on every tool.
const REAL_SCHEMAS = {
  "launch_app": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "bundle": {
        "type": "string",
        "description": "Bundle id, e.g. com.netease.163music."
      },
      "activates": {
        "description": "macOS's own cold-launch activation flag, and only that. Default false. It has no effect on a running app, and nothing here can move the foreground away from the user \u2014 do not reach for it to make an action work.",
        "type": "boolean"
      }
    },
    "required": [
      "bundle"
    ]
  },
  "list_apps": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "days": {
        "description": "Lookback window for recency (days). Default 14.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 90
      }
    }
  },
  "get_app_state": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "depth": {
        "description": "AX tree depth. Default 6.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 20
      },
      "interactive_only": {
        "description": "Limit to interactive elements. Default true.",
        "type": "boolean"
      },
      "screenshot_max_width": {
        "description": "Downsample width for the screenshot (default 1280).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "auto_launch": {
        "description": "Auto-launch the app in the background if not running. Default true.",
        "type": "boolean"
      }
    }
  },
  "click": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "ref": {
        "description": "Element ref from get_app_state (e.g. \"e7\"). Either ref or {x, y} is required.",
        "type": "string"
      },
      "x": {
        "description": "X coordinate (screenshot pixel by default; see coord_space).",
        "type": "number"
      },
      "y": {
        "description": "Y coordinate (screenshot pixel by default; see coord_space).",
        "type": "number"
      },
      "coord_space": {
        "description": "\"screenshot\" (default) \u2014 coords are pixels in the last get_app_state screenshot. \"screen\" \u2014 raw screen points.",
        "type": "string",
        "enum": [
          "screenshot",
          "screen"
        ]
      },
      "button": {
        "description": "Mouse button. Default left.",
        "type": "string",
        "enum": [
          "left",
          "right",
          "middle"
        ]
      },
      "click_count": {
        "description": "1=single, 2=double, 3=triple. Default 1.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 3
      },
      "strategy": {
        "description": "auto (default) prefers CGEvent if bounds known.",
        "type": "string",
        "enum": [
          "auto",
          "physical",
          "ax"
        ]
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    }
  },
  "perform_secondary_action": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "ref": {
        "type": "string"
      },
      "x": {
        "description": "X coordinate (screenshot pixel by default).",
        "type": "number"
      },
      "y": {
        "description": "Y coordinate (screenshot pixel by default).",
        "type": "number"
      },
      "coord_space": {
        "type": "string",
        "enum": [
          "screenshot",
          "screen"
        ]
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    }
  },
  "drag": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "start_x": {
        "type": "number"
      },
      "start_y": {
        "type": "number"
      },
      "end_x": {
        "type": "number"
      },
      "end_y": {
        "type": "number"
      },
      "coord_space": {
        "type": "string",
        "enum": [
          "screenshot",
          "screen"
        ]
      },
      "button": {
        "type": "string",
        "enum": [
          "left",
          "right",
          "middle"
        ]
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    },
    "required": [
      "start_x",
      "start_y",
      "end_x",
      "end_y"
    ]
  },
  "type_text": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "text": {
        "type": "string"
      },
      "ref": {
        "description": "Optional text-field ref from get_app_state. When present, auto mode inserts via AX instead of keystrokes.",
        "type": "string"
      },
      "input_method": {
        "description": "auto (default), physical key events, unicode CGEvents, or AX insertion when ref is provided.",
        "type": "string",
        "enum": [
          "auto",
          "physical",
          "unicode",
          "ax"
        ]
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    },
    "required": [
      "text"
    ]
  },
  "press_key": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "key": {
        "type": "string",
        "description": "xdotool-style key combo, e.g. \"cmd+s\" or \"Return\""
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    },
    "required": [
      "key"
    ]
  },
  "scroll": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "ref": {
        "type": "string"
      },
      "direction": {
        "type": "string",
        "enum": [
          "up",
          "down",
          "left",
          "right"
        ]
      },
      "pages": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 20
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    },
    "required": [
      "ref",
      "direction"
    ]
  },
  "set_value": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "ref": {
        "type": "string"
      },
      "value": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "number"
          },
          {
            "type": "boolean"
          }
        ]
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    },
    "required": [
      "ref",
      "value"
    ]
  },
  "select_text": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "ref": {
        "type": "string",
        "description": "Element index/ref from the latest get_app_state."
      },
      "text": {
        "type": "string",
        "description": "Text to locate within the editable element."
      },
      "prefix": {
        "description": "Text immediately before the target, to disambiguate repeats.",
        "type": "string"
      },
      "suffix": {
        "description": "Text immediately after the target, to disambiguate repeats.",
        "type": "string"
      },
      "selection_type": {
        "description": "Select the text itself (default), or collapse the cursor before/after it.",
        "type": "string",
        "enum": [
          "text",
          "cursor_before",
          "cursor_after"
        ]
      },
      "bundle": {
        "description": "Bundle id (com.apple.Music). Either bundle or pid is required.",
        "type": "string"
      },
      "pid": {
        "description": "Process id. Either bundle or pid is required.",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "window_id": {
        "description": "Specific CGWindowID (optional).",
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      }
    },
    "required": [
      "ref",
      "text"
    ]
  },
  "sky_list_apps": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {}
  },
  "sky_get_app_state": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string",
        "description": "App id, display name or process name from sky_list_apps."
      },
      "disableDiff": {
        "description": "Return the full accessibility tree instead of a diff from the previous tree.",
        "type": "boolean"
      }
    },
    "required": [
      "app"
    ]
  },
  "sky_click": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "element_index": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "x": {
        "description": "X coordinate in the app-window screenshot.",
        "type": "number"
      },
      "y": {
        "description": "Y coordinate in the app-window screenshot.",
        "type": "number"
      },
      "click_count": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "mouse_button": {
        "type": "string",
        "enum": [
          "left",
          "right",
          "middle",
          "l",
          "r",
          "m"
        ]
      }
    },
    "required": [
      "app"
    ]
  },
  "sky_press_key": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "key": {
        "type": "string"
      }
    },
    "required": [
      "app",
      "key"
    ]
  },
  "sky_type_text": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "text": {
        "type": "string"
      }
    },
    "required": [
      "app",
      "text"
    ]
  },
  "sky_scroll": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "element_index": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "direction": {
        "type": "string",
        "enum": [
          "up",
          "down",
          "left",
          "right",
          "u",
          "d",
          "l",
          "r"
        ]
      },
      "pages": {
        "type": "number"
      }
    },
    "required": [
      "app",
      "element_index",
      "direction"
    ]
  },
  "sky_set_value": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "element_index": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "value": {
        "type": "string"
      }
    },
    "required": [
      "app",
      "element_index",
      "value"
    ]
  },
  "sky_drag": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "from_x": {
        "type": "number"
      },
      "from_y": {
        "type": "number"
      },
      "to_x": {
        "type": "number"
      },
      "to_y": {
        "type": "number"
      }
    },
    "required": [
      "app",
      "from_x",
      "from_y",
      "to_x",
      "to_y"
    ]
  },
  "sky_perform_secondary_action": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "element_index": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "action": {
        "type": "string"
      }
    },
    "required": [
      "app",
      "element_index",
      "action"
    ]
  },
  "sky_select_text": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {
      "app": {
        "type": "string"
      },
      "element_index": {
        "type": "integer",
        "minimum": -9007199254740991,
        "maximum": 9007199254740991
      },
      "text": {
        "type": "string"
      },
      "prefix": {
        "type": "string"
      },
      "suffix": {
        "type": "string"
      },
      "selection_type": {
        "type": "string",
        "enum": [
          "text",
          "cursor_before",
          "cursor_after"
        ]
      }
    },
    "required": [
      "app",
      "element_index",
      "text"
    ]
  },
  "permissions": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {}
  },
  "grant": {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "properties": {}
  }
};

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
    value: { anyOf: [{ type: "string" }, { type: "number" }, { type: "boolean" }], description: "string, number, or boolean" },
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

// ---------- Minami product-layer tools (not in Alma's 23-tool surface) ----------
// Picture-in-Picture mirror control. The daemon protocol is unchanged Alma
// wire; these five MCP tools are our own product surface so agents can open
// mirrors on request instead of requiring socket-level orchestration.

defTool(
  "pip_open",
  "Open a floating Picture-in-Picture mirror of an app window — a live, always-on-top video of that window. Works on background, occluded, or minimized windows (ScreenCaptureKit captures the texture regardless of visibility). Identify the window by window_id (from get_app_state window.id) directly, or by bundle/pid plus optional title to pick a window. Optional width/height set the floater size.",
  {
    window_id: { type: "integer", description: "CGWindowID of the window to mirror (from get_app_state window.id). Direct path — no bundle/pid needed." },
    bundle: { type: "string", description: "Bundle id — resolves the app and picks its window (title filters the pick)." },
    pid: { type: "integer", description: "Process id — same resolution as bundle." },
    title: { type: "string", description: "Window-title filter when resolving by app, and the floater's display title." },
    width: { type: "number", description: "Preferred floater width in points." },
    height: { type: "number", description: "Preferred floater height in points." }
  },
  [],
  async (args) => gated("pip_open", args, async () => {
    const res = await daemon.call("pip_open", {
      window_id: args.window_id, pid: args.pid, bundle: args.bundle,
      title: args.title, width: args.width, height: args.height
    });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  })
);

defTool(
  "pip_close",
  "Close a PiP mirror. Pass window_id for one session, or all:true to close every session.",
  {
    window_id: { type: "integer", description: "CGWindowID whose PiP session to close." },
    all: { type: "boolean", description: "Close all PiP sessions." }
  },
  [],
  async (args) => gated("pip_close", args, async () => {
    const res = await daemon.call("pip_close", { window_id: args.window_id, all: args.all });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  })
);

defTool(
  "pip_status",
  "List live PiP mirror sessions (window_id, floater frame, first-frame status, frame age) and currently armed windows.",
  {},
  [],
  async () => {
    const res = await daemon.call("pip_status", {});
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "pip_arm",
  "Arm a window so that when the USER minimizes it, a PiP mirror pops open automatically (then disarms). Edge-triggered: the arm only fires on the minimize transition — an already-minimized window must be restored and minimized again to trigger. This is the 'minimize → floating mirror' product gesture; nothing happens until the user minimizes. Direct path needs window_id AND pid; or resolve by bundle/pid + title.",
  {
    window_id: { type: "integer", description: "CGWindowID to arm (requires pid too on the direct path)." },
    bundle: { type: "string", description: "Bundle id — resolves the app and picks its window (title filters)." },
    pid: { type: "integer", description: "Process id of the window's owner." },
    title: { type: "string", description: "Title stored on the arm entry (empty allowed); also filters the app-window pick." }
  },
  [],
  async (args) => gated("pip_arm", args, async () => {
    const res = await daemon.call("pip_arm", {
      window_id: args.window_id, pid: args.pid, bundle: args.bundle, title: args.title
    });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  })
);

defTool(
  "pip_disarm",
  "Remove a PiP arm entry. Pass window_id, or all:true to disarm everything.",
  {
    window_id: { type: "integer", description: "CGWindowID to disarm." },
    all: { type: "boolean", description: "Disarm all armed windows." }
  },
  [],
  async (args) => gated("pip_disarm", args, async () => {
    const res = await daemon.call("pip_disarm", { window_id: args.window_id, all: args.all });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  })
);

// ---------- recording tools (minami-studio extension — no Alma equivalent) ----------
// Not wrapped in gated(): recording targets the screen, not a bundle, so the
// per-app approval gate does not apply.

defTool(
  "record_start",
  "Start recording the screen (or one window) to an mp4 via ScreenCaptureKit, cursor EXCLUDED from pixels — cursor moves and clicks are captured separately to <out>.cursor.json for later re-compositing/zoom export. Returns once the first frame is written. Blocks while a recording is already active.",
  {
    out: { type: "string", description: "Output path, .mp4 or .mov (required)." },
    window_id: { type: "integer", description: "Record only this CGWindowID's on-screen rect (display-relative crop; occluded pixels show whatever is on top). Omit for full display." },
    display_id: { type: "integer", description: "CGDirectDisplayID to record. Default: main display." },
    fps: { type: "integer", description: "Capture rate, 1–120. Default 60." },
    audio: { type: "boolean", description: "Also record system audio inline. Default false." },
    os_cursor: { type: "boolean", description: "Track the real OS cursor in telemetry (moves + clicks). Default true. Set false for agent-only telemetry — the exported cursor overlay then follows only the agent's actions, never the user's mouse." }
  },
  ["out"],
  async (args) => {
    const res = await daemon.call("record_start", {
      out: args.out, window_id: args.window_id, display_id: args.display_id,
      fps: args.fps, audio: args.audio, os_cursor: args.os_cursor
    });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "record_stop",
  "Stop the active recording, finalize the mp4 (moov atom) and write the cursor telemetry sidecar. Returns {out, frames, duration_s, cursor_telemetry}.",
  {},
  [],
  async () => {
    const res = await daemon.call("record_stop", {});
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "record_pause",
  "Pause the active recording — captured frames are dropped and the timeline is rebased so the pause never appears in the file.",
  {},
  [],
  async () => {
    const res = await daemon.call("record_pause", {});
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "record_resume",
  "Resume a paused recording.",
  {},
  [],
  async () => {
    const res = await daemon.call("record_resume", {});
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "record_status",
  "Report the active recording: {recording, paused, out, frames, elapsed_ms, width, height, cursor_tap}. Returns {recording:false} when idle.",
  {},
  [],
  async () => {
    const res = await daemon.call("record_status", {});
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "zoom_export",
  "Post-process a recording into an auto-zoomed mp4: decodes `in`, clusters click telemetry into zoom regions (or uses explicit `regions`), renders the Recordly-style camera (easeOutZoom, focus-anchored affine, cursor-follow safe zone, chained pan), re-draws the cursor + click rings, and writes `out`. Blocks until finished — expect ~realtime on 60fps sources.",
  {
    in: { type: "string", description: "Source recording path (mp4/mov) written by record_stop." },
    out: { type: "string", description: "Destination path (.mp4 recommended)." },
    cursor: { type: "string", description: "Cursor telemetry JSON. Default: <in>.cursor.json." },
    depth: { type: "integer", description: "Zoom depth 1–6 (1.25×–5×). Default 3 = 1.8×." },
    auto_zoom: { type: "boolean", description: "Cluster clicks into regions automatically (default true)." },
    regions: {
      type: "array",
      description: "Explicit regions — overrides auto_zoom. Each: {start_ms,end_ms,cx,cy,depth?}.",
      items: { type: "object" }
    },
    show_cursor: { type: "boolean", description: "Draw the cursor overlay (default true)." },
    click_rings: { type: "boolean", description: "Draw expanding rings at clicks (default true)." },
    motion_blur: { type: "boolean", description: "Directional/radial blur during camera moves (default true)." },
    audio: { type: "boolean", description: "Pass the source's audio track through untouched (default true)." }
  },
  ["in", "out"],
  async (args) => {
    const res = await daemon.call("zoom_export", {
      in: args.in, out: args.out, cursor: args.cursor, depth: args.depth,
      auto_zoom: args.auto_zoom, regions: args.regions,
      show_cursor: args.show_cursor, click_rings: args.click_rings,
      motion_blur: args.motion_blur, audio: args.audio
    });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

defTool(
  "zoom_suggest",
  "Dry-run auto-zoom: returns the click count and zoom regions the exporter would use for `in` (or a `cursor` JSON). Useful to inspect/edit before passing explicit `regions` to zoom_export.",
  {
    in: { type: "string", description: "Recording path; telemetry defaults to <in>.cursor.json." },
    cursor: { type: "string", description: "Cursor telemetry JSON directly (overrides `in`)." },
    depth: { type: "integer", description: "Zoom depth 1–6 for suggested regions. Default 3." }
  },
  [],
  async (args) => {
    const res = await daemon.call("zoom_suggest", {
      in: args.in, cursor: args.cursor, depth: args.depth
    });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);

// ---------- minimal MCP stdio transport ----------
// Auto-detects framing like the SDK's StdioServerTransport: accepts both
// Content-Length headers and bare newline-delimited JSON (what codex sends),
// and replies in the framing the client used.

const SERVER_INFO = { name: "minami-studio", version: "1.0.0" };
const INSTRUCTIONS = [
  "Drive native macOS apps via the Accessibility API and CGEvent.",
  "Start every turn with `get_app_state <bundle|pid>` — it returns a",
  "screenshot + AX tree. Subsequent action tools automatically return",
  "a fresh post-action screenshot so you can see the effect.",
  'Prefer element refs (e.g. "e7") when the AX tree has them; fall',
  "back to pixel coordinates when elements is empty (Qt/custom apps).",
  "HARD RULE: never take the user's foreground app, key window, or cursor — not even momentarily,",
  "and never by bringing a window forward and putting it back. Every verb works on a background app; nothing here needs the foreground.",
  "Never activate, raise, or otherwise front an app on your own initiative. If an action reports it could not be delivered, tell the user — do not reach for the foreground to force it through.",
  "PiP mirrors: pip_open/pip_close/pip_status/pip_arm/pip_disarm manage live floating window mirrors; pip_arm makes the user's own minimize gesture spawn a mirror.",
  "Session recording: record_start{out,window_id?|display_id?,fps?,audio?}/record_stop/record_pause/record_resume/record_status capture the screen to mp4 without the OS cursor; cursor telemetry lands in <out>.cursor.json. zoom_export{in,out,...} re-renders it with auto-zoom + cursor overlay; zoom_suggest previews the regions.",
  "Field-tested playbooks: call the Skill tool with a computer-use doc name, or read skill://computer-use resources."
].join(" ");

const toolsByName = new Map(tools.map((t) => [t.name, t]));

/* ------------------- skills via MCP (minami-browser mcp-skill-pattern) ---
 * tools give capability; this channel gives progressive operation knowledge:
 *   - resources/list+read  → skill://computer-use[/<doc>] (canonical browse)
 *   - Skill tool           → for harnesses that only surface tools; the name
 *     mirrors Alma's agent-side Skill tool (invoke by name, get full doc).
 * skills/<name>/SKILL.md lives in this repo and is read from disk per call —
 * doc updates land without restarting the wrapper or the daemon. */
const SKILLS_DIR = path.join(__dirname, "..", "skills");
const SKILL_NS = "computer-use";

function skillDocs() {
  try {
    return readdirSync(SKILLS_DIR, { withFileTypes: true })
      .filter((d) => d.isDirectory() && existsSync(path.join(SKILLS_DIR, d.name, "SKILL.md")))
      .map((d) => d.name)
      .sort();
  } catch { return []; }
}

function skillIndex() {
  const lines = skillDocs().map((name) => {
    let desc = "";
    try {
      const fm = readFileSync(path.join(SKILLS_DIR, name, "SKILL.md"), "utf8")
        .match(/^description:\s*(.+)$/m);
      if (fm) desc = ` — ${fm[1].trim()}`;
    } catch {}
    return `- ${SKILL_NS}/${name}${desc}`;
  });
  return [
    `# ${SKILL_NS} playbooks`,
    `Field-tested operation procedures (evidence: CX/R3/R5 desktop runs).`,
    `Load a doc by name via the Skill tool or read skill://${SKILL_NS}/<name>.`,
    "",
    ...lines,
    ""
  ].join("\n");
}

function readSkillDoc(doc) {
  let rel = (doc === SKILL_NS || doc === "" || doc == null)
    ? null
    : doc.startsWith(`${SKILL_NS}/`) ? doc.slice(SKILL_NS.length + 1) : doc;
  if (rel == null) return skillIndex();
  if (rel.endsWith(".md")) rel = rel.slice(0, -3);
  if (rel.endsWith("/SKILL")) rel = rel.slice(0, -6);
  if (!/^[A-Za-z0-9_-]+$/.test(rel)) return null;   // no traversal
  try { return readFileSync(path.join(SKILLS_DIR, rel, "SKILL.md"), "utf8"); }
  catch { return null; }
}

const SKILL_TOOL = {
  name: "Skill",
  description:
    "Load a computer-use playbook doc (field-tested procedures per app/scenario). Call without a name to list available docs. Docs also ship as MCP resources under skill://computer-use/.",
  inputSchema: {
    type: "object",
    properties: {
      name: {
        type: "string",
        description: 'Doc name, e.g. "computer-use" (index) or "computer-use/textedit-editing". Omit to list docs.'
      }
    }
  }
};

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

function rpcResult(id, result) { writeMessage({ result, jsonrpc: "2.0", id }); }
function rpcError(id, code, message) { writeMessage({ jsonrpc: "2.0", id, error: { code, message } }); }

// [ALMA] notifications/cancelled suppresses the eventual response — the
// aborted request never emits a late result frame.
const cancelledRequests = new Set();

// [ALMA] zod-equivalent argument validation. The real wrapper bundles the
// MCP SDK + zod; tool args are validated BEFORE the handler runs and a
// failure returns `{isError:true, content:[{text:"MCP error -32602: Input
// validation error: Invalid arguments for tool <name>: <issues JSON>"}]}`.
// Issue shapes below were live-probed against the shipped Alma wrapper
// (Resources/cli/alma-computer-use-mcp.mjs) — keep them byte-identical.
function zodReceived(v) {
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  if (typeof v === "number" && Number.isNaN(v)) return "nan";
  return typeof v;
}
function invalidType(expected, path, v, extra = {}) {
  return {
    expected,
    ...extra,
    code: "invalid_type",
    path,
    message: `Invalid input: expected ${expected}, received ${zodReceived(v)}`
  };
}
function validateField(spec, v, key) {
  if (spec.anyOf) {
    const errors = [];
    for (const member of spec.anyOf) {
      const issues = validateField(member, v, key);
      if (issues.length === 0) return [];
      errors.push(issues.map((i) => ({ ...i, path: [] })));
    }
    return [{ code: "invalid_union", errors, path: [key], message: "Invalid input" }];
  }
  // [ALMA] z.enum fields: ANY non-member — wrong type or undefined — reports
  // invalid_value, never invalid_type (live-probed: button:42, direction
  // missing).
  if (spec.enum) {
    if (!spec.enum.includes(v)) {
      return [{
        code: "invalid_value",
        values: spec.enum,
        path: [key],
        message: `Invalid option: expected one of ${spec.enum.map((e) => JSON.stringify(e)).join("|")}`
      }];
    }
    return [];
  }
  switch (spec.type) {
    case "string":
      if (typeof v !== "string") return [invalidType("string", [key], v)];
      break;
    case "boolean":
      if (typeof v !== "boolean") return [invalidType("boolean", [key], v)];
      break;
    case "number":
      if (typeof v !== "number") return [invalidType("number", [key], v)];
      break;
    case "integer":
      if (typeof v !== "number") return [invalidType("number", [key], v)];
      if (Math.abs(v) > 9007199254740991) {
        return [{
          code: "too_big",
          maximum: 9007199254740991,
          note: "Integers must be within the safe integer range.",
          origin: "int",
          inclusive: true,
          path: [key],
          message: "Too big: expected int to be <=9007199254740991"
        }];
      }
      if (!Number.isInteger(v)) return [invalidType("int", [key], v, { format: "safeint" })];
      break;
    default:
      break;
  }
  if (spec.maximum !== void 0 && typeof v === "number" && v > spec.maximum) {
    return [{
      origin: "number",
      code: "too_big",
      maximum: spec.maximum,
      inclusive: true,
      path: [key],
      message: `Too big: expected number to be <=${spec.maximum}`
    }];
  }
  return [];
}
function validateArgs(tool, args) {
  if (args === void 0) {
    return [invalidType("object", [], args)];
  }
  const issues = [];
  const required = new Set(tool.inputSchema?.required ?? []);
  for (const [key, spec] of Object.entries(tool.inputSchema?.properties ?? {})) {
    const v = args[key];
    if (v === void 0) {
      if (required.has(key)) issues.push(...validateField(spec, v, key));
      continue;
    }
    issues.push(...validateField(spec, v, key));
  }
  return issues;
}

// [ALMA] zod's getParsedType naming for "received X" issue messages.
function zodType(v) {
  if (v === void 0) return "undefined";
  if (v === null) return "null";
  if (Array.isArray(v)) return "array";
  if (typeof v === "number" && Number.isNaN(v)) return "nan";
  return typeof v;
}

async function handleMessage(msg) {
  const { id, method, params } = msg;
  if (id === void 0 || id === null) {
    if (method === "notifications/cancelled" && params?.requestId !== void 0) {
      cancelledRequests.add(params.requestId);
    }
    return;
  }
  try {
    switch (method) {
      case "initialize": {
        // [ALMA] InitializeRequestSchema: params{protocolVersion:string,
        // capabilities:object, clientInfo:object} — each required; missing
        // params → single path ["params"] issue; failures are -32603 with
        // the zod issue array.
        const issues = [];
        if (params === void 0 || params === null || typeof params !== "object" || Array.isArray(params)) {
          issues.push({ expected: "object", code: "invalid_type",
            path: ["params"],
            message: `Invalid input: expected object, received ${zodType(params)}` });
        } else {
          for (const [f, exp] of [["protocolVersion","string"],["capabilities","object"],["clientInfo","object"]]) {
            const v = params[f];
            const ok = exp === "string" ? typeof v === "string"
              : (v !== null && typeof v === "object" && !Array.isArray(v));
            if (!ok) issues.push({ expected: exp, code: "invalid_type",
              path: ["params", f],
              message: `Invalid input: expected ${exp}, received ${zodType(v)}` });
          }
        }
        if (issues.length) { rpcError(id, -32603, JSON.stringify(issues, null, 2)); return; }
        // [ALMA] negotiation: a supported version echoes back; anything
        // else falls to the server's max.
        const SUPPORTED = ["2024-10-07","2024-11-05","2025-03-26","2025-06-18","2025-11-25"];
        const pv = SUPPORTED.includes(params.protocolVersion)
          ? params.protocolVersion : SUPPORTED[SUPPORTED.length - 1];
        rpcResult(id, {
          protocolVersion: pv,
          capabilities: { tools: { listChanged: true }, resources: {} },
          serverInfo: SERVER_INFO,
          instructions: INSTRUCTIONS
        });
        return;
      }
      case "ping":
        rpcResult(id, {});
        return;
      case "tools/list": {
        rpcResult(id, {
          tools: [
            ...tools.map((t) => ({
              name: t.name,
              description: t.description,
              execution: { taskSupport: "forbidden" },
              inputSchema: REAL_SCHEMAS[t.name] ?? t.inputSchema
            })),
            { ...SKILL_TOOL, execution: { taskSupport: "forbidden" } }
          ]
        });
        return;
      }
      case "resources/list": {
        rpcResult(id, {
          resources: [
            { uri: `skill://${SKILL_NS}`, name: `${SKILL_NS} skill index`, mimeType: "text/markdown" },
            ...skillDocs().map((n) => ({
              uri: `skill://${SKILL_NS}/${n}`,
              name: `${SKILL_NS}: ${n}`,
              mimeType: "text/markdown"
            }))
          ]
        });
        return;
      }
      case "resources/read": {
        const uri = params?.uri;
        const m = typeof uri === "string"
          ? uri.match(/^skill:\/\/computer-use(?:\/(.*))?$/)
          : null;
        const text = m ? readSkillDoc(m[1] ?? SKILL_NS) : null;
        if (text == null) { rpcError(id, -32002, `Unknown resource: ${uri}`); return; }
        rpcResult(id, { contents: [{ uri, mimeType: "text/markdown", text }] });
        return;
      }
      case "tools/call": {
        if (params === void 0 || params === null || typeof params !== "object" || Array.isArray(params)) {
          rpcError(id, -32603, JSON.stringify([{ expected: "object",
            code: "invalid_type", path: ["params"],
            message: `Invalid input: expected object, received ${zodType(params)}` }], null, 2));
          return;
        }
        const name = params.name;
        if (typeof name !== "string") {
          rpcError(id, -32603, JSON.stringify([{ expected: "string",
            code: "invalid_type", path: ["params", "name"],
            message: `Invalid input: expected string, received ${zodType(name)}` }], null, 2));
          return;
        }
        if (name === "Skill") {
          const requested = params.arguments?.name;
          const text = readSkillDoc(requested ?? "");
          if (text == null) {
            rpcResult(id, { content: [textBlock(`Unknown skill doc: ${requested}`)], isError: true });
          } else {
            rpcResult(id, { content: [textBlock(text)] });
          }
          return;
        }
        const tool = toolsByName.get(name);
        if (!tool) {
          rpcResult(id, { content: [textBlock(`MCP error -32602: Tool ${name} not found`)], isError: true });
          return;
        }
        if (params.arguments !== void 0
            && (typeof params.arguments !== "object"
                || params.arguments === null
                || Array.isArray(params.arguments))) {
          // [ALMA] request-schema rejection happens before tool validation —
          // it surfaces as a JSON-RPC error, not an isError tool result.
          rpcError(id, -32602, JSON.stringify([{
            expected: "record", code: "invalid_type",
            path: ["params", "arguments"],
            message: `Invalid input: expected record, received ${zodType(params.arguments)}`
          }], null, 2));
          return;
        }
        const issues = params.arguments === void 0
          ? [{ expected: "object", code: "invalid_type", path: [],
               message: "Invalid input: expected object, received undefined" }]
          : validateArgs(tool, params.arguments);
        if (issues.length > 0) {
          rpcResult(id, {
            content: [textBlock(
              `MCP error -32602: Input validation error: Invalid arguments for tool ${name}: ${JSON.stringify(issues, null, 2)}`
            )],
            isError: true
          });
          return;
        }
        try {
          const result = await tool.handler(params?.arguments ?? {});
          if (!cancelledRequests.delete(id)) rpcResult(id, result);
        } catch (e) {
          if (!cancelledRequests.delete(id)) {
            rpcResult(id, { content: [textBlock(e instanceof Error ? e.message : String(e))], isError: true });
          }
        }
        return;
      }
      default:
        rpcError(id, -32601, "Method not found");
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
  process.stderr.write("[minami-cu-mcp] ready on stdio\n");
}
main();
