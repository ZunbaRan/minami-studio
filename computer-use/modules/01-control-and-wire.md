# 控制面与守护进程

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

所有能力先穿过明确的入口适配器，再进入独立daemon；stdio JSON-RPC、native NDJSON、host REST、native HTTP MCP是四个不同协议面。连接生命周期由TransportOwner负责，AX引用和截图映射由各自store负责，不在socket teardown中偷做清空。

## 2 输入与默认

输入为UTF-8 NDJSON：id/cmd必须String，args是object或null/省略；数值id、坏JSON、缺cmd均为decode失败。AnyCodable先null、Bool、Int、Double、String、数组、字典。raw args的字符串/整型/布尔转换必须分别实现，不用宽松统一转换函数。

## 3 状态与所有权

每connection保存readBuffer/alive/writeLock/subscriptions；daemon保存listenFD/lastActivity/shuttingDown。不同peer并发，同peer同步逐行处理。宿主保存pending[id]与timer、socket、connectPromise、child与事件listeners。native默认idle600秒；host/MCP启动显式900秒，30秒轮询，严格超过才退出。

## 4 逐分支执行

1. socket父目录创建→unlink旧路径→AF_UNIX/SOCK_STREAM→路径UTF-8长度<104→bind sockaddr长度106→chmod0600→listen backlog4
2. recv scratch8192；EINTR重试；累积至LF；空行忽略；EOF残尾不作为完整请求
3. processLine先刷新activity再decode，因此坏JSON也保活；合法请求同步dispatch
4. 成功{id,ok:true,data}；失败{id,ok:false,error:{code,message,hint?}}；malformed id="?"；encode fallback没有id
5. send在peer写锁内循环处理partial write；连接断开不等于已dispatch动作取消
6. 宿主初连失败只spawn一次、每100ms重连约4秒；id是8随机字节hex；普通20秒/capture30秒；timeout删本地pending，不发送native cancel

## 5 输出与错误

错误必须区分decode、helper_unreachable、helper_disconnected、timeout、CUError与untyped internal。精确encode fallback是{"ok":false,"error":{"code":"internal","message":"encode failure"}}加LF。默认不设native累计line上限是兼容事实；safe拟定8MiB上限是设计，不反写为原值。

## 6 清理取消与竞争

peer teardown仅alive=false与Appshot订阅清理；idle退出restoreAllEnhancedUI、close listener、unlink socket、exit，不承诺drain。safe新增connection epoch、防止半行跨重连拼接；shutdown仅删除自己owner的socket和进程。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [03_原生快照捕获与守护进程.md](../chapters/03_原生快照捕获与守护进程.md)
- [WIRE_SCHEMA.md](../analysis/native-snapshot/WIRE_SCHEMA.md)
- [native-envelope.schema.json](../contracts/native-envelope.schema.json)
- [host-contract-report.md](../analysis/host/host-contract-report.md)

对应代码/函数：

- [transport](../code-evidence/stdio/transport.md)
- [helper-client](../code-evidence/host/helper-client.md)
- [direct-snap](../code-evidence/native/direct-snap.md)

## 8 依赖与实现步骤

CU-00证据与profile→CU-01 wire纯编解码→CU-02 fake双peer→CU-03独立daemon ping。先不注册真实输入handler；完成短写、坏行、半行、断线和pending取消观测再接OS。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

请求/响应id一一对应；UTF8跨chunk不坏；同peer顺序与双peer并发分别验；timeout不重放；encode fallback精确；shutdown不清他人文件。多peer真实AX交错仍STOP。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
