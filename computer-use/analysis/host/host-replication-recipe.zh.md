> 来源：用户提供的 .164 研究资料 `analysis/host/host-replication-recipe.zh.md`；原文件 SHA256 `a3ecaf528b2eac2bc865f64541d7e32f08a0da2f91dff91afc8a7a31080f59a0`；全文件 1–126 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Electron 宿主：可直接拆成工程任务的复刻说明

## 先区分两种目标

下面的“兼容行为”来自 0.4.164 的静态调用链；“建议实现”是独立设计，不表示 Alma 已采用。不要把文档中的改进悄悄当成原程序事实。

最小模块拆分：

1. HelperLocator：纯函数，解析原生 helper 文件路径；不启动进程
2. DaemonTransport：Unix socket 连接、JSONL 帧、请求 ID、超时、事件；不决定应用授权
3. ComputerUseService：强类型命令接口；将参数和错误映射到协议
4. ApprovalRepository：每个 bundle 的批准/撤销记录与使用统计
5. ExecutionPolicy：所有调用入口共同使用的授权门；兼容模式和安全模式明确分开
6. McpRuntime：托管 stdio 子进程、工具发现、调用与关闭
7. ToolAdapter：把 MCP 结果转换成模型多模态内容，并保留错误状态
8. ToolImageStore：截图持久化、恢复、配额和清理
9. TurnController：当前生成的取消、操作跟踪和 UI 状态
10. AppshotBridge：原生事件订阅到 preload 回调的窄桥接

不要让 renderer 直接拥有 spawn、任意 native command 或凭据。REST 与 MCP 只是入口适配器，不能各自复制一份授权规则。

## 任务 H1：先写协议与错误对象，再写连接

对外类型（独立设计示例）：

- RequestEnvelope：id 为字符串，cmd 为命令名，args 为对象
- ReplyEnvelope：id，ok；成功携带 data；失败携带 error={code,message,hint?}
- EventEnvelope：evt=true，topic，payload
- PendingRequest：resolve，reject，timer，connectionEpoch，operationId
- ComputerUseError：code,message,hint；保持可用于 UI 与模型的稳定 code

合成测试帧：

{"id":"test-001","cmd":"windows","args":{"bundle":"org.example.Editor"}}
{"id":"test-001","ok":true,"data":{"windows":[]}}
{"id":"test-002","ok":false,"error":{"code":"ref_stale","message":"Synthetic stale reference"}}
{"evt":true,"topic":"appshot.update","payload":{"test":true}}

这些是传输合成样例，windows 的真实 data 字段与 Appshot payload 以原生/MCP 契约章节为准，不要将示例的占位字段视为真实业务 schema。

兼容帧格式：每个 JSON 对象后一个 LF；允许一块读取包含多帧，也允许一个帧被切成任意多块。

建议解析器步骤：收到 bytes → 限制缓冲区最大值 → 追加 → 找 LF → 提取一帧 → JSON.parse → 用已解析的 evt 布尔值分流 → 验证 id/ok/error → 从 pending 找请求 → 清 timer → 删除 pending → settle。不要复制原实现对 `"evt":true` 字符串的格式依赖。断连时清空残帧并增加 epoch。

测试顺序：单帧；每字节拆分；两个帧合并；中文跨 UTF-8 字节；空行；非法 JSON 后合法帧；带空格 evt；未知 ID；重复 reply；超时后迟到 reply；断连留半帧后重连。

## 任务 H2：实现连接状态机

状态为 Idle、Connecting、Ready、Stopping、Failed。维护一个共享 connectPromise，不能每次 call 都 spawn。

兼容启动策略：先连已有 socket，失败再启动 helper；参数 daemon、socket 路径、idle-seconds=900；随后约每100ms重试，4s为总重试窗口。默认请求20s，状态/截图与Appshot捕获30s；显式 shutdown 等2s后清理。

建议实现顺序：

1. locateHelper，确认 macOS、文件存在；仅说明可发现，不报告“权限已授予”
2. 尝试 connectExisting
3. 若失败，持有启动锁并 spawn；保存 pid 和退出监听
4. 在绝对 deadline 前重连；可记录最后错误，不无限重试
5. 连接成功后只注册一套 data/error/close 监听
6. connectPromise 在 finally 清除，下一次失败调用可重试
7. shutdown 把状态设 Stopping；拒绝新请求；尝试协议 shutdown；统一清理 pending、socket、child

建议使用绝对时间预算，把单次 connect 也包进剩余时间；原静态代码的4s循环不是每个 connectOnce 自身的硬超时保证。

验证：两并发 call 只启动一次；已有 helper 不重复启动；二进制缺失；socket不可达；helper立刻退出；helper晚于deadline就绪；关闭时有三个待定请求；只连接到外部已有 helper 时 shutdown 行为明确。

## 任务 H3：把三个授权层画清楚

第一层是“此模型/此项目能否调用该工具”，按 activeTools、project MCP allowlist 判断。第二层是“此目标应用能否被访问”，按 bundle批准账本和本次操作范围判断。第三层是 macOS 的 AX/屏幕录制授权，交由 helper 查询和 OS 实际控制。

原兼容语义：strict setting并非true时，新bundle会被自动批准；strict=true且没有有效批准记录时返回approved=false。撤销只写revokedAt；非strict后续检查可再次自动批准。这并非永久 denylist。

安全建议：canonicalTarget先把 ref/PID/bundle解析成同一bundle；每种入口统一 authorize(target,operation,threadId)。strict模式下网络/解析/账本错误不能当作允许。需要批准时生成待审批对象，不执行native动作；批准回到宿主写账本后重试相同operationId。不要在未来重试中扩大授权目标。

批准表最小字段：bundleId主键、appName、approvedAt可空、revokedAt可空、useCount初始0、lastUsedAt可空。ActionLog独立表，默认不开启；如记录输入文本可能含敏感内容，建议参数脱敏和明确保留期限。

测试矩阵按入口×目标标识×授权状态：MCP/REST/UI；bundle/PID/ref；never-approved/approved/revoked；strict on/off；网络错误；OS AX denied；OS screen denied。每个格子必须有期望结果，不能只测MCP的正常bundle路径。

## 任务 H4：取消必须落到正在执行的操作

原程序可见：模型Stop会停止生成和部分Bash子进程，MCP适配器未向callTool传AbortSignal，helper请求超时仅删pending。因此不要复刻“UI停止=原生停止”的假设。

建议每次执行创建OperationRecord：operationId,turnId,target,status,cancelRequestedAt,cancelAcknowledgedAt,finalObservation。状态 Pending→Authorized→Sent→Running→Succeeded/Failed；取消另有 CancelRequested→Cancelled 或 TooLate→Finalizing。

有cancel协议时，Stop发送operationId并等待确认；没有cancel协议时明确使用 best-effort 状态，禁止新操作，等待当前动作完成或超时，再读取状态。已经完成的点击不可能靠取消回滚。不能因为Promise.race超时就向用户声称native进程已终止。

对于共用daemon，不宜每次Stop杀整个helper，否则可能中断用户Appshot/PiP。应优先细粒度取消；如最终只能kill，必须声明受影响会话并重建订阅。

测试：取消前未发包；发包后排队；键盘事件发到一半；刚收到成功后取消；同时两个thread只有一个取消；断连与取消同刻；超时后的迟到成功；Appshot仍可用。

## 任务 H5：多模态适配和错误不可混淆

兼容实现接收MCP content数组，text→text，image/audio→带mediaType的file，resource→文本或file，resource_link→引用文本。原实现仅对本地异常sentinel标错，未传播MCP isError；安全实现必须修正。

推荐内部ToolResult：ok,error?,content[],structuredData?,sourceTool,operationId。先处理isError，再处理内容；错误也允许带截图，但不能因此变成成功。图片传递前根据真实模型能力决定保留、交给指定视觉模型或返回明确“未视觉检查”。判断依据是内容类型和工具能力，不是工具名里有没有Screenshot。

样例预期：

- MCP {isError:true,content:[text stale-ref]} → ToolResult ok=false,code=ref_stale（若可解析）
- MCP {content:[image,data,MIME]} → 模型file内容，base64从不当普通文本输出
- 空content与未知block → 可诊断结构化fallback；不得默默丢失error
- 同一结果含text+image → 保持顺序和坐标/尺寸说明

测试顺序：text；image；text+image；resource文本；blob；链接；未知类型；isError；无content；非vision模型；损坏base64；巨型截图；重复图像；模型历史重放。

## 任务 H6：截图存储统一为内容寻址

原程序的image_base64顶层字段可以被外置；MCP content[].image不走同一个外置匹配器。推荐在边界统一识别两种形态，提取二进制到ImageAsset；保留MIME、原始像素宽高、逻辑窗口尺寸、缩放、裁剪原点、snapshotId、target和生成时间。

建议ImageAsset主键使用完整SHA256；写临时文件后原子重命名；message保存assetId与metadata，发给模型前恢复成模型支持的多模态格式。下载/renderer用只读资源URL。basename校验是最低要求，再限制到cache root。不要以dataURL前后64字节和长度作为唯一正确性键。

配额需明确：最大单图、单消息、单thread、总cache；LRU清理只删没有被持久消息引用的资产，或保留可读的missing标记。任何清理不能让坐标引用误指向另一张旧图。

验收：两种图片形态统一去重；写入崩溃可恢复；asset缺失有明确状态；恶意路径被拒；MIME一致；清理不会破坏活跃turn；重放同一模型会收到同样图像；更换非视觉模型不注入base64。

## 任务 H7：Appshot事件只通过窄preload接口

兼容接口：getState、setHotkey、captureNow、prewarm；事件starting、fired、failed、context-update；每个订阅返回unsubscribe。

建议host只转发验证过的payload；renderer订阅生命周期与组件卸载绑定；使用captureId/epoch防止旧capture更新覆盖新capture。断连→状态标记失联→清理旧订阅→重连成功后重建monitor。前端不得通过这些接口传任意cmd。

验收：反复mount/unmount无listener泄漏；捕获A较慢，B先完成，不被A覆盖；断连后恢复；切换thread后旧事件不写入新thread；热键失败可展示原始稳定error code。

## 交付边界

实现顺序建议 H1→H2→H3→H5→H6→H4→H7；任何真实鼠标键盘动作测试应放在测试应用/专用桌面，先做dry-run与只读观察。复刻包不需要也不应包含提取的Alma JavaScript或原提示词。证据只用于核对行为，工程代码从以上接口和验收要求重新实现。
