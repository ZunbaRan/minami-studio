> 本轮有效实测：2026-10-09 11:13起，MCP和哨兵实际可用。当前确认 **4项minor实现差异**：opt别名、menu_shortcuts按键名、PiP默认位置/布局、源窗口关闭后PiP残留；另保留**16项前台/光标变化观察**（1项major、15项minor，均待归因）。文件原有CX00两项blocker属于另一权限环境的记录，保留历史，不计入本轮结果。没有修改源码/配置。

# CX field mission bugs

本文件只记观察，不修代码。差异需真 Alma 同请求对照；Alma 同样表现标为 parity，不计实现 bug。前台/光标变化单独记录，因果未证实时明确注明。

## BUG-CX00-MCP授权策略阻断全部探测
- 严重度: blocker
- 分类: 测试运行环境阻塞；不是已确认的 agent-computer-use 实现缺陷，不计入 parity bug。
- 任务: CX00 预检，在开始真实桌面任务前检查权限、应用和 TextEdit 状态。
- 复现: 依次调用 `agent_computer_use.permissions({})`、`agent_computer_use.list_apps({"days":1})`、`agent_computer_use.get_app_state({"bundle":"com.apple.TextEdit","auto_launch":false,"depth":2,"interactive_only":true})`。
- 实际: 三次均返回 `{"content":[{"type":"text","text":"MCP tool call requires approval, but approval policy is never"}],"isError":true}`。未得到 daemon 响应或应用快照。
- 期望: 运行环境允许本次已授权的 MCP 测试请求到达被测工具；此期望来自任务执行前提，不是对 Alma wire 的修改建议。
- 真机对照: 未执行。拒绝发生在工具授权层，未取得可与 Alma daemon 对比的被测响应。不可将该文字当作 Alma 错误语义。
- 时间/环境备注: 2026-10-09 11:11–11:12 +08:00；当前会话 `approval_policy=never`、workspace-write；未更改任何配置，未绕过 MCP 去驱动被测 daemon。

## BUG-CX00-哨兵无法取得前台和光标基线
- 严重度: blocker
- 分类: 测试运行环境/哨兵可观测性阻塞；不是已确认的前台窃取或光标漂移。
- 任务: CX00 首次前台及光标采样。
- 复现: 执行 `/tmp/cu-review/frontmost.sh`；随后单独执行 `osascript -e 'tell application "System Events" to get bundle identifier of first process whose frontmost is true'` 和 `swift -e 'import Cocoa; print(NSEvent.mouseLocation)'`，查看原脚本隐藏的 stderr。
- 实际: 原脚本输出 `frontmost= pid= cursor=`，但 exit 0。单独 osascript exit 1，输出 `40:98: execution error: 发生“-10827”类型错误。 (-10827)`。Swift exit 1，首先报告无法写入 `/Users/lu/.cache/clang/ModuleCache/.../SwiftShims-....pcm`：`Operation not permitted`；其后还报告 SDK/compiler 版本不匹配，不能仅凭级联诊断断定独立根因。一次无文件写入的 Python ctypes/AppKit 只读哨兵尝试 exit 134，无输出，未获得替代基线。
- 期望: 哨兵返回有效 bundle、pid 和光标坐标；空值不能视为前后台保持稳定。
- 真机对照: 不适用；这是桌面测试哨兵失败，尚无 GUI 动作可归因或对照。
- 时间/环境备注: 2026-10-09 11:11–11:14 +08:00。原哨兵文件只读，未修改。未激活任何 app 以恢复检测。

## CX00旧会话定性汇总（历史，不代表本轮）
- 实现 parity bug：0 个已确认；由于 GUI 实测未开始，不能据此认为实现无 bug。
- 环境 blocker：2 个。
- 前台/光标偏移：无法判定；基线不可用，不能报告“未变化”。
- PiP：当前 23 工具 MCP 闭集中无 pip_*，属于测试入口限制，不报实现缺陷；是否允许额外 socket 测试仍待用户答复。

补充复核：CX00 收尾时原哨兵再次返回 `frontmost= pid= cursor=`（exit 0），仍不可用。没有观察到可归因的前台/光标变化，因为没有有效采样。

## BUG-CX02-opt-修饰键不识别
- 严重度: minor
- 任务: 后台 TextEdit 查找替换。
- 复现: MCP press_key({"bundle":"com.apple.TextEdit","window_id":232171,"key":"cmd+opt+f"})。
- 实际: `unknown modifier "opt" in "cmd+opt+f"`。
- 期望: 接受 opt 别名，再依据 enabled 菜单项决定派发或 suppressed。
- 真机对照: 2026-10-09 11:15 CST，alma socket 同 cmd/args 返回 `ok:true,data:{pressed:"cmd+opt+f",delivered:false,delivery_note:"the target app is in the background and no ENABLED menu item owns this chord, so nothing was posted …"}`，无 via；没有 unknown modifier。
- workaround: `cmd+alt+f` 在被测 MCP 可解析，但本场景仍正确 suppressed；用 select_text + type_text(input_method:ax) 完成定点替换。
- 时间/环境备注: TextEdit pid64284，测试窗232171；macOS 本机；未改代码。

## BUG-CX03-Finder-前台变化待归因
- 严重度: major
- 任务: TextEdit 保存后通过 Finder 清理 CX03 测试文件。
- 复现: Finder `get_app_state(depth:2)`；`press_key(cmd+n)`；`press_key(cmd+shift+g)`；`set_value(e298,"/Users/lu/Desktop/")`；`type_text(text:"\n",input_method:"physical",window_id:232187)`；`get_app_state(depth:5,screenshot_max_width:800)`；`perform_secondary_action(x:195,y:88,coord_space:screenshot,window_id:232187)`；快照。
- 实际: 11:16:47 前台 com.electron.lark/3299；11:17:37 变为 com.apple.finder/1661；光标始终970,522。尚不能在上述序列中定位单一触发调用。
- 期望: 用户原前台保持。没有主动 activate/raise，也没有恢复前台掩盖事件。
- 真机对照: 未完成焦点复现。目标已成为前台，此时重复同操作无法有效比较后台焦点保护；且用户硬约束禁止故意再次抢前台。已询问用户是否手动切换；未答复前为观察事件，不计确认 parity 差异。
- 时间/环境备注: 2026-10-09 11:17 CST；Finder测试窗232187；仅本轮创建的 CX03_Field_20261009.rtf 被移到废纸篓；既有文件未碰。

## BUG-CX04-哨兵变化待归因
- 严重度: minor
- 任务: TextEdit多窗口隔离及清理。
- 复现: CX04两个测试窗set_value、指定window_id快照、AXCloseButton与表单删除；详见RUNLOG。
- 实际: 前11:19:16 Finder/970,522；后11:20:35 Lark/676,603。
- 期望: 工具不改变用户前台/光标。
- 真机对照: 未归因到调用，不能构造有效同请求焦点对照。变化目标为用户常用飞书，不是被操作的TextEdit；不据此认定工具抢前台。
- 时间/环境备注: 2026-10-09；用户是否手动操作尚未回复；按要求保留观察记录，不计确认实现差异。

## BUG-CX05-哨兵变化待归因
- 严重度: minor
- 任务: Finder创建/重命名测试目录。
- 复现: RUNLOG CX05操作序列。
- 实际: 11:20:36 Lark/676,603；11:23:41 Lark/961,28；11:24:00 Paseo/637,307；11:24:45及49单次采样Paseo/(756.43,590.95)；11:26:09 Lark/(807.27,21.19)。
- 期望: 工具不移动光标或切前台。
- 真机对照: Alma的physical换行和右键对照均未见前台/光标改变；但不能对本段持续用户活动归因。
- 时间/环境备注: 原frontmost.sh分次读取bundle和pid，11:24:21得到Lark+Finder pid1661的混合状态。此后改为一次Swift读取NSWorkspace.frontmostApplication与NSEvent.mouseLocation。没有恢复前台掩盖记录。

## BUG-CX06-哨兵变化待归因
- 严重度: minor
- 任务: Finder文件操作。
- 复现: RUNLOG CX06；无主动activate/raise。
- 实际: 11:27:33 Lark/(822.43,448.375)；11:28:39 Paseo/(650.89,139.78)；11:30:36 Lark/(983.69,274.12)。
- 期望: 不扰动用户前台和光标。
- 真机对照: 拖动被测路径11:29:11→13前后台与光标完全保持Paseo/(1060,152)；Alma拖动也未实现文件移动。整段光标持续用户活动，无法归因到工具。
- 时间/环境备注: 2026-10-09，按任务硬约束登记观察，不计确认实现差异。

## BUG-CX18-menu_shortcuts键名与Alma不一致
- 严重度: minor
- 分类: 已确认实现parity差异。
- 任务: 计算器截图/OCR与快捷键边界检查。
- 复现: MCP get_app_state({bundle:"com.apple.calculator",depth:0,interactive_only:true,screenshot_max_width:460})；wrapper向daemon固定附加include_screenshot:true。
- 实际: menu_shortcuts同一路径[窗口,关闭]为cmd+key13，[显示,基础]为cmd+key18，[编辑,拷贝]为cmd+key8。TextEdit、Notes亦见同类数字键码fallback。
- 期望: 与Alma快照相同，返回可读的cmd+w、cmd+1、cmd+c，不把硬件keycode替代实际按键名。
- 真机对照: 2026-10-09 11:56及12:06，对alma socket get_app_state同bundle/depth/interactive_only/include_screenshot/screenshot_max_width，返回对应三项分别为cmd+w、cmd+1、cmd+c。第二次对照request id d72ea4ddc2ea，ok:true。不是JSON键序差异。
- 时间/环境备注: 本机Calculator pid57752、W230248；未变更键盘布局或系统设置；只记录不修。暂用已验证标准chord及AX按钮，不能照抄key13当可用键名。

## CX06清理尾段补充观察
12:00:01前后开始Finder逐项删除；此前11:59:48 Ghostty/(859,522)，12:00:57变为Finder/(859,522)。操作是CX05空文件夹的“立即删除…”确认与关闭测试窗。没有主动activate，但两采样间有前台变化，归并BUG-CX06待归因；尚无单调用对照证明触发源。后续12:01:39又为Ghostty/(636.69,195.38)。

## BUG-CX07-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Notes建写与清理。
- 复现: RUNLOG对应任务的MCP序列：set_value/type_text、列表AXShowMenu与失败像素删除；最终有效删除12:08:15→25 Electron/(1252,674)完全相同。
- 实际: 前/中采样 11:34:53 Passwords/(405.65,727.13)；后采样 11:39:21 Chrome/(678,401)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX09-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Calculator基本计算清零。
- 复现: RUNLOG对应任务的MCP序列：AX按钮序列；计算结果11:42:46哨兵仍与前相同，变化出现在清理阶段。
- 实际: 前/中采样 11:42:17 Chrome/(840,480)；后采样 11:43:15 Chrome/(892,521)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX10-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Calculator科学计算。
- 复现: RUNLOG对应任务的MCP序列：cmd+2、AX 5!、AC、cmd+1。
- 实际: 前/中采样 11:43:16 Chrome/(892,521)；后采样 11:45:06 Paseo/(433.41,424.93)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX11-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Preview后台打开面板。
- 复现: RUNLOG对应任务的MCP序列：cmd+o、suppressed cmd+shift+g、physical斜杠、AX取消。
- 实际: 前/中采样 11:45:28 Paseo/(433,425)；后采样 11:46:37 Chrome/(678.94,549.53)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX12-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Music只读导航。
- 复现: RUNLOG对应任务的MCP序列：开始聆听AX按钮、歌曲cell physical点击；没有播放或购买。
- 实际: 前/中采样 11:46:38 Chrome/(678.94,549.53)；后采样 11:47:46 Chrome/(469.71,482.38)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX13-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Calendar月视图只读。
- 复现: RUNLOG对应任务的MCP序列：cmd+0、下一月/上一月AX按钮、关闭测试窗。
- 实际: 前/中采样 11:47:23 Chrome/(678.94,549.53)；后采样 11:48:26 WeChat/(254.72,605.60)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX14-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Reminders后台欢迎与只读字段。
- 复现: RUNLOG对应任务的MCP序列：欢迎页继续、CX14搜索字段set_value再清空、关闭测试窗。
- 实际: 前/中采样 11:48:27 WeChat/(254.72,605.60)；后采样 11:49:19 WeChat/(152.12,488.36)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX15-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Maps和Mail只读。
- 复现: RUNLOG对应任务的MCP序列：Maps cmd+n、Mail cmd+0、浅快照和关闭；未选未读邮件或发送。
- 实际: 前/中采样 11:49:19 WeChat/(244.57,369.98)；后采样 11:50:22 Ghostty/(568.11,507.24)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX16-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: Stocks冷启动。
- 复现: RUNLOG对应任务的MCP序列：launch_app({bundle:"com.apple.stocks",activates:false})；是子像素差异，Weather启动前后598,277完全相同。
- 实际: 前/中采样 11:51:33 Paseo/(598.484,276.844)；后采样 11:51:35 Paseo/(598,277)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX18-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: 截图与OCR探测。
- 复现: RUNLOG对应任务的MCP序列：Music depth0与v1失败点击、Calculator screenshot坐标输入8后AC；本任务起始采样的精确值未完整落盘，不编造。
- 实际: 前/中采样 中段11:56:22 Paseo/(588.34,141.98)；后采样 11:57:38 Lark/(859.71,521.90)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## BUG-CX19-哨兵变化待归因
- 严重度: minor
- 分类: 按任务硬约束登记观察，非已确认实现差异。
- 任务: 三app搬运和文件清理。
- 复现: RUNLOG对应任务的MCP序列：Calculator AX、Notes自有笔记、TextEdit Unicode与保存；12:09:44为Lark/(117.125,846.945)，没有操作系统设置。
- 实际: 前/中采样 12:02:26 Ghostty/(1048.54,699.38)；后采样 12:04:15 System Settings/(779.80,579.69)。
- 期望: 工具不改变用户前台及光标；实际不同必须保留。
- 真机对照: 未定位到触发调用，无法构造有效同请求因果对照。对具体动作的语义对照见RUNLOG，不替代焦点对照。
- 时间/环境备注: 2026-10-09 CST，桌面持续有人或其他进程活动；已询问是否手动/并发操作，尚未获得答复。没有主动activate或用恢复前台掩盖变化。

## 后续收尾哨兵
- 12:12:22 Lark/(1098.09,502.41)→12:12:31 Lark/(1115.39,542.61)，期间仅多个app浅快照复核，归并后续清理观察，非新增实现差异。
- 同一路径RUNLOG开头曾出现“0项执行”的另一预检记录，而本轮有效MCP调用已执行；文档存在外部并写证据，但不能由此断言所有桌面变化都来自另一agent。

## 不计bug的本轮Alma对照
- visual_refs字段名、v1/v2乱码及bbox均同Alma；普通MCP ref分支丢目标后v*点击invalid_arg也同Alma。
- Finder physical下划线不支持；拖到边栏文稿无移动；Notes上下文像素点击只关闭菜单，均同Alma。
- unknown bundle/ref、空key、后台cmd+s suppressed，错误文案与Alma一致。
- PiP入口缺失、Preview路径面板受阻、大AX树慢，是覆盖限制或已知parity，不包装为新的实现缺陷。

收尾采样补充：12:18:14 Lark Helper/(1500.46,323.27)→12:22:12 Paseo/(857.367,327.125)。期间写文档并只读复核Calculator/Notes/Finder，归并收尾观察；没有主动切换用户前台。

## BUG-CX17-floater-frame默认位置与Alma不同
- 严重度: minor
- 任务: CX17，后台同时打开 TextEdit 和 Calculator PiP，核对默认几何及多浮窗布局。
- 复现: 两端初始 `pip_status({}) → sessions:[],armed:[]`。按顺序向各 daemon 发送 `pip_open({"bundle":"com.apple.TextEdit","pid":64284,"window_id":233332,"title":"CX17_TextMirror"})`、`pip_open({"bundle":"com.apple.calculator","pid":57752,"window_id":230248,"title":"CX17_CalculatorMirror"})`，再 `pip_status({})`。MCP 23 工具没有 pip_*，本项按用户新增授权走 socket。
- 实际: ours 的 TextEdit 返回 `floater_frame:{x:1248,y:84,w:240,h:200}`；Calculator 返回 `{x:1248,y:84,w:240,h:426}`。两窗共用原点。MCP 对 ours helper pid36812 的截图读取到 TextEdit 浮窗 W233386 的 AX bounds `{x:1248,y:698,w:240,h:200}`、Calculator W233389 的 AX bounds `{x:1248,y:472,w:240,h:426}`；不能把 native floater_frame 直接当作 AX/截图点击坐标。
- 期望: 同屏、同源窗口、同请求的默认位置及后续浮窗布局与 Alma 一致；不要求固定通用坐标或固定334×220尺寸。
- 真机对照: Alma TextEdit `{x:1248,y:725,w:240,h:200}`；Calculator `{x:1220,y:471,w:240,h:426}`。重复 open 维持各自原有 frame。关闭后继续新开时，Alma 又出现 x1192、x1164 的阶梯变化，ours 仍 x1248/y83–84。宽高一致，位置/后续布局不一致。差异不能用 JSON 键序或随机 id 解释；这里不推断 Alma 返回坐标系的根因。
- 时间/环境备注: 2026-10-09 12:31:46–12:33:47 +08:00；ours socket computer-use-72097929.sock，Alma socket computer-use-9bd08bc1.sock；首次状态双方空。请求及完整响应逐条保存在 RUNLOG 的 CX17 socket evidence。前台采样均 Paseo，未激活目标 app；只记录，不改源码。
- workaround: 用 MCP `get_app_state(pid:helperPid)` 得到真正浮窗 window.id/截图；后续截图指定浮窗 id。不要用 pip_status 的 frame 代替 get_app_state 的像素映射。

## BUG-CX17-哨兵光标变化待归因
- 严重度: minor
- 分类: 按用户硬约束记录的哨兵异常；未确认为实现 parity 差异。
- 任务: CX17 测试准备、双应用 PiP open/status/arm/disarm/close。
- 复现: 以单次 Swift 读取 `NSWorkspace.shared.frontmostApplication` 与 `NSEvent.mouseLocation`；GUI 使用 MCP，PiP 使用获授权的 daemon socket。具体 PiP 调用见 RUNLOG CX17 evidence。
- 实际: 前台所有这些采样都为 `sh.paseo.desktop/20400`。光标 12:28:58 `(857,328)` → 12:31:37 `(747.40234375,387.58984375)` → 12:31:52 `(801.69921875,333.03125)` → 12:32:00 `(772.95703125,322.56640625)` → 12:32:26 `(738.83203125,134.9609375)` → 12:32:35 `(70,397.86328125)`；P2 的 12:32:55 `(314.07421875,444.69140625)` → 12:33:06 `(1125.0703125,665.33984375)`。不能视为“全程无漂移”。
- 期望: 工具不应更改用户前台或光标；后台操作前后光标应保持基线。
- 真机对照: ours 与 Alma 交错执行，未隔离用户输入，无法将上述变化归因单端。后续 P3 最小化一次性消费（12:33:15→12:33:32）、P4 已有会话时消费（12:33:42→12:33:47）均为 Paseo/20400、`(806,316)`，完全一致。
- 时间/环境备注: 2026-10-09 +08:00；没有执行 activate、鼠标恢复或前台恢复来掩盖变化。后续收尾采样见 RUNLOG。

## BUG-CX17-源窗口关闭后PiP会话残留
- 严重度: minor
- 任务: CX17 收尾关闭测试源文稿，验证 PiP session 随源关闭的生命周期；另建第二个文稿复现。
- 复现: MCP `press_key({bundle:"com.apple.TextEdit",key:"cmd+n"})` 创建 W233456；`set_value({bundle:"com.apple.TextEdit",ref:"e182",value:"CX17_DestroyProbe\nSource-close comparison"})`。向两端发完全相同的 `pip_open({"bundle":"com.apple.TextEdit","pid":64284,"window_id":233456,"title":"CX17_DestroyProbe"})`；本次没有 arm。MCP `click({bundle:"com.apple.TextEdit",ref:"e219",strategy:"ax"})` 关闭源文稿，在该测试文稿保存面板 `click({bundle:"com.apple.TextEdit",ref:"e245",strategy:"ax"})` 删除未存内容，然后两端 `pip_status({})`。
- 实际: 12:36:14.365 ours 仍有 W233456 session，`last_frame_age_ms:1078`；12:36:38.123 仍有，帧龄24837；12:36:56.422 仍有，帧龄43135。源已关闭43秒仍保留不更新的 session。最终显式 `pip_close({bundle:"com.apple.TextEdit",pid:64284,window_id:233456})` 返回 `data:{closed:true,window_id:233456}`，之后 status 为空。
- 期望: 对同一源关闭事件与 Alma 一致，清除对应 session，不留下无新帧浮窗。
- 真机对照: 同请求 open 成功；同一个 MCP 源窗口关闭事件后，12:36:14.451、12:36:38.217、12:36:56.523 Alma 均 `data:{armed:[],sessions:[]}`；最后同请求 close 返回 `closed:false`，表示已不存在。
- 首次观察: W233332 的 auto-open session 在源关闭后，ours 留存至少20秒，helper 浮窗截图显示空白/等待指示，Alma sessions 已空；两端 armed 均仍有条目，armed 留存本身属于 parity。随后12:36:01 对旧 session close 两端均 false，消失时点/原因未观测，不能声称它永久泄漏。第二次 W233456 无 arm、无自动打开，仍复现43秒残留，最终由明确的 socket close 清掉。
- 时间/环境备注: 2026-10-09 12:35:28–12:36:57 +08:00；第二次关闭前12:36:12、关闭后12:36:14、延后12:36:39、清理后12:36:58，哨兵均 `sh.paseo.desktop/20400,(609,138)`。没有发送焦点激活；仅删除本轮两个未保存测试文稿。完整 socket 回包见 RUNLOG。
- workaround: 不依赖源关闭自动收尾；对本轮登记的源 ID 显式 disarm、close，并对照初始 status 验证。

CX17 哨兵观察补记：P6 12:35:16 的 Paseo/20400 `(806,316)` → 12:35:30 `(746,320)` → 12:35:47 `(689.37890625,251.26953125)`，归入 BUG-CX17-哨兵光标变化待归因；P7 12:36:12→12:36:58 保持 Paseo/20400 `(609,138)`。
