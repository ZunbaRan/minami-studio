# AGENTS.md — agent-computer-use

Independent MCP-native reproduction of Alma's macOS Computer Use surface.
**唯一准绳：严格对标 Alma。** 不加 Alma 没有的能力、不改 Alma 的 wire/错误语义，
不接受"看起来更稳"的自创墙。证据基准：`.164` 统一契约包（`computer-use/`）
+ `.153` 反汇编/live-probe（`alma-computer-use-archive/`）。

## 结构与入口

```
Sources/agent-computer-use/   Swift daemon（main / Support / Daemon /
                              Daemon+Actions / AX / Capture / Focus /
                              Input / PIP）
mcp/agent-computer-use-mcp.mjs  23-tool stdio MCP wrapper（Alma wrapper 移植）
bin/agent-computer-use-mcp      稳定入口（任何 harness 指这里）
scripts/{build,install-codex,smoke}.sh
```

架构：`agent → stdio MCP → unix socket NDJSON → Swift daemon → AX/CGEvent/SCK`。
daemon 自带 45 命令注册表；未实现项返回 Alma 的 `not_implemented` 形状，
不可达 MCP 的（`intent`/`lens`/`mcp_*`/`appshot_*` 等）保持协议位即可。

## 构建/验证

```sh
./scripts/build.sh            # swift build → bin/agent-computer-use
./scripts/smoke.sh            # initialize→tools/list(23)→permissions→list_apps
./scripts/install-codex.sh    # codex mcp add agent_computer_use
```

Devin 侧已配置：项目根 `.devin/mcp_config.local.json` 的
`mcpServers.agent_computer_use` 指到 `bin/agent-computer-use-mcp`。

## 本机踩出的硬坑（再改别再踩）

1. **daemon 主线程必须 `NSApp.run()`**，不能 `dispatchMain()`——后者下
   `DispatchQueue.main.sync` 的 block 会内联跑在调用者线程，NSPanel/NSWindow
   直接 `NSInternalInconsistencyException` 崩。NSApp.run 同时泵主队列和
   CFRunLoop，PiP 的 AX observer / SCStream 都靠它。
2. **`SCShareableContent.getWithCompletionHandler` 回调走 main runloop**，
   绝不能放进 `main.sync` 块里——先做 shareable 解析，再 hop 到 main。
3. **`CGWindowListCreateImage` 在 NSApp 进程的 worker 线程上死锁**
   （SCK 代理层 `SLSWindowListCreateImageProxying` 等 main-runloop 服务的
   回复）。所有截图调用必须 `onMainThread{}`。这就是 MCP `get_app_state`
   30s 超时的根因，症状是 `semaphore_timedwait` 无限挂。
4. **macOS 27 上 `AXWindows` 普遍返回退化 `AXApplication` 代理元素**
   （Notes/TextEdit/Ghostty 全是），`_AXUIElementGetWindow` 永不成功。
   `pip_arm`/`installDestroyObserver` 因此挂 **app 元素级** observer，
   回调里对投递元素做 wid 过滤（唯一 armed 窗口兜底匹配）；"No AX window
   element for windowId=" 错误面仍由 CGWindowList 校验保住。
5. **`type_text` 的 TIS 键盘布局数据是 opaque 指针**：必须
   `unsafeBitCast(raw, to: CFData.self)`，类型守卫 + `as?` 反而崩
   （TISGetInputSourceProperty 返回的 opaque 不是完整 CFData 对象头）。
6. **Apple 系 app 的 AXWindows 自环**：snapshot walker 必须 CFEqual 祖先
   防环 + `maxSerializedElements=4000` 硬顶。
7. **Codex 用裸 JSONL 帧**（无 Content-Length）；wrapper 双帧自适应——
   请求什么帧就回什么帧。codex 工具名要下划线（`agent_computer_use`）。
8. **`codex exec` 默认 `approval=never` 拒掉所有 MCP 调用**——用
   `--approve-for-me` 或交互式审批。
9. **TCC 归因**：裸二进制无独立条目，权限挂责任进程（本机 = Ghostty）。
   `pip_*`/`shot` 能跑是因为 Ghostty 有 Screen Recording 授权。
10. macOS **没有 `timeout` 命令**；测试脚本用 python `Popen` 或 socket
    timeout 自控。

## Wire 语义钉死（别再回归）

- snapshot id `s_<ISO>Z`；`ax_status:"populated"`；`window{id,title,bounds}`
  独立嵌套；`menu_shortcuts[{combo,title,path}]`；diff 键只在有前次快照时出现
- `apps` ≠ `list_apps` wire；`apps` 元素不含 `running`
- `shot` 必须带 `out`（否则 `missing "out"`）；状态文件
  `/tmp/alma-cu-state-<ms>.jpg`
- `launch_app` 响应 `{activates,bundle,launched,app{...}}`
- pip session dict `{window_id,pid,title,floater_frame{x,y,w,h},
  has_first_frame,last_frame_age_ms}`；默认浮窗 334×220 右下角
- 错误面逐字：`unknown cmd: X` / `element_not_found` /
  `forbidden_target` / `No element known for ref …` /
  `"width" and "height" are required when pip_open carries a preferred size`

## 评审纪律（本项目的合作模式）

外部 reviewer（如 Codex）可以提缺口，但**每一条必须能落到 Alma 证据**
（disasm 地址 / strings / live probe / .164 契约章节）才接受；纯
"工程最佳实践"类建议一律拒绝——这是复刻，不是新设计。
