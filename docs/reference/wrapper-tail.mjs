      return "down";
    case "l":
    case "left":
      return "left";
    default:
      return "right";
  }
}
var KEYSYM_TO_ALMA = {
  control_l: "ctrl",
  control_r: "ctrl",
  control: "ctrl",
  ctrl: "ctrl",
  alt_l: "opt",
  alt_r: "opt",
  alt: "opt",
  option: "opt",
  opt: "opt",
  meta_l: "cmd",
  meta_r: "cmd",
  super_l: "cmd",
  super_r: "cmd",
  super: "cmd",
  command: "cmd",
  cmd: "cmd",
  shift_l: "shift",
  shift_r: "shift",
  shift: "shift",
  return: "return",
  enter: "return",
  tab: "tab",
  escape: "esc",
  esc: "esc",
  space: "space",
  backspace: "delete",
  delete: "delete",
  prior: "pageup",
  next: "pagedown",
  page_up: "pageup",
  page_down: "pagedown",
  home: "home",
  end: "end",
  up: "up",
  down: "down",
  left: "left",
  right: "right"
};
function normalizeKeyChord(key) {
  return key.split("+").map((part) => part.trim()).filter(Boolean).map((part) => KEYSYM_TO_ALMA[part.toLowerCase()] ?? part.toLowerCase()).join("+");
}
var PlaybookOnce = class {
  sent = /* @__PURE__ */ new Set();
  /** True the first time an app is seen, false thereafter. */
  shouldSend(appKey) {
    if (this.sent.has(appKey)) return false;
    this.sent.add(appKey);
    return true;
  }
  reset() {
    this.sent.clear();
  }
};
function renderAppStateText(elements, opts = {}) {
  const refByIndex = [...opts.carryOver ?? []];
  const indexOfRef = /* @__PURE__ */ new Map();
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
    const label = [el.title, el.description, el.value, el.role_description].map((v) => typeof v === "string" ? v.trim() : "").find((v) => v.length > 0);
    const bounds = el.bounds;
    const pos = bounds ? ` @${Math.round(bounds.x ?? 0)},${Math.round(bounds.y ?? 0)} ${Math.round(bounds.w ?? 0)}x${Math.round(bounds.h ?? 0)}` : "";
    const flags = [el.focused === true ? "focused" : "", el.enabled === false ? "disabled" : ""].filter(Boolean).join(",");
    lines.push(`[${index}] ${role}${label ? ` "${label}"` : ""}${pos}${flags ? ` (${flags})` : ""}`);
  }
  const parts = [];
  if (opts.instructions) parts.push(`<app_specific_instructions>
${opts.instructions}
</app_specific_instructions>`);
  if (opts.diffNote) parts.push(opts.diffNote);
  parts.push(lines.join("\n"));
  return { text: parts.join("\n"), refByIndex };
}

// electron/mcp-servers/computer-use.ts
import { spawn } from "node:child_process";
import { createConnection } from "node:net";
import { existsSync, mkdirSync } from "node:fs";
import { randomBytes, createHash } from "node:crypto";
import * as path from "node:path";
import * as os from "node:os";

// electron/skills/bundled/computer-use/playbooks/AppleMusic.md
var AppleMusic_default = '# Music.app Playbook\n\nBundle id: `com.apple.Music`.\n\n## Searching\n\nClick the Search row in the sidebar, then `set_value` on the search text\nfield. The search submits automatically. If results don\'t appear, re-run\n`get_app_state` \u2014 they may still be loading.\n\nIf the search field isn\'t visible, scroll the sidebar to the top. The\n`filterField` (a search field shown when clicking `filterBtn`) is for\nfiltering the current view, not the whole library or Apple Music catalog.\n\nTo find a playlist, either perform a search (with "Your Library" selected in\nsearch results) or scroll the sidebar down.\n\n## Navigation\n\nScroll elements with their `Scroll Up` / `Scroll Down` AX actions, or\n`alma cu scroll <ref> down --pages=N`. For speed, dispatch multiple scroll\ncalls in parallel.\n\nAfter selecting a sidebar item, you may be drilled into a sub-view. Use the\n`backBtn` to return to the root.\n\n## Playback\n\n- **Play a track**: double-click it (`alma cu click <ref> --clicks=2`).\n- **Queue ("Playing Next")**: click the `More` button, then `Play Next` or\n  `Play Last`. If `More` isn\'t available, `perform_secondary_action` (right\n  click) on the track.\n- **Play/pause toggle**: `alma cu press_key space --pid <music-pid>` after a\n  click on any track has established focus.\n';

// electron/skills/bundled/computer-use/playbooks/Spotify.md
var Spotify_default = '# Spotify Playbook\n\nBundle id: `com.spotify.client`.\n\n## Playback\n\nSpotify doesn\'t immediately update UI state after a playback click. Rather\nthan re-dispatching the action, re-run `get_app_state` first \u2014 it often took\neffect already. Don\'t sleep; just re-check on the next turn.\n\n## Searching\n\nMake sure the search field is focused before `press_key Return`. Pressing\nReturn without the search field focused may toggle playback instead.\n\n## General navigation\n\nSpotify is not fully local. After a search or navigation, the "no results"\nstate may flash momentarily while the network resolves. Re-run\n`get_app_state` before changing course.\n\nSpotify is Electron \u2014 the first `get_app_state` call enables\n`AXEnhancedUserInterface` / `AXManualAccessibility`; the second call usually\nreturns a fuller tree.\n\n## Link rewrites\n\nUse canonical `open.spotify.com/...` URLs, not `xpui.app.spotify.com/...`.\nOnly use links verbatim from the UI. IDs are valid only with their type \u2014\ndon\'t turn an "album" URL into a "track" URL.\n';

// electron/skills/bundled/computer-use/playbooks/Notion.md
var Notion_default = '# Notion Playbook\n\nBundle id: `notion.id`.\n\n## Editing documents\n\nA Notion page is a list of "blocks". Blocks can be selected. To edit a\nselected block\'s content, `press_key Return`.\n\nNew documents start with an empty title ("New page" placeholder). Press\n`Return` after typing the title to begin editing the body. To select the\ntitle field, click its inner text element.\n\nInsert one line of text at a time and `press_key Return` between lines. You\ncan parallelise the pair (type_text + press_key) across multiple lines.\n\nFormat with markdown syntax. Two Notion-specific twists:\n- `>` inserts a toggle checklist\n- `|` inserts a block quote\n\n## List items\n\nPressing `Return` at the end of a list item creates a new list item with the\nappropriate bullet. Just type the content \u2014 don\'t re-insert the bullet.\nTo end a list, press `Return` on an empty list item.\n\n## Selection\n\n`cmd+a` behaves differently based on state:\n- Empty block + cursor inside: selects all blocks in the document.\n- Nonempty block: selects all content within that block.\n- Full block already selected: a second `cmd+a` selects all blocks.\n\n## Placeholder text\n\nEmpty blocks show placeholder text: `New page`, `List`, `To-do`, `Write, \u2026`.\nTyping replaces the placeholder \u2014 don\'t try to select and delete it.\n\n## Code and quote blocks\n\n- Inside **code** blocks: `Return` inserts a newline INSIDE; `shift+Return`\n  exits the block.\n- Inside **quote** blocks: `Return` exits; `shift+Return` inserts a newline\n  INSIDE.\n\n## Cursor navigation\n\nTo jump to the top/bottom of the doc: focus the body, press `cmd+a` twice,\nthen `Up` / `Down`, then `Return` to edit the topmost / bottommost block.\n\nTo jump to a specific block: press `cmd+a` twice (selects all blocks),\nthen click the target block once.\n\nAlternatively: `cmd+f` \u2192 `type_text <term>` \u2192 `press_key Escape` positions\nthe cursor on the found text.\n';

// electron/skills/bundled/computer-use/playbooks/Clock.md
var Clock_default = "# Clock Playbook\n\nBundle id: `com.apple.clock`.\n\nFour tabs: **World Clock**, **Alarm**, **Stopwatch**, **Timer**. Switch by\nclicking the toolbar tab.\n\n## World Clock \u2014 add a city\n\n1. Click the toolbar tab `World Clock`.\n2. Determine the existing clocks by reading the IDs of container elements\n   with a single text child. **Ignore** the locations under the heading\n   \"world map\" \u2014 that list is stale after removals.\n3. If the desired city isn't listed, click the toolbar button described\n   `Add a clock`.\n4. In the sheet that appears:\n   - `set_value` on the search text field.\n   - Click the city row to add and close the sheet.\n\n## Timer \u2014 start one\n\n1. Click the toolbar tab `Timer`.\n2. Read the current timer state from the Start/Stop button.\n   - If **Running** or **Paused**: ask the user whether to cancel the\n     existing timer first.\n   - If **Stopped**: continue.\n3. Convert the requested duration into three integers:\n   - hours: 0\u201323\n   - minutes: 0\u201359\n   - seconds: 0\u201359\n   Reject durations longer than 23:59:59 \u2014 Clock.app can't express them.\n   Examples:\n   - `90 seconds` \u2192 0h 1m 30s\n   - `3600 seconds` \u2192 1h 0m 0s\n4. Find the container with identifier `TimePicker`. It has three slider\n   children: hour, minute, second. For **each**:\n   - `click` to focus.\n   - `type_text <2-digit value>`. **Do not** use `set_value` directly \u2014 the\n     UI requires keystrokes. Max 2 digits; hour \u2264 23, others \u2264 59.\n5. Click the button described `Start`.\n\n## Stopwatch\n\n1. Click the toolbar tab `Stopwatch`.\n2. Read state from the Start/Stop button text.\n   - `Stop`: stopwatch is **Running** \u2014 offer to stop or restart.\n   - `Start`: stopwatch is **Stopped** \u2014 click Start.\n\n## Alarm \u2014 create one\n\n1. Click the toolbar tab `Alarm`.\n2. Click the toolbar button described `Add an alarm`.\n3. In the sheet:\n   - `set_value` on the date-time area using the same format as its current\n     value. Ignore the AM/PM radio \u2014 setting the date-time updates it.\n   - Repeat days: seven toggle buttons labelled S M T W T F S. Click to\n     enable/disable each day.\n   - Other elements: label, sound, snooze toggle.\n4. Click the `Save` button.\n";

// electron/skills/bundled/computer-use/playbooks/Numbers.md
var Numbers_default = '# Numbers Playbook\n\nBundle id: `com.apple.iWork.Numbers`.\n\n## Editing cells\n\n- **Append / edit**: one click on the cell to focus.\n- **Replace**: three clicks on the cell (`alma cu click <ref> --clicks=3`).\n\nFor value entry, dispatch the click and the keyboard write in parallel:\n```bash\nalma cu click <ref> --clicks=3        # select + clear\nalma cu type_text "42" --pid <pid>    # enter the new value\n```\n\n## Batch entry\n\nOne row at a time is fine \u2014 use `\\t` delimiters to jump between columns in\na single `type_text` call. **Don\'t** pack multiple rows into one call;\nNumbers will reject it. Same for multiple formulas \u2014 one per call.\n\n## Notes\n\n- Focused cells sometimes show a "text entry area" with extra formatting\n  (e.g. Markdown-bold table headers). Ignore it.\n- Values save immediately \u2014 no need to press Return unless you\'re done\n  editing the whole spreadsheet.\n- Checkbox cells: type `0` or `1`.\n';

// electron/skills/bundled/computer-use/playbooks/NetEaseMusic.md
var NetEaseMusic_default = '# \u7F51\u6613\u4E91\u97F3\u4E50 Playbook\n\nBundle id: `com.netease.163music` (may vary by version \u2014 check\n`alma cu list_apps | grep -i netease`).\n\n## Why this playbook exists\n\nNetEase Cloud Music is a Qt-based app that exposes **no usable AX tree**.\n`alma cu get_app_state com.netease.163music` returns `elements: []` but\nstill captures a window screenshot and the window\'s pixel bounds. Drive the\napp entirely via pixel-coordinate clicks and keyboard shortcuts.\n\n## Start-of-turn\n\n```bash\nalma cu get_app_state com.netease.163music\n# Read the screenshot at the `screenshot.path` location.\n```\n\nThe screenshot is your only visual anchor \u2014 it will include the exact\nlayout the user sees. All clicks should be pixel coordinates derived from\nthat image.\n\n## Key pixel landmarks (approximate, default window size)\n\nThe app\'s layout:\n- **Left sidebar**: `\u53D1\u73B0`, `\u79C1\u4EBAFM`, `\u89C6\u9891`, `\u670B\u53CB`, `\u76F4\u64AD` etc.\n- **Top of sidebar, "\u63A8\u8350"** submenu: includes `\u4E2A\u6027\u5316\u63A8\u8350`, `\u6BCF\u65E5\u63A8\u8350`,\n  `\u6B4C\u5355`, `\u6392\u884C\u699C`, `\u6B4C\u624B`, `\u6700\u65B0\u97F3\u4E50`.\n- **Main content area**: playlist cards, featured albums.\n- **Bottom bar**: play/pause, next, previous, lyric toggle, volume.\n\nAlways verify from the screenshot \u2014 positions shift with window resize and\ntheme / version updates.\n\n## Play "\u4ECA\u65E5\u63A8\u8350" / "\u6BCF\u65E5\u63A8\u8350"\n\n1. `alma cu get_app_state com.netease.163music`\n2. Read the screenshot. Locate "\u6BCF\u65E5\u63A8\u8350" in the sidebar.\n3. `alma cu click --pixel <x> <y> --pid <netease-pid>` on it.\n4. Re-`get_app_state`. The main area now shows the daily recommendation\n   list.\n5. Locate the play-all button (usually top-left of the track list) and\n   click it by pixel. Or double-click the first track:\n   `alma cu click --pixel <x> <y> --pid <pid> --clicks=2`.\n\n## Play/pause, next, previous\n\nThese are in the bottom bar of the window. Once focus is on the app (click\nanywhere neutral first), the media keys also work:\n- `alma cu press_key space --pid <pid>` \u2014 play/pause\n- `alma cu press_key right --pid <pid>` \u2014 next track (varies by version;\n  may need the bottom-bar next button instead)\n\n## Search\n\n1. Locate the search field at the top of the window (usually a magnifier\n   icon + text box).\n2. `click --pixel` to focus it.\n3. `type_text "<query>" --pid <pid>`.\n4. `press_key Return --pid <pid>`.\n5. Re-`get_app_state`; pick a result from the screenshot.\n\n## Tips\n\n- Some NetEase versions wrap a web view. If so, the `browser` skill may\n  reach more \u2014 but only inside the embedded view, not the native chrome.\n  Stick with pixel clicks for the native window.\n- After a resize, re-take `get_app_state` \u2014 all cached pixel positions are\n  invalid.\n- Coords passed to `click --pixel` are interpreted as **screenshot\n  pixels** (not raw screen points), and the daemon translates them via\n  the mapping from the latest `get_app_state` for the same pid. Always\n  snap right before clicking. The screenshot is downsampled to 1280px\n  wide by default, so on Retina + wide displays "screenshot pixel" and\n  "display point" are not interchangeable \u2014 read coords from the\n  returned image and trust the daemon to translate.\n';

// electron/skills/bundled/computer-use/playbooks/IPhoneMirroring.md
var IPhoneMirroring_default = "### iPhone Mirroring Instructions\n\nAvailable keyboard shortcuts:\n\n- Command-1: Home Screen\n- Command-2: App Switcher\n- Command-3: Spotlight\n\nUse the `scroll` tool for scrolling, not `drag`.\n\nWhen clicking apps on the home screen, click the center of the icon instead of the app label.\n";

// electron/mcp-servers/computer-use.ts
var PLAYBOOKS = {
  "com.apple.Music": AppleMusic_default,
  "com.spotify.client": Spotify_default,
  "notion.id": Notion_default,
  "com.apple.clock": Clock_default,
  "com.apple.iWork.Numbers": Numbers_default,
  "com.netease.163music": NetEaseMusic_default,
  "com.apple.ScreenContinuity": IPhoneMirroring_default
};
function playbookFor(bundle) {
  if (!bundle) return null;
  return PLAYBOOKS[bundle] ?? null;
}
var ALMA_API = process.env.ALMA_API_URL || "http://localhost:23001";
async function checkApproval(bundle, appName) {
  if (!bundle) return { approved: true, strictMode: false };
  try {
    const url2 = new URL(`${ALMA_API}/api/computer-use/check_approval`);
    url2.searchParams.set("bundle", bundle);
    if (appName) url2.searchParams.set("app_name", appName);
    const res = await fetch(url2.toString());
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
  try {
    await fetch(`${ALMA_API}/api/pip/computer-use-activity`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ tool_name: entry.toolName, bundle: entry.bundle, pid: entry.pid })
    });
  } catch {
  }
}
var focusGuardChecked = 0;
var focusGuardWarned = false;
async function focusGuardWarning() {
  const now = Date.now();
  if (now - focusGuardChecked < 3e4) {
    return focusGuardWarned ? FOCUS_GUARD_WARNING : null;
  }
  focusGuardChecked = now;
  try {
    const res = await fetch(`${ALMA_API}/api/computer-use/permissions`);
    const body = await res.json();
    focusGuardWarned = (body.focus_guard?.arm_failures ?? 0) > 0;
  } catch {
    focusGuardWarned = false;
  }
  return focusGuardWarned ? FOCUS_GUARD_WARNING : null;
}
var FOCUS_GUARD_WARNING = "WARNING: focus-steal protection is not active on this Mac, so this action may have pulled the user's frontmost window or keyboard focus away from what they were doing. Tell the user, and ask them to re-grant Accessibility for the Alma Computer Use helper in Settings \u2192 Computer Use (macOS resets that grant for each new build).";
async function logAction(entry) {
  try {
    await fetch(`${ALMA_API}/api/computer-use/action_log`, {
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
  } catch {
  }
}
async function gated(toolName, args, inner) {
  const approval = await checkApproval(args.bundle);
  if (!approval.approved) {
    return {
      content: [
        textBlock(
          `Alma has not yet been approved to drive ${args.bundle}. Ask the user to open Settings \u2192 Computer Use and approve "${args.bundle}", then retry. (Strict-approval mode is currently on.)`
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
function resolveHelperBinary() {
  const override = process.env.ALMA_CU_HELPER;
  if (override && existsSync(override)) return override;
  const candidates = [];
  const rel = path.join("Alma Computer Use.app", "Contents", "MacOS", "AlmaComputerUse");
  const resources = process.env.ALMA_RESOURCES_PATH;
  if (resources) {
    candidates.push(path.join(resources, rel));
  }
  try {
    const self = process.argv[1] || "";
    if (self) {
      const dir = path.dirname(path.resolve(self));
      candidates.push(path.join(dir, "..", "computer-use", rel));
      candidates.push(path.join(dir, "..", "..", "computer-use", rel));
      candidates.push(path.join(dir, "..", "..", "..", "computer-use", rel));
    }
  } catch {
  }
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}
function defaultSocketPath() {
  const base = path.join(os.homedir(), "Library", "Application Support", "Alma");
  mkdirSync(base, { recursive: true });
  const helper = resolveHelperBinary();
  if (!helper) return path.join(base, "computer-use.sock");
  const tag = createHash("sha1").update(helper).digest("hex").slice(0, 8);
  return path.join(base, `computer-use-${tag}.sock`);
}
var DaemonClient = class {
  sock = null;
  child = null;
  readBuffer = Buffer.alloc(0);
  pending = /* @__PURE__ */ new Map();
  connecting = null;
  socketPath = defaultSocketPath();
  async call(cmd, args = {}, timeoutMs = 2e4) {
    await this.ensureConnected();
    return new Promise((resolve2, reject) => {
      const id = randomBytes(8).toString("hex");
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`computer-use ${cmd} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this.pending.set(id, { resolve: resolve2, reject, timer });
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
      } catch {
      }
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
    return new Promise((resolve2, reject) => {
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
        resolve2();
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
    s.on("error", () => {
    });
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
        // Must match CU_DAEMON_IDLE_SECONDS in computerUseManager.ts: whichever
        // process starts the daemon sets its lifetime for both.
        ["daemon", "--socket", this.socketPath, "--idle-seconds", "900"],
        {
          stdio: ["ignore", "pipe", "pipe"],
          detached: false
        }
      );
      child.stderr?.on("data", (buf) => process.stderr.write(buf));
      child.on("exit", (code, sig) => {
        if (this.child === child) this.child = null;
        if (code !== 0 && code !== null) {
          process.stderr.write(`[computer-use-mcp] daemon exited code=${code} sig=${sig}
`);
        }
      });
      this.child = child;
    } catch (e) {
      throw new Error(`Failed to spawn computer-use daemon: ${String(e)}`);
    }
  }
};
var daemon = new DaemonClient();
function normalizeTarget(args) {
  return {
    bundle: typeof args.bundle === "string" && args.bundle.length > 0 ? args.bundle : void 0,
    pid: typeof args.pid === "number" && args.pid > 0 ? Math.floor(args.pid) : void 0,
    window_id: typeof args.window_id === "number" && args.window_id > 0 ? Math.floor(args.window_id) : void 0
  };
}
async function screenshotTarget(target) {
  if (!target || !target.bundle && target.pid === void 0) return null;
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
        // we only need the screenshot, skip the AX walk
        screenshot_max_width: 1280
      },
      3e4
    );
    const shotPath = state.screenshot?.path;
    if (!shotPath) return { type: "text", text: "Post-action screenshot unavailable." };
    const buf = await (await import("node:fs/promises")).readFile(shotPath);
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
var server = new McpServer(
  { name: "alma-computer-use", version: "1.0.0" },
  {
    instructions: [
      "Drive native macOS apps via the Accessibility API and CGEvent.",
      "Start every turn with `get_app_state <bundle|pid>` \u2014 it returns a",
      "screenshot + AX tree. Subsequent action tools automatically return",
      "a fresh post-action screenshot so you can see the effect.",
      'Prefer element refs (e.g. "e7") when the AX tree has them; fall',
      "back to pixel coordinates when elements is empty (Qt/custom apps).",
      "HARD RULE: never take the user's foreground app, key window, or cursor \u2014 not even momentarily,",
      "and never by bringing a window forward and putting it back. Every verb works on a background app; nothing here needs the foreground.",
      "Never activate, raise, or otherwise front an app on your own initiative. If an action reports it could not be delivered, tell the user \u2014 do not reach for the foreground to force it through."
    ].join(" ")
  }
);
server.registerTool(
  "launch_app",
  {
    description: "Launch an app by bundle id WITHOUT bringing it to the foreground. The user's frontmost app stays put; the launched app opens in the background so Alma can drive it. A running app is NEVER touched: there is no way to make this tool bring an app to the foreground, because Alma must never take the foreground away from the user. `activates` only reaches macOS's own cold-launch flag, exactly as double-clicking an app would, and does nothing for an app already running. `get_app_state` auto-launches too, so you usually do not need to call this explicitly.",
    inputSchema: {
      bundle: external_exports3.string().describe("Bundle id, e.g. com.netease.163music."),
      activates: external_exports3.boolean().optional().describe(
        "macOS's own cold-launch activation flag, and only that. Default false. It has no effect on a running app, and nothing here can move the foreground away from the user \u2014 do not reach for it to make an action work."
      )
    }
  },
  async (args, _extra) => {
    return gated("launch_app", args, async () => {
      const res = await daemon.call("launch_app", { bundle: args.bundle, activates: args.activates ?? false });
      return { content: [textBlock(JSON.stringify(res, null, 2))] };
    });
  }
);
var posIntOr = (v, defaultVal) => {
  return typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.floor(v) : defaultVal;
};
server.registerTool(
  "list_apps",
  {
    description: "List running apps plus any used in the last N days (default 14), with usage frequency. Use this when picking which app to drive.",
    inputSchema: {
      days: external_exports3.number().int().max(90).optional().describe("Lookback window for recency (days). Default 14.")
    }
  },
  async (args, _extra) => {
    const res = await daemon.call("list_apps", { days: posIntOr(args.days, 14) });
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);
var targetShape = {
  bundle: external_exports3.string().optional().describe("Bundle id (com.apple.Music). Either bundle or pid is required."),
  pid: external_exports3.number().int().optional().describe("Process id. Either bundle or pid is required."),
  window_id: external_exports3.number().int().optional().describe("Specific CGWindowID (optional).")
};
server.registerTool(
  "get_app_state",
  {
    description: "Snapshot the target app: returns the AX tree + a window screenshot. Call this at the start of every turn before acting. On apps with no AX tree (Qt / custom-drawn) the elements list is empty but the screenshot is still captured so you can click by pixel. AUTO-LAUNCH: if `bundle` is given and the app is not running, it is launched in the BACKGROUND \u2014 the user's frontmost app stays put. Pass `auto_launch: false` to disable.",
    inputSchema: {
      ...targetShape,
      depth: external_exports3.number().int().max(20).optional().describe("AX tree depth. Default 6."),
      interactive_only: external_exports3.boolean().optional().describe("Limit to interactive elements. Default true."),
      screenshot_max_width: external_exports3.number().int().optional().describe("Downsample width for the screenshot (default 1280)."),
      auto_launch: external_exports3.boolean().optional().describe("Auto-launch the app in the background if not running. Default true.")
    }
  },
  async (args, _extra) => {
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
      content.push(textBlock(`## App playbook (auto-injected)

${playbook}`));
    }
    const body = { ...res };
    delete body.screenshot;
    content.push(textBlock(JSON.stringify(body, null, 2)));
    if (res.screenshot?.path) {
      try {
        const buf = await (await import("node:fs/promises")).readFile(res.screenshot.path);
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
var clickInput = {
  ref: external_exports3.string().optional().describe('Element ref from get_app_state (e.g. "e7"). Either ref or {x, y} is required.'),
  x: external_exports3.number().optional().describe("X coordinate (screenshot pixel by default; see coord_space)."),
  y: external_exports3.number().optional().describe("Y coordinate (screenshot pixel by default; see coord_space)."),
  coord_space: external_exports3.enum(["screenshot", "screen"]).optional().describe('"screenshot" (default) \u2014 coords are pixels in the last get_app_state screenshot. "screen" \u2014 raw screen points.'),
  button: external_exports3.enum(["left", "right", "middle"]).optional().describe("Mouse button. Default left."),
  click_count: external_exports3.number().int().max(3).optional().describe("1=single, 2=double, 3=triple. Default 1."),
  strategy: external_exports3.enum(["auto", "physical", "ax"]).optional().describe("auto (default) prefers CGEvent if bounds known."),
  ...targetShape
  // used to pick the app for the post-action screenshot
};
server.registerTool(
  "click",
  {
    description: "Click an element by ref (from get_app_state) or at absolute pixel (x, y) coordinates. Returns a post-action screenshot of the target app so you can see the result.",
    inputSchema: clickInput
  },
  async (args, _extra) => gated("click", args, async () => {
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
server.registerTool(
  "perform_secondary_action",
  {
    description: "Right-click / open context menu on an element or at a pixel. Returns a post-action screenshot.",
    inputSchema: {
      ref: external_exports3.string().optional(),
      x: external_exports3.number().optional().describe("X coordinate (screenshot pixel by default)."),
      y: external_exports3.number().optional().describe("Y coordinate (screenshot pixel by default)."),
      coord_space: external_exports3.enum(["screenshot", "screen"]).optional(),
      ...targetShape
    }
  },
  async (args, _extra) => gated("perform_secondary_action", args, async () => {
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
server.registerTool(
  "drag",
  {
    description: 'Mouse drag from one point to another. Coordinates default to screenshot pixels; pass coord_space="screen" for raw points. Returns a post-action screenshot.',
    inputSchema: {
      start_x: external_exports3.number(),
      start_y: external_exports3.number(),
      end_x: external_exports3.number(),
      end_y: external_exports3.number(),
      coord_space: external_exports3.enum(["screenshot", "screen"]).optional(),
      button: external_exports3.enum(["left", "right", "middle"]).optional(),
      ...targetShape
    }
  },
  async (args, _extra) => gated("drag", args, async () => {
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
    return respond(`drag ok (${args.start_x},${args.start_y} \u2192 ${args.end_x},${args.end_y})`, target);
  })
);
server.registerTool(
  "type_text",
  {
    description: "Text entry into the target app. By default this uses AX insertion when ref is provided, physical key events translated from the current keyboard layout, and Unicode CGEvents as fallback. Target must already have keyboard focus \u2014 click it first. Returns a post-action screenshot.",
    inputSchema: {
      text: external_exports3.string(),
      ref: external_exports3.string().optional().describe("Optional text-field ref from get_app_state. When present, auto mode inserts via AX instead of keystrokes."),
      input_method: external_exports3.enum(["auto", "physical", "unicode", "ax"]).optional().describe("auto (default), physical key events, unicode CGEvents, or AX insertion when ref is provided."),
      ...targetShape
    }
  },
  async (args, _extra) => gated("type_text", args, async () => {
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
server.registerTool(
  "press_key",
  {
    description: "Press a key or combo in xdotool syntax \u2014 cmd+s, ctrl+shift+t, Return, Escape, F1, cmd+opt+esc. Modifiers: cmd|command|meta, ctrl|control, shift, opt|option|alt, fn.",
    inputSchema: {
      key: external_exports3.string().describe('xdotool-style key combo, e.g. "cmd+s" or "Return"'),
      ...targetShape
    }
  },
  async (args, _extra) => gated("press_key", args, async () => {
    const target = normalizeTarget(args);
    const res = await daemon.call("press_key", { key: args.key, pid: target.pid, bundle: target.bundle });
    if (res?.delivered === false) {
      const note = res.delivery_note ?? "the target app did not accept the key event";
      return respond(`NOT delivered: pressed ${args.key} was suppressed \u2014 ${note}`, target);
    }
    if (res?.via === "menu_ax_press") {
      return respond(`pressed ${args.key} (invoked its menu item in the background; the user's focus was untouched)`, target);
    }
    return respond(`pressed ${args.key}`, target);
  })
);
server.registerTool(
  "scroll",
  {
    description: "Scroll an element (AX-based). Returns a post-action screenshot.",
    inputSchema: {
      ref: external_exports3.string(),
      direction: external_exports3.enum(["up", "down", "left", "right"]),
      pages: external_exports3.number().int().max(20).optional(),
      ...targetShape
    }
  },
  async (args, _extra) => gated("scroll", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("scroll", {
      ref: args.ref,
      direction: args.direction,
      pages: posIntOr(args.pages, 1),
      show_cursor: true
    });
    return respond(`scrolled ${args.direction} \xD7${posIntOr(args.pages, 1)}`, target);
  })
);
server.registerTool(
  "set_value",
  {
    description: "Directly set AXValue on an element (sliders, steppers, text fields). Skips keystroke simulation. Value can be a string, number, or boolean.",
    inputSchema: {
      ref: external_exports3.string(),
      value: external_exports3.union([external_exports3.string(), external_exports3.number(), external_exports3.boolean()]),
      ...targetShape
    }
  },
  async (args, _extra) => gated("set_value", args, async () => {
    const target = normalizeTarget(args);
    await daemon.call("set_value", { ref: args.ref, value: args.value });
    return respond(`set ${args.ref} = ${JSON.stringify(args.value)}`, target);
  })
);
server.registerTool(
  "select_text",
  {
    description: "Select a run of text inside an editable element \u2014 or place the cursor immediately before/after it \u2014 without touching the rest of the field. Use this instead of set_value when the user's existing text must survive, and instead of faking a selection with key chords. Pass prefix/suffix when the same text appears more than once.",
    inputSchema: {
      ref: external_exports3.string().describe("Element index/ref from the latest get_app_state."),
      text: external_exports3.string().describe("Text to locate within the editable element."),
      prefix: external_exports3.string().optional().describe("Text immediately before the target, to disambiguate repeats."),
      suffix: external_exports3.string().optional().describe("Text immediately after the target, to disambiguate repeats."),
      selection_type: external_exports3.enum(["text", "cursor_before", "cursor_after"]).optional().describe("Select the text itself (default), or collapse the cursor before/after it."),
      ...targetShape
    }
  },
  async (args, _extra) => gated("select_text", args, async () => {
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
var playbookOnce = new PlaybookOnce();
var skyIndexMap = /* @__PURE__ */ new Map();
function skyRefFor(app, index) {
  const refs = skyIndexMap.get(app);
  if (!refs || index < 0 || index >= refs.length) {
    throw new Error(`element_index ${index} is not valid for "${app}" \u2014 call sky_get_app_state first, then use an index from its text.`);
  }
  return refs[index];
}
server.registerTool(
  "sky_list_apps",
  {
    description: "Codex-compatible: list apps that can be targeted by the window API. Returns {id, displayName, isRunning, lastUsedDate, useCount}.",
    inputSchema: {}
  },
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
server.registerTool(
  "sky_get_app_state",
  {
    description: "Codex-compatible: capture the current state, screenshot and accessibility text for an app window. Returns {app, screenshot:{url}|null, text}; the text numbers each element so you can pass element_index to the other sky_ verbs.",
    inputSchema: {
      app: external_exports3.string().describe("App id, display name or process name from sky_list_apps."),
      disableDiff: external_exports3.boolean().optional().describe("Return the full accessibility tree instead of a diff from the previous tree.")
    }
  },
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
    const url2 = shot?.data_url ?? shot?.url;
    return {
      content: [textBlock(JSON.stringify({ app: args.app, screenshot: url2 ? { url: url2 } : null, text }, null, 2))]
    };
  })
);
server.registerTool(
  "sky_click",
  {
    description: "Codex-compatible: click an indexed element from the latest sky_get_app_state, or a coordinate in the app window.",
    inputSchema: {
      app: external_exports3.string(),
      element_index: external_exports3.number().int().optional(),
      x: external_exports3.number().optional().describe("X coordinate in the app-window screenshot."),
      y: external_exports3.number().optional().describe("Y coordinate in the app-window screenshot."),
      click_count: external_exports3.number().int().optional(),
      mouse_button: external_exports3.enum(["left", "right", "middle", "l", "r", "m"]).optional()
    }
  },
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
server.registerTool(
  "sky_press_key",
  {
    description: "Codex-compatible: press a `+`-separated keysym chord (Return, Tab, Control_L+a, Super_L+d) in an app window.",
    inputSchema: { app: external_exports3.string(), key: external_exports3.string() }
  },
  async (args) => gated("sky_press_key", { bundle: args.app }, async () => {
    const res = await daemon.call("press_key", { key: normalizeKeyChord(args.key), bundle: args.app });
    const target = normalizeTarget({ bundle: args.app });
    if (res?.delivered === false) {
      const note = res.delivery_note ?? "the target app did not accept the key event";
      return respond(`NOT delivered: pressed ${args.key} was suppressed \u2014 ${note}`, target);
    }
    if (res?.via === "menu_ax_press") {
      return respond(`pressed ${args.key} (invoked its menu item in the background; the user's focus was untouched)`, target);
    }
    return respond(`pressed ${args.key}`, target);
  })
);
server.registerTool(
  "sky_type_text",
  {
    description: "Codex-compatible: type text into the current focus in an app window.",
    inputSchema: { app: external_exports3.string(), text: external_exports3.string() }
  },
  async (args) => gated("sky_type_text", { bundle: args.app }, async () => {
    await daemon.call("type_text", { text: args.text, bundle: args.app });
    return respond(`typed ${args.text.length} chars`, normalizeTarget({ bundle: args.app }));
  })
);
server.registerTool(
  "sky_scroll",
  {
    description: "Codex-compatible: scroll an indexed element in an app window.",
    inputSchema: {
      app: external_exports3.string(),
      element_index: external_exports3.number().int(),
      direction: external_exports3.enum(["up", "down", "left", "right", "u", "d", "l", "r"]),
      pages: external_exports3.number().optional()
    }
  },
  async (args) => gated("sky_scroll", { bundle: args.app }, async () => {
    await daemon.call("scroll", {
      ref: skyRefFor(args.app, args.element_index),
      direction: normalizeDirection(args.direction),
      pages: args.pages ?? 1
    });
    return respond("scrolled", normalizeTarget({ bundle: args.app }));
  })
);
server.registerTool(
  "sky_set_value",
  {
    description: "Codex-compatible: replace the value of an indexed editable element.",
    inputSchema: { app: external_exports3.string(), element_index: external_exports3.number().int(), value: external_exports3.string() }
  },
  async (args) => gated("sky_set_value", { bundle: args.app }, async () => {
    await daemon.call("set_value", { ref: skyRefFor(args.app, args.element_index), value: args.value });
    return respond("set value", normalizeTarget({ bundle: args.app }));
  })
);
server.registerTool(
  "sky_drag",
  {
    description: "Codex-compatible: drag from one app-window coordinate to another.",
    inputSchema: { app: external_exports3.string(), from_x: external_exports3.number(), from_y: external_exports3.number(), to_x: external_exports3.number(), to_y: external_exports3.number() }
  },
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
server.registerTool(
  "sky_perform_secondary_action",
  {
    description: "Codex-compatible: invoke a secondary accessibility action on an indexed element.",
    inputSchema: { app: external_exports3.string(), element_index: external_exports3.number().int(), action: external_exports3.string() }
  },
  async (args) => gated("sky_perform_secondary_action", { bundle: args.app }, async () => {
    await daemon.call("perform_secondary_action", { ref: skyRefFor(args.app, args.element_index), action: args.action });
    return respond(`performed ${args.action}`, normalizeTarget({ bundle: args.app }));
  })
);
server.registerTool(
  "sky_select_text",
  {
    description: "Codex-compatible: select matching text in an indexed editable element, or place the cursor before/after it.",
    inputSchema: {
      app: external_exports3.string(),
      element_index: external_exports3.number().int(),
      text: external_exports3.string(),
      prefix: external_exports3.string().optional(),
      suffix: external_exports3.string().optional(),
      selection_type: external_exports3.enum(["text", "cursor_before", "cursor_after"]).optional()
    }
  },
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
server.registerTool(
  "permissions",
  {
    description: "Check whether Alma Computer Use has Accessibility + Screen Recording permissions.",
    inputSchema: {}
  },
  async (_args, _extra) => {
    const res = await daemon.call("permissions");
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);
server.registerTool(
  "grant",
  {
    description: "Trigger the macOS Accessibility permission dialog. Caller should poll `permissions` after.",
    inputSchema: {}
  },
  async (_args, _extra) => {
    const res = await daemon.call("grant");
    return { content: [textBlock(JSON.stringify(res, null, 2))] };
  }
);
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  process.stderr.write("[alma-cu-mcp] ready on stdio\n");
}
main().catch((err) => {
  process.stderr.write(`[alma-cu-mcp] fatal: ${err instanceof Error ? err.stack || err.message : String(err)}
`);
  process.exit(1);
});
