# 快照字段与差分基线

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

AXBridge负责目标解析、window选择与遍历；Serializer负责精确wire；AppStateDiff独立按PID/window保存基线。direct snap只走plain serializer，get_app_state走diff与可选capture。

## 2 输入与默认

native get_app_state：depth6、interactive_only=true、include_screenshot=true、maxWidth1600、auto_launch=true、wakeup1.5、disable_diff=false；stdio通常把宽度改1280。snap wakeup0。SerializedElement固定6字段和可选7字段按schema省略，不把所有缺值变null。

## 3 状态与所有权

window优先requested match→focused→AXWindows第一项；无效requested window可回退。snapshot_id/currentRefs只在本次begin建立；重试共用一代。diff基线按PID/window分组，保存前一全量fingerprint集合，不只存变化项。

## 4 逐分支执行

1. TCC诊断→resolveApp（有效pid优先，可按bundle/namefallback）→enable enhanced UI→beginSnapshot一次
2. AXWindows原序，不擅自按CG z-order重排；缺geometry填0；窗口ID获取失败可能保留0
3. preorder DFS：先role/actions/children，interactive=actions非空或16角色；filter只限制输出；depth0仍处理root再停止
4. 初轮元素>1即populated；否则按150/250/400ms至多重试3次且受预算截短；duration只累计sleep
5. snapToDictDiffed：先转全量；首次或disabled返回full且更新baseline；已有baseline即返回delta，即使0变化仍isDiff=true
6. 指纹固定字段、跳nil、bounds round；removed_refs仅非空输出。截图失败不回滚已更新diff
7. include_screenshot可能unminimize，成功后wakeup0重snapshot；观察并非保证无UI副作用

## 5 输出与错误

字段名用snake_case：role_description、children_count；identifier/parentRoles不外发。原native整数转换某些越界可trap，safe显式validate并映射自身错误。SnapshotResult optional容器规则与element省略独立查wire，不推广。

## 6 清理取消与竞争

diff disable仍刷新baseline，后续diff基于这次全量。direct snap不改diff、不凭快照更新mapping。原多peer能交错store与diff；safe per-target lane是额外设计。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [03_原生快照捕获与守护进程.md](../chapters/03_原生快照捕获与守护进程.md)
- [04_原生输入引用与差分.md](../chapters/04_原生输入引用与差分.md)
- [FINDINGS.md](../analysis/native-snapshot/FINDINGS.md)
- [normalized-state.schema.json](../contracts/normalized-state.schema.json)

对应代码/函数：

- [direct-snap](../code-evidence/native/direct-snap.md)
- [ax-walk](../code-evidence/native/ax-walk.md)
- [diff-state](../code-evidence/native/diff-state.md)

## 8 依赖与实现步骤

CU-07先字段序列化golden→CU-08 DFS/wakeup fakeclock→CU-09纯diff→连接CU-04store。深度、过滤、diff不做一个开关混用。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

首轮/full/disabled/unchanged/remove/window switch/subpixel；depth0 root与postaction diff副作用；AXWindows missing requested fallback；false/empty/nil序列化；read-only宣称不得覆盖unminimize分支。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
