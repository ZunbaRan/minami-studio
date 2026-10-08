# 键盘文本与焦点保护

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

KeyboardCodec只处理解析/布局映射；TextRouter区分ref AX、focused AX、physical、Unicode；FocusGuard保护前台并使用延迟清理lease。三个文本计量单位（Character、Unicode scalar、UTF16）不可统一。

## 2 输入与默认

组合键按+分割省空段、trim whitespaces非newline、modifier不分大小写、末项主键；48 ANSI+56命名别名见完整契约。Unicode cap20 scalars，select_text UTF16，physical布局按完整Swift Character匹配。

## 3 状态与所有权

焦点保护保存原前台PID；VictimObserver观察目标PID，PreserveFrontmostWatcher观察保存PID。per-PID listenOnly tap与global preventer作用不同。target AXFocusedWindow存在且app active才构成hasKeyWindow。

## 4 逐分支执行

1. ref type先尝试AXFocused；replace=true直接AXValue；replace=false若SelectedText settable则写，写失败直接抛错；不可写/查询失败才AXValue old+text
2. focused AX helper不同：SelectedText setter成功即true；失败还尝试AXValue append；成功不做内部读回postcondition
3. 无ref auto先focused helper，true直接返回；layout翻译失败才Unicode，成功才physical，不靠语言启发式
4. Unicode先收集scalar，每批最多20再编码UTF16；不得切32 UTF16 units，避免断开代理对
5. press_key active/key-window可物理；否则尝试支持的菜单快捷键AXPress，无匹配可delivered=false；该枚举不是effect ACK
6. FocusGuard正常和异常都安排+5s尾期清理；即时修复只在preservingOther且当前front仍是保存PID时作用于保存PID
7. daemon TypeVerification只判value变化/结果状态，并非逐字证明文本已按要求插入

## 5 输出与错误

key parser invalid_arg、布局不支持、event构造错误、suppressed/unverified分别保留。菜单禁用、Secure Input、tap失败、TCC不允许时不能发明系统fallback。文本setter success不意味着字符内容校验通过。

## 6 清理取消与竞争

延迟清理移disallowed、结束preventer/watcher/victim，不能动作返回即全部拆掉。全局guard状态并发可干扰，safe用有owner的lease。禁止以剪贴板机制替换未证路径而称兼容。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [04_原生输入引用与差分.md](../chapters/04_原生输入引用与差分.md)
- [keycode-contract.json](../analysis/native/keycode-contract.json)
- [native-test-plan.json](../analysis/native/native-test-plan.json)

对应代码/函数：

- [ax-text-paths](../code-evidence/native/ax-text-paths.md)
- [unicode-scalar](../code-evidence/native/unicode-scalar.md)
- [auto-input-routing](../code-evidence/native/auto-input-routing.md)
- [focus-guard](../code-evidence/native/focus-guard.md)

## 8 依赖与实现步骤

CU-17 parser与标量/UTF16纯测试→CU-18 fake路由→CU-19受控菜单与文本receiver→CU-20持续前台输入旁路见证。须记录完整字符串而非仅valueChanged。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

31BMP+emoji、20/21scalars、组合字符/CJK、SelectedText settable但setter失败两路线差异、inactive仍有focusedwindow、5s尾期、动作异常、tap禁用。没有事件级焦点日志不能声称零抢焦点。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
