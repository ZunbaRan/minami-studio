# AX引用身份与恢复

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

ElementStore是整个进程的引用身份层；snapshot输出扁平ref列表，动作解析同一store。ref自身带目标PID，调用方的截图bundle不能改写ref归属。descriptor用于失效后的有界唯一恢复，不是坐标/标题模糊点选。

## 2 输入与默认

Entry保存AX element、pid、snapshot ID、invalidated、descriptor；descriptor包含role/subrole/title/identifier/roleDescription与受限parentRoles；不含value/description。bounds不作为descriptor签名。输入ref必须来自已观察状态，safe可另加storeEpoch/generation，但原wire没有。

## 3 状态与所有权

counter跨快照单调；currentSnapshotRefs只记录本代已分配的ref；table和observer独立。beginSnapshot清当前代集合并检查旧条目，不清counter。clear才可重置counter并移除observer，旧e1可能撞上新e1是兼容边界。

## 4 逐分支执行

1. register先找同PID且CFEqual的旧元素；当前snapshot已经使用的ref不能再次复用
2. 未找到才counter+=1产生eN；保存descriptor/当前generation；不要每轮从e1重排
3. AX销毁通知将entry标记invalidated，不简单立即删干净；resolve区分缺ref、stale与AX失败
4. 必要时按descriptor搜索：最多200 visited、最大12层、祖先只比较最近3个；发现第二候选即失败
5. 最终candidateCount必须恰好1才绑定；零或多个都不得选第一个
6. snapshot过滤不阻断子树；本代重试不重新beginSnapshot，故同代ref分配行为要纳入fixture

## 5 输出与错误

保留element_not_found/ref_stale/action_unsupported/ax_failure等边界，不一律internal或unsupported。eN、vN、sky整数index是三种命名空间；vN按PID+截图映射解析，不能进AX store。

## 6 清理取消与竞争

observer与store寿命成对；native clear移observer runloop source，未证明在每次进程退出/PID复用自动清理所有引用。safe按daemon epoch及目标generation拒绝混代，不静默绑定到前台app。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [04_原生输入引用与差分.md](../chapters/04_原生输入引用与差分.md)
- [FINDINGS.md](../analysis/native/FINDINGS.md)
- [serialized-element.schema.json](../contracts/serialized-element.schema.json)

对应代码/函数：

- [ref-identity](../code-evidence/native/ref-identity.md)
- [ref-recovery](../code-evidence/native/ref-recovery.md)
- [ax-walk](../code-evidence/native/ax-walk.md)

## 8 依赖与实现步骤

CU-04先以FakeAXHandle测试CFEqual与生命周期→CU-05 descriptor纯恢复→CU-06真实AX只读接线。禁止直接拷贝AX.swift的counter reset/unbounded DFS。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

跨app连续snapshot、同代重复元素、销毁后唯一/双候选/零候选、200/201节点与12/13层边界、最近3祖先对比、store clear epoch。任何模糊多候选允许投递即失败。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
