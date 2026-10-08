# 宿主HTTP与模型结果管线

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

模型调用通过Qk→MCP manager→stdio；CLI/UI通过127.0.0.1 REST→helper singleton。两条链共享helper但不共享所有应用审批。ToolSelection、project限制、hook、ledger、TCC是五种不同控制面。

## 2 输入与默认

HTTP body默认{}；replace/show_cursor默认true，scroll pages1，launch activates仅严格true。registry key computer-use，打包Electron-as-node；custom入口保留。本包不读取或修改真实mcp配置。

## 3 状态与所有权

MCP manager connect60s、listTools15s、callTool600s；host watchdog常规300s、长任务14400s、显式正timeout+15s封顶1800s；helper20/30s。各timer作用层不同，不能统一timeout含义。

## 4 逐分支执行

1. 自动注册只说明工具入口，不授予TCC；每轮工具选择/项目筛选可能移除可见工具
2. ledger strict设置非严格true时可自动批准；直接REST已检查handler未经过该ledger；本地监听不是安全证明
3. REST已知CUError按400名单/其余500保留code/message/hint；untyped保留异常message或fallback
4. 成功launch_app REST handler在activity middleware之前结束；名单含launch不证明实际执行middleware
5. toModelOutput把content转text/file；resolved isError:true仍可能走普通成功转换，安全实现需显式保留错误
6. 顶层image_base64 externalize与MCP content image是两条持久化路径；basename rehydrate防路径越界不等于所有图片去重
7. 普通MCP模型输出compact目标2600、string1000/text600等预算，图片保护可能超目标；落盘全量不代表模型见全量

## 5 输出与错误

logs可包含args/text，safe默认maxTextLogValueChars0；例外不意味着无限history。停止生成只改变模型/UI并可能结束Bash，不足以证明MCP/helper事件停止。来源AX/网页文本必须是数据，不能升为指令。

## 6 清理取消与竞争

owner唯一管理HTTP注册、helper client、MCP registration、asset cache与shutdown。safe维持op_id→dispatch→native outcome→model presentation审计；外部取消后的已派发结局unknown，禁止自动重试。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [05_宿主工具与模型接入.md](../chapters/05_宿主工具与模型接入.md)
- [14_附录宿主HTTP契约.md](../chapters/14_附录宿主HTTP契约.md)
- [host-http-routes.json](../analysis/host/host-http-routes.json)
- [host-replication-recipe.zh.md](../analysis/host/host-replication-recipe.zh.md)

对应代码/函数：

- [helper-client](../code-evidence/host/helper-client.md)
- [computer-use-rest](../code-evidence/host/computer-use-rest.md)
- [model-mcp-adapter](../code-evidence/host/model-mcp-adapter.md)
- [image-rehydration](../code-evidence/host/image-rehydration.md)

- [原始MCP注册叶模块](../code-evidence/host/mcp-registration.md#source)

## 8 依赖与实现步骤

CU-24 route mock→CU-25 schema/action logs与approval隔离→CU-26 model conversion假provider→CU-27停止语义日志。不得先接真实模型再用自然语言观察猜adapter行为。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

各HTTP error分支、launch注册顺序、isError保留/丢失、视觉/非视觉provider、缺图/坏图、watchdog与迟到reply、MCP content是否被外置、长AX压缩与检索。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
