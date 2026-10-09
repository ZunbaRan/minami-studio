# CX real-desktop field mission — 有效实测汇总

- 执行环境：2026-10-09，本机macOS；首轮实测11:13–12:22 CST，CX17补测12:28–12:36 CST。**计划20项，实际执行20项（含部分完成和确认差异）；不能宣称全部覆盖通过。**
- 已确认实现差异：4项minor（opt别名、menu_shortcuts键名、PiP默认位置/布局、源关闭后PiP残留），见[BUGS](BUGS.md)。另按硬约束记录16项哨兵变化观察，因用户/其他操作未排除，不计已确认parity差异。
- 本轮编写17本类别手册。原有field-preflight是另一权限环境预检留下的历史手册，不计入17本。
- 只写本目录两份Markdown和skills各SKILL.md；没有修改源码、配置、构建或修复系统。GUI操作走minami_studio；CX17按用户新增明确授权使用PiP daemon socket，真Alma socket用于同请求对照。未发送消息、购物、修改真实系统选项或删除用户既有数据。
- 下表为最终有效统计。附录保留文件原有的CX00预检阻塞记录和逐步流水，包含已更正的临时结论；旧“0项执行”不代表本轮实测。

|任务|覆盖|结果|发现的bug|手册|
|---|---|---|---|---|
|CX01|TextEdit富文本、中文/emoji、选区加粗|功能通过；测试文稿关闭并删除未存内容|—|[textedit-editing](../../skills/textedit-editing/SKILL.md)、[unicode-text-entry](../../skills/unicode-text-entry/SKILL.md)|
|CX02|TextEdit重复串查找与定点替换|替换通过；查找条快捷键未可达|BUG-CX02（minor确认）|[textedit-editing](../../skills/textedit-editing/SKILL.md)、[background-menu-chords](../../skills/background-menu-chords/SKILL.md)|
|CX03|TextEdit保存面板、RTF落盘、Finder清理|通过；445字节内容/MD5已验；复用后永久删除|BUG-CX03（前台观察）|[save-dialog-handling](../../skills/save-dialog-handling/SKILL.md)|
|CX04|TextEdit双窗口隔离|部分；A/B读取及B隔离正确，A瞬时修改未证持久性；两测试窗已关|BUG-CX04（哨兵观察）|[multi-window-isolation](../../skills/multi-window-isolation/SKILL.md)|
|CX05|Finder前往、新建目录、重命名、sky索引|功能完成；早期Alma同请求对照也参与确认；目录最终逐项永久删除|BUG-CX05（哨兵观察）|[finder-file-ops](../../skills/finder-file-ops/SKILL.md)|
|CX06|Finder恢复文件、重命名、拖动、视图、简介|重命名/视图/简介通过；拖动未移动，Alma同样；文件永久删除|BUG-CX06（哨兵观察）|[finder-file-ops](../../skills/finder-file-ops/SKILL.md)、[context-menu-driving](../../skills/context-menu-driving/SKILL.md)|
|CX07|Notes建立、中文/emoji、列表右键、删除|建写删完成；最终用工具栏更多AXShowMenu→删除，146恢复145；列表像素删除未成|BUG-CX07（哨兵观察）|[notes-lifecycle](../../skills/notes-lifecycle/SKILL.md)|
|CX08|Notes重AX列表浏览及滚动恢复|scroll不支持；后续AXDecrementPage两次回到顶部，截图已核对|—|[heavy-ax-tree-strategy](../../skills/heavy-ax-tree-strategy/SKILL.md)|
|CX09|Calculator基本计算|42+17=59双验；AC回0|BUG-CX09（哨兵观察）|[calculator-driving](../../skills/calculator-driving/SKILL.md)|
|CX10|Calculator科学模式与阶乘|cmd+2、5!=120；AC与cmd+1恢复基础|BUG-CX10（哨兵观察）|[calculator-driving](../../skills/calculator-driving/SKILL.md)、[background-menu-chords](../../skills/background-menu-chords/SKILL.md)|
|CX11|Preview后台图片打开与缩放尝试|部分；打开文件面板可达，路径未提交，图片/缩放未完成；面板已取消|BUG-CX11（哨兵观察）|[preview-readonly](../../skills/preview-readonly/SKILL.md)|
|CX12|Music欢迎页与歌曲库只读|已查看空歌曲库；AX失败后physical cell可达；没有播放/购买/添加|BUG-CX12（哨兵观察）|[readonly-native-apps](../../skills/readonly-native-apps/SKILL.md)|
|CX13|Calendar只读月视图|10月→11月→10月；测试显示的窗口已关闭|BUG-CX13（哨兵观察）|[readonly-native-apps](../../skills/readonly-native-apps/SKILL.md)|
|CX14|Reminders后台只读、搜索字段|字段写CX14再清空；未改用户条目；原测试窗已点关闭，后续出现未登记新window.id|BUG-CX14（哨兵观察）|[readonly-native-apps](../../skills/readonly-native-apps/SKILL.md)|
|CX15|Maps/Mail只读窗口|地图读取、邮件摘要读取；最终两app均无窗口；没有发送或点未读邮件|BUG-CX15（哨兵观察）|[readonly-native-apps](../../skills/readonly-native-apps/SKILL.md)|
|CX16|Stocks/Weather冷启动焦点|activates:false启动成功；天气哨兵完全一致，Stocks子像素变化记录；两app最终未运行|BUG-CX16（哨兵观察）|[app-launch-focus-safety](../../skills/app-launch-focus-safety/SKILL.md)|
|CX17|TextEdit/Calculator PiP多app生命周期、镜像更新、armed独立性、最小化一次性、来源关闭|已完成授权socket实测；主要流程通过，有2项差异；两端会话/armed均清空|2项minor：默认位置/布局、源关闭后PiP残留；另有光标观察|[pip-preview](../../skills/pip-preview/SKILL.md)|
|CX18|gas→像素click、OCR v*、快照快捷键|8像素点击成功且清0；OCR与v*错误均同Alma；发现shortcut键名差异|BUG-CX18-menu_shortcuts（minor确认）；另有哨兵观察|[screenshot-coordinate-clicks](../../skills/screenshot-coordinate-clicks/SKILL.md)|
|CX19|Calculator→Notes→TextEdit→Finder|861四处核对；RTF保存473字节；文稿关、AC清0、笔记删除、文件移入废纸篓|BUG-CX19（哨兵观察）|[cross-app-data-transfer](../../skills/cross-app-data-transfer/SKILL.md)|
|CX20|非法参数、旧ref、unknown bundle/ref、suppressed|已执行；可比native错误文字与Alma一致；schema非法枚举在MCP层拒绝|—|[error-recovery](../../skills/error-recovery/SKILL.md)|

## 最终清理与限制

- TextEdit仅保留原有W230637、原文本é👩‍💻；本轮所有新建文稿窗口均已关闭。CX19文件已完成保存验证后从Desktop移入废纸篓。
- Calculator已恢复基础模式并AC清零。CX03/CX06复用文件与CX05文件夹逐项永久删除，ls证实原处/Trash均不存在。
- Notes测试笔记通过原生删除移入“最近删除”，iCloud全部从146恢复原145，原Auto ok重新显示。原生可恢复副本仍保留；未永久清空最近删除，未删除其他笔记。
- `/Users/lu/.Trash/CX19_Transfer_20261009.rtf`仍有473字节可恢复副本；本轮已完成原生“移到废纸篓”，后续逐项永久删除菜单未稳定可达，未声称永久擦除。桌面原路径不存在。
- Finder本轮最后W233189已AX关闭，返回Post-action screenshot unavailable；此前W232872/232317等已关闭。12:12复核Maps/Mail/Calendar/Preview无窗口，Stocks/Weather不再运行。
- Reminders最初测试窗口232598已经执行关闭；12:12复核出现新W232982（不同于本轮登记窗口），未盲目关闭。桌面可能存在并发操作，未收到用户归因回复。
- Music使用的是原有窗口；仅停在空歌曲库。没有播放或新增媒体。
- CX17补测已完成PiP open/arm/disarm/close；最终两端sessions/armed均空、两测试文稿已丢弃。Preview图片打开/缩放未完成，Finder拖动移动未完成。工具自动生成的alma-cu-state截图属于被测工具原生输出，不更改其固定命名语义。

## 哨兵与对照方法

每类任务开始、结束采样前台/光标；详细采样见流水与BUGS。早期frontmost.sh分次取bundle/pid可串出混合值，后改为单次Swift读NSWorkspace.frontmostApplication与NSEvent.mouseLocation。相同采样仅证明两个采样点相同，不证明中间完全无瞬态；变化记录不等于因果成立。CX18起始采样精确值未完整落盘，保留中段与末尾值，不能补造。

CX20完整前后12:06:13→18 WeChat/(182.8164,807)相同。Notes成功删除12:08:15→25 Electron/(1252,674)相同。收尾12:16:28 Lark/(1134.24,22.54)→12:18:14 Lark Helper/(1500.46,323.27)，归并清理阶段哨兵观察。

Alma对照socket为computer-use-9bd08bc1.sock，JSON-lines。通过只读脚本发同cmd/args；ref需要先取得该daemon当前ref，不能横用两边的编号。比较语义、错误文字和GUI效果，不比较随机id、截图时间戳或Foundation字典键序。OCR的live字段名为visual_refs，与本实现相同，旧章文字visual_regions不作为反证。

## CX01补回的实测记录

11:13:22→11:14:53前后均Lark/(970,522)。原TextEdit W230637内容é👩‍💻保留。cmd+n新建W232163，正文CX01_Field rich text/中文与emoji/alpha beta alpha；select_text选标题后AX点粗体e73，状态value=1并截图验证。关闭e89后确认删除未存测试文稿e101。该段曾被另一份预检记录覆盖，依据本轮工具返回补记，不改原始预检记录。

## 手册目录

- [textedit-editing](../../skills/textedit-editing/SKILL.md)
- [save-dialog-handling](../../skills/save-dialog-handling/SKILL.md)
- [multi-window-isolation](../../skills/multi-window-isolation/SKILL.md)
- [finder-file-ops](../../skills/finder-file-ops/SKILL.md)
- [context-menu-driving](../../skills/context-menu-driving/SKILL.md)
- [notes-lifecycle](../../skills/notes-lifecycle/SKILL.md)
- [heavy-ax-tree-strategy](../../skills/heavy-ax-tree-strategy/SKILL.md)
- [calculator-driving](../../skills/calculator-driving/SKILL.md)
- [unicode-text-entry](../../skills/unicode-text-entry/SKILL.md)
- [background-menu-chords](../../skills/background-menu-chords/SKILL.md)
- [readonly-native-apps](../../skills/readonly-native-apps/SKILL.md)
- [preview-readonly](../../skills/preview-readonly/SKILL.md)
- [app-launch-focus-safety](../../skills/app-launch-focus-safety/SKILL.md)
- [screenshot-coordinate-clicks](../../skills/screenshot-coordinate-clicks/SKILL.md)
- [pip-preview](../../skills/pip-preview/SKILL.md)
- [cross-app-data-transfer](../../skills/cross-app-data-transfer/SKILL.md)
- [error-recovery](../../skills/error-recovery/SKILL.md)

最后MCP只读复核（12:22）：Calculator静态值0，Notes W230343标题145个备忘录，Finder无window。最终哨兵12:22:12 Paseo/(857.367,327.125)；相对12:18 Lark Helper有变化，期间只有文件文档操作及以上快照，按观察记录，不归因为工具焦点缺陷。

## 文档验证

17本本轮手册均通过只读结构检查：frontmatter name/description、规定五章节、相对链接存在性、长度；首张汇总表准确20行，BUGS共19个BUG节（2个历史环境blocker、2个确认minor、15个未归因哨兵观察）。skill-creator自带quick_validate.py已尝试，但环境缺PyYAML，未通过运行；未安装依赖或更改配置，不把自检冒充官方验证器通过。

最后ls复核：Desktop/CX19_Transfer_20261009.rtf不存在；Trash中同名473字节；CX05文件夹与CX06文件在Trash均不存在。12:16–12:18新增Finder窗口233189已关闭；尝试恢复图标视图遇到旧ref element_not_found，未声称该视图恢复成功；窗口是本轮新建。

## 附录：原始预检记录与逐步流水

以下包含另一权限环境的CX00记录和本轮先后追加的观察；最终状态以上文汇总为准。

# CX field mission execution log

- 日期：2026-10-09（Asia/Shanghai）；执行者：Codex CX。
- 状态：预检阻塞，计划 20 项真实任务，完成 0 项；下表明确区分计划与实测。
- GUI 仅使用 minami_studio MCP；真 Alma socket 只用于同请求定性。未执行 socket 调用。
- 不改源码/配置；不发送消息；不操作既有数据。实际未创建任何测试文件、笔记、窗口或 PiP 会话，也未修改计算器状态，无测试数据待清理。
- 哨兵前后采样只能检查采样点，不能证明中间没有瞬时变化。本轮连有效首次基线也未取得。
- 当前 MCP 暴露 23 工具，不含 pip_*、press；get_app_state schema 未暴露 include_screenshot。PiP 是否允许 socket 例外已询问，未获答复前不执行。
- 下表“阻塞/未执行”不是失败的 app 功能验证，也不是覆盖完成。所有类别手册名仅为计划；实际只产出 field-preflight。

|任务|覆盖|结果|发现的bug|手册|
|---|---|---|---|---|
|CX00 预检（不计入20项）|权限、list_apps、TextEdit只读快照、前台/光标哨兵|已执行诊断；三次MCP授权拒绝，哨兵无有效值|BUG-CX00-MCP授权策略阻断全部探测；BUG-CX00-哨兵无法取得前台和光标基线|[field-preflight](../../skills/field-preflight/SKILL.md)|
|CX01 基本计算|Calculator：17×23=391，读取显示，AC清零|阻塞/未执行|—|calculator-driving（待实测）|
|CX02 科学计算及像素链路|Calculator：科学模式、平方根；gas→截图像素→click；恢复模式及清零|阻塞/未执行|—|calculator-driving、screenshot-coordinate-clicks（待实测）|
|CX03 富文本和中文输入|TextEdit：新建CX03_文档，粗体/段落、unicode中文、选区插入|阻塞/未执行|—|textedit-editing、unicode-text-entry（待实测）|
|CX04 查找替换|TextEdit：仅CX04_测试文档，查找重复词并替换，核对内容|阻塞/未执行|—|textedit-editing（待实测）|
|CX05 保存面板|TextEdit：保存CX05_测试文件到测试目录、验证格式及内容、清理|阻塞/未执行|—|save-dialog-handling（待实测）|
|CX06 多窗口隔离|TextEdit：CX06_A/B两个测试窗，按window_id读写、关闭一个后试旧ref|阻塞/未执行|—|multi-window-isolation、error-recovery（待实测）|
|CX07 Finder定位及新建|Go-to-Folder，创建唯一CX07_目录，确认路径|阻塞/未执行|—|finder-file-ops（待实测）|
|CX08 Finder重命名及移动|仅CX08_测试文件/目录，重命名、移动、核对路径并清理|阻塞/未执行|—|finder-file-ops（待实测）|
|CX09 Finder视图及简介|测试目录视图切换、右键菜单、Get Info；记录并恢复原视图|阻塞/未执行|—|finder-file-ops、context-menu-driving（待实测）|
|CX10 Preview与OCR引用|只读打开已有图片（不保存修改），缩放；若快照确有v*再尝试该ref，关闭测试窗|阻塞/未执行|—|screenshot-coordinate-clicks（待实测）|
|CX11 Notes建笔记|CX11_唯一标题、中文正文、核对写入，仅在能确认清理路径时创建|阻塞/未执行|—|notes-lifecycle、unicode-text-entry（待实测）|
|CX12 Notes浏览与删除|depth≤6、interactive_only、window_id；浏览并仅通过目标CX12_笔记上下文删除|阻塞/未执行|—|notes-lifecycle、heavy-ax-tree-strategy（待实测）|
|CX13 Music只读|读取库/栏目及可用控件，不播放、不改资料库|阻塞/未执行|—|background-menu-chords（待实测）|
|CX14 日历只读|日期/月视图浏览，不建事件，恢复原视图|阻塞/未执行|—|app-launch-focus-safety（待实测）|
|CX15 提醒事项只读|列表浏览，不勾选、不新建、不删除用户条目|阻塞/未执行|—|heavy-ax-tree-strategy（待实测）|
|CX16 Stocks/天气冷启动|先确认未运行；launch_app activates:false，立即及延迟哨兵；若本已运行则标记非冷启动|阻塞/未执行|—|app-launch-focus-safety（待实测）|
|CX17 地图/邮件只读|读取初始界面、栏目，不发送邮件、不改已读状态或用户数据|阻塞/未执行|—|app-launch-focus-safety（待实测）|
|CX18 多app PiP生命周期|TextEdit/Calculator：open、arm、disarm、close；只清理本轮会话|阻塞/未执行；另有MCP工具面无pip_*限制|—|pip-preview（待入口授权及实测）|
|CX19 三app数据搬运|Calculator结果→CX19_Notes笔记→CX19_TextEdit保存；逐段比对并清理全部测试产物|阻塞/未执行|—|cross-app-data-transfer（待实测）|
|CX20 错误面与恢复|非法参数、未知bundle（auto_launch:false）、suppressed chord、旧ref；同请求Alma定性|阻塞/未执行|—|error-recovery、background-menu-chords（待实测）|

## CX00 实际执行证据

2026-10-09 11:11–11:14 +08:00：

1. 创建本次产出目录与日志，读取项目 AGENTS.md、skill-creator 规范和现有哨兵/socket示例；只读检查 wrapper 工具入口。
2. `/tmp/cu-review/frontmost.sh` → exit 0，`frontmost= pid= cursor=`。该输出不可用。
3. `permissions({})` → `isError:true`，`MCP tool call requires approval, but approval policy is never`。
4. `list_apps({"days":1})` → 同上。
5. 单独运行前台采样 → System Events `-10827`；光标采样 → Swift ModuleCache `Operation not permitted`，完整关键诊断见 BUGS。
6. `get_app_state({"bundle":"com.apple.TextEdit","auto_launch":false,"depth":2,"interactive_only":true})` → 同一授权错误。没有应用快照，没有自动启动 app。
7. ctypes/AppKit 只读替代哨兵 → exit 134、无值。没有可用基线。
8. 停止 GUI 测试，写入两个环境 blocker；未反复重试各 app，未将其计作真实任务。

## 恢复入口

需要运行环境允许 minami_studio MCP 调用，并能取得有效的前台/光标哨兵。当前会话禁止审批升级；不在本次任务中修改源码、MCP配置或系统选项。环境恢复后先重跑CX00，再逐项执行CX01–CX20；不得沿用不存在的截图、ref或窗口id。若PiP仍只有socket入口，需明确获准该例外后才执行CX18。

每项执行时先写入前哨兵，再做操作和效果验证，清理后记录后哨兵；有异常时立即记录动作时间与参数。每3–5项落盘已验证手册。真Alma也有的行为写入手册的parity限制，不报实现bug。

## 本轮产出

- [BUGS.md](BUGS.md)：两个环境blocker；零个已确认实现bug。
- [field-preflight/SKILL.md](../../skills/field-preflight/SKILL.md)：本次实际诊断支撑的预检手册。
- 其余类别手册未生成，避免把计划或先验约束包装为现场成功经验。

## 收尾复核

- CX00 后哨兵再次运行：exit 0，仍为 `frontmost= pid= cursor=`。前后均无有效观测，不能宣称未变化。
- skill-creator 的只读 `quick_validate.py` 已尝试，因当前 Python 无 `yaml` 模块而未完成；未安装依赖、未改配置。人工检查了必需 frontmatter、五个规定章节及相对链接；不把人工检查描述为验证器通过。
- 本轮仅写入上述三个产出文档。无GUI测试产物，无需关闭测试窗口、删除笔记或清零计算器。

CX01 后哨兵 11:14:53 Lark/970,522。
|CX02|TextEdit 查找替换、重复串消歧|替换通过：green apple→green 梨，red apple 保留；查找条 chord suppressed；测试窗已关闭|BUG-CX02-opt-修饰键不识别|textedit-editing、background-menu-chords|
CX02 前 11:14:54 Lark/970,522；select_text(ref=e109,text=apple,prefix="green ") + type_text(ref=e109,input_method=ax,text=梨) 验证成功。点击 e127 后回到既有 230637，既有文本仍 é👩‍💻，测试窗已清理。

CX02 后哨兵11:16:00 Lark/970,522。
|CX03|TextEdit Unicode、保存面板、Finder清理|保存通过；445字节RTF；测试文稿已关闭，桌面文件已移入废纸篓|BUG-CX03-Finder-前台变化待归因|save-dialog-handling、unicode-text-entry|
CX03 前11:16:02 Lark/970,522；中11:16:47相同；后11:18:15 Finder/970,522。type_text(unicode)完整落字。cmd+s suppressed。关闭按钮→保存表单→保存为CX03_Field_20261009.rtf→位置桌面→保存。md5=4d4de49dd50db246a7610efa7241cf20，RTF含中文与emoji代理对。Finder测试窗232187已关闭；/Users/lu/Desktop/CX03_Field_20261009.rtf不存在，文件在用户废纸篓（未清空废纸篓）。

|CX04|TextEdit 两个测试窗口隔离|部分通过：指定232197/232199读取A/B正确，改A后B不变；A的AX值在关闭表单出现后回显旧值，未验证持久性；两个测试窗均关闭并删除未存文稿|未新增确认bug|multi-window-isolation|
CX04 前11:19:16 Finder/970,522；中11:19:50同。A=e372/W232197，B=e399/W232199。A修改后快照为CX04_Window_A_only_changed，B为CX04_Window_B；关闭A后快照回显CX04_Window_A，故手册不将瞬时AX回读等同持久存储。清理A表单后再快照B才能继续；编排脚本因未找到按钮停止过一次，未越过未知状态行动。

CX04 后11:20:35 Lark/676,603，与前不同，记BUG-CX04-哨兵变化（归因未定）。
|CX05|Finder 前往文件夹、新建文件夹、重命名、sky索引|新建/重命名/删除完成；前往确认成功含Alma对照辅助，不声称全程仅被测MCP成功；CX05文件夹已移入废纸篓，232221关闭|BUG-CX05-哨兵变化（待归因）；physical下划线错误为parity|finder-file-ops、heavy-ax-tree-strategy|
CX05 前11:20:36 Lark/676,603；11:20:57 Lark/676,604。Go字段e509，sky完整树index85（不是e509的509）；sky_perform_secondary_action(action=AXConfirm)仍打开菜单，Alma同样opened_menu。Alma physical换行对照11:22:40→11:22:42前台/光标保持Lark/676,604，成功前往桌面。新建菜单的toolbar版本disabled，但空白处右键版本enabled；点新建后必须重新右键→重新命名，再unicode写CX05_Field_20261009，再physical单独换行确认。physical含下划线报错，Alma同样action_unsupported。ls证实命名成功。11:24后光标持续变化，已改为单次Swift读取前台+pid+光标，原frontmost.sh两次osascript可能串出混合bundle/pid。

CX05 后11:27:04 WeChat/(271,355)，观察归并BUG-CX05。后续CX06已将CX05目录逐项从废纸篓永久删除，未使用清倒废纸篓。
|CX06|Finder 文件恢复、重命名、移动尝试、简介、视图、逐项永久清理|重命名/简介/图标↔列表成功；拖到边栏文稿未移动，Alma同样无效果（parity）；CX03文件复用为CX06后逐项删除，所有自有文件/目录已清理|BUG-CX06-哨兵变化待归因|finder-file-ops、context-menu-driving、multi-window-isolation|
CX06 前11:27:33 Lark/(822.43,448.375)，前往废纸篓并确认路径后11:27:40同；11:29:11→13拖动前后Paseo/(1060,152)同。恢复CX03文件、右键重新命名→unicode CX06_Move→physical换行，ls证实CX06_Move.rtf。gas800后drag(195,85→60,197)无移动，Alma同参数亦无移动；Alma回声screen from(578.25,302.78) to(423,431.63)。简介232399确认445字节、桌面路径和原正文。e695 AXPress列表，e694恢复图标。废纸篓改列表后e1058/e1053是文件/目录的AXCell，按ref右键可靠；立即删除每个对象并检查确认窗名称。注意e1073上一菜单为立即删除，下一菜单变为清倒废纸篓——必须重新读标题，绝不复用旧菜单ref。关闭232399、232233、232317。
计划调整：原CX07视图/简介并入CX06；CX07改为Notes建写删；CX08为Notes列表浏览；CX09/10为基本/科学计算；CX11预览；CX12音乐；CX13日历；CX14提醒事项；CX15地图/邮件；其余不变。

**CX06清理更正 11:33:38**：上段“所有目录已清理/关闭232317”不能视为验证结论。ls确认CX06_Move.rtf已永久删除，但CX05_Field_20261009空目录仍在废纸篓。点第二次“立即删除”后快照意外是前往文件夹表单，未点击任何未知删除确认；e785关闭未确认成功，232317待复核。已询问是否存在其他agent并发操作。最终清理以文末复核为准。CX06后哨兵Lark/(1299,562)。

|CX07|Notes新建、中文/emoji、列表上下文删除尝试|建写成功；Unicode无ref未落字，AX ref插入完整；上下文菜单可见但AXShowMenu报cannotComplete，像素删除本机/Alma均未生效；清理仍在继续|焦点观察待归因；深树超时为已知限制|notes-lifecycle、unicode-text-entry|
CX07 前11:34:53 Passwords/(405.65,727.13)，未操作Passwords；Notes原145→146；新建e1144，AX编辑e1139，正文CX07_Field_20261009/中文记录与emoji/42+17=59。depth5取得cell e1348/内cell e1536，AXShowMenu报cannotComplete但截图菜单可见。depth6未得到上下文menuitem；一次仅为清理升depth7耗16.8s仍无menuitem，随后depth6出现30sMCP超时，故回到depth3。Alma气泡菜单像素click(337,297)实际screen(456.25,410.25)，同样只关闭菜单未删除（不报实现差异）。尝试清空自有正文后切走未成功，146中目前仍有本轮空白笔记，需重新标记/最终清理。11:39:21 Chrome/(678,401)。

CX07续：已将自有空笔记重新标为“CX07_Field_20261009 cleanup pending”，避免无前缀残留。重取更多菜单ref后，删除备忘录enabled=false；AXPress虽click ok但146未下降，不能视为已删。清理保持待办，当前不再创建额外Notes笔记。
|CX08|Notes列表只读分页、低深度策略|向下/向上各1页，按截图核对；不编辑既有笔记|无新增确认差异|heavy-ax-tree-strategy|

CX08更正：两个scroll均返回 `Element does not support action performing AXScrollDownByPage/AXScrollUpByPage.`，**未滚动成功**；无新增内容。前后11:42:16→17均Chrome/(840,480)。
|CX09|计算器基本计算、AX按钮、静态结果|通过42+17=59，已AC清零|无|calculator-driving|
CX09 前11:42:17 Chrome/(840,480)，结果11:42:46同。AX序列AC→4→2→加→1→7→等于，interactive_only:false depth6读出42+17与59，截图亦为59。清理点AC，截图核实0。

CX09后11:43:15 Chrome/(892,521)，相比起点光标变化，作为BUG-CX09哨兵观察记入汇总，不据此认定AX按钮移动了光标；计算结果前后采样相同。
|CX10|科学模式、阶乘、模式恢复|cmd+2进入科学；5! = 120；AC清零，cmd+1恢复基本|无新增确认差异|calculator-driving、background-menu-chords|
CX10 前11:43:16 Chrome/(892,521)。按钮模式AXPress没有显示可用菜单；cmd+2经menu_ax_press成功。e1798→e1801→e1820，非交互静态文本与截图双验120；e1778清零。

CX10后11:45:06 Paseo/(433.41,424.93)，相对起点有用户前台/光标变化，归因未定。
|CX11|Preview后台打开图片面板|部分：cmd+o打开232559；cmd+shift+g suppressed，physical斜杠未出路径框；未打开图片/未测缩放；已AX取消面板|无确认差异，覆盖受阻|preview-readonly|
CX11前11:45:28 Paseo/(433,425)。只读目标为本轮工具截图/tmp/alma-cu-state-1791517000229.jpg，ls确认存在；未改写该图。未为绕过路径面板而激活Preview。

CX11后11:46:37 Chrome/(678.94,549.53)；取消后Post-action screenshot unavailable，与无预览文稿窗口一致。
|CX12|Music欢迎页、资料库只读导航|已过欢迎页并查看歌曲入口；不播放、不购买、不改资料库|无|readonly-native-apps|
CX12前11:46:38→11:46:59均Chrome/(678.94,549.53)。欢迎页“开始聆听”e1889 AXPress，进入主页；无任何购买/试用动作；资料库为空的具体界面以截图为准。

CX12续：歌曲cell e1899无AX动作，strategy:ax报unsupported；改strategy:physical后截图确认“将音乐添加到资料库”，歌曲视图为空。没有播放/购买/新增内容。后11:47:46 Chrome/(469.71,482.38)。
|CX13|日历无窗口恢复、月视图前后翻页|cmd+0打开日历；10月→11月→10月，随后关闭本次显示的窗口|无新增确认差异|readonly-native-apps、background-menu-chords|
CX13前11:47:23 Chrome/(678.94,549.53)；cmd+0对应窗口>日历（AX菜单key29），恢复窗口75156；未创建或改动日程。

CX13后11:48:26 WeChat/(254.72,605.60)。
|CX14|提醒事项冷启动、只读列表、搜索字段|后台启动与欢迎页继续成功；搜索CX14前缀并清空；未新建/完成/删除提醒，窗口已关闭|无确认差异|readonly-native-apps、app-launch-focus-safety|
CX14前11:48:27 WeChat/(254.72,605.60)，启动后11:48:30 WeChat/(254,606)，继续后11:48:48 WeChat/(373.91,498.40)。原列表未完成0；用户既有已完成项目未展开或修改。

CX14后11:49:19 WeChat/(152.12,488.36)；搜索只验证字段值，未声称触发真正过滤。
|CX15|Maps新窗口与地图读取、Mail收件箱窗口只读|地图cmd+n打开并只读，邮件cmd+0打开收件箱摘要；两个本次窗口均关闭；未发送/创建邮件|无确认差异|readonly-native-apps|
CX15前11:49:19 WeChat/(244.57,369.98)，后11:50:22 Ghostty/(568.11,507.24)，用户前台/光标变化待归因。地图232607，邮件232626；邮件只读窗口计数，不主动打开未读邮件，不把内容抄入日志。

CX15清理更正：Mail e2065关闭返回AXError(-25200)，不能视为成功，待最终浅快照确认。Maps关闭后Post-action screenshot unavailable。
|CX16|Stocks/天气冷启动focus|activates:false后台启动；Stocks欢迎页与天气页可见；测试窗已AX关闭|Stocks子像素光标差异待归因；天气启动前后完全相同|app-launch-focus-safety|
Stocks11:51:33 Paseo/(598.484,276.844)→11:51:35 Paseo/(598,277)，pid8475，W232665，未完成欢迎页设置；天气11:52:06→08均Paseo/(598,277)，pid8956，W232683，未点系统设置。CX16真实运行，未购物或改关注列表。
|CX17|PiP多app open/arm/disarm/close|首轮入口受限；用户新增授权后已完成，详见下方CX17续测|2项minor差异，另有哨兵观察|pip-preview|
CX17首轮未执行的历史记录由下方12:28–12:36授权续测更新；续测有独立前后哨兵和完整socket证据。

|CX18|截图像素点击、OCR v*|计算器gas460→click(177,421,screenshot)成功输入8，AX与截图均验证；清除后0。Music深度0产生v1/v2，MCP ref点击缺pid错误；Alma对照见BUGS|OCR/shortcut差异待定性|screenshot-coordinate-clicks|
CX18后11:57:24 Ghostty/(441.52,730.69)，之前11:56:22 Paseo/(588.34,141.98)，当前用户前台/光标持续活动，归因未定。计算器depth0没有OCR，Music depth0有两个识别质量很低的区域，不将OCR文本当作真实控件名称。

## 12:08 清理和CX19/CX20补记

CX07：对当前工具栏“更多”ref e2136调用perform_secondary_action，再depth4得到enabled=true的删除备忘录e2369；AX点击后146→145，回到原笔记Auto ok。成功删除本轮笔记，原生“最近删除”保留可恢复副本。12:08:15→25均Electron pid22026/(1252,674)。不要对当前e1139继续写入，它已复用为用户原笔记。
CX05目录、CX06文件最终ls均不存在；Finder232317已关闭。Mail浅快照无窗口，已确认清理。提醒事项6287的232598关闭按钮e2309已点击，待最终无窗口复核。
|CX19|Calculator→Notes→TextEdit保存→Finder验证|123×7=861，Notes与TextEdit回读一致；RTF473字节、md5 bf38d0e852f3b25be22116279afbf1e9；计算器清零、TextEdit测试窗关闭、Notes测试笔记已删，文件已移到废纸篓|无新增确认差异|cross-app-data-transfer|
CX19前12:02:26 Ghostty/(1048.54,699.38)，保存后12:04:15系统设置/(779.80,579.69)，没有操作系统设置。12:09:44 Lark/(117.125,846.945)。文件CX19_Transfer_20261009.rtf在Trash，清理仍继续。
|CX20|unknown bundle、unknown/失效ref、空key、非法枚举、suppressed chord|已执行；Alma逐项对照unknown bundle/ref、空key、cmd+s文字一致；失效ref返回element_not_found，非法枚举由MCP校验层拦截|无新增确认差异|error-recovery|
CX20前12:06:13→18均WeChat/(182.8164,807)。失效测试是已关闭的本轮TextEdit e2142，仅select_text，不写用户内容；返回No element known，而非武断要求ref_stale。非法selection_type=invalid返回MCP -32602。Alma同请求没有wrapper schema层，因此不拿native未校验结果对比MCP输入层。
CX18定性：Alma Music depth0同样返回visual_refs=[v1 SiQrn,v2 pJ•]，confidence均0.5、bbox逐值相同；普通MCP click(v1,bundle)丢目标，Alma等效native click(ref:v1)返回invalid_arg同文。契约章写visual_regions与live不一致，依live不报实现bug。

## CX17 获授权的PiP续测

用户新增授权明确允许 PiP 使用 daemon socket；本项不再受“23个 MCP 工具无 pip_*”阻塞。2026-10-09 12:28:58–12:36:58 CST，GUI 编辑/最小化/文稿关闭全部使用 minami_studio MCP；PiP 使用授权的两端 socket，同源、同参数对照。没有改源码、配置或系统选项。

- 被测 socket：`computer-use-72097929.sock`；Alma：`computer-use-9bd08bc1.sock`；目录均为 `/Users/lu/Library/Application Support/Alma/`。
- 源应用：TextEdit pid64284；Calculator pid57752。初始 TextEdit 用户原窗 W230637、内容 `é👩‍💻`；Calculator W230248、基础模式0。
- 本轮创建 TextEdit W233332（CX17_A/B 镜像、arm/minimize）、W233456（CX17_DestroyProbe 来源关闭复现）；自定义 PiP title 均加 CX17_。没有保存测试文件。
- 通过 socket 对端元数据读取 helper pid：ours36812、Alma37196；用于 MCP 读取浮窗。源 window_id 与 helper 浮窗 window_id 不能混用。

|场景|调用与实际验证|结果|
|---|---|---|
|P0 准备|ours 首次 socket ConnectionRefused；正常 MCP get_app_state 后恢复；两端 status 均空|恢复成功；不将闲置 socket 状态直接定为实现 bug|
|P1 双 app / 镜像|TextEdit、Calculator 同时 open；status 两会话均 first_frame:true，帧龄更新；重复 open 无第三会话；MCP set_value e40 从 CX17_A/1729/阶段甲改为 CX17_B/4096/阶段乙，helper 浮窗 W233386 两次截图实际变化；Calculator 浮窗显示0|功能通过；默认位置与后续排列存在 minor 差异|
|P2 armed 独立性|两 app arm；重复 TextEdit arm 回声 ArmB，但 status 保留 ArmA且只有一条；disarm Calculator 保留其 session；close TextEdit 保留其 arm；再次 close/disarm 返回 false|两端一致；最终这一步两端均空|
|P3 最小化一次性|两端同时 arm 同源 W233332；MCP AX 点最小化 e75；首次 status 为 session有/armed空；close后恢复源、不rearm再次最小化，status两端均空|一次性消费通过；保持最小化时新会话约9秒未出帧，两端一致|
|P4 已有会话再arm|Calculator open→arm→MCP AXMinimize e34|两端保留一个原 session/title，消费 armed；随后 close并恢复源|
|P5 重新arm与出帧|TextEdit重新arm→最小化可再次auto-open；先查status，再带截图gas恢复源；两端 first_frame从false到true；ours浮窗W233443实际显示B/4096|通过；不得把源恢复后的出帧声称为最小化期间实时画面|
|P6 源关闭收尾|对 W233332 再arm，MCP关闭源并删除本轮未存内容；Alma session消失，ours至少20秒残留；两端arm均留存，随后定向disarm|发现来源关闭后的session差异；armed留存是parity|
|P7 独立复现/最终清理|新建W233456，直接open且不arm；关闭源后 ours 到43秒仍有session、帧龄43135ms；Alma始终空；显式close ours:true/Alma:false|复现第二项minor；清理后两端status均空|

### MCP与视觉证据

- W233332：正文 e40；最小化 e75；关闭 e73；保存面板“删除”e149，仅丢弃本轮未保存内容。
- W233456：正文 e182；关闭 e219；保存面板“删除”e245，仅丢弃本轮未保存内容。
- ours helper：MCP get_app_state(pid36812) 返回 W233389 Calculator 浮窗、W233386 TextEdit 浮窗；TextEdit A→B两张截图均从真实 PiP helper 窗口读取，并非用源截图代替。
- Alma helper pid37196 的 MCP AX读取尝试返回 `cannotComplete while reading AXWindows`；本轮没取得它的浮窗截图。Alma 出帧/帧龄通过 native status 验证；镜像 A→B 视觉证据仅覆盖被测端。
- first_frame/age 是异步状态，不是图像内容证明。源最小化时的新会话不出帧、源关闭后 armed 留存，均有 Alma 同表现，不计新增差异。
- open 默认宽高本轮 TextEdit240×200、Calculator240×426；不能沿用未复核的固定334×220假设。
- 确认差异详见 [BUGS](BUGS.md)：`BUG-CX17-floater-frame默认位置与Alma不同`、`BUG-CX17-源窗口关闭后PiP会话残留`，均 minor；另外一条哨兵观察待归因。

### CX17哨兵

全部下列前台采样均 `sh.paseo.desktop/20400`，未观察到目标 app 成为前台。准备和P1/P2/P6光标变化已记 BUG-CX17-哨兵光标变化待归因，不能声称全程无漂移。使用单次Swift读取，不通过恢复前台/光标掩盖变化。

|范围|前采样（CST，光标）|后采样（CST，光标）|判定|
|---|---|---|---|
|整项|12:28:58 (857,328)|12:36:58 (609,138)|光标变化观察|
|P1镜像/open|12:31:37 (747.40234375,387.58984375)|12:32:35 (70,397.86328125)|光标变化观察|
|P2 arm/disarm/close|12:32:55 (314.07421875,444.69140625)|12:33:06 (1125.0703125,665.33984375)|光标变化观察|
|P3 一次性|12:33:15 (806,316)|12:33:32 (806,316)|一致|
|P4 已有session|12:33:42 (806,316)|12:33:47 (806,316)|一致|
|P5 再arm/恢复|12:34:41 (806,316)|12:35:07 (806,316)|一致|
|P6 关闭来源|12:35:16 (806,316)|12:35:30 (746,320)|光标变化观察|
|P7独立复现准备|12:35:47 (689.37890625,251.26953125)|12:36:58 (609,138)|准备期间光标变化|
|P7实际关闭至清理|12:36:12 (609,138)|12:36:58 (609,138)|一致|

### CX17最终状态

12:36:56.800 ours、12:36:57.059 Alma：`data:{armed:[],sessions:[]}`。两个CX17源文稿均已关闭并丢弃；最终 MCP 只读核对用户原 TextEdit W230637/`é👩‍💻` 与 Calculator W230248/基础模式0保持。没有使用 all:true，没有永久删除用户数据。12:36:58收尾哨兵为 Paseo/20400、(609,138)。

`skills/pip-preview/SKILL.md` 已重写为 socket 入口，包含可复制请求、helper PID/浮窗截图、armed两套独立状态、最小化消费、差异workaround与定向清理。仅修改本轮三份产出 Markdown。

### CX17原始socket证据

以下是执行时持续追加的完整请求/回包，随机 id、字段顺序与时刻原样保留。不同会话的数组顺序不作 parity 断言。

CX17 socket evidence: `{"time": "2026-10-09T12:29:05.047+08:00", "case": "P0 baseline", "side": "ours", "request": {"id": "2d2e0f42ab1ed045", "cmd": "pip_status", "args": {}}, "response": {"transport_error": "ConnectionRefusedError: [Errno 61] Connection refused"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:29:05.127+08:00", "case": "P0 baseline", "side": "alma", "request": {"id": "cb79cd59c0b0eeb6", "cmd": "pip_status", "args": {}}, "response": {"id": "cb79cd59c0b0eeb6", "data": {"armed": [], "sessions": []}, "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:29:24.661+08:00", "case": "P0 after MCP wake", "side": "ours", "request": {"id": "d34fc70ba104977a", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "id": "d34fc70ba104977a", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:31:46.374+08:00", "case": "P1-open-text", "side": "ours", "request": {"id": "dd0276c7a1bfc9e8", "cmd": "pip_open", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_TextMirror"}}, "response": {"data": {"opened": true, "session": {"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 64284, "title": "CX17_TextMirror", "window_id": 233332}}, "id": "dd0276c7a1bfc9e8", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:31:46.550+08:00", "case": "P1-open-calculator", "side": "ours", "request": {"id": "ef7ebcc23005baba", "cmd": "pip_open", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_CalculatorMirror"}}, "response": {"data": {"opened": true, "session": {"floater_frame": {"h": 426, "w": 240, "x": 1248, "y": 84}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 57752, "title": "CX17_CalculatorMirror", "window_id": 230248}}, "id": "ef7ebcc23005baba", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:31:51.710+08:00", "case": "P1-first-frames", "side": "ours", "request": {"id": "c3d456a01da9a87f", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 20, "pid": 64284, "title": "CX17_TextMirror", "window_id": 233332}, {"floater_frame": {"h": 426, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 11, "pid": 57752, "title": "CX17_CalculatorMirror", "window_id": 230248}]}, "id": "c3d456a01da9a87f", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:31:59.343+08:00", "case": "P1-open-text", "side": "alma", "request": {"id": "b261407732210cf8", "cmd": "pip_open", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_TextMirror"}}, "response": {"data": {"session": {"floater_frame": {"y": 725, "w": 240, "h": 200, "x": 1248}, "has_first_frame": false, "title": "CX17_TextMirror", "pid": 64284, "window_id": 233332, "last_frame_age_ms": null}, "opened": true}, "id": "b261407732210cf8", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:31:59.583+08:00", "case": "P1-open-calculator", "side": "alma", "request": {"id": "9448d3c101f1ca77", "cmd": "pip_open", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_CalculatorMirror"}}, "response": {"data": {"opened": true, "session": {"pid": 57752, "window_id": 230248, "floater_frame": {"h": 426, "x": 1220, "y": 471, "w": 240}, "has_first_frame": false, "last_frame_age_ms": null, "title": "CX17_CalculatorMirror"}}, "ok": true, "id": "9448d3c101f1ca77"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:11.897+08:00", "case": "P1-first-frames", "side": "alma", "request": {"id": "436bcbc1445af6c0", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"pid": 57752, "window_id": 230248, "floater_frame": {"h": 426, "x": 1220, "y": 471, "w": 240}, "has_first_frame": true, "last_frame_age_ms": 10, "title": "CX17_CalculatorMirror"}, {"pid": 64284, "window_id": 233332, "floater_frame": {"h": 200, "x": 1248, "y": 725, "w": 240}, "has_first_frame": true, "last_frame_age_ms": 21, "title": "CX17_TextMirror"}]}, "ok": true, "id": "436bcbc1445af6c0"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:11.982+08:00", "case": "P1-repeat-open-text", "side": "ours", "request": {"id": "db443fc80289537e", "cmd": "pip_open", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_TextMirror"}}, "response": {"data": {"opened": true, "session": {"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 20, "pid": 64284, "title": "CX17_TextMirror", "window_id": 233332}}, "id": "db443fc80289537e", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:35.145+08:00", "case": "P1-repeat-open-text", "side": "alma", "request": {"id": "bfa24074d9297f8c", "cmd": "pip_open", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_TextMirror"}}, "response": {"data": {"opened": true, "session": {"pid": 64284, "window_id": 233332, "floater_frame": {"h": 200, "x": 1248, "y": 725, "w": 240}, "has_first_frame": true, "last_frame_age_ms": 0, "title": "CX17_TextMirror"}}, "ok": true, "id": "bfa24074d9297f8c"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:55.590+08:00", "case": "P2-arm-text", "side": "ours", "request": {"id": "91eb80461240a7bb", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_ArmA"}}, "response": {"data": {"armed": {"pid": 64284, "title": "CX17_ArmA", "window_id": 233332}}, "id": "91eb80461240a7bb", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:55.672+08:00", "case": "P2-duplicate-arm", "side": "ours", "request": {"id": "4fcc45534c14a87c", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_ArmB"}}, "response": {"data": {"armed": {"pid": 64284, "title": "CX17_ArmB", "window_id": 233332}}, "id": "4fcc45534c14a87c", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:55.748+08:00", "case": "P2-arm-second-app", "side": "ours", "request": {"id": "0abcc530781a5cef", "cmd": "pip_arm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_ArmCalc"}}, "response": {"data": {"armed": {"pid": 57752, "title": "CX17_ArmCalc", "window_id": 230248}}, "id": "0abcc530781a5cef", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:55.843+08:00", "case": "P2-both-armed", "side": "ours", "request": {"id": "7de25b14c29c26b6", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [{"pid": 64284, "title": "CX17_ArmA", "window_id": 233332}, {"pid": 57752, "title": "CX17_ArmCalc", "window_id": 230248}], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 10, "pid": 64284, "title": "CX17_TextMirror", "window_id": 233332}, {"floater_frame": {"h": 426, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 30, "pid": 57752, "title": "CX17_CalculatorMirror", "window_id": 230248}]}, "id": "7de25b14c29c26b6", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:55.921+08:00", "case": "P2-arm-text", "side": "alma", "request": {"id": "c2c29ac04951cd54", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_ArmA"}}, "response": {"ok": true, "id": "c2c29ac04951cd54", "data": {"armed": {"title": "CX17_ArmA", "pid": 64284, "window_id": 233332}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:56.006+08:00", "case": "P2-duplicate-arm", "side": "alma", "request": {"id": "e8215dfcf907f00d", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_ArmB"}}, "response": {"ok": true, "id": "e8215dfcf907f00d", "data": {"armed": {"title": "CX17_ArmB", "pid": 64284, "window_id": 233332}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:56.083+08:00", "case": "P2-arm-second-app", "side": "alma", "request": {"id": "080d9bb4798e3246", "cmd": "pip_arm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_ArmCalc"}}, "response": {"ok": true, "id": "080d9bb4798e3246", "data": {"armed": {"title": "CX17_ArmCalc", "pid": 57752, "window_id": 230248}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:32:56.170+08:00", "case": "P2-both-armed", "side": "alma", "request": {"id": "3f6395683c913e7f", "cmd": "pip_status", "args": {}}, "response": {"ok": true, "id": "3f6395683c913e7f", "data": {"sessions": [{"title": "CX17_CalculatorMirror", "last_frame_age_ms": 16, "floater_frame": {"h": 426, "w": 240, "x": 1220, "y": 471}, "pid": 57752, "window_id": 230248, "has_first_frame": true}, {"title": "CX17_TextMirror", "last_frame_age_ms": 17, "floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 725}, "pid": 64284, "window_id": 233332, "has_first_frame": true}], "armed": [{"title": "CX17_ArmCalc", "pid": 57752, "window_id": 230248}, {"title": "CX17_ArmA", "pid": 64284, "window_id": 233332}]}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:04.737+08:00", "case": "P2-disarm-leaves-session", "side": "ours", "request": {"id": "4660fd4e8876a657", "cmd": "pip_disarm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"disarmed": true, "window_id": 230248}, "id": "4660fd4e8876a657", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:04.813+08:00", "case": "P2-close-leaves-arm", "side": "ours", "request": {"id": "2edd4bf2dbba21bc", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"closed": true, "window_id": 233332}, "id": "2edd4bf2dbba21bc", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:04.888+08:00", "case": "P2-independent-lifecycles", "side": "ours", "request": {"id": "722425474fdbfefd", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [{"pid": 64284, "title": "CX17_ArmA", "window_id": 233332}], "sessions": [{"floater_frame": {"h": 426, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 5, "pid": 57752, "title": "CX17_CalculatorMirror", "window_id": 230248}]}, "id": "722425474fdbfefd", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:04.965+08:00", "case": "P2-disarm-text", "side": "ours", "request": {"id": "81a2c5865c4fe12a", "cmd": "pip_disarm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"disarmed": true, "window_id": 233332}, "id": "81a2c5865c4fe12a", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.046+08:00", "case": "P2-close-calculator", "side": "ours", "request": {"id": "2e64f68be57632e0", "cmd": "pip_close", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"closed": true, "window_id": 230248}, "id": "2e64f68be57632e0", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.234+08:00", "case": "P2-repeat-close", "side": "ours", "request": {"id": "27e9274811c5fbac", "cmd": "pip_close", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"closed": false, "window_id": 230248}, "id": "27e9274811c5fbac", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.311+08:00", "case": "P2-repeat-disarm", "side": "ours", "request": {"id": "66fb15434f1ecaac", "cmd": "pip_disarm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"disarmed": false, "window_id": 230248}, "id": "66fb15434f1ecaac", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.389+08:00", "case": "P2-clean", "side": "ours", "request": {"id": "657b7644dfc21873", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "id": "657b7644dfc21873", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.466+08:00", "case": "P2-disarm-leaves-session", "side": "alma", "request": {"id": "0cc30cf36e1b3307", "cmd": "pip_disarm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"window_id": 230248, "disarmed": true}, "ok": true, "id": "0cc30cf36e1b3307"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.544+08:00", "case": "P2-close-leaves-arm", "side": "alma", "request": {"id": "71e3686bd3ecdc1c", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"closed": true, "window_id": 233332}, "ok": true, "id": "71e3686bd3ecdc1c"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.624+08:00", "case": "P2-independent-lifecycles", "side": "alma", "request": {"id": "8870938e72bcfd3a", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [{"pid": 64284, "window_id": 233332, "title": "CX17_ArmA"}], "sessions": [{"pid": 57752, "window_id": 230248, "floater_frame": {"h": 426, "x": 1220, "y": 471, "w": 240}, "has_first_frame": true, "last_frame_age_ms": 1, "title": "CX17_CalculatorMirror"}]}, "ok": true, "id": "8870938e72bcfd3a"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.704+08:00", "case": "P2-disarm-text", "side": "alma", "request": {"id": "dc081415ec6a4cc7", "cmd": "pip_disarm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"window_id": 233332, "disarmed": true}, "ok": true, "id": "dc081415ec6a4cc7"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.782+08:00", "case": "P2-close-calculator", "side": "alma", "request": {"id": "326ed89b0fb955fe", "cmd": "pip_close", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"closed": true, "window_id": 230248}, "ok": true, "id": "326ed89b0fb955fe"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.874+08:00", "case": "P2-repeat-close", "side": "alma", "request": {"id": "8d4dce7c56e5d1a3", "cmd": "pip_close", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"closed": false, "window_id": 230248}, "ok": true, "id": "8d4dce7c56e5d1a3"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:05.951+08:00", "case": "P2-repeat-disarm", "side": "alma", "request": {"id": "f2e2f85435710fda", "cmd": "pip_disarm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"disarmed": false, "window_id": 230248}, "ok": true, "id": "f2e2f85435710fda"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:06.032+08:00", "case": "P2-clean", "side": "alma", "request": {"id": "a26a468c7fe3cedf", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "ok": true, "id": "a26a468c7fe3cedf"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:15.681+08:00", "case": "P3-arm-before-minimize", "side": "ours", "request": {"id": "6b909b7ec57d3e19", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_OneShot"}}, "response": {"data": {"armed": {"pid": 64284, "title": "CX17_OneShot", "window_id": 233332}}, "id": "6b909b7ec57d3e19", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:15.767+08:00", "case": "P3-arm-before-minimize", "side": "alma", "request": {"id": "ff8b7c2182b707eb", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_OneShot"}}, "response": {"data": {"armed": {"pid": 64284, "window_id": 233332, "title": "CX17_OneShot"}}, "ok": true, "id": "ff8b7c2182b707eb"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:18.540+08:00", "case": "P3-after-first-minimize", "side": "ours", "request": {"id": "b22c2141724db60f", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 83}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 64284, "title": "CX17_OneShot", "window_id": 233332}]}, "id": "b22c2141724db60f", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:18.620+08:00", "case": "P3-after-first-minimize", "side": "alma", "request": {"id": "56f6b4a9bcb3f0c8", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"pid": 64284, "has_first_frame": false, "window_id": 233332, "floater_frame": {"x": 1192, "h": 200, "y": 669, "w": 240}, "last_frame_age_ms": null, "title": "CX17_OneShot"}]}, "ok": true, "id": "56f6b4a9bcb3f0c8"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:27.873+08:00", "case": "P3-minimized-stream-check", "side": "ours", "request": {"id": "a9164c492e6179e9", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 83}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 64284, "title": "CX17_OneShot", "window_id": 233332}]}, "id": "a9164c492e6179e9", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:27.952+08:00", "case": "P3-minimized-stream-check", "side": "alma", "request": {"id": "0642ca4f80c72b54", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"pid": 64284, "has_first_frame": false, "window_id": 233332, "floater_frame": {"x": 1192, "h": 200, "y": 669, "w": 240}, "last_frame_age_ms": null, "title": "CX17_OneShot"}]}, "ok": true, "id": "0642ca4f80c72b54"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:28.029+08:00", "case": "P3-close-first-session", "side": "ours", "request": {"id": "cc9c6d3271461b17", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"closed": true, "window_id": 233332}, "id": "cc9c6d3271461b17", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:28.118+08:00", "case": "P3-close-first-session", "side": "alma", "request": {"id": "3cc6f779daa70a41", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"closed": true, "window_id": 233332}, "ok": true, "id": "3cc6f779daa70a41"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:31.749+08:00", "case": "P3-second-minimize-no-rearm", "side": "ours", "request": {"id": "6cc0c2e4f79526d3", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "id": "6cc0c2e4f79526d3", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:31.839+08:00", "case": "P3-second-minimize-no-rearm", "side": "alma", "request": {"id": "43bc7dce8828baab", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "ok": true, "id": "43bc7dce8828baab"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:43.517+08:00", "case": "P4-open-before-arm", "side": "ours", "request": {"id": "30cba640d477b65a", "cmd": "pip_open", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_CalcExisting"}}, "response": {"data": {"opened": true, "session": {"floater_frame": {"h": 426, "w": 240, "x": 1248, "y": 83}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 57752, "title": "CX17_CalcExisting", "window_id": 230248}}, "id": "30cba640d477b65a", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:43.666+08:00", "case": "P4-arm-existing-session", "side": "ours", "request": {"id": "c85afc716087bee5", "cmd": "pip_arm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_CalcArmed"}}, "response": {"data": {"armed": {"pid": 57752, "title": "CX17_CalcArmed", "window_id": 230248}}, "id": "c85afc716087bee5", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:43.794+08:00", "case": "P4-open-before-arm", "side": "alma", "request": {"id": "0abceb993b05d1f1", "cmd": "pip_open", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_CalcExisting"}}, "response": {"ok": true, "id": "0abceb993b05d1f1", "data": {"opened": true, "session": {"last_frame_age_ms": null, "window_id": 230248, "has_first_frame": false, "title": "CX17_CalcExisting", "floater_frame": {"h": 426, "x": 1164, "y": 415, "w": 240}, "pid": 57752}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:43.966+08:00", "case": "P4-arm-existing-session", "side": "alma", "request": {"id": "9847063dcd11cca2", "cmd": "pip_arm", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248, "title": "CX17_CalcArmed"}}, "response": {"ok": true, "id": "9847063dcd11cca2", "data": {"armed": {"title": "CX17_CalcArmed", "window_id": 230248, "pid": 57752}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:47.489+08:00", "case": "P4-existing-session-consumes-arm", "side": "ours", "request": {"id": "a8c2c1bdadcff8d4", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 426, "w": 240, "x": 1248, "y": 83}, "has_first_frame": true, "last_frame_age_ms": 5, "pid": 57752, "title": "CX17_CalcExisting", "window_id": 230248}]}, "id": "a8c2c1bdadcff8d4", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:33:47.567+08:00", "case": "P4-existing-session-consumes-arm", "side": "alma", "request": {"id": "6b61c3464c0a46af", "cmd": "pip_status", "args": {}}, "response": {"ok": true, "id": "6b61c3464c0a46af", "data": {"sessions": [{"floater_frame": {"h": 426, "x": 1164, "y": 415, "w": 240}, "title": "CX17_CalcExisting", "has_first_frame": true, "window_id": 230248, "pid": 57752, "last_frame_age_ms": 16}], "armed": []}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:34:38.390+08:00", "case": "P4-close-existing-session", "side": "ours", "request": {"id": "edfa2110eca93c94", "cmd": "pip_close", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"data": {"closed": true, "window_id": 230248}, "id": "edfa2110eca93c94", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:34:38.477+08:00", "case": "P4-close-existing-session", "side": "alma", "request": {"id": "5445903b4bb8d7f4", "cmd": "pip_close", "args": {"bundle": "com.apple.calculator", "pid": 57752, "window_id": 230248}}, "response": {"ok": true, "id": "5445903b4bb8d7f4", "data": {"window_id": 230248, "closed": true}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:01.891+08:00", "case": "P5-rearm-after-consumption", "side": "ours", "request": {"id": "59d177f816d759d0", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_RearmRestore"}}, "response": {"data": {"armed": {"pid": 64284, "title": "CX17_RearmRestore", "window_id": 233332}}, "id": "59d177f816d759d0", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:01.983+08:00", "case": "P5-rearm-after-consumption", "side": "alma", "request": {"id": "cf12123f81eb7ecb", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_RearmRestore"}}, "response": {"ok": true, "id": "cf12123f81eb7ecb", "data": {"armed": {"title": "CX17_RearmRestore", "window_id": 233332, "pid": 64284}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:04.577+08:00", "case": "P5-rearmed-minimize", "side": "ours", "request": {"id": "bbe68d28daf7a2c8", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 83}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 64284, "title": "CX17_RearmRestore", "window_id": 233332}]}, "id": "bbe68d28daf7a2c8", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:04.668+08:00", "case": "P5-rearmed-minimize", "side": "alma", "request": {"id": "afe3cd6b195737de", "cmd": "pip_status", "args": {}}, "response": {"ok": true, "id": "afe3cd6b195737de", "data": {"sessions": [{"last_frame_age_ms": null, "window_id": 233332, "has_first_frame": false, "title": "CX17_RearmRestore", "floater_frame": {"h": 200, "x": 1136, "y": 613, "w": 240}, "pid": 64284}], "armed": []}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:05.838+08:00", "case": "P5-stream-after-restore", "side": "ours", "request": {"id": "409de6c0ab3c327a", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 83}, "has_first_frame": true, "last_frame_age_ms": 11, "pid": 64284, "title": "CX17_RearmRestore", "window_id": 233332}]}, "id": "409de6c0ab3c327a", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:05.931+08:00", "case": "P5-stream-after-restore", "side": "alma", "request": {"id": "9dbdf8f9f3574d3a", "cmd": "pip_status", "args": {}}, "response": {"ok": true, "id": "9dbdf8f9f3574d3a", "data": {"sessions": [{"floater_frame": {"h": 200, "x": 1136, "y": 613, "w": 240}, "title": "CX17_RearmRestore", "has_first_frame": true, "window_id": 233332, "last_frame_age_ms": 20, "pid": 64284}], "armed": []}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:16.159+08:00", "case": "P6-arm-before-owned-window-close", "side": "ours", "request": {"id": "705e684ac97a29a7", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_DestroyCleanup"}}, "response": {"data": {"armed": {"pid": 64284, "title": "CX17_DestroyCleanup", "window_id": 233332}}, "id": "705e684ac97a29a7", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:16.251+08:00", "case": "P6-arm-before-owned-window-close", "side": "alma", "request": {"id": "8d76f498de1676e0", "cmd": "pip_arm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332, "title": "CX17_DestroyCleanup"}}, "response": {"ok": true, "id": "8d76f498de1676e0", "data": {"armed": {"title": "CX17_DestroyCleanup", "window_id": 233332, "pid": 64284}}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:28.718+08:00", "case": "P6-source-window-destroyed", "side": "ours", "request": {"id": "430c10e5bdfcbc4a", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [{"pid": 64284, "title": "CX17_DestroyCleanup", "window_id": 233332}], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 83}, "has_first_frame": true, "last_frame_age_ms": 1423, "pid": 64284, "title": "CX17_RearmRestore", "window_id": 233332}]}, "id": "430c10e5bdfcbc4a", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:28.815+08:00", "case": "P6-source-window-destroyed", "side": "alma", "request": {"id": "d989ce9376649021", "cmd": "pip_status", "args": {}}, "response": {"ok": true, "id": "d989ce9376649021", "data": {"armed": [{"window_id": 233332, "title": "CX17_DestroyCleanup", "pid": 64284}], "sessions": []}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:47.234+08:00", "case": "P6-delayed-destroy-status", "side": "ours", "request": {"id": "a255776b971ef141", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [{"pid": 64284, "title": "CX17_DestroyCleanup", "window_id": 233332}], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 83}, "has_first_frame": true, "last_frame_age_ms": 19939, "pid": 64284, "title": "CX17_RearmRestore", "window_id": 233332}]}, "id": "a255776b971ef141", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:35:47.322+08:00", "case": "P6-delayed-destroy-status", "side": "alma", "request": {"id": "a9575b5ab1d69a2e", "cmd": "pip_status", "args": {}}, "response": {"ok": true, "id": "a9575b5ab1d69a2e", "data": {"armed": [{"title": "CX17_DestroyCleanup", "window_id": 233332, "pid": 64284}], "sessions": []}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:01.121+08:00", "case": "P6-clean-old-arm", "side": "ours", "request": {"id": "8d0850509c480a98", "cmd": "pip_disarm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"disarmed": true, "window_id": 233332}, "id": "8d0850509c480a98", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:01.217+08:00", "case": "P6-clean-old-session", "side": "ours", "request": {"id": "bf8adc54f19e636a", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"data": {"closed": false, "window_id": 233332}, "id": "bf8adc54f19e636a", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:01.292+08:00", "case": "P6-clean-old-arm", "side": "alma", "request": {"id": "c5db558e8c34d820", "cmd": "pip_disarm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"ok": true, "id": "c5db558e8c34d820", "data": {"window_id": 233332, "disarmed": true}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:01.365+08:00", "case": "P6-clean-old-session", "side": "alma", "request": {"id": "f77166df90d77c7e", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233332}}, "response": {"ok": true, "id": "f77166df90d77c7e", "data": {"window_id": 233332, "closed": false}}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:02.712+08:00", "case": "P7-explicit-open-no-arm", "side": "ours", "request": {"id": "e2e036d7ad7e590d", "cmd": "pip_open", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233456, "title": "CX17_DestroyProbe"}}, "response": {"data": {"opened": true, "session": {"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": false, "last_frame_age_ms": null, "pid": 64284, "title": "CX17_DestroyProbe", "window_id": 233456}}, "id": "e2e036d7ad7e590d", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:02.869+08:00", "case": "P7-explicit-open-no-arm", "side": "alma", "request": {"id": "efc4c46c8e6ade1b", "cmd": "pip_open", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233456, "title": "CX17_DestroyProbe"}}, "response": {"data": {"opened": true, "session": {"last_frame_age_ms": null, "title": "CX17_DestroyProbe", "has_first_frame": false, "window_id": 233456, "floater_frame": {"x": 1108, "h": 200, "y": 585, "w": 240}, "pid": 64284}}, "ok": true, "id": "efc4c46c8e6ade1b"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:14.365+08:00", "case": "P7-after-source-close", "side": "ours", "request": {"id": "f2eea8799ddfc14c", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 1078, "pid": 64284, "title": "CX17_DestroyProbe", "window_id": 233456}]}, "id": "f2eea8799ddfc14c", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:14.451+08:00", "case": "P7-after-source-close", "side": "alma", "request": {"id": "8c023500dc2b39ae", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "ok": true, "id": "8c023500dc2b39ae"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:38.123+08:00", "case": "P7-delayed-source-close", "side": "ours", "request": {"id": "d8a2e0b449f64f96", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 24837, "pid": 64284, "title": "CX17_DestroyProbe", "window_id": 233456}]}, "id": "d8a2e0b449f64f96", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:38.217+08:00", "case": "P7-delayed-source-close", "side": "alma", "request": {"id": "fcbb1c265dfbe352", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "ok": true, "id": "fcbb1c265dfbe352"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.422+08:00", "case": "P7-before-explicit-cleanup", "side": "ours", "request": {"id": "3e91200fb45765ef", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": [{"floater_frame": {"h": 200, "w": 240, "x": 1248, "y": 84}, "has_first_frame": true, "last_frame_age_ms": 43135, "pid": 64284, "title": "CX17_DestroyProbe", "window_id": 233456}]}, "id": "3e91200fb45765ef", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.523+08:00", "case": "P7-before-explicit-cleanup", "side": "alma", "request": {"id": "1574fa706547aa39", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "ok": true, "id": "1574fa706547aa39"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.606+08:00", "case": "P7-final-disarm", "side": "ours", "request": {"id": "2b9e01c393c175ca", "cmd": "pip_disarm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233456}}, "response": {"data": {"disarmed": false, "window_id": 233456}, "id": "2b9e01c393c175ca", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.685+08:00", "case": "P7-final-close", "side": "ours", "request": {"id": "02bfec8307be94b1", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233456}}, "response": {"data": {"closed": true, "window_id": 233456}, "id": "02bfec8307be94b1", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.800+08:00", "case": "P7-final-empty", "side": "ours", "request": {"id": "3af455e85d72e68d", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "id": "3af455e85d72e68d", "ok": true}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.890+08:00", "case": "P7-final-disarm", "side": "alma", "request": {"id": "8a58004819fd535c", "cmd": "pip_disarm", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233456}}, "response": {"data": {"disarmed": false, "window_id": 233456}, "ok": true, "id": "8a58004819fd535c"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:56.968+08:00", "case": "P7-final-close", "side": "alma", "request": {"id": "be88603f248f166c", "cmd": "pip_close", "args": {"bundle": "com.apple.TextEdit", "pid": 64284, "window_id": 233456}}, "response": {"data": {"closed": false, "window_id": 233456}, "ok": true, "id": "be88603f248f166c"}}`

CX17 socket evidence: `{"time": "2026-10-09T12:36:57.059+08:00", "case": "P7-final-empty", "side": "alma", "request": {"id": "c5f96b83b3c67e95", "cmd": "pip_status", "args": {}}, "response": {"data": {"armed": [], "sessions": []}, "ok": true, "id": "c5f96b83b3c67e95"}}`


### CX17文档核对

83条socket请求/响应记录均可解析（ours42、Alma41；包含1条首次连接被拒记录），五种pip命令两端均有覆盖，随机请求id唯一。核对了最终两端空状态、20项主表、CX17三节bug/观察、文档链接、代码围栏、skill规定章节、示例JSON与Python语法。静态核对通过。skill-creator的quick_validate.py已实际尝试，因当前Python缺少PyYAML（ModuleNotFoundError: yaml）未运行成功；未安装依赖或修改配置，不能宣称该标准校验器通过。


## run_id=r3 — Round-3 回归 + 11项补扫（2026-10-09）

执行13:42:41–13:59:58 +08:00，macOS26.6.2(25G83)，HEAD `7d5e3073a449ed6c4e7acd932501156ca6456002`。任务来源 [R3-TASK.md](R3-TASK.md)，完整矩阵与哨兵见 [R3-VERIFY.md](R3-VERIFY.md)，新发现追加 [BUGS.md](BUGS.md#round-3-回归新发现)。只写这三份报告，没有改源码/配置、构建或提交。

- **先ping**：指定72097929、9bd08bc1两socket于13:43:02均pong成功。任务数字id示例双端同报malformed JSON，改字符串后成功；不是实现独有错误。
- **Phase1 4/4 PASS**：opt/alt/option别名与ctl/win拒绝一致；menu combo Calculator41、TextEdit84、Notes103，两端差集空；PiP历史counter差5次，补齐后n9/10/11同序frame一致且逐窗x/y减28；源窗销毁0.25秒首采样已双端回收session，pip_close均false。
- **Phase2 11项**：P01输入、P02快照、P03选区、P04赋值、P05动作/scroll、P06枚举、P07wakeup、P08socket/ref、P09PiP、P10错误、P11capture/映射。6项FAIL、4项PASS、1项OBS；确认6类差异：physical队列断言崩溃、scroll非正pages（含崩溃）、快照空字段、AX错误文案、armed销毁过度清理、type_text首错顺序。2 major、4 minor。
- **两次恢复**：13:47:34 physical与13:50:41 pages=-1使ours退出；原二进制重启到PID87947、89009，Alma37196未重启；P06/P07首次受断连污染的结果弃作独立结论，重新对照完成。没有为测试修bug。
- **时序裁决**：Unicode零等待误报在两端均出现，不单列实现缺陷；空affix首次读回受迟发Unicode污染，独立纯AX新文稿补验通过。capture即时尺寸差发生在不同2秒缓存龄，稳定等待2.5秒复验一致。wakeup小预算的尝试数随真实初次遍历耗时不同，不以性能差报bug。
- **待归因**：一次Maps windows的真实app_not_found/success差异，后续8对不再出现，保留OBS；哨兵变化未获用户操作确认，不写成确定focus steal。
- **哨兵**：1015条，42组批次前后，其中19组有变化；初始4点cliclick不可用，后续只读CoreGraphics光标+指定System Events查询。连续监控13:44:20–13:59:09，末次独立选区复测另有前后采样。完整记录见证据目录sentinel.jsonl和R3-VERIFY全表。
- **清理**：新建5文稿窗 `234320, 234393, 234560, 234656, 234718` 全关；原TextEdit230637与内容é👩‍💻保留；Calculator230248、Notes230343/145笔记维持原状。两端sessions/armed最终空、ping成功。未创建/删除用户笔记或保存测试文稿到用户目录；原始截图/探针作为证据留在/tmp。
- **证据**：`/tmp/cu-field-r3-20261009-134241`，requests.jsonl 775条（ours410、Alma365），另4条预检；包括原始wire、排序diff、ips、脚本、输出、manifest散列。查看命令：`python3 -c 'import json,pathlib; p=pathlib.Path("/tmp/cu-field-r3-20261009-134241/requests.jsonl"); [print(x) for x in p.read_text().splitlines() if json.loads(x)["case"]=="C-order-0"]'`。

结论边界：R2菜单不存在Return/Tab/F1…F12 fallback样本；未重置Alma counter直接测n0；多屏/多Space/超大树/slider与datefield/完整sky工具层/wakeup中断未覆盖。没有把这些写为PASS。


## run_id=r5 — Round-5 收口（2026-10-09）

主序列执行15:21:13–15:36:51 +08:00；出稿补充D后置检查15:47:15–15:48:17并再次清理，按[R5-TASK.md](R5-TASK.md)先ping、再A→G、最后清理。完整结果与精确证据见[R5-VERIFY.md](R5-VERIFY.md)，三类新差异追加[BUGS.md](BUGS.md#round-5-收口新发现)。只写这三份测试文档，没有改产品代码/配置、构建、重启或提交。

- **环境**：macOS26.6.2(25G83)，HEAD c5ccba7110f9867a478717aabffbec3124699e07；ours PID31242、Alma37196。72097929/9bd08bc1两个socket初始ping成功，最终ping仍成功。两端权限true，ours guard未armed/Alma已armed的现场条件原样保留。
- **A**：扫描运行app和Font/Color面板；TextEdit组合框、Finder滑块和4个segmented radio共42对有效动作完全一致。AXStepper/DateField/Incrementor/DisclosureTriangle/AXTab无样本，未虚报覆盖。
- **B**：TextEdit84、Notes103、Calculator41、Finder118、Preview106、Maps64、Calendar68、Music71、Settings41、Mail125、Ghostty61，两端combo差集空；只命中方向键命名。Chrome连续两次我们ax_not_granted/Alma空树成功，确认BUG-R5-01（minor）。
- **C**：wakeup挂起期间第二连接ping/windows均提前完成；主动断连后即时与延时请求正常。无窗/死pid/0,-1,.001,1000000均对照。无窗响应我们省略window、Alma三字段null，snap与gas各复验2对，BUG-R5-02（minor）。微预算尝试数按耗时OBS保留。
- **D**：Finder98节点中树，snap与gas各8对；depth5→3移除71个，恢复返回71个，空diff后仍空；disable_diff切换形状一致。removed_refs本端排序与跨端逻辑成员单独核对，不把ref分配顺序算bug。出稿时补原生命令snap：等待双端真正空diff后，snap全量98节点，再gas仍空diff。D2及D3准备阶段的AXGroup瞬态已保留，不作为该断言成功证据。
- **E**：Maps/TextEdit各20对windows均成功，app_not_found均0/20；auto无ref两种settle各5对，反转调用次序后仍ours0/10落字、Alma10/10且verified=true，BUG-R5-03（major）。每次都有ANCHOR前置与后置读回，E时段前台哨兵均Paseo。根因未定，保留双daemon/guard现场条件。
- **F**：gas后移动及关闭测试窗，两端都用旧点431,352；只读目标PID鼠标tap确认实际down/up同点。shot_display五种coord_space均相同756×491；事件窗口字段差另记OBS，原文稿内容未变。
- **G**：双窗arm后消费其一、手工close后再最小化不重开，剩余arm保持；0/负尺寸均成功默认240×200，4000最终1072×893。历史计数差15次，ours补15次后完整frame逐字一致。pip_status实测false→true首次采样119.703/125.908ms；全部会话/armed收空。
- **哨兵**：1993条，1851条身份一致的连续monitor有效；初始49条查询错误、7条混合身份monitor明确剔除。有效采样中位间隔0.500024s、最大1.502142s。28次前台转换，2组完成后≤1秒候选，未证明单端焦点窃取。补测另210条原子哨兵（206个monitor），5次转换、1组新候选（Chrome→Electron，双端读取均相邻）。最终原子读取Chrome/52445、1177.6796875,279.4609375。
- **清理**：本轮TextEdit235981/236168/236170、Finder236036/236285/236294全部关闭；修改的自有文稿丢弃未保存。原TextEdit230637的内容/几何保留，Maps235174保留，Preview仍无窗；Font/Color面板恢复隐藏，Finder图标大小恢复24。两个daemon原PID存活；临时监听器停止。
- **证据**：`/tmp/cu-r5`，859条正式请求（ours454/Alma405；主817+补42，含2条主动断连）+2条初始ping，无非预期transport_error。包含raw响应、逐字diff、全部脚本、原始哨兵、候选归因、鼠标事件、截图、manifest与环境散列。测试脚本的拼写/语法/Path错误已修正续跑，未归为产品bug。

收尾并发更新：全部r5正式请求止于15:48:17后，外部于15:49:58重建二进制、15:49:59将ours换为PID61573，并于15:50:22提交`9d5e745`修复上述三项且纳入已写文档。BUGS中的修复复验声明属于该提交；本测试未做这些代码/构建/重启/提交操作，也未将旧基线结果当成新版本复验。详见R5-VERIFY末节与`environment-after-concurrent-update.json`。
