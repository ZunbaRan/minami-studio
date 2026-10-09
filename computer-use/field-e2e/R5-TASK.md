# Round-5 收口任务(Codex/Astra 执行)

你是外场测试工程师。延续 field-e2e 方法学:**只记录不改码**;任何差异必须在我们 socket 与真机 socket 发同一请求逐字 diff 后才入 BUGS.md;全程前台/光标哨兵;测试对象全部清理。

- 我们:`/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock`
- 真 Alma:`/Users/lu/Library/Application Support/Alma/computer-use-9bd08bc1.sock`
- 信封 `{"id":"<str>","cmd":"...","args":{...}}` 行分隔 JSON;ref 用本端 snap 重绑
- 先读 `R3-VERIFY.md` 与 `BUGS.md` 已有结论,**不重复已确认项**

## 任务面(按序,每项独立小节记录)

### R5-A 控件族 set_value/press 接受集
在运行中 app 里**主动搜寻**以下 role 的真实元素:`AXSlider`、`AXStepper`、`AXDateField`、`AXIncrementor`、`AXComboBox`、`AXRadioButton`、`AXDisclosureTriangle`、`AXTab`(segmented)。候选宿主:System Settings(若在跑)、Font/Color 面板、VoiceOver Utility、TextEdit 标尺、预览工具栏——自己扫树找,找不到就跳过并在结果里写"无样本"。对每个找到的控件:string/int/float/bool/null 五型 set_value + press/secondary,双端逐字。

### R5-B 菜单 vk fallback 真机样本
遍历**多个** app 的 menu_shortcuts(TextEdit/Notes/Calculator/Finder/预览/地图/字体册/任何在跑的),收集 combo 里出现的**非字符键名**集合(Return/Tab/Space/Backspace/Escape/F1..F12/Home/End/PageUp/PageDown/Delete/Left/Right/Down/Up/vk%02X 形态)。双端 diff 每个 app 的 combo 集合;若真机出现 `vk%02X` 或大写表名而我们不同,记 bug。

### R5-C wakeup 中断与并发
- wakeup(预算中等)挂起期间,从第二连接发 ping/windows —— 双端看是否并发服务
- wakeup 挂起期间主动断开该连接,再发请求 —— 双端看后续请求是否正常
- wakeup 对无窗 app、dead pid、budget 边界(0/-1/0.001/超大)双端对照

### R5-D 中树 diff 语义
Notes 或 Finder(中等树):snap depth 5→3→5 交替,disable_diff 开关交替,验证 removed_refs/elements_are_diff/diff 形状双端一致;空 diff 后再 snap 的响应形状。

### R5-E OBS 归因复现(重要)
1. `windows(bundle:com.apple.Maps,pid:<实时pid>)` 连发 20 次双端,统计 app_not_found 出现率;同时对 TextEdit 20 次。
2. `type_text auto` 无 ref 对后台 TextEdit 测试窗,双端各 5 次,settle_ms 0 与默认各试,记录 typed/verified/落字结果。
3. 全程加密哨兵采样(0.5s),任何前台切换记录精确到秒;若某请求后 1s 内前台变化,单列候选归因。

### R5-F 坐标映射边界
- gas 注册映射后**移动窗口**,click 原 image 坐标 —— 双端看 stale 映射回声与派发点
- shot_display 各 coord_space 值(screen/window/screenshot/空)双端回声
- 窗口关闭后用 stale 映射 click —— 双端响应

### R5-G PiP 组合压力
- 对同 app 两窗各 arm,最小化其一 —— 双端会话/armed 形状
- armed 窗最小化弹 PiP 后再手动 pip_close,再最小化 —— armed 已消费,双端形状
- pip_open 指定 size 超屏(4000×4000)、0×0、负值 —— 双端 frame/错误
- pip_status 在 session first_frame 前后的 has_first_frame 字段翻转时序

## 产出

1. `computer-use/field-e2e/R5-VERIFY.md` — 每项 PASS/FAIL/OBS/无样本 + 证据
2. 新发现追加 `BUGS.md` 末节 `## Round-5 收口新发现`
3. `RUNLOG.md` 追加 run_id=r5 概要

只写文档不改码。开始。
