# agent-computer-use

Independent, MCP-native reproduction of Alma's macOS Computer Use surface.
Behavior is benchmarked against Alma .153 (disassembly + live probes) and the
.164 contract package — same three-layer chain, same wire formats, same error
text. No added features.

```
Agent (Codex CLI / any MCP client)
  └── stdio MCP ── bin/agent-computer-use-mcp (node, zero-dep)
        ├── optional host calls → AGENT_CU_HOST_URL (fail-open)
        └── unix socket NDJSON ── bin/agent-computer-use (Swift daemon)
              └── Accessibility API / CGEvent / CGWindowList / TCC
```

## Build & install

```sh
./scripts/build.sh            # swift build + stage bin/agent-computer-use
./scripts/install-codex.sh    # codex mcp add agent_computer_use
./scripts/smoke.sh            # initialize → tools/list(23) → permissions → list_apps
```

The MCP wrapper auto-spawns the daemon (`daemon --socket <path> --idle-seconds 900`)
on first call; socket lives at
`~/Library/Application Support/agent-computer-use/computer-use-<hash>.sock`.

For non-Codex harnesses: stdio command = `<repo>/bin/agent-computer-use-mcp`
(accepts both Content-Length headers and bare-JSONL framing, replies in kind).

## Tool surface (23 — verbatim parity)

| plain (11) | sky_* Codex-compat (10) | diag (2) |
|---|---|---|
| launch_app, list_apps, get_app_state, click, perform_secondary_action, drag, type_text, press_key, scroll, set_value, select_text | sky_list_apps, sky_get_app_state, sky_click, sky_press_key, sky_type_text, sky_scroll, sky_set_value, sky_drag, sky_perform_secondary_action, sky_select_text | permissions, grant |

Not exposed (Alma protocol-level, not MCP-reachable): `intent`, `open_url`,
`lens`, `mcp_*` (native HTTP MCP), `appshot_*`, `raise`, `remote_input`.
The daemon registry carries all 45 command names — unimplemented ones return
Alma's own `invalid_arg`/`not_implemented` shape.

## Picture-in-picture (daemon protocol, implemented)

`pip_open {window_id, title?, width?, height?}` opens a live mirror of a
specific CG window in an always-on-top non-activating `NSPanel`
(ScreenCaptureKit `SCStream` → `AVSampleBufferDisplayLayer`, 30fps cap,
BGRA, queueDepth 3, showsCursor, ignoresSingleWindowShadow on macOS 14+).
Response matches Alma verbatim: `{opened, session:{window_id, pid, title,
floater_frame:{x,y,w,h}, has_first_frame, last_frame_age_ms}}`.

`pip_status {}` → `{sessions:[…], armed:[…]}` · `pip_close {window_id}|{all:true}`
· `pip_arm {window_id,pid,title}` → auto-opens a mirror when that window is
minimized (AX `AXWindowMiniaturized` observer) · `pip_disarm`.

Actions broadcast the agent cursor into open panels via the `alma.lens.*`
NotificationCenter family (move/click/scrollBadge/typeBadge) — the lens is
rendered inside the mirror, never on the user's desktop.

Verified live: `pip_open` on a Notes CGWindowID → panel appears bottom-right
(334×220 default), `floater_frame`/`has_first_frame`/`last_frame_age_ms`
fields match the Alma probe shape exactly; partial `width`/`height` is
rejected with Alma's verbatim message.

## Verified end-to-end (live, this machine)

- `launch_app` background launch (Calculator/TextEdit) without focus theft.
- `press_key cmd+n` → `{"delivered":true,"via":"menu_ax_press"}` — Notes created
  a new note window with zero foreground involvement.
- `type_text` (auto→unicode/physical/AX) — text landed in the background note.
- `get_app_state` → `s_<ISO>Z` snapshot ids, `ax_status: populated`, nested
  `window{id,title,bounds}`, `menu_shortcuts:[{combo,title,path}]`, screenshot
  at `/tmp/alma-cu-state-<ms>.jpg` (visible dark-mode Notes window, text present).
- `sky_get_app_state` indexed text (`[0] Window "dialog" @-22,755 84x77`),
  `sky_click` element_index → post-action screenshot, verbatim index errors.
- Error paths verbatim: `element_not_found` (stale ref), `forbidden_target`
  (blocklist), `no screenshot mapping for pid …`, `missing "direction"`,
  `unknown cmd: …`, `missing "out"` (shot).
- Codex CLI e2e: registered as `agent_computer_use`, tools load as
  `mcp__agent_computer_use__*`; requires `codex exec --approve-for-me`
  (default `never` policy auto-denies MCP calls).

## Platform realities observed

- Some Apple apps (Calculator, Notes) answer `AXWindows` with the app element
  itself and expose no window AX content while off-screen — menubar + menu
  items only. Walker guards self-cycles via CFEqual ancestor check + 4000
  element cap. Alma's documented escape hatch is the same: screenshot +
  pixel-coordinate input and menu-AX.
- `NSWorkspace.runningApplications` goes stale in a bare-executable daemon —
  resolution uses `NSRunningApplication` direct queries; daemon also boots an
  `NSApplication` context (`accessory` policy) for live inventory.
- `codex` speaks bare JSONL over stdio (no Content-Length headers); the
  wrapper auto-detects framing like the SDK transport.
- `NSWindow`/`SCStream` require a real main runloop: the daemon's main thread
  runs `NSApp.run()`, and AppKit-facing commands hop via `onMainThread`.
  Notably, `CGWindowListCreateImage` deadlocks on worker threads inside an
  NSApp process (its ScreenCaptureKit proxy waits on a reply the main
  runloop must service) — all capture calls run on the main queue.
- On this host, `AXWindows` returns degenerate `AXApplication` proxies for
  every app tested (Notes, TextEdit, Ghostty) — `_AXUIElementGetWindow`
  never resolves. `pip_arm` therefore observes `AXWindowMiniaturized` at the
  app element and filters delivered elements by window id; the verbatim
  "No AX window element" error is preserved for bogus window ids.

## Layout

```
Package.swift
Sources/agent-computer-use/   main, Support, Daemon, Daemon+Actions,
                              AX, Capture, Focus, Input, MCPServer, PIP,
                              Appshot+VisualIndex
mcp/agent-computer-use-mcp.mjs   23-tool stdio server (Alma wrapper port)
mcp/playbooks/*.md               7 verbatim app playbooks
bin/agent-computer-use{,-mcp}    staged artifacts
scripts/{build,install-codex,smoke}.sh
docs/                            provenance notes
```

Evidence source: `../computer-use/` (.164 unified package),
`../alma-computer-use-archive/` (.153 disassembly + probes + my reconstructions).
Deviations from Alma are documented inline with `[IMPL]` markers; observable
behavior (commands, args, errors, wire keys, constants) tracks verbatim evidence.
