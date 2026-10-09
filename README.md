# minami-computer-use

Independent, MCP-native reproduction of Alma's macOS Computer Use surface.
Behavior is benchmarked against Alma .153 (disassembly + live probes) and the
.164 contract package — same three-layer chain, same wire formats, same error
text. No added features.

```
Agent (Codex CLI / any MCP client)
  └── stdio MCP ── bin/minami-computer-use-mcp (node, zero-dep)
        ├── optional host calls → MINAMI_CU_HOST_URL (fail-open)
        └── unix socket NDJSON ── bin/minami-computer-use (Swift daemon)
              └── Accessibility API / CGEvent / CGWindowList / TCC
```


## 安装

### A. npx 一行接入（推荐）

harness 配置里直接写（无需 clone；postinstall 会自动从 Release 拉对应版本
的 universal 守护进程，私有 repo 需要本机 git/gh 对该 repo 有访问权）：

```json
"minami_computer_use": {
  "command": "npx",
  "args": ["-y", "github:ZunbaRan/minami-computer-use"]
}
```

### B. 预编译 tarball

```sh
# 下载 release 里的 minami-computer-use-<ver>-macos-universal.tar.gz
# (Apple Silicon + Intel 双架构；私有 repo 需 gh 登录或 token)
gh release download v1.0.0-beta.2 -R ZunbaRan/minami-computer-use \
  -p 'minami-computer-use-*-macos-universal.tar.gz'
tar xzf minami-computer-use-*.tar.gz && cd minami-computer-use
xattr -dr com.apple.quarantine .   # 去掉 Gatekeeper 隔离位
```

得到 `bin/minami-computer-use`(Swift daemon)+ `bin/minami-computer-use-mcp`
(MCP 入口)+ `mcp/` + `skills/`(操作手册，Skill 工具/resources 即时读)。

### C. 源码构建

```sh
git clone <this repo> && cd minami-computer-use
./scripts/build.sh release     # 需要 Xcode CLT / Swift toolchain
```

### 权限（TCC，两步必做）

daemon 需要 **辅助功能(Accessibility)** 和 **屏幕录制(Screen Recording)**。
权限挂"责任进程"：谁拉起它就授给谁——终端手动跑授给终端 app，
MCP harness 自动拉起授给 harness(pi/Codex 等)。首次截图/PiP 会弹授权框。

### 接入 MCP harness

入口文件 = `bin/minami-computer-use-mcp`(stdio,node≥18):

```sh
# Codex
codex mcp add minami_computer_use -- /abs/path/bin/minami-computer-use-mcp

# pi —— 写进 ~/.pi/agent/mcp.json 的 mcpServers:
#   "minami_computer_use": { "command": "/abs/path/bin/minami-computer-use-mcp" }

# Claude Code
claude mcp add minami-computer-use -- /abs/path/bin/minami-computer-use-mcp
```

wrapper 首次收到请求会自动 spawn daemon
（socket `~/Library/Application Support/minami-computer-use/computer-use-<sha1tag8>.sock`)。
手动拉起：

```sh
bin/minami-computer-use daemon \
  --socket "$HOME/Library/Application Support/minami-computer-use/computer-use-<tag>.sock" \
  --idle-seconds 3600 [--lens] [--pip-hide-hw-cursor]
```

| flag | 语义 |
|---|---|
| `--lens` | agent 虚拟光标（蓝点+点击脉冲+type/scroll 徽标）渲染进 PiP 面板；Alma 默认 off |
| `--pip-hide-hw-cursor` | **Minami 自有 opt-in**：镜像流里去掉用户硬件光标（Alma 默认 showsCursor=true，不加此 flag 保持逐字 parity） |

### 冒烟验证

```sh
./scripts/smoke.sh    # initialize → tools/list(24) → permissions → list_apps
```

## Build & install

```sh
./scripts/build.sh            # swift build + stage bin/minami-computer-use
./scripts/install-codex.sh    # codex mcp add agent_computer_use
./scripts/smoke.sh            # initialize → tools/list(23) → permissions → list_apps
```

The MCP wrapper auto-spawns the daemon (`daemon --socket <path> --idle-seconds 900`)
on first call; socket lives at
`~/Library/Application Support/agent-computer-use/computer-use-<hash>.sock`.

For non-Codex harnesses: stdio command = `<repo>/bin/minami-computer-use-mcp`
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
bin/minami-computer-use{,-mcp}    staged artifacts
scripts/{build,install-codex,smoke}.sh
docs/                            provenance notes
```

Evidence source: `../computer-use/` (.164 unified package),
`../alma-computer-use-archive/` (.153 disassembly + probes + my reconstructions).
Deviations from Alma are documented inline with `[IMPL]` markers; observable
behavior (commands, args, errors, wire keys, constants) tracks verbatim evidence.
