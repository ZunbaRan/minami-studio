# Browser与Computer Use联合集成所有权

本页使两个独立资料包可以合用，但不要求读取另一ZIP。下面是建议独立实现架构，非对Alma已实现保障的宣称。每个进程只创建一个共享owner，适配器不能自行再创建同类singleton。

| 共享对象 | 唯一owner | CU adapter责任 | Browser adapter责任 | namespace与清理 |
|---|---|---|---|---|
| Electron main生命周期 | ApplicationHost | helper及native消费者注册 | IAB/CDP消费者注册 | before-quit统一按owner释放，禁止各自杀无关child |
| 本地HTTP server | HostHttpServer | /api/computer-use/*及CU frame需求 | /api/iab/*、browser viewer | 一次listen；route注册顺序明确；native /mcp是另一listener |
| Unified PiP stack | PresentationOwner | computer:desktop presentation | browser:<workspace> presentation | /api/pip/*通用；/api/iab/pip/:action独立；user close与program hide分开 |
| Frame leases | FrameSourceRegistry | JPEG pump/capture generation | CDP normal/HD/PiP lease | 释放具体lease；stack-close≠所有浏览器流都停 |
| Settings | SettingsOwner | CU enable、Appshot hotkey | IAB/PiP/browser配置 | schema命名空间分离，单一持久化点，不各自写覆盖 |
| Appshot assets | AssetStore | imagePath/captureId/AX关联 | 如composer共用，仅接附件API | 主动用户capture；不自动发送；不复用浏览器cookie/profile目录 |
| Tool result conversion | ModelResultAdapter | native/MCP delivery+error+图片 | browser结果/截图/错误 | 同一压缩/图片存储入口，保留来源与错误，不双重压缩 |
| 系统输入 | NativeInputOwner | AX/CGEvent/FocusGuard | 不把viewer输入路由到CU默认target | 原生helper与CDP完全分开；没有隐式fallback |

## 两包统一命名与别名

联合工程采用下列canonical名称；本CU资料里的旧设计名仅是同一对象的别名，不允许因此new出第二套实例：

- CompositionRoot = ApplicationHost
- HostApiServer = HostHttpServer
- SharedPipCoordinator = PresentationOwner
- SettingsStore = SettingsOwner
- HostToolRuntime = ModelResultAdapter

FrameSourceRegistry与AssetStore各是一个共享服务，两包通过adapter引用同一实例。旧分析中的Alma minified符号是证据符号，不是要求实现模型采用其名称。Browser viewer/CDP与CU native backend仍是不同子系统，它们共享宿主owner不意味着共享target或输入路由。

输入边界：Browser viewer的交互通道不等于只读PiP点击穿透；CU helper不是CDP。Browser执行上下文、profile、session与CU的PID/window/ref不是可互换身份。选择browser截图不能自动扩展为desktop截图；native HTTP监听不能借host的批准状态声称已认证。

生命周期顺序建议：停止接新请求→阻断新frame demand→标generation retired→释放subscriber/lease→等待可证明的owned任务结束→清独立临时资产→记录未结束的native outcome。没有可观测ACK的系统输入仍unknown，不能只靠abort signal宣称已停。
