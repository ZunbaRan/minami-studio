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

## Codex 评审轮 1 裁决摘要（tag v0.2.0-parity-round1, commit b49720d）

140 条发现 → 解析落盘 `/tmp/cu-review/round1-gaps.json`。已修（有证据）：

- 封套：malformed JSON → `id:"?"` + `internal` + `malformed JSON: <Foundation
  描述>`（live probe 实测）；EINTR 重试 accept/read/write；backlog 4；
  同连接串行、异连接并行；socket 父目录 mkdir
- 参数：`requireStr` 拒绝空串；resolveApp 错误 `No running app matched
  pid=0.`；forbidden_target 带 `hint` 键（live probe 逐字）
- 快照：wakeup 调度 [0.15,0.25,0.4] 共 4 次尝试、`wakeup_duration_ms` 是
  累计睡眠时间非墙钟；`children_count` 为原始 AX 数；可选字段缺省省略；
  交互过滤 = actions ∪ Alma 16-role 集；ref 跨快照 CFEqual 复用 +
  descriptor 恢复（~200 节点/~12 层/唯一匹配）+ `ref_stale`
- 动作 wire：`clicked:<ref>`（不是 bool）/`opened_menu` / `dragged:{from,
  to,button,coord_space}` / `typed:<ref>,length:String.count` /
  `pressed:<key>` / `set:<ref>` / `selected,selection_type` /
  `scrolled,pages`；press_key → `delivered,via,delivery_note`
- 输入：菜单快捷键 `(flags^wanted)&0x1e0000==0` 首匹配即 AXPress，
  失败 → `suppressed` 立即返回；unicode 20 标量块不拆代理对；
  focused-AX 插入 AXSelectedText→AXValue 回落
- PiP：`pip_close {closed:"all"|{closed,window_id}}`、
  `pip_disarm {disarmed:"all"|{disarmed,window_id}}`、缺 id 字面量
  `missing "window_id" (or pass "all": true)`
- Capture：SCScreenshotManager one-shot（1/60、无光标/音频/阴影、
  main-screen scale、宽高≥1）；`Failed to encode JPEG.`；
  映射只在成功 `get_app_state` 发布（`shot` 不碰）
- wrapper：`notifications/cancelled` 抑制迟发响应；ref-only 动作
  screenshotTarget 返回 null 不发空 `get_app_state`；set_value 值
  schema 改 anyOf union

## Round-2 追加裁决（v0.3.0）

- FocusGuard 已按 disasm 0x100027a04 回调 + ALGORITHMS §6 重建：
  CGEventTap(annotatedSession/headInsert/default/0x6000) 类型 13/14，
  sentinel 0x2a 放行，data1 取目标 pid，disallowed∪onlyAllow∪
  temporaryAllowance(未过期即放行) 三闸；tapDisabled 自动重开+stderr
  计数；VictimObserver 扫 `bundle.*` 后缀含 helper/xpc/service；
  makeWindowKeyWithoutActivating = GetProcessForPID +
  SetFrontProcessWithOptions(1)；动作后 immediate + 5s 双时点
  frontmost==oldFront 才 rekey；arm 失败仅 armFailures+1 + FATAL
  stderr 不退出
- CLI 金标准（ad-hoc 重签 .164 二进制实测）：`version`→
  `alma-computer-use 0.1.0`；help/bogus usage 走 stdout、unknown
  subcommand 走 stderr；`daemon --help` 也出 usage exit 0；idle 实际
  默认 900s 而 help 文案仍写 600（逐字保留）
- MCP 协议面已 byte-identical：initialize 协商支持集
  [2024-10-07,2024-11-05,2025-03-26,2025-06-18,2025-11-25] 非成员→
  2025-11-25；`{tools:{listChanged:true}}`；result 帧键序
  `{result,jsonrpc,id}`、error 帧 `{jsonrpc,id,error}`；未知方法
  `-32601 "Method not found"`（无后缀、无 resources/prompts/logging
  stub）；tools/call 校验分层：params/name 非 string→-32603 zod
  issue；arguments 非 record→-32602；arguments 缺失→工具层
  `expected object path:[]` isError
- tools/list 23 工具 schema 全量嵌入 REAL_SCHEMAS（draft-07 $schema
  + safe-int bounds + 空 required 省略 + execution.taskSupport:
  "forbidden"），逐字节核对通过
- DaemonClient 侧：ALMA_CU_HELPER/ALMA_RESOURCES_PATH 优先，socket
  `~/Library/Application Support/Alma/computer-use[-sha1tag8].sock`，
  spawn `daemon --socket X --idle-seconds 900`，helper 缺失文案逐字
- AppUsage：kMDItemFSName 补进 valueListAttributes（fallback 源）
- text/scroll 系 AX 写路径挂 EnhancedUI assertion（withEnablement），
  click/drag 不挂（§6.1 证据）；type_text 事件路由包 FocusGuard

## Round-2 E2E（8 场景实测）抓出的真修正

ad-hoc 重签 .164 二进制起 `/tmp/real-cu.sock` 做逐条 live 对照：

- `app_not_found` label = 裸 bundle 字符串（有 bundle 就 echo 它，无论
  pid 死活）；launch/get_app_state 同一句 `No running app matched X.`
- `type_text auto` 无 ref 恒 `auto_key_events`——砍掉 focused-AX 多余
  路径（Alma 该路径不存在）
- `press_key` suppressed 响应无 `via` 键；`via` 仅 delivered 路由出现
- `dragged.from/to` 回声的是翻译后桌面点，不是请求值
- Codex 判错的项：`press_key cmd+f` 在后台 TextEdit 真机同样
  suppressed（无 ENABLED 菜单项持 chord），E2E 断言不可全信

E2E 亮点：cmd+n 经 menu_ax_press 真在后台开新文档；pip_arm→AXPress
minimize→自动开 PiP 会话全链路实测；gas AX-only 不还原最小化窗、
带截图才 unminimize；armed 一次性消费；8MiB 分片行 + 双 peer 并发 +
码点中段切片全通。

## 真实桌面 E2E 补记（10 场景 T01-T10，run_id=r1）

与真 .164 daemon 同机双 socket 对照跑完。关键实测语义：

- **坐标映射只在 `get_app_state`（含截图）注册**；`shot`/`shot_display`
  不注册。无映射时 click/drag 按**原始屏幕坐标**派发并回声原值；
  有映射时翻译并回声**派发点**（翻译后）。我们实现逐字吻合
  （实测同一坐标两次执行：(30,31)→(196,117.5) 陈旧映射 vs 真机同款
  陈旧命中；gas 后 (30,31)→(225,146.5) 与真机分毫不差）
- **stale 映射会被照常使用**——映射按 pid 存取、不校验 window_id；
  对 A 的映射点击 B 的截图像素会命中 A 的旧位置（真机同）。点击前
  必须重新 gas 刷新映射，这是协议使用约束不是 bug
- **pip_arm 无 bundle/pid → `app_not_found` / `No running app matched
  pid=0.`**（真机逐字一致）；armed 响应 `{armed:{pid,title,window_id}}`
- `press_key cmd+n` 后台 TextEdit/Finder 均 menu_ax_press 真开新窗；
  `cmd+f`/`cmd+2`/`delete`/`cmd+delete`/`cmd+s` 在无 enabled 持有者时
  suppressed——真机逐字一致（含 TextEdit cmd+s 后台抑制 → 保存面板
  仅 AX 可达）
- Notes 148 条目中深度 snap 双方均 >120s 超时（真机同样，非我们的
  性能问题）；笔记删除走**列表 cell 右键上下文菜单→"删除"**（末项，
  enabled），无确认弹窗即删；AS 路径 -1743 未授权
- PiP：open→status(has_first_frame)→close 全链路与真机一致；浮窗
  镜像随 set_value 实时更新；TCC 屏录弹窗非目标 app AX 窗，须对
  host pid 发像素点击，且注意截图缩放换算
- type_text：CJK 走 `unicode_events` 后台可落字（含 \n）；`auto` 无
  ref 恒 `auto_key_events`，CJK 键事件丢字是 macOS 事实非 bug
- 前台哨兵全程 Paseo；**一次例外**：Notes 上下文菜单删除动作后
  Electron(46582,agent-browser dev) 成为前台——无法归因是我们的
  AXPress 还是用户操作，记录在案待复现

## 已拒的 Codex 建议（画蛇添足，不收）

- 给 daemon 加请求体大小上限/超时（Alma 无此墙）
- 把 `not_implemented` 命令实现出来（Alma 自己就是 not_implemented）
- 给错误加 `retryable`/`details` 字段（wire 无此键）
- 规范化 response 键序。修正：live 探针实锤 Alma **不是**字典序——
  `{"path","width","height"}`、`coord_space` 在 `clicks` 前、`from:{y,x}`
  ——是 Foundation NSDictionary 的枚举序。我们 `.sortedKeys` 输出与真机
  键序不同（语义等价、JSON 无键序语义）；若要逐字节对齐需换有序发射
  结构（大改，暂记为已知 cosmetic 差异，不改）
- 给 MCP wrapper 加 ping/health 工具（23 工具面是闭集）

## Round-3 修复（2026-10-09，针对 CX 外场确认的 4 个 parity bug)

- **修饰键别名全集**(press_key 探针实测）:cmd/command/meta/super、ctrl/control、shift、alt/option/opt、fn/function;`ctl`/`win`/`caps` 被拒。此前只缺 `opt`。
- **menu_shortcuts 序列化规则**(walk @0x100030608 逐指令）:mods 位 3 置位=无 cmd;cmd/ctrl/opt/shift 固定序；key=`AXMenuItemCmdChar.lowercased()` 原样（glyph ⎋/\x1b/? 不映射）;char 空→vk 跳表命名（Return/Tab/Space/Backspace/Escape/F1-F12/Home/End/PageUp/PageDown/Delete/Left/Right/Down/Up，首字母大写）；表外→`vk%02X` 大写 hex。char 与 vk 皆无→跳过该项。
- **PiP 浮窗定位**(`nextCascadeOrigin` @0x10004f36c)：全局单调 counter（锁保护、关闭不重置、**读旧值再自增**);`x=max(vf.maxX-w-24-28n,minX+12)`,`y=max(vf.maxY-h-24-28n,minY+12)`;**Cocoa 顶右锚定**（视觉上是屏幕右上、菜单栏下方），非右下。本机验证 (1248,725)/(1220,471) 逐字节命中。
- **PiP 会话回收**：已销毁 AX 元素的属性（含 wid）不可读；且 **AXUIElementDestroyed 先于 CGWindowList 移除**——两类替代判定都不可靠。真实语义：观察器只注册在解析出的窗口元素上，destroyed 通知即权威、无条件 close;MinimizeArmer 同理用元素身份 CFEqual 定位。
- daemon 手工拉起约定：`bin/agent-computer-use daemon --socket ~/Library/Application Support/Alma/computer-use-72097929.sock --idle-seconds 3600`(MCP 客户端也会自动 spawn)。

## Round-4 修复（2026-10-09，针对 R3 回归新发现的 6 项）

- **scroll pages 语义**：反汇编 `AXBridge.scroll` 0x100016258 `cmp x25,#1; csinc x8,x25,xzr,gt` = `max(1,pages)`——0/-1 也执行一次动作（可 action_unsupported），响应回声原始 pages。
- **physical type_text 崩溃根因**:`TISCopyCurrentKeyboardLayoutInputSource` 触发 `islGetInputSourceListWithAdditions` 的 main-queue 断言；请求处理在并发 conn queue。修法：`keyPresses` 整体经 `DispatchQueue.main.sync`（主线程直跑，非主跳主）。真机同请求返回 `internal` 且存活。
- **快照空字段**:Alma 对 `subrole/role_description/title/value/description` 一律**空串不发射**(toDict 层 isEmpty 门）。
- **ax_failure 文案**:`"AX error <case> while <context>."`——前缀 `AX error ` + 句点结尾，所有 ax_failure 路径统一。
- **armed 与源窗销毁解耦**:MinimizeArmer 仍注册 destroyed 通知（disarm 时两者都 remove)，但回调**不消费 arm**——pip_status 保留条目、pip_disarm 返回 true。与活动 session 的 destroyed 回收（R4 语义）是两条独立路径。
- **type_text 校验顺序**：目标（pid/bundle/ref）缺失检查先于 `input_method=ax requires ref`。

## Round-5 修复（2026-10-09,R5 收口确认的 3 项）

- **auto 无 ref 的真实投递链**(typeText @0x10002102c):`typeTextViaFocusedAXElement` 先行——app `AXFocusedUIElement` 的 `AXSelectedText` 可写则写、否则 `AXValue` 读旧值+append 写入；失败才进 `keyPresses→typeKeyPresses`/`typeUnicodeText`(withFocusPreserved 只包事件路径）。label 恒 `auto_key_events`,focused-AX 成功也不改标。**调用点必须在 deliver 闭包内**(baseline 先于写入）。
- **snapshot 的 per-app AX 失败**:windows(of:) 抛错→`try?` 吞为空列表继续（elements 空、ax_status 正常、window 由 CG 元数据兜底）。`windows` 命令本身仍传播错误——两条路径不同，勿混。
- **window 封套恒发**：无窗 app 也输出 `{"id":null,"title":null,"bounds":null}`，不是省略键。
