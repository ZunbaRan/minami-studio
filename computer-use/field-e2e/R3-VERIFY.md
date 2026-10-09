# Round-3 回归与补扫验证

run_id=`r3`；2026-10-09 13:42:41–13:59:58 +08:00；本机 macOS **26.6.2 (25G83)**。按 [R3-TASK.md](R3-TASK.md) 执行，先 ping、后 Phase1 四项、再 Phase2 **11 项**。准备 Phase2 文稿发生在 R4 重试前，Phase2 实际动作在 R4 完成之后。

**Phase1：4/4 PASS。Phase2：6 项 FAIL、4 项 PASS、1 项 OBS；确认 6 类实现差异（2 major、4 minor）**，详见 [BUGS.md 的 Round-3 回归新发现](BUGS.md#round-3-回归新发现)。PASS 仅指表中实际覆盖；不是所有候选分支均已覆盖。只写测试文档，未修改 Sources、wrapper、脚本、配置，未构建或修复代码。

## 环境、证据与对照方法

- 我们：`/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock`。
- Alma：`/Users/lu/Library/Application Support/Alma/computer-use-9bd08bc1.sock`；原进程 PID 37196，整个测试未重启。
- 被测 Git HEAD：`7d5e3073a449ed6c4e7acd932501156ca6456002`。
- 我们二进制 SHA256：`8797588e08d23a51332a66d21e0ba3beb1799108ed433cf56fa313430c763fd0`；Alma：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`。
- 权限：两端 accessibility/screen_recording 均 true。ours 首次 permissions 的 focus_guard.armed=false、Alma=true，只记录启动状态，不作为相同动作条件的差异。
- 原始证据目录：`/tmp/cu-field-r3-20261009-134241`。`requests.jsonl` **775 条**（ours 410、Alma 365，含断连/失败事件）；另有 4 条预检 ping 记录。保存逐行原始响应 `raw`、cmd/args、时间、耗时；`comparisons.jsonl` 保存排序后的逐字 diff；`phase2-results.jsonl` 保存提取/重绑 ref 后的比较；`manifest.json` 提供散列。
- 测试脚本与输出均保存在该目录；核心客户端 `r3lib.py`。长批次由 shell 后台会话执行，socket 自设 timeout，未使用 macOS 不存在的 `timeout` 命令。
- 对照请求使用相同字符串 id、cmd/args。ref 属于各 daemon，只用本端快照获得的对应元素重绑；不跨端复用编号。比较时对象键序排序，ref/id 和计时差异明确标注，**未把 raw JSON 键序不同算 bug**。BUGS 中保留关键完整请求/响应，避免只有临时文件指针。
- 我们两次崩溃，原 PID 81258 → 87947 → 89009；均用原二进制与原 socket、`--idle-seconds 3600` 重启。失去连接期间的后续失败不是独立 bug，P06/P07 已重跑；新 daemon 的 ref 重新采集。

## 预检：两个 socket 的 ping

任务示例 `{"id":1,"cmd":"ping","args":{}}` 被两端同样拒绝：`id:"?"`、`invalid_arg`、`malformed JSON: The data couldn’t be read because it isn’t in the correct format.`。改为字符串 id `r3-ping` 后，两端 **13:43:02** 均 `ok:true, pong:true, version:"0.1.0", uptime_s:2098787`。这是信封类型校准，不是我们独有的错误。之后才开始 Phase1。

## Phase1 四项回归

|编号|结论|实际证据与范围|
|---|---|---|
|R1 opt 别名|PASS|TextEdit 的 `cmd+opt+f` / `cmd+alt+f` / `cmd+option+f` 两端均 suppressed，无 via，delivery_note 逐字一致；`cmd+ctl+f` / `cmd+win+f` 均 `unknown modifier`。单独 `alt/option/opt` 两端均是 `unknown key`，不能把孤立修饰键当 chord。|
|R2 menu_shortcuts|PASS|Calculator **41/41**、TextEdit **84/84**、Notes **103/103** 个去重 combo；三个差集均空。含 `cmd+w`、`cmd+?`、`ctrl+Left/Up/Right/Down` 和原样 `⎋`、ESC、Tab 字符，无 `key<N>`。这三组菜单没有 `Return/Tab/F1…F12` 的 vk fallback 样本，不能宣称整个命名跳表被实测。|
|R3 PiP 定位|PASS|先开 TextEdit→Calculator→Notes，初始历史 counter ours=1、Alma=6，frame 差 140=5×28；未误报为定位回归。关闭后在 ours 额外开/关 5 次补齐，再同顺序、统一 334×220 开三窗，n=9/10/11 两端 frame 完全相等，见下表。关闭不重置 counter。|
|R4 源窗销毁|PASS|W234320 双端 pip_open 后，ours 的 `press(ref=关闭按钮,key=Space)` 关闭源窗；0.25/0.5/1/2 秒双端 sessions 均空；随后双端 `pip_close(window_id:234320)` 均 `closed:false`。一次预读 snap 临时 app_not_found，重试并双端确认源窗后完成。|

R3 屏幕可见区由 AppKit 实读：`x=0,y=60,w=1512,h=889`，maxY=949，单屏。公式 `x=max(1512-w-24-28n,12)`、`y=max(949-h-24-28n,72)`。

|统一计数 n|窗口|我们 floater_frame|Alma floater_frame|
|---|---|---|---|
|9|TextEdit W234320|{x:902,y:453,w:334,h:220}|相同|
|10|Calculator W230248|{x:874,y:425,w:334,h:220}|相同|
|11|Notes W230343|{x:846,y:397,w:334,h:220}|相同|

现有 Alma counter 未重置，n=0 没有重新直接观测；验证的是相同历史计数、实读 visibleFrame 下的顶右锚定与逐次 -28。原初不同尺寸序列同样符合各自 n 的公式，不能直接要求不同 h 的原始 y 差恰好 -28。

## Phase2：11 项补扫

|编号|结果|覆盖、实际结果与证据 case|
|---|---|---|
|P01 type_text 方法/Unicode|FAIL|auto+ref、ax+ref 的 CJK/emoji/组合字符/换行成功，返回 `typed/method/length`（不是候选文案中的 chars/via）；AX 样本 length=7。unicode 19 个 x 后接 😀/中/é/👩‍💻/换行/Z，length=25，实际落字观察已保存。physical `A\nB` 触发 ours SIGTRAP，Alma 返回 internal 后仍存活：**R3-01**。auto 无 ref 已走到事件路由。零等待事件 verification/读回受时序影响，单列观察，不额外定 bug。|
|P02 snapshot/diff/空字段|FAIL|`disable_diff:true` 全量；重复为空 diff；depth5→1 产生 removed_refs，再重复不产生 removed；depth0/-1 输出根节点；`disableDiff` 与附加 sky/sky_mode 原生参数被忽略。稳定快照仍发现空 `title/value` ours 保留、Alma 省略：**R3-03**。`P02-*`、`C-empty-fields-0/1`。|
|P03 select_text|PASS|空 text、找不到 text、错误 prefix/suffix 文案一致；空 prefix/suffix 首匹配、用 prefix 消歧第二匹配、Unicode cursor_after、未知 selection_type、额外 start=-1/end=999999（忽略）均对照。`P03-*`；空 affix 初次读回受前序 Unicode 污染，已废弃该读回，用全新纯 AX 文稿 `C-selection-empty-affixes` 复测：两端 `alpha beta alpha` → `\|R3\| beta alpha`。|
|P04 set_value 控件/类型|FAIL|TextArea、粗体 AXCheckBox、disabled AXScrollBar，逐项 string/int/bool/array/object/null；接受集相同，AXValue 写失败文案不同：**R3-04**。TextArea string/array/object 成功，int/bool=ax_failure；checkbox 除 null 外均 action_unsupported；scrollbar int/bool 成功、string/array/object=ax_failure；null 均 missing value。没有覆盖 slider/stepper/datefield。|
|P05 press/secondary/scroll 边界|FAIL|disabled scrollbar 上 Space/Increment、TextArea 上 Enter/Escape/未知 key、未知 ref 的 secondary_action/press、非法 scroll direction 错误一致。`pages:0` ours 成功但 Alma 执行动作报错，`pages:-1` ours 崩溃、Alma 同错误：**R3-02**；恢复后 pages1/2 两端错误一致。未覆盖真实 hidden 元素 secondary_action。|
|P06 apps/windows/app_info|OBS|8 组重跑请求逐字一致：apps 忽略 pid、死 pid、死 pid+bundle 回落、pid0、未知 bundle、无窗 Maps、Notes；`app_info` 双端 unknown cmd。另有一次 `C-maps-windows` ours app_not_found / Alma 存活无窗，随后 4 轮 Maps/TextEdit（8 对）全相等；保留待归因，不给总体全通过结论。多 Space 未测。|
|P07 wakeup budget|PASS（状态边界）|Maps 无窗、Calculator depth0；0/-1=一次尝试/no_wakeup_budget/0ms；0.01/0.2=empty_after_wakeup；1000000 仍至多4次尝试、约0.8秒累计睡眠，不按巨大值阻塞。小预算下 ours 2/3次、Alma 1次，因 Alma 初次遍历已超过预算；时长/次数不能宣称逐字相同。中断语义未测。|
|P08 分片/并发/断连/ref|PASS|UTF-8 中/emoji 字节切片的 set_value 可读回；每端双 peer 并发 ping；发请求后主动断开，写入仍执行；重连使用原 ref 成功。`P08-fragment/concurrent/drop/old-ref-new-connection`。|
|P09 PiP 重复/无窗/armed 销毁|FAIL|重复 open 均 opened:true，保持原 title/pid/size/frame；close→reopen 两端 delta -28；无窗/无目标/不存在 window 的错误一致。armed 后直接销毁，ours 移除 armed、Alma 保留，两个新窗、分别由两端驱动关闭均复现：**R3-05**。|
|P10 错误信封/校验顺序|FAIL|未知 cmd、缺 click/drag/key/ref/out/window_id、forbidden hint、坏 JSON、数字 id、args null/array/缺省均已对照。无目标且 input_method=ax 的首错不同：**R3-06**。有 pid 时缺 ref、非法 method、缺/空 text 均一致。pip_open 只给 width 在两端原生 socket 均静默使用默认大小，未把旧文案预期误报为 bug。|
|P11 capture/移动缩放/coord_space|PASS（稳定条件）|只移动/缩放测试窗；shot/shot_display、无 out、坏 wid、目录 out 均对照；shot 不刷新旧 mapping，stale drag 两端 (310,311)→(340,311)；仅精确 `screen` 绕过映射，`screenshot/window/SCREEN/空串` 均用映射并原样回声。即时刷新跨缓存时点出现不同图高；等待2.5秒后重新捕获，两端586×478及 click(362.23890784982933,318.69037656903765)相同。|

### 时序与预条件观察，不计新实现 bug

1. **Unicode verification**：两端都观察到文本已落入测试窗、但 `settle_ms:0` 返回 `type_text delivered no text`。首次 ours 报错/Alma 成功；反序 `C-unicode-0-0` 恰好相反，两端前置读回均 ANCHOR、后置均 `中🙂\nZ`。后续清空/写入出现迟发残留，一条预置断言失败后该次实验停止。不能将单边瞬时误报直接定为实现差异。`C-auto-no-ref` 另记录 Alma 成功、ours 未落字，尚未隔离双 daemon focus guard、后台 key-window 和事件时序条件，不并入确认缺陷。
2. **截图缓存**：P11 即时 gas-refresh 两端 AX bounds 都646×528，ours图高488、Alma478；两次响应相隔约2.6秒，跨过 .164 契约的 window cache TTL 2s（[FINDINGS §8](../analysis/native-snapshot/FINDINGS.md)）。`C-capture-*` 加2.5秒稳定后尺寸、映射点一致。保留原差异，裁决为缓存龄预条件不等，未证明算法不同。
3. **wakeup**：例如 Calculator 0.2秒，ours elapsed215ms/attempts3/sleep192ms，Alma elapsed2173ms/attempts1/sleep0ms；巨大预算为809/811ms实测睡眠。符合初次遍历消耗墙钟预算后再决定重试的约束，不把性能/调度差异报为 wire 修复项。
4. **偶发 app_not_found**：R4 预读、C-arm-before、C-maps-windows 出现；最后一项有同请求双端差异。原始 P07 的 Alma 也曾对 Maps snap 返回 app_not_found，但该次 ours 已离线，不能当成严格 parity 对照。后续8对稳定读取未复现；仍需要独立归因，详见 BUGS 的 OBS。

## 哨兵全程记录

每批前后按要求执行 System Events 的 frontmost 查询。`cliclick p` 及常见安装路径均未找到，最初4个样本光标不可用，**没有把空值算稳定**；之后使用只读 `CGEventCreate/CGEventGetLocation` 记录左上原点屏幕坐标，CFRelease 事件，不注入鼠标事件。任务要求的 cliclick 本体未运行成功，这是明确环境偏差。

共 **1015 条**哨兵记录，`frontmost_error/非零返回=0`；其中批次前后配对 **42 组**，前台或光标变化 **19 组**（另2组光标缺测）。13:44:20–13:59:09 另有后台采样，目标间隔0.75秒加 osascript 执行时间；最后独立选区复核单独采样前后。原始 `sentinel.jsonl` 保留全部点；下表保留所有批次起止，正文不会把中间未采样时段写成“绝无瞬态”。

用户/其他进程是否操作未得到确认，所有变化均**待归因**。采样中没有 TextEdit/Calculator/Notes 成为前台；Electron、WeChat、Paseo、ghostty、Feishu、Chrome 间变化不能据此认定为我们的 focus steal。没有主动 activate/raise 恢复前台掩盖现象，也没有归位用户光标。

|批次|开始→结束 (+08:00)|前台 开始→结束|光标 开始→结束|变化|
|---|---|---|---|---|
|preflight|13:42:41→13:42:42|Paseo→Paseo|不可用（cliclick 缺失）→不可用（cliclick 缺失）|前台相同；光标缺测|
|preflight.corrected|13:43:02→13:43:02|Paseo→Paseo|不可用（cliclick 缺失）→不可用（cliclick 缺失）|前台相同；光标缺测|
|baseline|13:44:06→13:44:06|Paseo→Paseo|(828.9258,788.4609)→(828.9258,788.4609)|端点相同|
|R1.modifier-aliases|13:44:21→13:44:23|WeChat→WeChat|(497.3086,612.9141)→(593.2305,708.5938)|待归因|
|R2.menu-shortcuts|13:44:23→13:44:31|WeChat→WeChat|(593.2305,708.5938)→(593.2305,708.5938)|端点相同|
|R3.fixture-create|13:44:49→13:44:52|Paseo→Paseo|(737.1836,564.1992)→(385.3945,477.3516)|待归因|
|R3.cascade-initial|13:44:53→13:44:55|Paseo→Paseo|(532.8125,467.3555)→(726.4297,526.3867)|待归因|
|R3.align-counters|13:45:43→13:45:44|WeChat→WeChat|(523.6836,836.8984)→(523.6836,836.8984)|端点相同|
|R3.aligned-cascade|13:45:44→13:45:46|WeChat→WeChat|(523.6836,836.8984)→(523.6836,836.8984)|端点相同|
|R4.source-destroy|13:45:46→13:45:46|WeChat→WeChat|(523.6836,836.8984)→(523.6836,836.8984)|端点相同|
|P.fixture-create|13:46:12→13:46:17|WeChat→WeChat|(956.0781,768.0234)→(956.0000,768.0000)|待归因|
|R4.retry-source-destroy|13:46:35→13:46:39|Electron→Electron|(1193.9141,212.1953)→(1471.3320,222.7812)|待归因|
|P01.type-text-methods|13:47:28→13:47:32|ghostty→ghostty|(296.0039,814.0117)→(296.0039,814.0117)|端点相同|
|incident.physical-crash|13:48:01→13:48:02|ghostty→ghostty|(305.6055,813.2305)→(305.6055,813.2305)|端点相同|
|recovery.daemon|13:48:26→13:48:29|ghostty→ghostty|(50.3320,673.4102)→(50.3320,673.4102)|端点相同|
|P01.type-text-methods-recovered|13:49:03→13:49:12|ghostty→ghostty|(601.7734,415.5039)→(1066.9844,647.0312)|待归因|
|P03.select-text-boundaries|13:49:12→13:49:21|ghostty→ghostty|(1066.9844,647.0312)→(466.2344,153.2500)|待归因|
|P04.set-value-types|13:49:21→13:49:24|ghostty→ghostty|(468.4805,153.2578)→(208.4883,805.3359)|待归因|
|P02.snapshot-diff-boundaries|13:50:20→13:50:40|Paseo→WeChat|(557.0234,631.7266)→(616.9609,542.9844)|待归因|
|P05.press-disabled-errors|13:50:41→13:50:41|WeChat→WeChat|(616.9609,542.9844)→(616.9609,542.9844)|端点相同|
|P06.enumeration-dead-pid|13:50:41→13:50:42|WeChat→WeChat|(616.9609,542.9844)→(616.9609,542.9844)|端点相同|
|P07.wakeup-boundaries|13:50:42→13:51:00|WeChat→WeChat|(616.9609,542.9844)→(630.6836,640.6016)|待归因|
|recovery.daemon|13:51:45→13:51:47|Paseo→Paseo|(1274.0547,517.0000)→(1274.0547,517.0000)|端点相同|
|P06.enumeration-dead-pid|13:52:13→13:52:13|WeChat→WeChat|(1197.4375,454.8672)→(1197.4375,454.8672)|端点相同|
|P07.wakeup-boundaries|13:52:13→13:52:36|WeChat→WeChat|(1197.4375,454.8672)→(737.2578,592.0938)|待归因|
|P08.fragment-reconnect-ref|13:52:47→13:52:52|WeChat→WeChat|(737.2578,592.0938)→(755.1992,747.3047)|待归因|
|P09.pip-duplicate-nowindow-armdestroy|13:52:52→13:52:57|WeChat→WeChat|(755.1992,747.3047)→(466.2422,525.7773)|待归因|
|P10.error-schema|13:52:57→13:52:57|WeChat→WeChat|(466.2422,525.7773)→(466.2422,525.7773)|端点相同|
|P10.cleanup-pip|13:52:58→13:52:58|WeChat→WeChat|(466.2422,525.7773)→(466.2422,525.7773)|端点相同|
|P11.capture-stale-coordinate-space|13:53:22→13:53:30|Paseo→WeChat|(466.2422,521.9219)→(469.4023,773.2422)|待归因|
|confirm.unicode-postcondition|13:54:05→13:54:13|Paseo→Google Chrome|(631.4336,586.6406)→(1056.5703,410.1875)|待归因|
|confirm.empty-fields-and-ax-error|13:54:50→13:54:56|WeChat→WeChat|(234.5352,257.1016)→(234.5352,257.1016)|端点相同|
|confirm.validation-order|13:55:10→13:55:11|WeChat→WeChat|(234.0000,257.0000)→(234.0000,257.0000)|端点相同|
|confirm.armed-destroy-other-driver|13:55:11→13:55:11|WeChat→WeChat|(234.0000,257.0000)→(234.0000,257.0000)|端点相同|
|confirm.capture.capture-stale-coordinate-space|13:55:19→13:55:30|Paseo→WeChat|(628.1367,376.6875)→(628.1367,376.6875)|待归因|
|confirm.armed-destroy-other-driver|13:55:47→13:55:51|Electron→Electron|(388.9297,351.0820)→(1229.8516,764.6289)|待归因|
|confirm.no-window-wakeup-zero|13:55:51→13:55:53|Electron→Electron|(1229.8516,764.6289)→(1050.1641,924.8789)|待归因|
|confirm.resolution-transients|13:56:43→13:56:45|Feishu→Feishu|(732.4492,462.6523)→(732.4492,462.6523)|端点相同|
|P01.auto-no-ref-event-route|13:56:45→13:56:49|Feishu→Feishu|(732.4492,462.6523)→(732.4492,462.6523)|端点相同|
|cleanup.owned-windows-and-pip|13:57:45→13:57:49|Feishu→Feishu|(732.4492,462.6523)→(732.4492,462.6523)|端点相同|
|cleanup.discard-test-document|13:58:38→13:58:43|Paseo→Paseo|(1052.1641,459.1328)→(1052.1641,459.1328)|端点相同|
|confirm.selection-with-fresh-ax-only-document|13:59:50→13:59:58|WeChat→WeChat|(523.0273,466.7539)→(609.1641,586.8047)|待归因|

### 连续采样的前台转换

|时间 (+08:00)|frontmost|样本标签|
|---|---|---|
|13:42:41.759|Paseo|preflight.before|
|13:44:20.681|WeChat|monitor|
|13:44:48.404|Paseo|monitor|
|13:44:57.436|WeChat|monitor|
|13:46:34.046|Paseo|monitor|
|13:46:35.219|Electron|R4.retry-source-destroy.before|
|13:46:39.201|Paseo|monitor|
|13:46:39.954|Electron|R4.retry-source-destroy.after|
|13:47:00.309|ghostty|monitor|
|13:47:13.691|Electron|monitor|
|13:47:17.022|ghostty|monitor|
|13:47:37.067|Electron|monitor|
|13:47:38.029|ghostty|monitor|
|13:49:39.327|Electron|monitor|
|13:49:40.266|Paseo|monitor|
|13:49:42.162|WeChat|monitor|
|13:50:01.264|Paseo|monitor|
|13:50:27.966|WeChat|monitor|
|13:50:53.711|Paseo|monitor|
|13:50:57.428|WeChat|monitor|
|13:51:04.064|Paseo|monitor|
|13:51:31.693|WeChat|monitor|
|13:51:44.185|Paseo|monitor|
|13:52:12.675|WeChat|monitor|
|13:52:15.510|Paseo|monitor|
|13:52:16.482|WeChat|monitor|
|13:52:21.267|Paseo|monitor|
|13:52:32.655|WeChat|monitor|
|13:53:21.275|Paseo|monitor|
|13:53:23.172|WeChat|monitor|
|13:53:47.211|Paseo|monitor|
|13:54:07.379|Google Chrome|monitor|
|13:54:18.947|Paseo|monitor|
|13:54:40.936|WeChat|monitor|
|13:55:14.309|Paseo|monitor|
|13:55:21.013|WeChat|monitor|
|13:55:22.982|Google Chrome|monitor|
|13:55:23.940|WeChat|monitor|
|13:55:38.099|Electron|monitor|
|13:55:41.962|WeChat|monitor|
|13:55:42.916|Electron|monitor|
|13:55:56.248|Google Chrome|monitor|
|13:55:57.190|Paseo|monitor|
|13:56:13.228|Feishu|monitor|
|13:58:04.259|Paseo|monitor|
|13:59:50.153|WeChat|confirm.selection-with-fresh-ax-only-document.before|

## 清理、保留现场与限制

- 本轮创建 **5 个** TextEdit 测试文稿窗 `234320, 234393, 234560, 234656, 234718`，全部关闭；修改过的文稿只对本轮保存表单点“删除”，未保存到用户目录。最终仅原窗230637，原内容 `é👩‍💻` 双端读回。
- Calculator 原窗230248：bounds(306,462,230,408)；Notes 原窗230343：bounds(35,39,1000,660)、145个备忘录，均与初始一致。未创建/删除 Notes 笔记。
- 所有本轮 PiP 会话与 armed 已逐窗关闭/解除，最终两端 `{sessions:[],armed:[]}`，两个 ping 成功；保留原两 daemon 服务，其中 ours 因两次崩溃换为 PID89009。
- 测试截图/崩溃报告/临时探针只在证据目录及 `/tmp`；不删除作为证据的文件。截图生成文件 `P11-*.jpg`、`C-capture-*.jpg` 均保留。
- GUI 测试结束哨兵最后为 WeChat/(609.1641,586.8047)。前台在测试过程中多次变化，原因尚未确认，未擅自切回起始 Paseo；“恢复现场”指撤销本轮创建与修改的测试对象。
- 未覆盖多屏、多 Space、超大 Notes 树、slider/stepper/datefield、完整 F1…F12 菜单 fallback、MCP wrapper 的 sky_* 展示层、wakeup 中断；没有为补覆盖制造长时间阻塞或改变已有用户控件设置。

## 可复核文件

- 原始请求：`/tmp/cu-field-r3-20261009-134241/requests.jsonl`
- 完整哨兵：`/tmp/cu-field-r3-20261009-134241/sentinel.jsonl`
- 响应差异：`/tmp/cu-field-r3-20261009-134241/comparisons.jsonl` 与 `phase2-results.jsonl`
- 回归定位/销毁：`r3-initial-frames.json`、`r3-aligned-frames.json`、`r4-destroy.json`
- 崩溃报告：`minami-studio-2026-10-09-134734.ips`、`minami-studio-2026-10-09-135043.ips`
- 所有临时脚本/输出与散列：同目录 `r3*.py`、`r3*.out`、`manifest.json`。生产仓库不新增可执行测试代码。

## 产出核验

已核对4条Phase1、11条Phase2主表、6个确认bug编号、所有新增JSON/Python代码块、Markdown表格列数与本地文档链接。BUGS/RUNLOG保留原有内容，仅末尾追加；Git差异仅限本轮三份报告，预先存在的未跟踪R3-TASK.md未改。二进制散列与记录一致，证据manifest逐项校验通过。重启daemon的stdout/stderr仍会增长，另复制为`.frozen`后参与散列；活动日志原件不列入manifest。
