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

---

## 修复记录（2026-10-09 下午，commit 前）

全部四个确认 bug 已修复并逐条对真机验证：

### BUG-CX02-opt-修饰键 → FIXED
- 修法：`KeyParser.parse` 修饰键表补 `opt`（真机全集实测：`cmd/command/meta/super`,`ctrl/control`,`shift`,`alt/option/opt`,`fn/function`;`ctl`/`win`/`caps` 拒绝——与我们一致）。
- 验证：`press_key cmd+opt+f` 后台 TextEdit → `delivered:false` + 逐字 delivery_note，与真机同。

### BUG-CX18-menu_shortcuts → FIXED
- 修法：`chordString` 解耦 keyCode 解析——mods 取自 `AXMenuItemCmdModifiers` 位（bit3 set=无 cmd；顺序 cmd/ctrl/opt/shift),key 部分 = `AXMenuItemCmdChar.lowercased()` 原样（⎋/\x1b/? 等 glyph 直出）；char 空→`AXMenuItemCmdVirtualKey` 查 vk 命名表；表外→`vk%02X`。
- vk 命名表从 0x100030bc0 跳表逐 arm 解码：36 Return,48 Tab,49 Space,51 Backspace,53 Escape,96 F5,97 F6,98 F7,99 F3,100 F8,101 F9,103 F11,109 F10,111 F12,115 Home,116 PageUp,117 Delete,118 F4,119 End,120 F2,121 PageDown,122 F1,123 Left,124 Right,125 Down,126 Up。
- 验证：Calculator/TextEdit/Notes 三 app combo 集合与真机差集为空（41/41、全部命中）。

### BUG-CX17-floater-frame → FIXED
- 修法：从 `PIPFloaterWindow.nextCascadeOrigin(size:)` @0x10004f36c 逐指令还原：全局单调 counter(锁保护、关闭不重置、读旧值再自增）,`x=max(vf.maxX-w-24-28n, vf.minX+12)`,`y=max(vf.maxY-h-24-28n, vf.minY+12)`,mainScreen nil→(100,100)。此前实现的"右下锚定"是错的——真机是 Cocoa 顶部锚定（视觉右上）。
- 验证：本机 vf.maxY=949 → 首开 h200 → (1248,725)、第二个 h426 → (1220,471)，与真机记录逐字节一致。

### BUG-CX17-源窗口关闭残留 → FIXED
- 根因：我们的回调用 `windowIDNumber(el)==windowId` 过滤，但**已销毁元素的属性不可读**→永远 false→会话残留。曾尝试 CGWindowList 存在性判定——又踩到 **AX 销毁先于 CGWindow 移除**的竞态（回调瞬间 CG 列表还在）。
- 真机语义：观察器只挂在**解析出的窗口元素**上（解析失败不装）,destroyed 通知即权威，无条件 `PIPManager.close(windowId:)`。
- 修法：去掉 wid 过滤与 CG 检查；winEl 解析失败则不装观察器（同真机）。MinimizeArmer 的 destroyed 同病同治：按 `CFEqual(el, arm.element)` 元素身份定位 arm。
- 验证：AXPress 关闭源窗口 → 1s 内 `sessions:[]`；后续 `pip_close` → `closed:false`，与真机逐字一致。


## Round-3 回归新发现

run_id=`r3`，2026-10-09；原4项修复回归均PASS，Phase2选11项补扫。确认 **6类差异：2 major、4 minor**。证据来自两个指定 socket，同请求对照；ref按两端快照重绑。完整范围、哨兵、恢复与未覆盖项见 [R3-VERIFY.md](R3-VERIFY.md)。本节仅记录及建议裁决，没有改码。对象键序、计时、不同历史PiP计数不当作实现bug。

> **Round-4 修复(同日,已验证)**：R3-01 `KeyboardLayoutTranslator.keyPresses` 改经 DispatchQueue.main 执行(HIToolbox 队列断言);R3-02 `cmdScroll` 循环钳制 `max(1,pages)`(反汇编 csinc 实锤,0/-1 仍执行一次);R3-03 快照空字符串字段统一不发射;R3-04 ax_failure 文案补 `AX error ` 前缀+句点;R3-05 armed 条目在源窗销毁后保留(disarm 仍 true);R3-06 type_text 目标校验先于 ax-ref 校验。六项均双 socket 复验通过,daemon 不再因 physical/pages:-1 崩溃。

### BUG-R3-01 — physical type_text 触发输入源读取队列断言

- 严重度：major（daemon进程退出）。
- 现象：后台测试TextEdit W234393，AX重置为ANCHOR并选中后，`type_text(input_method:physical,text:"A\nB",settle_ms:0)` 导致我们的连接EOF，后续ping拒绝连接。
- 我们：原PID81258于13:47:34 `EXC_BREAKPOINT/SIGTRAP`；故障线程8栈为 `_dispatch_assert_queue_fail` → `islGetInputSourceListWithAdditions` → `TISCopyCurrentKeyboardLayoutInputSource` → `KeyboardLayoutTranslator.keyPresses(for:)`（Input.swift:135）→ `cmdTypeText`（Daemon+Actions.swift:1094）。这是运行时崩溃证据，不是仅凭源码推测。
- 真机：相同请求返回 `internal/type_text delivered no text...`，随后ping成功；没有进程退出。
- 证据命令：下面两个记录的request可用文末的socket客户端重放，text含真实换行（码点65,10,66）；先用本端快照ref重置/选中测试文稿。崩溃日志 `agent-computer-use-2026-10-09-134734.ips` 已留存。
- 裁决建议：接受为崩溃级parity差异，检查命中HIToolbox队列约束的键盘布局读取路径；不得把新增参数拒绝或永久禁用physical作为对齐。输入源运行状态可能影响触发，不宣称每次physical调用必崩。

```json
{
  "time": "2026-10-09T13:47:31.421936+08:00",
  "side": "ours",
  "request": {
    "id": "P01-physical-ascii",
    "cmd": "type_text",
    "args": {
      "bundle": "com.apple.TextEdit",
      "pid": 64284,
      "window_id": 234393,
      "text": "A\nB",
      "input_method": "physical",
      "settle_ms": 0
    }
  },
  "exception": "JSONDecodeError('Expecting value: line 1 column 1 (char 0)')"
}
```
```json
{
  "time": "2026-10-09T13:47:31.682538+08:00",
  "side": "alma",
  "request": {
    "id": "P01-physical-ascii",
    "cmd": "type_text",
    "args": {
      "bundle": "com.apple.TextEdit",
      "pid": 64284,
      "window_id": 234393,
      "text": "A\nB",
      "input_method": "physical",
      "settle_ms": 0
    }
  },
  "response": {
    "ok": false,
    "id": "P01-physical-ascii",
    "error": {
      "message": "type_text delivered no text: the target app has no key window, so the keystrokes were discarded (its AX element still reports focused=true — that only means it is the app's first responder). Use set_value with the element's ref to write the field directly. Do NOT bring the app forward to make typing land — Alma never takes the user's foreground.",
      "code": "internal"
    }
  }
}
```

### BUG-R3-02 — scroll 非正 pages 未采用 Alma 的有效步数语义

- 严重度：major（负数导致daemon退出）；pages=0同时有wire差异。
- 现象：测试文稿AXScrollArea声明AXScrollDownByPage，但执行返回不支持。对同一逻辑元素分别传pages0/-1。
- 我们：pages0直接成功 `scrolled:<ref>,pages:0`；pages-1在 `Daemon.cmdScroll` 的range遍历崩溃，PID87947退出。
- 真机：pages0和-1均尝试动作，返回 `action_unsupported/Element does not support action performing AXScrollDownByPage.`，继续正常服务。正数1/2经恢复后双端同错误。
- 证据命令：`P05-scroll-down--1`、`P05-scroll-down-0`，复核 `C-scroll-0/1/2`；两边ref来自同W234393的AXScrollArea。崩溃报告 `agent-computer-use-2026-10-09-135043.ips`，栈 `closure #1 in Daemon.cmdScroll(_:)`（Daemon+Actions.swift:1354）→ `_assertionFailure`。
- 裁决建议：接受；应复刻Alma的非正pages有效步数处理，不能自行增加invalid_arg墙。本次不推断Alma究竟钳制为几步，因为该控件第一步已失败。

```json
{
  "time": "2026-10-09T13:50:41.518321+08:00",
  "side": "ours",
  "request": {
    "id": "P05-scroll-down--1",
    "cmd": "scroll",
    "args": {
      "direction": "down",
      "pages": -1,
      "settle_ms": 0,
      "ref": "e2"
    }
  },
  "exception": "JSONDecodeError('Expecting value: line 1 column 1 (char 0)')"
}
```
```json
{
  "time": "2026-10-09T13:50:41.537037+08:00",
  "side": "alma",
  "request": {
    "id": "P05-scroll-down--1",
    "cmd": "scroll",
    "args": {
      "direction": "down",
      "pages": -1,
      "settle_ms": 0,
      "ref": "e1084"
    }
  },
  "response": {
    "ok": false,
    "id": "P05-scroll-down--1",
    "error": {
      "message": "Element does not support action performing AXScrollDownByPage.",
      "code": "action_unsupported"
    }
  }
}
```
```json
{
  "ours": {
    "data": {
      "pages": 0,
      "scrolled": "e2"
    },
    "id": "C-scroll-0",
    "ok": true
  },
  "alma": {
    "error": {
      "code": "action_unsupported",
      "message": "Element does not support action performing AXScrollDownByPage."
    },
    "ok": false,
    "id": "C-scroll-0"
  }
}
```

### BUG-R3-03 — snapshot 保留 Alma 省略的空字符串字段

- 严重度：minor（wire字段存在性不同）。
- 现象：同一测试窗、空TextArea及“字体大小”AXButton，重复两轮原生snap。
- 我们：TextArea含 `value:""`，Button含 `title:""`。
- 真机：相应value/title键省略，其余对应属性一致。
- 证据命令：先set_value清空测试TextArea，然后 `snap({bundle:"com.apple.TextEdit",pid:64284,window_id:234393,depth:5,interactive_only:false})`；`C-empty-snap-0/1` 原始记录包含完整树，`C-empty-fields-0/1` 抽取对应元素。
- 裁决建议：接受；仅对实测空字符串字段省略行为对齐，不将空、null、缺省擅自整体合并。

```json
{
  "ours": {
    "elements": [
      {
        "role": "AXTextArea",
        "value": ""
      },
      {
        "description": "字体大小",
        "role": "AXButton",
        "title": ""
      }
    ]
  },
  "alma": {
    "elements": [
      {
        "role": "AXTextArea"
      },
      {
        "description": "字体大小",
        "role": "AXButton"
      }
    ]
  }
}
```

### BUG-R3-04 — AX 写失败 message 缺少固定前后缀

- 严重度：minor。
- 现象：向TextArea的AXValue写入JSON数字1或true；也由disabled AXScrollBar写字符串/数组/对象复现。
- 我们：`ax_failure / illegalArgument while setting AXValue`。
- 真机：`ax_failure / AX error illegalArgument while setting AXValue.`。
- 证据命令：`set_value({ref:<本端TextArea>,value:1,settle_ms:0})`，`P04-text-integer/boolean`、`C-ax-error-1/True`；code和接受/拒绝类型一致，message逐字不同。
- 裁决建议：接受；按真实AX错误字符串形状补齐，不新增retryable/details等字段。

```json
{
  "time": "2026-10-09T13:54:56.095562+08:00",
  "side": "ours",
  "request": {
    "id": "C-ax-error-1",
    "cmd": "set_value",
    "args": {
      "ref": "e3",
      "value": 1,
      "settle_ms": 0
    }
  },
  "response": {
    "error": {
      "code": "ax_failure",
      "message": "illegalArgument while setting AXValue"
    },
    "id": "C-ax-error-1",
    "ok": false
  }
}
```
```json
{
  "time": "2026-10-09T13:54:56.121638+08:00",
  "side": "alma",
  "request": {
    "id": "C-ax-error-1",
    "cmd": "set_value",
    "args": {
      "ref": "e1085",
      "value": 1,
      "settle_ms": 0
    }
  },
  "response": {
    "error": {
      "code": "ax_failure",
      "message": "AX error illegalArgument while setting AXValue."
    },
    "ok": false,
    "id": "C-ax-error-1"
  }
}
```

### BUG-R3-05 — armed 源窗销毁后清理得比 Alma 更多

- 严重度：minor（状态机与后续disarm回声不同）。
- 现象：两端pip_arm同一新建空白TextEdit窗，不最小化，直接AXPress关闭源窗。
- 我们：0.3秒及2秒均 `armed:[]`；随后pip_disarm为false。
- 真机：窗口已销毁仍保留armed条目；随后pip_disarm为true。sessions始终空。
- 证据命令：W234560由Alma执行关闭、W234656由ours执行关闭，两轮均同结果；`P09-arm-status-*`、`C-arm-status-*`、`C-arm-windows`、`C-arm-disarm`。这与R4的**活动PiP session**销毁回收是不同路径，不能用R4通过替代。
- 裁决建议：接受为过度清理的parity差异；应按Alma实测状态保留/消费armed。不能把“清得更干净”作为实现正确的理由；本次不提交修复。

```json
{
  "time": "2026-10-09T13:55:48.298962+08:00",
  "side": "ours",
  "request": {
    "id": "C-arm-arm",
    "cmd": "pip_arm",
    "args": {
      "bundle": "com.apple.TextEdit",
      "pid": 64284,
      "window_id": 234656,
      "title": "R3-Armed-Repeat"
    }
  },
  "response": {
    "data": {
      "armed": {
        "pid": 64284,
        "title": "R3-Armed-Repeat",
        "window_id": 234656
      }
    },
    "id": "C-arm-arm",
    "ok": true
  }
}
```
```json
{
  "time": "2026-10-09T13:55:48.299882+08:00",
  "side": "alma",
  "request": {
    "id": "C-arm-arm",
    "cmd": "pip_arm",
    "args": {
      "bundle": "com.apple.TextEdit",
      "pid": 64284,
      "window_id": 234656,
      "title": "R3-Armed-Repeat"
    }
  },
  "response": {
    "data": {
      "armed": {
        "title": "R3-Armed-Repeat",
        "pid": 64284,
        "window_id": 234656
      }
    },
    "ok": true,
    "id": "C-arm-arm"
  }
}
```
```json
{
  "time": "2026-10-09T13:55:51.617026+08:00",
  "side": "ours",
  "request": {
    "id": "C-arm-status-2",
    "cmd": "pip_status",
    "args": {}
  },
  "response": {
    "data": {
      "armed": [],
      "sessions": []
    },
    "id": "C-arm-status-2",
    "ok": true
  }
}
```
```json
{
  "time": "2026-10-09T13:55:51.617568+08:00",
  "side": "alma",
  "request": {
    "id": "C-arm-status-2",
    "cmd": "pip_status",
    "args": {}
  },
  "response": {
    "data": {
      "armed": [
        {
          "title": "R3-Armed-Repeat",
          "pid": 64284,
          "window_id": 234656
        }
      ],
      "sessions": []
    },
    "ok": true,
    "id": "C-arm-status-2"
  }
}
```
```json
{
  "time": "2026-10-09T13:55:51.625438+08:00",
  "side": "ours",
  "request": {
    "id": "C-arm-disarm",
    "cmd": "pip_disarm",
    "args": {
      "window_id": 234656
    }
  },
  "response": {
    "data": {
      "disarmed": false,
      "window_id": 234656
    },
    "id": "C-arm-disarm",
    "ok": true
  }
}
```
```json
{
  "time": "2026-10-09T13:55:51.625744+08:00",
  "side": "alma",
  "request": {
    "id": "C-arm-disarm",
    "cmd": "pip_disarm",
    "args": {
      "window_id": 234656
    }
  },
  "response": {
    "data": {
      "disarmed": true,
      "window_id": 234656
    },
    "ok": true,
    "id": "C-arm-disarm"
  }
}
```

### BUG-R3-06 — type_text 的目标缺失与 ax ref 缺失校验顺序不同

- 严重度：minor。
- 现象：只传 `text:"X",input_method:"ax"`，同时不带pid/bundle/ref。
- 我们：``invalid_arg / input_method=ax requires `ref`.``。
- 真机：``invalid_arg / type_text requires `pid`, `bundle`, or `ref`.``。
- 证据命令：`P10-13-type_text`与`C-order-0`两次同请求复现。有pid无ref时两端都报ax requires ref；非法method与缺/空text也逐字一致（C-order-1…5）。
- 裁决建议：接受；按Alma实际先后顺序恢复该组合的首个错误，保留所有原错误文字与键集。

```json
{
  "time": "2026-10-09T13:55:11.170160+08:00",
  "side": "ours",
  "request": {
    "id": "C-order-0",
    "cmd": "type_text",
    "args": {
      "text": "X",
      "input_method": "ax"
    }
  },
  "response": {
    "error": {
      "code": "invalid_arg",
      "message": "input_method=ax requires `ref`."
    },
    "id": "C-order-0",
    "ok": false
  }
}
```
```json
{
  "time": "2026-10-09T13:55:11.171034+08:00",
  "side": "alma",
  "request": {
    "id": "C-order-0",
    "cmd": "type_text",
    "args": {
      "text": "X",
      "input_method": "ax"
    }
  },
  "response": {
    "error": {
      "code": "invalid_arg",
      "message": "type_text requires `pid`, `bundle`, or `ref`."
    },
    "ok": false,
    "id": "C-order-0"
  }
}
```

### OBS-R3 — 应用解析、事件时序与哨兵（待归因，不计确认实现缺陷）

- **偶发app_not_found**：`C-maps-windows` 同请求 ours称Maps不存在，Alma立即返回pid56340及空windows；随后同pid的snap双端成功，之后Maps/TextEdit交替8对windows均相同。另有ours对TextEdit的单端瞬时失败。已有真实同请求差异，但尚未稳定复现并隔离NSRunningApplication/共享桌面并发条件；建议保留原始记录调查，不据此加自动launch或自创重试墙。
- **事件验证**：Unicode `settle_ms:0` 的“已落字仍返回no text”两端均能出现，反序测试方向翻转；auto无ref也记录到不同落字结果。不能仅凭一次成功/失败将后台key-window、双daemon焦点保护、事件队列时序合成确定根因。报告保留为观察。
- **哨兵**：`1015`点、`42`组前后配对，其中`19`组前台或光标变化。最初4点cliclick不可用，后续CoreGraphics补位。变化目标、时间、坐标详见R3-VERIFY全表与 `/tmp/cu-field-r3-20261009-134241/sentinel.jsonl`；未收到用户归因，均待归因，未擅自恢复焦点/光标。

```json
{
  "time": "2026-10-09T13:55:51.945176+08:00",
  "side": "ours",
  "request": {
    "id": "C-maps-windows",
    "cmd": "windows",
    "args": {
      "bundle": "com.apple.Maps",
      "pid": 56340
    }
  },
  "response": {
    "error": {
      "code": "app_not_found",
      "message": "No running app matched com.apple.Maps."
    },
    "id": "C-maps-windows",
    "ok": false
  }
}
```
```json
{
  "time": "2026-10-09T13:55:51.959907+08:00",
  "side": "alma",
  "request": {
    "id": "C-maps-windows",
    "cmd": "windows",
    "args": {
      "bundle": "com.apple.Maps",
      "pid": 56340
    }
  },
  "response": {
    "data": {
      "windows": [],
      "app": {
        "bundle": "com.apple.Maps",
        "pid": 56340
      }
    },
    "ok": true,
    "id": "C-maps-windows"
  }
}
```

### Round-3 证据读取/复放

原始请求、raw响应、差异、两份ips和临时探针均位于 `/tmp/cu-field-r3-20261009-134241`；关键差异已内嵌上文。以下客户端仅示范单条调用；涉及ref/窗口的例子必须在新建测试文稿上重新取本端ref/window_id，不直接重放已关闭窗。不得向原有用户文稿注入测试内容。

```python
import json, socket
paths = {
    "ours": "/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock",
    "alma": "/Users/lu/Library/Application Support/Alma/computer-use-9bd08bc1.sock",
}
request = {"id": "r3-replay", "cmd": "type_text",
           "args": {"text": "X", "input_method": "ax"}}
for side, path in paths.items():
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(15)
        sock.connect(path)
        sock.sendall((json.dumps(request) + "\n").encode())
        raw = b""
        while b"\n" not in raw:
            chunk = sock.recv(65536)
            if not chunk:
                break
            raw += chunk
        print(side, raw.decode())
```


## Round-5 收口新发现

> **Round-5 修复(同日,已验证)**：R5-01 `snapshot` 对 per-app `AXWindows` 失败 `try?` 吞成空列表(Chrome 等拒 AX 的 app 不再整体报 ax_not_granted,CG 元数据照样填 window);R5-02 `snapToDict` 无窗也发 `window:{id,title,bounds}` 三 null;R5-03 `typeTextViaFocusedAXElement` 按 0x10002102c 还原——auto 无 ref 的 deliver 内先试 `AXFocusedUIElement` 插入(AXSelectedText→AXValue append),label 恒 `auto_key_events`,且**必须在 TypeVerification baseline 之后**执行(否则 verifier 读到已写入态误判 unchanged)。三项均双 socket 逐字节复验。


run_id=`r5`，2026-10-09；按[R5-TASK.md](R5-TASK.md)完成A→G，完整覆盖与哨兵见[R5-VERIFY.md](R5-VERIFY.md)。确认 **3类差异（1 major、2 minor）**；均已双socket同请求对照，ref仅在前置AX操作按本端重绑。无产品代码修改、无daemon重启。原始证据 `/tmp/cu-r5`，859条请求记录（主序列817、补充42）另加2条初始ping。

> 归属说明：顶部“Round-5修复、已验证”段由15:50:22的并发提交`9d5e745`加入，予以保留。本节r5证据采集止于15:48:17，三条是c5ccba7旧二进制上的测试发现；此测试会话未修改产品代码或执行新提交的修复复验。环境分界详见R5-VERIFY末节。

### BUG-R5-01 — Chrome AX不可读时，get_app_state 的成功/错误分支不同

- 严重度：minor（wire成功/错误形状不同）。
- 现象：R5-B扫描运行中的Chrome菜单，两个独立同请求对照均复现。
- 我们：`ok:false,error.code:ax_not_granted`，附Alma Computer Use授权hint。
- 真机：`ok:true`，`ax_status:no_wakeup_budget`、空elements、window50968，不含menu_shortcuts。
- 环境限定：双方permissions仍accessibility/screen_recording=true；随后相同Chrome windows请求两端都报ax_not_granted，说明本条并非简单宣称全局权限不同。未查明Chrome AX不可读的根因，也未推断所有AX失败都应被吞掉。
- 证据：`B-menu-com.google.Chrome`与`B-menu-com.google.Chrome-retry`；`B-chrome-permissions/B-chrome-windows`提供上下文。不能将空combo计数0=0报告为PASS。
- 裁决建议：接受为该现场get_app_state异常路径的parity差异；按Alma本条响应调查分支，不新增授权流程或重试墙。

```json
{"id":"B-menu-com.google.Chrome-retry","cmd":"get_app_state","args":{"bundle":"com.google.Chrome","depth":0,"include_screenshot":false,"disable_diff":true,"wakeup_seconds":0}}
```

我们（2026-10-09T15:27:29.313485+08:00）：

```json
{"error":{"code":"ax_not_granted","hint":"Open System Settings → Privacy & Security → Accessibility and enable \"Alma Computer Use\".","message":"Accessibility permission not granted to Alma Computer Use."},"id":"B-menu-com.google.Chrome-retry","ok":false}
```

Alma（2026-10-09T15:27:29.658499+08:00）：

```json
{"data":{"wakeup_attempts":1,"snapshot_id":"s_2026-10-09T072731Z","ax_status":"no_wakeup_budget","wakeup_duration_ms":0,"app":{"name":"Google Chrome","bundle":"com.google.Chrome","pid":52445},"elements":[],"window":{"title":"WiseStudio Admin","id":50968,"bounds":{"w":1512,"h":888,"x":0,"y":33}}},"ok":true,"id":"B-menu-com.google.Chrome-retry"}
```

### BUG-R5-02 — 无窗快照省略了Alma保留的null window封套

- 严重度：minor（键存在性不同）。
- 现象：正在运行且无窗的Preview PID96946；windows双端确认空后，同请求snap与get_app_state各重复两次。
- 我们：成功响应不含window。
- 真机：成功响应始终含 `window:{id:null,title:null,bounds:null}`。
- 证据：`C-window-shape-snap-0/1`及`C-window-shape-get_app_state-0/1`。去snapshot_id后，其余响应逐字相同。A的Calendar无窗样本提供旁证；正式裁决仅依赖重复Preview实验。
- 裁决建议：接受；复刻无窗window三字段null形状，不擅自改变其它空值/缺省规则。这不是R3-03的元素空字符串问题。

```json
{"id":"C-window-shape-snap-0","cmd":"snap","args":{"bundle":"com.apple.Preview","pid":96946,"depth":0,"interactive_only":false,"wakeup_seconds":0,"include_screenshot":false,"disable_diff":true,"auto_launch":false}}
```

我们（2026-10-09T15:28:04.676471+08:00）：

```json
{"data":{"app":{"bundle":"com.apple.Preview","name":"预览","pid":96946},"ax_status":"no_wakeup_budget","elements":[],"snapshot_id":"s_2026-10-09T072804Z","wakeup_attempts":1,"wakeup_duration_ms":0},"id":"C-window-shape-snap-0","ok":true}
```

Alma（2026-10-09T15:28:04.891894+08:00）：

```json
{"data":{"wakeup_attempts":1,"snapshot_id":"s_2026-10-09T072806Z","ax_status":"no_wakeup_budget","wakeup_duration_ms":0,"app":{"name":"预览","bundle":"com.apple.Preview","pid":96946},"elements":[],"window":{"title":null,"id":null,"bounds":null}},"ok":true,"id":"C-window-shape-snap-0"}
```

### BUG-R5-03 — 后台TextEdit auto无ref输入稳定不落字，Alma成功

- 严重度：major（核心输入功能在对照现场失败，未崩溃）。
- 现象：同一个自有后台TextEdit测试窗W235981，settle_ms=0与省略两组，每组双端各5次。每端调用前本端AX ref恢复ANCHOR、选中全文、snap确认ANCHOR/focused=true；动作后0.5秒再snap读回。奇数轮交换Alma→ours顺序。
- 我们：**10/10**返回`internal/type_text delivered no text...`，不含typed/verified；后置文本全部仍为ANCHOR。
- 真机：**10/10** `typed:true,verified:true,method:auto_key_events,length:7`，实际文本全部为请求的r5textN。
- 证据：`E-auto-zero-0…4`、`E-auto-default-0…4`；`E-typing.jsonl/.json`包含每次完整前置/后置读回；正式type_text请求完全不含ref，目标bundle/pid/window_id/text相同。
- 前台：该测试阶段有效0.5秒哨兵全为Paseo，未采到TextEdit前台；未通过activate/raise来让真机落字。前置/后置均为两套原daemon并存的同一现场，ours focus_guard.armed=false、Alma=true。
- 裁决建议：将R3单次auto无ref观察提升为本轮**可重复的行为差异**。根因仍未定，不声称已排除双daemon事件保护交互；不把恢复前台或增加用户重试作为对齐。与R3中“Unicode已落字但零等待误报”不同，本轮ours实际也未落字。

```json
{"id":"E-auto-default-0","cmd":"type_text","args":{"bundle":"com.apple.TextEdit","pid":64284,"window_id":235981,"input_method":"auto","text":"r5text0"}}
```

我们（2026-10-09T15:30:48.592486+08:00）：

```json
{"error":{"code":"internal","message":"type_text delivered no text: the target app has no key window, so the keystrokes were discarded (its AX element still reports focused=true — that only means it is the app's first responder). Use set_value with the element's ref to write the field directly. Do NOT bring the app forward to make typing land — Alma never takes the user's foreground."},"id":"E-auto-default-0","ok":false}
```

Alma（2026-10-09T15:30:52.715963+08:00）：

```json
{"data":{"method":"auto_key_events","verified":true,"typed":true,"length":7},"ok":true,"id":"E-auto-default-0"}
```

同case后置读回（两端均focused=true，snap成功）：

```json
{"ours":{"value":"ANCHOR","focused":true,"response_ok":true,"error":null},"alma":{"value":"r5text0","focused":true,"response_ok":true,"error":null}}
```

### OBS-R5 — 保留观察，不计确认实现bug

- **枚举偶发项**：Maps/TextEdit bundle+实时pid各20对windows，四组均0/20 app_not_found。本轮另有A-color-scan（TextEdit snap无pid）ours app_not_found/Alma成功；不能用不同请求参数的连发结果宣布旧OBS已消失。
- **焦点候选**：有效连续哨兵1851点，28次前台转换、495次光标变化；初始49条查询错误与7条混合身份monitor样本不计有效前台证据。15:29:12.815和15:34:57.816两个转换落在请求完成后1s内：前者双方Finder gas均有候选，后者27条PiP调用覆盖两端。出稿补测另210条原子哨兵、5次转换；15:47:24.704 Chrome→Electron/44599为第三组候选：Alma D2 snap后677ms、ours D2 gas后385ms，两端均在候选窗口内。完整具体case/时间/光标见R5-VERIFY、`sentinel-transitions.json`及`sentinel-native-summary.json`。没有已证实的单端focus steal。
- **中树ref顺序**：D的removed_refs两端各自排序、成员一致，跨端ref分配历史不同使重绑后的数组顺序不同；不当作算法差异。原始数组未删除。
- **PiP瞬态/顺序**：两个arm的数组顺序相反；最小化0.4s时ours短暂session/armed重叠，1s后双端同状态；无稳定错误结论。历史cascade差15次，经校准后0/负/4000尺寸完整frame一致，不误报位置。
- **事件窗口标记**：F移动后两个相同click的实际坐标及响应均431,352，但event tap窗口字段ours235981/Alma230637；关闭后均230637。保存为内部事件差异，未仅凭这些字段确认协议缺陷。

以上观察各自有双端记录或完整哨兵，不提出无Alma依据的工程改造。复放只能用新建测试对象，原R5文稿/窗口已清理。
