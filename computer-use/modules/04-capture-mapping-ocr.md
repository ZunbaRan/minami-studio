# 截图坐标映射与视觉引用

状态：研究规格与后续实现计划；behavior_profile=UNSELECTED；live_input=false；本次产品测试 NOT_RUN。

## 1 架构与唯一职责

CaptureService封装ScreenCaptureKit与可选fast capture；ShareableContentCache单独actor；MappingStore按PID保存point→pixel关系；VisualIndex把Vision结果变成内部vN。三种cache独立失效，不能假设一次snapshot全刷新。

## 2 输入与默认

window shot要求out路径，默认宽度依入口；window JPEG0.85；display可经pump传quality0.5/max1024；native get_app_state max1600。screen point、AX point、图像pixel、Visionnormalized和AppKit坐标必须用独立类型。

## 3 状态与所有权

ShareableContentCache：content/fetchedAt/inFlight/lastSuccess；display TTL30s、window TTL2s，严格age<maxAge才fresh；window miss使cache invalid后再查一次。MappingStore无已证TTL，visualRefs新OCR非空才替换，二者可各自陈旧。

## 4 逐分支执行

1. captureWindow查SCWindow，缺失internal；macOS<14该路径抛升级错误，无已证SCStream/CG fallback
2. filter=desktopIndependentWindow；scale=NSScreen.main backingScaleFactor或2，不一定目标screen；计算像素截断并按maxWidth缩放
3. window cursor=false/audio=false；display cursor=true；写JPEG后返实际CGImage尺寸
4. 仅成功截图且AX bounds存在发布mapping[pid]：x=originX+imageX*pointW/pixelW，y同理，无clamp/expiry
5. get_app_state成功截图且原始AX count≤1才Vision；不是diff count；最多80结果，无公开ocr工具
6. Vision bbox转左上图像：x=xW，y=(1-y-h)H，w=wW，h=hH；v编号每次非空索引从v1重建
7. v ref点击先按明确PID/bundle取bbox中心，再用当前mapping转point；不能把bbox当桌面点

## 5 输出与错误

capture失败保留AX成功并附screenshot_error；旧map不清。load/Vision失败返回空regions且旧v表可能保留。recognitionLevel原始raw1已证，枚举名称以目标SDK核对，不能把另一重建的accurate当oracle。

## 6 清理取消与竞争

cache invalidate不取消inFlight、不清lastSuccess；joiner失败错误身份可能不同。safe使用captureId/windowId/epoch、独立路径及过期拒绝；display fallback必须明确授权范围。原window捕获无fallback与Electron pump window→display fallback是不同层。

## 7 完整契约与代码证据

先读完整契约，再读原始代码页。下列 .153 原生反汇编只证明旧样本的对应分支；.164 结论来自明确标记的 .164 静态契约，不能凭旧汇编替代版本核验。原始JS页按本身SHA/范围使用；任何研究伪代码都不是原厂Swift。

- [03_原生快照捕获与守护进程.md](../chapters/03_原生快照捕获与守护进程.md)
- [PARITY_SURFACE.md](../analysis/native-snapshot/PARITY_SURFACE.md)
- [WIRE_SCHEMA.md](../analysis/native-snapshot/WIRE_SCHEMA.md)

对应代码/函数：

- [capture-cache](../code-evidence/native/capture-cache.md)
- [visual-index](../code-evidence/native/visual-index.md)
- [pipFrameSources-BwOu2Plt.js](../code-evidence/host/pipFrameSources-BwOu2Plt.js.md)

## 8 依赖与实现步骤

CU-10纯坐标→CU-11假捕获cache→CU-12授权fixture window/display→CU-13 Vision门槛。先证明图像generation与四角marker，不以返回尺寸代替实际图像解码。

每步先写独立纯测试/假backend，再接真实OS。输入校验、目标选择、投递、接收方effect、模型可见输出分开测。当前只规定未来工单，不创建应用或执行提供的代码。

## 9 验收与停止条件

1x/2x混合DPI、负坐标screen、窗口移动、失败保留旧map、空OCR旧v、PID重用、capture<14错误、display硬件cursor。普通MCP vref目标丢失必须预期invalid_arg而非假成功。

验收引用 [修订语料](../analysis/conformance/contract-vectors.json) 与 [受控macOS运行规则](../acceptance/CONTROLLED_MACOS.md)。运行状态未填或缺receiver/focus/cursor证据时必须NOT_RUN或INCONCLUSIVE。证据冲突、未知ABI/坐标单位、真实profile/权限未选、需要私密桌面数据时停止依赖步骤；可继续无副作用纯测试设计。

## 10 可直接给实现 Agent 的模块任务

阅读本模块及其第7节所有相关契约；只实现本模块被明确选择的工单，不生成全项目。先输出输入/状态/分支/错误/cleanup对照，逐条标注 .164事实、.153佐证、独立安全设计、未知。引用代码文件与本页链接，不以 reconstructed 标签作为证据。behavior_profile仍UNSELECTED时只写计划，不启动输入或真实账户操作。获准开发后，先mock/fake clock/replay-free fixture，再申请受控macOS验证；不得复制vendor身份或默认真实profile。提交时附改动文件、requirement/case IDs、实际运行命令与输出、未运行项、偏离、STOP和下一步。超时不得自动重放mutation；返回成功不代替接收效果。与其他模块共享对象时遵守 [联合所有权](../engineering/INTEGRATION_OWNERSHIP.md)。
