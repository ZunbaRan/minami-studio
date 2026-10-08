# 实现 Agent 启动任务模板

下段是可交给后续编码模型的任务文本，不是本次执行授权。

## 启动提示

你接手一项独立的macOS Computer Use实现。只读取本包，先打开START_HERE、SOURCE_MANIFEST、模块README、IMPLEMENTATION_DAG、INTEGRATION_OWNERSHIP与CONTROLLED_MACOS。当前behavior_profile=UNSELECTED、live_input=false；不要选择用户真实profile、不要读取凭证、不要执行提供的vendor二进制或源码。不要创建看似Alma官方的产品身份。

先交付：①四协议边界图；②本票输入/状态/分支/输出/错误/cleanup；③原始代码链接和版本；④已证/假设/设计/未知表；⑤最小文件列表与依赖；⑥准备运行的纯测试和未来真实测试。缺事实先STOP或设计明确拒绝路径，不能猜完后宣称兼容。

只有用户另外授权实现时才进入代码。优先纯函数+FakeAX/FakeCapture/FakeClock/FakeTransport；每个mutation op_id最多派发一次；timeout/cancel/截图失败后不重放。ref/目标/截图/审批身份分开，不能绕到前台app。每轮只做一模块或一票，提交前按734条中相关cases核对，但不要宣称全部运行。

.153原始反汇编是旧版本证据；.164主契约与当前代码片段独立标识；只有stdioMCP文件已证明两版byte-identical。quarantine的21个重建文件存在明确错误，不可作工程底座；不得先补编译再把它们当原行为。所有代码证据链接中标NOT_EXECUTED、缺函数上下文或推断强度的限制必须保留。

对真实macOS阶段，先确认使用独立fixture app、合成文本、专用临时目录、合法TCC授权和旁路receiver/focus/cursor记录器。不要读实际聊天、笔记、浏览器profile或密码框。系统保护不允许时标unsupported，不能绕过。真实结果只能覆盖对应OS/build/架构/显示布局/权限条件。

提交格式：本票范围；实现文件；证据与契约；测试实际结果；NOT_RUN/INCONCLUSIVE；profile偏离；资源清理与未知结局；下一票或阻塞。资料校验、mock pass、产品effect pass分别列出。
