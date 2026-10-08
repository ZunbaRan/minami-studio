# stdio MCP与CLI适配

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

stdio MCP应用层注册23工具：11普通业务+2权限+10sky；CLI23 canonical项含help；host REST30 registrations；native dispatcher45命令；native HTTP另有14目录。工具同名不证明schema、默认、审批、返回图片同义。

## 2 输入与默认

普通工具采用Zod schema、native参数独立归一化。普通click的ref分支只转ref，丢bundle/PID；show_cursor通常handler固定而非公开schema字段。sky app+integer index用独立缓存，state只读raw.elements。

## 3 状态与所有权

stdio transport拥有自己的socket/pending；SkyIndex按app carryOver旧ref，未据removed_refs全面清除；PlaybookOnce只用于sky状态。普通get_app_state每次附playbook。gate只取args.bundle，无bundle/服务异常某些路径fail-open。

## 4 逐分支执行

1. registerTool校验输入→handler检查语义必需字段→gated（仅特定工具）→native command→结果包装
2. ordinary state max1280/30s；sky state省timeout走20s；postaction state depth0, interactive=true, includeScreenshot=true, max1280/30s
3. launch_app只JSON text，不自动补图；press_key有bundle/PID时可能补图
4. respond无bundle/PID不补图；图读取失败追加warning，不把已经发生动作改isError/重发
5. 普通state可读取screenshot.path生成image block；sky只取data_url/url为单JSON text，path-only没有图
6. sky index范围检查不保证live ref有效，OCR visual_regions不自动变整数索引
7. CLI命令别名/位置参数/--json/exit code按各命令契约，不假定统一raw输出

## 5 输出与错误

包装摘要可能写成功而native delivered=false；MCP isError不等于host最终model error。普通MCP vref+bundle仍可能因ref分支丢目标而native invalid_arg，属于跨层契约，safe扩展需另schema。

## 6 清理取消与竞争

timeout/cancel不给动作重放许可；stdio SDK cancellation不自动贯穿native。MCP进程退出与host停止生成分开；脚本原文仅局部应用层，不重新打包SDK或prompt全文。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [02_协议包装与CLI.md](../chapters/02_协议包装与CLI.md)
- [10_附录MCP全契约.md](../chapters/10_附录MCP全契约.md)
- [11_附录CLI全契约.md](../chapters/11_附录CLI全契约.md)
- [protocol-catalog.json](../analysis/mcp/protocol-catalog.json)
- [cli-command-catalog.json](../analysis/mcp/cli-command-catalog.json)

对应代码/函数：

- [approval](../code-evidence/stdio/approval.md)
- [screenshot](../code-evidence/stdio/screenshot.md)
- [tool.get_app_state](../code-evidence/stdio/tool.get_app_state.md)
- [tool.click](../code-evidence/stdio/tool.click.md)
- [tool.sky_get_app_state](../code-evidence/stdio/tool.sky_get_app_state.md)
- [tool.press_key](../code-evidence/stdio/tool.press_key.md)

- [原始CLI的HTTP请求](../code-evidence/host/cli-http.md#l13)
- [原始CLI Computer Use dispatcher](../code-evidence/host/cli-computer-use.md#l8297)

## 8 依赖与实现步骤

CU-21用fake daemon逐23工具做schema/payload/output测试→CU-22 CLI fakeHTTP→CU-23 postaction副作用。禁止先写normalizeEverything再套所有入口。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

453 schema permutations全部DESIGN；ref-only/window-only不补图；sky path-only无图；普通playbook每次/sky一次；gate fail-open与safe fail-closed分开；23工具计数逐registerTool可复查。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
