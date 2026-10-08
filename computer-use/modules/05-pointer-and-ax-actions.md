# 语义动作与后台指针输入

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

ActionRouter按explicit ref、visual ref或坐标分流；AX语义动作与CGEvent注入分层。目标由resolved ref或明确PID决定，show_cursor属于反馈层，不是安全投递开关。

## 2 输入与默认

ref click strategy auto/physical/ax，button无效native回left，count按入口限制；native max(1,count)。forceSynth来自环境第一次读取缓存。set_value接受被契约支持的值类型；select_text范围单位UTF-16。

## 3 状态与所有权

ElementStore→AXActionBackend或EventFactory→FocusGuard→PostToPid。event counter、synthetic sentinel、pressed状态与ActionCursor分开。legacy event fields91/92和window-localSPI是待平台验证依赖，不是公开稳定API。

## 4 逐分支执行

1. ref click先resolve与boundscenter、可选showAt；只有!forceSynth && strategy!=physical && left && count<=1才尝试AXPress/AXPick/AXConfirm
2. 找到AX动作但执行失败直接error，不再合成补点；右键/多击即使strategy=ax也可走合成，是compat分支
3. secondary优先AXShowMenu；不支持且有bounds才right-click；执行失败不能重试为另一动作
4. EventFactory以NSEvent生成CGEvent，设button、field7=3、window91/92、global位置、可用时window-local位置、field42 sentinel
5. 后台目标flags额外OR Command位0x100000；click每轮预建down/up后才投递，轮间40ms
6. drag默认12步、至少2，i=1..<n插值，中间创建失败跳过；成功步骤sleep8ms，最终up可失败，原实现未证无条件补up
7. 坐标scroll delta=max(1,pages)*10：up/left正、down/right负；source0、units1、wheel2，与AX逐页scroll分开

## 5 输出与错误

AX错误精确保留permission/stale/unsupported/system failure；派发成功不等于receiver有效。select_text只找(prefix??"")+text+(suffix??"")完整相邻串，prefix缺失不是可忽略；NSAttributedString可取string；not found归internal。

## 6 清理取消与竞争

safe维护按键/鼠标down账本、异常尽力up与per-target串行，均为安全偏离。timeout后不自动再click/drag。未知派发结局报告unknown；不为提高成功率转当前前台。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [04_原生输入引用与差分.md](../chapters/04_原生输入引用与差分.md)
- [native-contract.json](../analysis/native/native-contract.json)
- [FORBIDDEN_TARGETS_CONTRACT.md](../analysis/native-snapshot/FORBIDDEN_TARGETS_CONTRACT.md)

对应代码/函数：

- [scroll-pid](../code-evidence/native/scroll-pid.md)
- [ref-recovery](../code-evidence/native/ref-recovery.md)
- [ax-text-paths](../code-evidence/native/ax-text-paths.md)

- [原始click函数](../code-evidence/native/pointer-click.md#l27197)
- [原始drag函数](../code-evidence/native/pointer-drag.md#l30655)
- [原始setValue函数](../code-evidence/native/ax-set-value.md#l19857)
- [原始selectText函数](../code-evidence/native/ax-select-text.md#l20031)

## 8 依赖与实现步骤

CU-14纯AX action decision表→CU-15 fake event factory字段与序列→CU-16受控receiver投递。私有SPI签名未确认时STOP该backend，可继续无输入算法。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

AX actionavailable但失败不得双执行；右键/多击/forceSynth；ref目标与bundle不一致；drag中间/最终创建失败；down/up配对；旁路前台无变更。AX成功与物理事件日志采用不同effect oracle。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
