# Round-5 收口验证

run_id=`r5`；2026-10-09 **15:21:13–15:36:51 +08:00**（主序列socket/GUI测试与清理）；出稿补充D后置检查15:47:15–15:48:17，再次清理；最终原子哨兵15:48:56。按 [R5-TASK.md](R5-TASK.md) 先 ping，再 **R5-A→B→C→D→E→F→G**，最后清理。已先读 [R3-VERIFY.md](R3-VERIFY.md) 与 [BUGS.md](BUGS.md)，未重复报告已修复的六项。

**确认3类新差异：1 major、2 minor**，见 [BUGS.md Round-5 收口新发现](BUGS.md#round-5-收口新发现)。全部来自相同请求的双 socket 响应及逐字 diff；本测试没有改产品源码、wrapper、脚本或配置，也没有构建/重启被测daemon；测试结束后的并发更新见文末。临时测试客户端和只读监视器在 `/tmp/cu-r5`，仓库只新增/追加本轮三份文档。

## 环境与对照规则

- 我们：`/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock`，PID31242；Alma：`/Users/lu/Library/Application Support/Alma/computer-use-9bd08bc1.sock`，PID37196。正式测试请求阶段使用这两个进程，无被测崩溃/本测试恢复；结束后外部更新了ours，见文末。
- macOS **26.6.2 (25G83)**；HEAD `c5ccba7110f9867a478717aabffbec3124699e07`。
- ours SHA256：`16a7b03b962de99d50907a7f7a9b203aacbec7c59c805d07f9325e43aadad0ac`；Alma SHA256：`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`。
- 15:21:13 两端相同字符串 id `r5-preflight-ping` 均 `ok:true,pong:true,version:"0.1.0",uptime_s:2104677`。最初ping之前没有哨兵点；预检仅发只读请求，首个GUI行为测试在有效哨兵启动之后。
- 基线两端 accessibility/screen_recording=true、sessions/armed为空。focus_guard 基线及E后 ours `armed:false`、Alma `armed:true`，arm_failures均0；保留此现场条件，不擅自把它当作输入差异的已证实根因。
- **859条**正式请求记录（ours454、Alma405；主序列817条、出稿补充42条；其中2条为主动断连，只保存已发送请求），另2条最初ping。没有非预期 transport_error。`requests.jsonl` 保存请求、原始响应 `raw`、起止时间和耗时；`comparisons.jsonl` 保存 JSON 对象键排序后的逐字 diff。
- 同一 case 使用相同 id/cmd/args；ref仅由本端快照重绑。每次有状态写入前恢复相同前置值。GUI建窗、共用源窗最小化/关闭属于共享现场准备，一次事件同时供两端观察；没有在源窗已被关闭后重复“关闭”作为不等价对照。
- `snapshot_id`、帧龄、历史PiP计数等差异均原样保留，只有在明确标注的派生比较中归一化。没有把对象键序不同算缺陷；没有把所有数组任意排序后宣称原始wire一致。

## 结果总表

|项|结论|覆盖与证据|
|---|---|---|
|R5-A|PASS（有样本的3类）；其余5类无样本|6个真实控件，42对有效动作。`A-results.jsonl`（另1条错拼命令不计覆盖）。|
|R5-B|菜单集合PASS；附带异常路径FAIL；扩展vk样本无样本|11个可读app集合一致；Chrome连续两次 ours错误/Alma空树成功，BUG-R5-01。|
|R5-C|并发/断连PASS；无窗封套FAIL；微预算次数OBS|第二连接在wakeup未结束时完成；无窗window缺失，BUG-R5-02。|
|R5-D|PASS|Finder中树；snap/gas各8对，另补空diff后原生snap的明确后置检查。|
|R5-E|FAIL（输入）；枚举样本PASS；焦点候选OBS|Maps/TextEdit各20对全成功；auto无ref两种settle各5对，ours0/10落字、Alma10/10，BUG-R5-03。|
|R5-F|回声/实际点PASS；事件窗口标记OBS|移动、关闭后均沿用旧点；5种shot_display参数对照。|
|R5-G|状态/尺寸/首帧PASS；armed顺序与过渡时点OBS|同app双arm、消费后再最小化、三种尺寸；计数校准后frame完全相同。|

## R5-A — 控件族接受集

主动双端扫描系统设置（179/180节点）、原TextEdit标尺（52/52）、Preview/日历（当前无窗）、Calculator（35/35）、Finder桌面及新建Finder窗（初次175/180）。Font/Color面板已通过菜单/颜色池尝试打开；后台完整面板没有可定位AX窗口，Color弹层只提供按钮/网格。打印面板入口被后台菜单路由suppressed，未打印。VoiceOver Utility、字体册不在运行应用清单，未启动它们。

测试全部在新TextEdit W235981和新Finder W236036。原TextEdit上发现的组合框只用于定位同类样本，没有向原文稿做set_value。

|真实role/控件|样本|set_value string / int / float / bool / null|press(Space)|perform_secondary_action|
|---|---|---|---|---|
|AXComboBox|TextEdit字体大小；e329/e1572|成功 / ax_failure / ax_failure / ax_failure / missing value|AXPress not on element|成功，opened_menu回本端ref|
|AXSlider|Finder调整大小图标；e495/e1878|ax_failure / 成功 / 成功 / 成功 / missing value|AXPress not on element|成功，opened_menu回本端ref|
|AXRadioButton，subrole=AXSegment|Finder图标/列表/分栏/画廊，**4个逐个测试**|前四型均action_unsupported；null为missing value|图标视图成功；另外3个performing AXPress不支持|4个均成功回opened_menu|
|AXStepper / AXDateField / AXIncrementor / AXDisclosureTriangle / AXTab|无样本|未执行，不能算PASS|未执行|未执行|

组合框值使用 `"12"/12/12.5/true/null`；滑块 `"24"/24/24.5/true/null`；radio `"1"/1/1.5/true/null`。写入前复原，最终滑块24、图标视图1、其余radio0，双端读回一致。segmented实际role是AXRadioButton，**不冒充AXTab**。

逐字错误包括 `AX error illegalArgument while setting AXValue.`、`missing "value"`、`Element does not support action set_value (AXValue not settable on this element).`；成功响应仅把本端ref替换为同一逻辑标签后比较，42/42相等。

第一次secondary误写成`secondary_action`，两端同报unknown cmd；随后以正确的`perform_secondary_action`重跑，前一条不计入42对。Font/Color菜单已恢复到“显示字体/显示颜色”，弹层已消失。证据：`A-*json`、`a-*.py/out`、`A-results.jsonl`。

## R5-B — menu_shortcuts 的真实vk样本

用同请求 `get_app_state({bundle,depth:0,include_screenshot:false,disable_diff:true,wakeup_seconds:0})`，逐app提取去重combo，再保存集合diff。

|app|ours / Alma去重combo|差集|非字符键名|
|---|---:|---|---|
|com.apple.TextEdit|84 / 84|空|Down, Left, Right, Up|
|com.apple.Notes|103 / 103|空|Down, Left, Right, Up|
|com.apple.calculator|41 / 41|空|Down, Left, Right, Up|
|com.apple.finder|118 / 118|空|Down, Left, Right, Up|
|com.apple.Preview|106 / 106|空|Down, Left, Right, Up|
|com.apple.Maps|64 / 64|空|Down, Left, Right, Up|
|com.apple.iCal|68 / 68|空|Down, Left, Right, Up|
|com.apple.Music|71 / 71|空|Down, Left, Right, Up|
|com.apple.systempreferences|41 / 41|空|Down, Left, Right, Up|
|com.apple.mail|125 / 125|空|Down, Left, Right, Up|
|com.mitchellh.ghostty|61 / 61|空|Down, Left, Right, Up|

本轮命中的命名集合只有 **Down/Left/Right/Up**（如 `ctrl+Left`）。Return/Tab/Space/Backspace/Escape/F1–F12/Home/End/PageUp/PageDown/Delete/`vk%02X` **无真实命名样本**；原样Tab、退格、ESC及私用区glyph不是大写fallback，未混入统计。未发现可读菜单的键名parity bug。

附带发现：Chrome两次同请求 ours `ax_not_granted`，Alma `ok:true` + 空elements、`no_wakeup_budget`，且不含menu_shortcuts。故Chrome **不能以“0=0”算集合PASS**。其后的permissions两端仍true，windows(Chrome)两端同报ax_not_granted，差异定位为该现场的get_app_state异常响应路径；根因未下结论。见BUG-R5-01。证据：`B-summary.json`、`B-chrome-retry.json`、case `B-chrome-permissions/B-chrome-windows`。

## R5-C — wakeup中断与并发

无窗宿主选**正在运行的Preview PID96946**，先双端windows确认空；Maps本轮有原窗口，不人为关闭用户窗口造无窗条件。挂起请求：`snap({bundle:"com.apple.Preview",pid:96946,depth:0,interactive_only:false,wakeup_seconds:3})`。

|场景|我们|Alma|结论|
|---|---|---|---|
|第二连接ping|0.165ms，wakeup仍pending|0.356ms，仍pending|PASS|
|同一第二连接随后windows(TextEdit)|2.880ms，仍pending|4.460ms，仍pending|PASS|
|原wakeup完成|4次，sleep802ms，总1088.943ms|4次，sleep806ms，总2949.536ms|并发成立；时长如实保留|
|发wakeup，100ms后断开|即时ping/windows及1s后ping正常|同|PASS；未声称断开取消了服务端执行|
|budget0 / -1，无窗|1次、0ms、no_wakeup_budget|同|状态边界PASS|
|budget0.001，无窗|2次、累计sleep0ms|1次、累计sleep0ms|均empty_after_wakeup；初次遍历耗时不同，OBS|
|budget1000000，无窗|4次、sleep811ms，总967.021ms|4次、sleep812ms，总2982.951ms|未按巨大预算持续阻塞|
|dead pid777777 ×上述4预算|app_not_found，`No running app matched pid=777777.`|逐字相同|PASS|

**新FAIL：无窗快照封套。** 我们省略window，Alma发 `window:{id:null,title:null,bounds:null}`。独立`C-window-shape-snap-0/1`与`get_app_state-0/1`各重跑两对，去掉snapshot_id后唯一结构差即window；BUG-R5-02。A中无窗Calendar同样出现，Finder桌面wid0也观察到我们不发window/Alma发id0，但本条裁决以更干净的Preview重复实验为准。

证据：`C-concurrent.json`、`C-drop.json`、`C-boundary-*.json`、`C-window-shape-*.json`。微预算次数/墙钟差不重复升级R3已记录的调度OBS。

## R5-D — 中树diff

Finder测试窗W236036，depth5有98节点、depth3有27节点。顺序 `5(true)→3(false)→5(false)→5(false)→3(true)→5(false)→5(false)→5(false)`，括号为disable_diff。

- **原生snap**：8对都输出全量；不出现elements_are_diff、removed_refs、unchanged_element_count或名为diff的键，disable_diff不改变这个事实。
- **get_app_state(include_screenshot:false)**：补测真正diff入口，8对结果如下。

|次序|depth / disable_diff|elements数|removed_refs|elements_are_diff|unchanged_element_count|
|---|---|---:|---|---|---:|
|0|5 / true|98|省略|省略|省略|
|1|3 / false|0|71个|true|27|
|2|5 / false|71|省略|true|27|
|3|5 / false|0|省略|true|98|
|4|3 / true|27|省略|省略|省略|
|5|5 / false|71|省略|true|27|
|6|5 / false|0|省略|true|98|
|7，空diff后再取|5 / false|0|省略|true|98|

表内双端相同，所有响应都没有独立`diff`键。唯一派生逐字diff来自第1次removed_refs：两端都按各自ref递增，早先遍历历史不同导致逻辑元素的顺序不同；**71个逻辑成员完全相同**。报告保留原始数组，并分别验证本端排序；只在`D-semantic-results.jsonl`的成员对照中按描述符排序。其余15对只去snapshot_id、重绑ref即相等。证据：`D-responses.json/D-summary.json/D-refmaps.json/D-results.jsonl/D-semantic-results.jsonl`。

### 出稿补充：空diff之后的原生命令snap

主A→G序列完成后，另建Finder W236285/W236294，只补这一条字面命令检查（15:47:15–15:48:17）。首次D2准备时ours还有2个AXGroup更新，Alma已空diff，前置条件没有同时成立；保存全部响应，未用它宣称“双方空diff后snap”。D3改为每次检查双端均`elements:[]、elements_are_diff:true、unchanged_element_count:98`才继续；断言通过后，**literal snap双端均98个全量节点，所有diff相关键省略**，再gas双端仍空diff。稳定snap逐元素重绑ref并去snapshot_id后逐字一致。

初始D3全量有97/98节点瞬态（窗口按钮区域的AXGroup），循环等待后的正式检查已稳定；此瞬态保留，不新增确定bug。两个补测窗都即时关闭，最后Finder仅桌面wid0、PiP空、双端ping正常。证据：`D2-responses.json`、`D3-responses.json`、`D3-results.jsonl`（以末条stable-literal-snap为该断言证据）、`D2/D3-final-windows.json`。补测全程采用每0.5秒的单NSRunningApplication实例读取，见哨兵补充节。

## R5-E — OBS归因复现

### 枚举连发

从`E-live-apps`取实时PID：Maps56340、TextEdit64284；各20轮双端发 `windows({bundle,pid})`。**两app、两端均20/20成功，app_not_found=0/20**，逐对响应一致。Maps原窗W235174始终存在。不得据此宣称偶发问题已消失：A的`A-color-scan`无pid的TextEdit snap曾出现ours app_not_found/Alma成功，与这80条指定bundle+实时pid的windows请求不是同一参数场景。

### auto无ref重复试验

独立TextEdit测试文稿W235981；每次用本端AX ref写ANCHOR、select_text选中、snap确认`value:"ANCHOR",focused:true`，然后发**不含ref**的 `type_text({bundle:"com.apple.TextEdit",pid:64284,window_id:235981,input_method:"auto",text:"r5textN",settle_ms:0})`。默认组省略settle_ms。每组5次，i=1/3反转Alma→ours顺序；每端动作后0.5秒再snap读回。

|组|次数/端|ours返回与落字|Alma返回与落字|
|---|---:|---|---|
|settle_ms=0|5|5次internal/no text；全仍ANCHOR；无typed/verified键|5次typed:true、verified:true、method:auto_key_events、length:7；全r5textN|
|settle_ms省略|5|同上|同上|

**BUG-R5-03：稳定双端行为差异**，已从R3单次观察补成10对重复证据。不能据此断言是某一函数或FocusGuard导致；原两daemon并存、ours guard未armed是实测环境条件。此次区别不是“已落字但零等待误报”：ours后置读回也完全没落字。证据：`E-typing.jsonl/.json`、`E-results.jsonl`、全部前置与后置快照。

E阶段15:30:04–15:31:27的有效连续哨兵均为Paseo；没有采到前台切换，也没有TextEdit成为前台。全轮的1秒候选及所有转换见下方哨兵节，不把“时间相邻”写成确定因果。

## R5-F — 坐标映射边界

TextEdit W235981初始bounds `(181,102,586,488)`，稳定等待2.6秒后双端gas各注册586×488图映射。用System Events只移动该测试窗至 `(241,142)`；没有重新gas注册。

|场景|相同请求关键参数|两端响应/只读监听|
|---|---|---|
|移动后旧image点|x250,y250,coord_space:screenshot|clicked_at均`{x:431,y:352}`，不是新位置点491,392|
|shot_display|coord_space分别screen/window/screenshot/空串/缺省；max_width756|5对均`{path:<指定文件>,width:756,height:491}`；不回coord_space|
|关闭后stale映射|同window_id235981、同250,250点|窗口已双端确认消失，仍ok:true、clicked_at431,352|

为验证实际派发，临时安装**仅PID64284、listenOnly、tailAppend**的鼠标event tap，不修改/拦截事件。4次click各捕获down/up，位置都为431,352、target_pid64284，与wire回声吻合。`mouse-events.jsonl`保存原始事件。关闭后点落到原文稿的事件窗口标记230637，原文稿文本前后双端相同。

**OBS：** 移动后那对click的事件`window_under/window_handle`标记 ours235981、Alma230637；位置和wire一致。未把该内部事件字段差异直接当成已确认协议bug，保留后续调查。没有强行恢复前台或移动用户光标。

途中临时Python脚本的Path拼接抛TypeError，发生在首个shot_display发送之前；续跑`f-resume.py`从该步骤开始，没有重做/改变已注册映射。证据：`F-register-map/F-moved-windows/F-stale-click/F-source-gone/F-stale-closed*.json`、`F-original-before/after.json`、`mouse-events.jsonl`。

## R5-G — PiP组合压力

新建同app两个空文稿W236168/W236170，两端分别arm两窗。由ours AXPress最小化第一窗，**共享一次真实AX事件**供两个daemon观察。

- 1秒延迟采样时，两端均只有W236168 session、仅W236170仍armed；`pip_close(W236168)`均true，随后`pip_disarm(W236168)`均false，证实已消费。
- 双端gas恢复W236168后，由Alma AXPress再次最小化；0.7秒采样两端sessions均空，W236170仍armed。随后仅对W236170 disarm，双方true。
- **原始OBS**：双arm时ours数组为[W236168,W236170]，Alma为反序；成员/字段一致，未证明Alma承诺顺序。首次最小化0.4秒采样ours短暂同时有W236168的session和armed，Alma只剩另一个arm；1秒后相同。采样非原子、打开为异步，不据单时点差异声称消费失败。

尺寸测试用未最小化的W236170，逐项open→status→close。初始两端历史cascade计数相差15，普通frame的x/y因此差420。先保留原始差异，再在ours单独完成15次open/close以补齐，之后重跑相同请求：

|width×height输入|两端校准后floater_frame|返回|
|---|---|---|
|0×0|`{x:688,y:165,w:240,h:200}`|opened:true|
|-10×-10|`{x:660,y:137,w:240,h:200}`|opened:true|
|4000×4000|`{x:0,y:56,w:1072,h:893}`|opened:true|

以上完整响应除JSON对象键序外逐字相同，三种输入都没有invalid_arg。超屏frame为本机真实AppKit结果，不能拿4000当返回宽高。计数校准为前置现场处理，未重启Alma或改全局计数源码。

首帧试验在第二连接以约10–13ms轮询pip_status；显式open指定334×220，两端open都先返回`has_first_frame:false,last_frame_age_ms:null`：

|端|首次观测到session且false|最后一次false|首次true（距发起open）|首次true帧龄|
|---|---:|---:|---:|---:|
|ours|70.174ms|106.677ms|119.703ms|4ms|
|Alma|64.461ms|113.389ms|125.908ms|4ms|

观测到了**pip_status本身**的false→true，未仅用open响应代替。该毫秒数只是本次采样时点。完成后sessions/armed双端为空。证据：`G-fixtures.json`、`G-after-minimize-*.json`、`G-no-rearm.json`、`G-size-*.json`、`G-aligned-*.json`、`G-timelines.json`。

## 前台/光标哨兵与1秒候选

所有GUI批次前后采样，另独立进程按monotonic时钟每0.5秒采样。前台来自System Events，光标来自只读CGEventGetLocation；没有注入恢复鼠标/激活应用。主序列后以**单个NSRunningApplication实例**额外读取，15:39:10为Paseo/20400、光标873,475；补测最终15:48:56为Chrome/52445、光标1177.6796875,279.4609375。

主序列共1993条哨兵；最初49条查询语法错误（含2个baseline端点），发生在首个GUI测试前，**不计有效样本**。修正后连续monitor有1858个返回成功的样本，其中7条在切换期间混合了name/pid/bundle，另存`sentinel-mixed-samples.json`并剔除前台归因。有效一致monitor **1851点**，15:22:38.796–15:38:07.316；间隔中位数0.500024s，剔除混合样本后最大1.502142s。实际原始调度最大0.763906s，不声称恰好每500ms或可排除采样间瞬态。

44组前后配对中43组前台可用，24组前台或光标有变化；有效连续样本中495次光标变化。28次前台转换见下表；没有采到TextEdit/Finder/被测helper成为前台。变化只保留观察，用户/其他进程是否操作未隔离，不能认定focus steal。

|采样时刻(+08:00)|前台转换|完成后≤1s候选|
|---|---|---|
|15:22:47.297|Paseo → WeChat|无|
|15:22:49.299|WeChat → Paseo|无|
|15:23:31.296|Paseo → Feishu|无|
|15:23:56.311|Feishu → Paseo|无|
|15:24:02.312|Paseo → Feishu|无|
|15:24:04.310|Feishu → Paseo|无|
|15:24:06.310|Paseo → WeChat|无|
|15:24:08.307|WeChat → Paseo|无|
|15:24:33.313|Paseo → WeChat|无|
|15:24:34.314|WeChat → Feishu|无|
|15:25:28.312|Feishu → WeChat|无|
|15:25:29.814|WeChat → Paseo|无|
|15:25:32.814|Paseo → Google Chrome|无|
|15:25:42.314|Google Chrome → Paseo|无|
|15:25:57.327|Paseo → Google Chrome|无|
|15:28:26.310|Google Chrome → Paseo|无|
|15:29:12.814|Paseo → Google Chrome|Alma D-gas-5 +541ms；ours D-gas-6 +190ms|
|15:29:34.311|Google Chrome → Paseo|无|
|15:31:55.314|Paseo → Google Chrome|无|
|15:32:17.813|Google Chrome → Paseo|无|
|15:32:30.311|Paseo → Google Chrome|无|
|15:33:58.311|Google Chrome → Paseo|无|
|15:33:58.813|Paseo → Google Chrome|无|
|15:34:03.312|Google Chrome → Paseo|无|
|15:34:19.811|Paseo → Google Chrome|无|
|15:34:28.816|Google Chrome → Paseo|无|
|15:34:29.311|Paseo → Google Chrome|无|
|15:34:57.816|Google Chrome → Paseo|G-first-frame：两端open/status/close等27条，见下文|

两组必须单列的候选归因：

1. **15:29:12.815 Paseo→Chrome**：Alma `D-get_app_state-5-d5-offFalse`完成后541ms、ours `D-get_app_state-6-d5-offFalse`完成后190ms；同时Alma第6次gas尚在执行。请求目标是Finder，变化目标是Chrome。两端调用重叠，无法单端归因。
2. **15:34:57.816 Chrome→Paseo**：此前1秒有27条G-first-frame相关请求；ours open完成后359ms、ours close后289ms、Alma open后236ms、Alma close后162ms、最后双端status后161ms。两端都在候选窗口内，未证明PiP导致前台切换。

另3个转换采样处于尚未结束的请求内（A系统设置Alma snap两次、A-combo-rebind ours snap一次），单独保存在`in_flight`，没有伪称“请求完成后1s”。完整候选明细与光标坐标在`sentinel-transitions.json`；所有44组前后点在`sentinel-batches.json`，可追至原始`sentinel.jsonl`。

### 补测的原子哨兵

`sentinel-native.jsonl`另有**210条**原子读取（206个连续monitor、2组前后点），15:47:14.247–15:48:56.663；间隔中位数0.499982s、最大0.505715s，无错误/混合身份样本。5次前台转换、38次光标变化；合计本轮2203条哨兵记录，两个监控时段之间仅整理文档，没有GUI测试动作。

|补测采样时刻(+08:00)|前台转换|候选|
|---|---|---|
|15:47:14.668|Paseo→Chrome|无；早于新建测试窗|
|15:47:24.704|Chrome→Electron/44599|Alma D2-literal-snap-after-empty完成后677ms、ours D2-gas-after-snap后385ms|
|15:47:26.667|Electron→Chrome|无完成后1s候选|
|15:47:35.753|Chrome→Ghostty|无|
|15:47:37.658|Ghostty→Chrome|无|

**第三组候选归因：15:47:24.704**。请求目标为Finder，前台变成Electron；候选同时包含两端读取，且用户/其他进程未隔离，仍为OBS，未指认为任一端focus steal。D3正式稳定检查期间前台始终Chrome。补充明细在`sentinel-native-summary.json`，结束时Chrome/52445、光标1177.6796875,279.4609375。

## 清理与测试工具偏差

- 本轮3个TextEdit文稿 **235981、236168、236170** 全部关闭；首个修改文稿仅在其自己的保存表单点“删除”丢弃，无新保存文件。新Finder窗 **236036、236285、236294** 已关闭，最终Finder只剩原桌面wid0。
- 原TextEdit W230637的bounds `(0,33,1512,897)` 和内容均与A基线一致，双端最终读回；原Maps W235174保留，Preview仍无窗。基线TextEdit另有35×28的无标题AXDialog W235512，后续清单中不再出现；未专门操作该窗口，消失原因未确定，也未为恢复瞬态UI而额外操作。因此不宣称所有临时系统窗口id都与基线相同。
- Font/Color菜单恢复“显示字体/显示颜色”；Finder大小24/图标视图已复原后再关闭测试窗。未创建/删除Notes笔记、修改系统设置或打印。
- 所有本轮PiP逐窗关闭/解除；最终两个socket均 `{sessions:[],armed:[]}`、ping成功。这是15:48:17前的测试收尾状态；随后外部重启了ours，见文末。
- 只读event tap与连续monitor已停止；最终独立原子哨兵Chrome/52445、(1177.6796875,279.4609375)。未重置用户前台/光标掩盖变化。
- 临时测试脚本有四类已记录的工具偏差：前台查询初始语法错误、secondary命令拼写错误、E脚本起跑前SyntaxError以及F的Path拼接错误。E语法修正前未发E请求；F从未发出的步骤续跑。均未当成被测产品bug。

原始证据与可复用探针保留在 `/tmp/cu-r5`，不删除证据截图。`manifest.json`记录证据SHA256；`environment.json`记录OS、进程、二进制。报告中的PASS仅限实测范围：5类控件、非方向键vk fallback、微预算统一尝试数及所有焦点因果均未被虚构为通过。

## 证据读取

```python
import json, pathlib
p = pathlib.Path('/tmp/cu-r5/requests.jsonl')
for line in p.read_text().splitlines():
    r = json.loads(line)
    if r['case'] in {'B-menu-com.google.Chrome-retry',
                     'C-window-shape-snap-0', 'E-auto-default-0'}:
        print(r['time'], r['side'], r['request'], r.get('raw'))
```

需要复放时重新创建自有文稿并从本端snap取ref/window_id；本报告测试窗口均已销毁，不向原用户文稿重放写入。

## 收尾并发更新（不混入本轮测试结论）

本轮最后GUI/socket检查于**15:48:17**完成。之后收尾核验发现另一个并发提交 `9d5e74501bb50e44fe2fa9e5d7d3105c91042139`（15:50:22，提交信息署名Devin）修改了三项实现并纳入了此前已写出的R5文档；磁盘二进制于15:49:58更新，SHA256现为`8e23a0377e69de31167edda9b6cf063a3805be34479c07c88770126fa40156ce`，ours新daemon PID61573于15:49:59启动，Alma仍37196。

这些代码/构建/重启/提交**不是本测试执行的操作**。BUGS顶部新增的“Round-5修复、已验证”段来自该并发提交，已保留；本报告859条正式请求仍对应上文c5ccba7/旧二进制测试时段，不自动为9d5e745背书，也不把三条基线失败误写为新版本仍未修复。新版本复验声明的来源是该提交；本轮未再重放写入测试。证据：`environment-after-concurrent-update.json`。
