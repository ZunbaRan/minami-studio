# 21个重建代码文件的保留思想与隔离决定

这些文件来自用户提供的 .153 reconstruction 包。原作者也说明不是可编译工程。本包不复制它们作主源码，不提供“修好imports即可用”的承诺；只保留职责思想、具体错误与正确替代链接。每一行给出原文件hash/全文件行范围，保证能对回用户原材料。代码差异须按本包原始代码页核实，不能用重建标签自证。

| 原文件 | SHA256 / 行范围 | 保留思想 | 隔离理由 | 正确模块 |
|---|---|---|---|---|
| `reconstructed/electron/alma-cu-cli.ts` | `e56fe0e2b259b5162000369206f6621d3ae06ceda9b55a14cfb19b1bce6bebcb` / 1–59 | CLI command digest | 大部分注释无dispatcher且遗漏launch等，不是可执行CLI | [模块](../modules/07-stdio-mcp-cli.md) |
| `reconstructed/electron/appshot-service.ts` | `f1dbf2ae27771ac1a33ed3a5cd0bf3097f63027cf26c283c7ba40fafb848c4bb` / 1–426 | captureguard/音效/动画/host协调 | OVERLAY_HTML占位、错误selector/dest测量，verified标签过强 | [模块](../modules/10-appshot-context.md) |
| `reconstructed/electron/computer-use-pip.ts` | `cdd9ce2193428dc2e3fe77261a809cdee95868f8c40ab2399e28ce935baa70f3` / 1–71 | activitytracker/present/end分离 | 文档stopAll/cooldown极性错误，须以.164原码为准 | [模块](../modules/09-pip-lens-cursor.md) |
| `reconstructed/electron/computer-use-routes.ts` | `436abc1b1f471993199c085f4177d01cc8de897982be374414f216403ac32871` / 1–166 | REST注册/错误映射/活动middleware | launch注册顺序与文档冲突；缺依赖，不是工程入口 | [模块](../modules/08-host-model-integration.md) |
| `reconstructed/electron/helper-client.ts` | `d498c69d6293650fc317e3512a25831a2e79d7c49198ce35f9dbc8bfde40b7cb` / 1–263 | pending/connection共享promise/evt监听 | locator推断/teardown遗漏，不能冒充逐字完整宿主 | [模块](../modules/08-host-model-integration.md) |
| `reconstructed/electron/pip-frame-sources.ts` | `ed63eaa992965096031aff92e26fa896228ea68e9fbc983d8039a96513b1aca4` / 1–145 | computer/browser frame seam | 误认stackclose为processshutdown、import缺失，capturePage说法未闭合 | [模块](../modules/09-pip-lens-cursor.md) |
| `reconstructed/electron/pip-stack.ts` | `18509531673f46273ea50357d9549d944145fb97751f03e2f735f08b1eba8d84` / 1–473 | unifiedstack/geometry/HTML展示 | 缺.164tombstone、labeltruthy差异、settingsstub/生命周期未接 | [模块](../modules/09-pip-lens-cursor.md) |
| `reconstructed/electron/register-mcp.ts` | `04f31a02ed60a3821700a41d079b86ae7ff2d4a6b1e2638f780bc352f4635579` / 1–101 | 注册入口幂等与custom保护 | 文档误称比较env；缺原.153 chunk，.164需官方源核对 | [模块](../modules/08-host-model-integration.md) |
| `reconstructed/electron/renderer-appshots.ts` | `63d99110d49b3bc9cc8cf19400a8a980743f39a28612f259703bc15305bf3541` / 1–198 | token消费/hiddencontext/附件状态 | requestIdnumber与hoststring不合、settings/submit主体缺失 | [模块](../modules/10-appshot-context.md) |
| `reconstructed/electron/renderer-composer.ts` | `f257830dc94f425322386d1e979603a09da86c9245efae8c8877760f60753ea6` / 1–105 | 发送动画与视觉参数参考 | 缺原renderer逐字核验；仅低优先UI草图，不是CU可靠性证据 | [模块](../modules/10-appshot-context.md) |
| `reconstructed/helper/AX.swift` | `4d844558c10810b5d9b8189affbc79343a4126be1fbbbf45b1656bcf6a9f408b` / 1–871 | AXBridge/ElementStore/Diff结构 | counter每轮reset、unboundedfirstmatch、diff/field/depth/filter错误 | [模块](../modules/02-ax-reference-store.md) |
| `reconstructed/helper/Appshot+VisualIndex.swift` | `f5fa8605fb0bbd5da66352b07b33c6d5674feee636c25f63c0af5a8d05e9007c` / 1–677 | Appshot/OCR/AppUsage函数导航 | 阻塞AX、错误文本字段、nilhotkey、supported/sort/2s预算等错误 | [模块](../modules/10-appshot-context.md) |
| `reconstructed/helper/Capture.swift` | `b0f23ca1e895c00f0cad96238eb2975e671c7a5aa9a73d78039fd338798a878f` / 1–201 | Capture与shareable cache分层 | 1秒TTL、错误fallback/JPEG/cursor值、文件结构不闭合 | [模块](../modules/04-capture-mapping-ocr.md) |
| `reconstructed/helper/Daemon+Actions.swift` | `cf83bc66b5d0b8d85006a5cb08fc024b6f4479b3c40045ed13b440a79f5b5e4a` / 1–759 | action handlers模块分离 | 目标/ref routing、SelectedText、clickgate、vref mapping、select_text语义多处错误 | [模块](../modules/05-pointer-and-ax-actions.md) |
| `reconstructed/helper/Daemon.swift` | `98f7b837191c70bcda7dd06263d255402eab5525497d3eaf6789a19e3f23ce4e` / 1–864 | listener/dispatcher/connection职责 | 把handleQueue写serial+blockingread、合并snap/diff、40case≠45 | [模块](../modules/01-control-and-wire.md) |
| `reconstructed/helper/Focus.swift` | `330bc6da3c35f399740111c5c0fde167a48fc3702caedcda12e23d75d4e51206` / 1–443 | FocusGuard/Watchers/Observers分工 | victim目标误读、perPID resolver/callback stub、disableevent漏分支 | [模块](../modules/06-keyboard-text-focus.md) |
| `reconstructed/helper/Input.swift` | `206f7f5b54b83258b26bc345017b9ac81233938fb992cc7a8cefe8234efb0870` / 1–948 | Codec/TextRouter/EventDispatch分层 | 32UTF16、active谓词、SelectedText fallback、dragstub、focus延迟错误 | [模块](../modules/06-keyboard-text-focus.md) |
| `reconstructed/helper/MCPServer.swift` | `b2de975708a474c0a909fabb7641143617f6444bf72d685f604286c1a5fcc3b6` / 1–1035 | nativeHTTP/OAuth/registry独立模块 | TTL/PID来源/token写回/白名单gate/目录/类型调用错误 | [模块](../modules/native-http-mcp/README.md) |
| `reconstructed/helper/PIP.swift` | `8b617fdaa78e27c6fd9af7d8320ef7f0ded96033431d506a46b342bd531cc952` / 1–628 | native session/armer/Lens职责 | schema/默认尺寸/arm解除/坐标/gates/fog错误，重复成员与stub | [模块](../modules/09-pip-lens-cursor.md) |
| `reconstructed/helper/Support.swift` | `bf46ae8178f185dd46aef50b085c49d8d86f25a878f0a59b3c23d01c583f2ea1` / 1–81 | wire helper/error/value types | 声明/编码依赖不完整，不能当编译基础 | [模块](../modules/01-control-and-wire.md) |
| `reconstructed/helper/main.swift` | `23642ada8c23f9417bd3ea476d2da6cbd107d85bfa15ab3429e5ee1c41490a6c` / 1–120 | 启动CLI与daemon生命周期概念 | args越界、flag/default覆盖不足，非入口等价实现 | [模块](../modules/01-control-and-wire.md) |

## 使用方式

可以借鉴模块职责和函数命名索引；必须重新依照已核契约与原始片段设计控制流。若确需引某段重建源码，应附原行、hash、相关原码、已核范围与未核范围，并标明RECONSTRUCTED / NON_COMPILABLE / NOT_ORIGINAL。此包优先提供原始JS/ASM片段，因此不把未核Swift伪实现混进事实层。

## 样例限制

原probe含真实应用/窗口/用户目录和标识；本包不附原probe全文，也不把其用户内容复制进fixture。历史示例只在 [报告状态](../provenance/REPORTED_PROBES.md) 以合成化描述保留。
