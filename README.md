# minami-studio

**Alma-parity macOS Computer Use daemon + self-recording & auto-zoom export.**

Fork of [minami-computer-use](https://github.com/ZunbaRan/minami-computer-use)
(@ v1.0.0-beta.3). The existing 23-tool wire surface keeps verbatim parity
with Alma (.153 disassembly / .164 contract); on top of it this project adds
the ability for the daemon to **record its own sessions** — cursor tracked
separately, then re-composited with Recordly-style auto-zoom camera motion
at export. Recording helpers derive from [Recordly](https://github.com/webadderallorg/Recordly)
(AGPL-3.0); this project is AGPL-3.0 accordingly.

```
Agent (Codex CLI / any MCP client)
  └── stdio MCP ── bin/minami-studio-mcp (node, zero-dep)
        ├── optional host calls → MINAMI_CU_HOST_URL (fail-open)
        └── unix socket NDJSON ── bin/minami-studio (Swift daemon)
              └── Accessibility API / CGEvent / CGWindowList / TCC
```


## 安装

### A. npx 一行接入（推荐）

harness 配置里直接写（无需 clone；postinstall 会自动从 Release 拉对应版本
的 universal 守护进程，私有 repo 需要本机 git/gh 对该 repo 有访问权）：

```json
"minami_studio": {
  "command": "npx",
  "args": ["-y", "github:ZunbaRan/minami-studio"]
}
```

### B. 预编译 tarball

```sh
# 下载 release 里的 minami-studio-<ver>-macos-universal.tar.gz
# (Apple Silicon + Intel 双架构；私有 repo 需 gh 登录或 token)
gh release download v1.0.0-beta.2 -R ZunbaRan/minami-studio \
  -p 'minami-studio-*-macos-universal.tar.gz'
tar xzf minami-studio-*.tar.gz && cd minami-studio
xattr -dr com.apple.quarantine .   # 去掉 Gatekeeper 隔离位
```

得到 `bin/minami-studio`(Swift daemon)+ `bin/minami-studio-mcp`
(MCP 入口)+ `mcp/` + `skills/`(操作手册，Skill 工具/resources 即时读)。

### C. 源码构建

```sh
git clone <this repo> && cd minami-studio
./scripts/build.sh release     # 需要 Xcode CLT / Swift toolchain
```

### 权限（TCC，两步必做）

daemon 需要 **辅助功能(Accessibility)** 和 **屏幕录制(Screen Recording)**。
权限挂"责任进程"：谁拉起它就授给谁——终端手动跑授给终端 app，
MCP harness 自动拉起授给 harness(pi/Codex 等)。首次截图/PiP 会弹授权框。

### 接入 MCP harness

入口文件 = `bin/minami-studio-mcp`(stdio,node≥18):

```sh
# Codex
codex mcp add minami_studio -- /abs/path/bin/minami-studio-mcp

# pi —— 写进 ~/.pi/agent/mcp.json 的 mcpServers:
#   "minami_studio": { "command": "/abs/path/bin/minami-studio-mcp" }

# Claude Code
claude mcp add minami-studio -- /abs/path/bin/minami-studio-mcp
```

wrapper 首次收到请求会自动 spawn daemon
（socket `~/Library/Application Support/minami-studio/computer-use-<sha1tag8>.sock`)。
手动拉起：

```sh
bin/minami-studio daemon \
  --socket "$HOME/Library/Application Support/minami-studio/computer-use-<tag>.sock" \
  --idle-seconds 3600 [--lens] [--pip-hide-hw-cursor]
```

| flag | 语义 |
|---|---|
| `--lens` | agent 虚拟光标（蓝点+点击脉冲+type/scroll 徽标）渲染进 PiP 面板；Alma 默认 off |
| `--pip-hide-hw-cursor` | **Minami 自有 opt-in**：镜像流里去掉用户硬件光标（Alma 默认 showsCursor=true，不加此 flag 保持逐字 parity） |

### 冒烟验证

```sh
./scripts/smoke.sh    # initialize → tools/list(36) → permissions → list_apps
```

## Build & install

```sh
./scripts/build.sh            # swift build + stage bin/minami-studio
./scripts/install-codex.sh    # codex mcp add minami_studio
./scripts/smoke.sh            # initialize → tools/list(36) → permissions → list_apps
```

The MCP wrapper auto-spawns the daemon (`daemon --socket <path> --idle-seconds 900`)
on first call; socket lives at
`~/Library/Application Support/minami-studio/computer-use-<hash>.sock`.

For non-Codex harnesses: stdio command = `<repo>/bin/minami-studio-mcp`
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

## Session recording + auto-zoom (minami-studio 新面)

The agent can record its own session and produce a polished auto-zoomed
video — Screen Studio / Recordly style — in one pass:

```
record_start{out, window_id?|display_id?, fps?, audio?}   # SCK→mp4, cursor NOT baked
   …agent operates the computer (click/drag/type_text/…)…
record_stop          # mp4 + <out>.cursor.json telemetry sidecar
zoom_suggest{in}     # optional: preview/edit auto-generated zoom regions
zoom_export{in,out,depth?,regions?,motion_blur?,audio?}   # final composited mp4
```

- **录制**（`Recorder.swift`）：SCStream 60fps + AVAssetWriter H.264；
  `showsCursor=false`——OS 光标不进像素；window 模式 = display filter +
  逐帧 CI crop（遮挡录上层）；pause/resume 时间轴重基线。
- **遥测**（同文件 `CursorTelemetryRecorder`）：33ms 轮询物理光标 +
  CGEvent session tap 记真实用户点击；**agent 的 `click`/`drag` 经
  `RecordManager.noteAction` 直接注入**（CGEventPostToPid 不经事件流，
  tap 看不见）——export 时渲染的光标因此跟随 agent 的虚拟指针。
- **变焦合成**（`ZoomExport.swift`）：AVAssetReader 逐帧 → 点击分类
  （dropdown/text-selection/text-field/double-click）+ 2.5s 聚簇生成
  region → easeOutZoom(0.16,1,0.3,1) 缓动 + focus 锚定仿射
  `s=1+(S−1)·p` → safe-zone 跟焦相机（25% 内缩）+ 缩出冻结 +
  gap≤1350ms chained pan（1000ms easeInOutCubic 混合）→ CIMotionBlur/
  CIZoomBlur 运动模糊 → 光标重绘 + 点击涟漪 → AVAssetWriter。
  `depth` 1–6 → 1.25×/1.5×/1.8×/2.2×/3.5×/5×，默认 3。音轨压缩样本透传。
- 数学与常数移植自 Recordly（AGPL-3.0），详见
  `docs/RECORDLY-ZOOM-PIPELINE.md`；本项目 AGPL-3.0。

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
- Codex CLI e2e: registered as `minami_studio`, tools load as
  `mcp__minami_studio__*`; requires `codex exec --approve-for-me`
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
Sources/minami-studio/   main, Support, Daemon, Daemon+Actions,
                              AX, Capture, Focus, Input, MCPServer, PIP,
                              Appshot+VisualIndex
mcp/minami-studio-mcp.mjs   36-tool stdio server (Alma wrapper port + record_*/zoom_*)
mcp/playbooks/*.md               7 verbatim app playbooks
bin/minami-studio{,-mcp}    staged artifacts
scripts/{build,install-codex,smoke}.sh
docs/                            provenance notes
```

Evidence source: `../computer-use/` (.164 unified package),
`../alma-computer-use-archive/` (.153 disassembly + probes + my reconstructions).
Deviations from Alma are documented inline with `[IMPL]` markers; observable
behavior (commands, args, errors, wire keys, constants) tracks verbatim evidence.
