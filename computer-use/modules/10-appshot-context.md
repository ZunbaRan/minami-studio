# Appshot图像与异步上下文

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

Appshot由用户显式触发，允许打开聚焦宿主composer；不同于被动PiP。native image-first/AX-later，host动画与renderer附件再分层；capture、动画、附件、发送是四个不同完成事件。

## 2 输入与默认

monitor_start安装固定monitor/update订阅；hotkey可null；supported在native是AXIsProcessTrusted，host是darwin&&helper available。请求id为string，imagePath是原更新关联键；safe可改captureId但另标扩展。

## 3 状态与所有权

全局hotkey/BareModifierMonitor与每peer subscriptions分开；host currentHotkey/unsubscribe/capturingNow/rearmScheduled/error；renderer currentRequest/phase/pending/token/hiddenContexts。isActive不是tap健康证明。

## 4 逐分支执行

1. start排CFRunLoopPerformBlock后立即true，不保证tap已创建；flagsChanged event12才处理，枚举0/1/2代表modifier选择
2. native capture不prompt AX；有权限才启动后台AX；普通CaptureResult先返回empty axText，另后台最多等3秒只发一次update，timeout不cancel原worker
3. AX文本：非空window title以# title+空行；每element role/title；value非空且不等title则加value并跳description，否则description；用 · 与LF，不含refs/bounds
4. native down播合成快门、manual不走音效；capturingNow防重入→starting→frontmost resolve→capture→可选1100ms动画→show/focus宿主
5. composer测量最多5次/80ms，目标56pxthumbnail；尝试动画则715ms后fired，尝试不证明已显示
6. renderer消费token一次，读图/upload失败fallback dataURL→attach JPEG/focus→hiddenContext；没有auto-send
7. 原context update早于hiddenContext创建会丢；已有非空不覆盖；AX最多4000chars并带来源标签，必须当不可信数据

## 5 输出与错误

frontmost_lookup_failed/no_target/capture_failed/monitor_refused/ax_not_granted/daemon_unreachable分别定位。nil hotkey不是unknown错误。快门配方44100Hz/12348samples/五频率与WAV生成属UX，不能替代capture成功状态。

## 6 清理取消与竞争

stop monitor只删monitor订阅，update可留；connection teardown清其订阅。断连仍有hotkey时1500ms重arm一次。safe缓冲early update、按captureId限寿命、observer token对称回收；原吞错/丢更新不能写成可靠交付保证。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [06_镜像光标与Appshot.md](../chapters/06_镜像光标与Appshot.md)
- [APPSHOT_EXTRA_CONTRACTS.md](../analysis/native-snapshot/APPSHOT_EXTRA_CONTRACTS.md)
- [behavioral-contract.md](../analysis/mirror-ui/behavioral-contract.md)

对应代码/函数：

- [appshot-async](../code-evidence/native/appshot-async.md)
- [appshot-text](../code-evidence/native/appshot-text.md)
- [appshot-monitor](../code-evidence/native/appshot-monitor.md)
- [appshot-shutter](../code-evidence/host/appshot-shutter.md)
- [appshot-host-state](../code-evidence/host/appshot-host-state.md)
- [appshot-destination](../code-evidence/host/appshot-destination.md)

## 8 依赖与实现步骤

CU-32 native监视fakeRunLoop→CU-33 image/AX事件偏序→CU-34 host guard与动画stub→CU-35 renderer附件/文本边界→受控UX回归。不要从placeholder OVERLAY_HTML开始修编译。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

AX晚/早/超时/no subscription；nilhotkey/starttrue但tapfail；多peer共享；重复down；动画失败；图片upload失败；删除附件清context；恶意AX delimiters不执行；capture不自动发送。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
