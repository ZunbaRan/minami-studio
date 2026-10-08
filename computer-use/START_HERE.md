# Alma Computer Use 统一逆向技术资料包

这是一套给实现模型和工程师使用的中文技术文件夹，目标是从已知证据建立可实现、可追溯、可验收的 Computer Use 系统。它覆盖 .164 主契约、.153 原生取证增量、四类协议、AX/输入/捕获/焦点、宿主模型、PiP/Appshot、native HTTP MCP/OAuth 与工程验收。交付的是研究和技术方案，未实现或启动目标产品。

最重要的结论：以修订后的 .164 契约为主线；两版 stdio MCP 原文件字节相同；原生 helper 两版不同，.153 反汇编不得无条件当 .164 源码。另一份材料的21个重建源码文件只用于模块思想和审查，不作为可编译底座或真值。本包纳入已核的局部原始JS和原生指令，避免实现模型只凭 prose 猜分支。

## 默认状态

- behavior_profile：UNSELECTED
- live_input：false；真实应用、用户profile、凭证与账户：未选择
- 产品构建与运行：NOT_RUN；本次未执行提供的代码、Mach-O或真实桌面输入
- 主机器语料：734条DESIGN/NOT_RUN，原733条保留并修正1条，新增零时钟哨兵1条；原39条P0仍NOT_RUN
- 高级HTTP/Intent另有79条Markdown设计用例（AU24/RP22/LC10/IT23），未并入主harness；两类合计813个设计条目，不代表813次运行
- 本包自己的结构/链接/hash检查与产品测试完全分开，见 [验证结果](acceptance/VALIDATION.md)

## 建议阅读顺序

1. [架构和状态总图](engineering/ARCHITECTURE.md)：先弄清四个协议面和进程边界
2. [模块导航](modules/README.md)：每模块按架构→输入→状态→分支→错误→清理→原码→工单→验收顺序走
3. [代码证据索引](provenance/CODE_INDEX.md) 与 [证据等级](provenance/SOURCE_MANIFEST.md)：确认每条事实的版本、hash和原范围
4. [21个重建文件的审查表](quarantine/RECONSTRUCTION_REVIEW.md)：知道可借鉴什么，哪些分支禁止照搬
5. [工程DAG与交付票](engineering/IMPLEMENTATION_DAG.md)、[bootstrap提示](engineering/BOOTSTRAP_AGENT_PROMPT.md)、[联合所有权](engineering/INTEGRATION_OWNERSHIP.md)
6. [受控macOS验收](acceptance/CONTROLLED_MACOS.md) 与 [关键反例](acceptance/NEGATIVE_FIXTURES.md)

## 完整细节在哪里

- [14章完整目录](chapters/README.md)：全部原有技术深度保留，局部文字和oracle已勘误
- [结构化契约与语料目录](contracts/README.md)：schema、命令目录、工具输入、734cases以独立机器JSON保留
- [证据覆盖与剩余STOP](provenance/COVERAGE_AND_STOPS.md)：已证、设计、作者报告、未知分别列示
- [修订日志](CHANGELOG.md)：包括UI.cooldown、REST launch顺序、native HTTP授权细节等

代码页的行号/字符范围指原输入，不等于本页Markdown行号。局部源码不是可运行工程；原始minified变量名保留以便复核。所有必需链接均相对本包，Browser包不作为读取依赖；两包联合落地时遵守唯一owner表。不要执行Markdown中的研究脚本，也不要从历史校验报告推断产品通过。
