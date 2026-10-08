# PiP镜像与三种光标

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

Electron unified stack是只读观看层；computer JPEG pump和browser CDP lease是两个frame source；native PIPSession是独立SCStream组件；desktop Lens、ActionCursor与hardware cursor是三个状态。

## 2 输入与默认

Presentation有id/kind/label/thread/workspace/display/target/created/updated。computer共享computer:desktop；browser按workspace。自动present与手动present必须有不同意图；源截图不自动重新present已关闭面板。

## 3 状态与所有权

items/activeId/fittedId/completing/tombstone；computer pump timer/busy/cache/file/initialDisplay；activity timestamp初值0是never-active sentinel、90s结束timer；native sessions按windowID、armer另表。

## 4 逐分支执行

1. tombstone key=(id,thread或空)，只对absent item的automatic upsert生效；age<=600000刷新并抑制，严格>才删除；manual清该id全部thread tombstone
2. 多item用户close记tombstone并420ms retire；program hide/invalidate不记。原upsert清completing但不取消旧retire timer
3. activity先记timestamp再查enabled；lastActivity=0→age=Infinity；333ms pump tick中age<1200跳过，安静后可抓
4. busy时该tick返回；只有elapsed严格>4000ms才清flag，不cancel旧任务，也不在清flag的同tick开始新capture；window shot max1024失败可display fallback quality0.5；旧cache无ageTTL
5. DOM每次response后220ms再poll；top-center contain，oy=0，无y翻转；22pxring，不转发点击
6. ActionCursor showAt先记录，再看Lens enabled；8秒有效、rect包含与正尺寸才normalized；Lens hide不保证clear ActionCursor
7. native PiP SCStream hardware cursor=true/audio=false/30Hz请求/BGRA/queue3；cursor双轴居中+(1-v)y翻转，不能照搬DOM

## 5 输出与错误

默认Electron380×250/min220×150与native sourceW/3 clamp240…960不同。native status包含window_id/pid/title/has_first_frame/last_frame_age_ms/floater_frame，不接受重建size/streaming/frames替代。最小化通知回调中，已有session或自动open成功才disarm；自动open失败保留armed。pip_arm命令成功不是立即disarm；close与disarm分开。

## 6 清理取消与竞争

stack-close订阅负责停computer pumps，不是通用process shutdown hook。stop不cancel在途capture，可能重建文件；safe必须generation隔离。Browser lease与normal/HDsubscriber分别释放，由统一owner协调，不重复实例。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [06_镜像光标与Appshot.md](../chapters/06_镜像光标与Appshot.md)
- [behavioral-contract.md](../analysis/mirror-ui/behavioral-contract.md)
- [native-cursor-contract.md](../analysis/mirror-ui/native-cursor-contract.md)
- [PIP_EXTRA_CONTRACTS.md](../analysis/native-snapshot/PIP_EXTRA_CONTRACTS.md)

对应代码/函数：

- [pip-upsert-tombstone-policy](../code-evidence/host/pip-upsert-tombstone-policy.md)
- [activity-age-and-refresh](../code-evidence/host/activity-age-and-refresh.md)
- [pipFrameSources-BwOu2Plt.js](../code-evidence/host/pipFrameSources-BwOu2Plt.js.md)
- [computerUsePip-BTut449V.js](../code-evidence/host/computerUsePip-BTut449V.js.md)
- [action-cursor](../code-evidence/native/action-cursor.md)
- [pip-status](../code-evidence/native/pip-status.md)
- [pip-arm-minimize](../code-evidence/native/pip-arm-minimize.md)

## 8 依赖与实现步骤

CU-28纯registry/fakeclock→CU-29合成frame源与lease→CU-30授权真实capture→CU-31 native stream可选模块。source切换与teardown先于视觉polish。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

10000epoch与zero sentinel分开；同/异thread滑动10分钟；420ms旧timer；4s晚完成；90send；display切换保留初始ID；浏览器subscriber仍有owner；三种cursor独立记录。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
