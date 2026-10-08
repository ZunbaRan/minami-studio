# 系统架构与状态流

## 1 四条协议边界

模型选择 computer-use__tool → 宿主Qk/工具选择/压缩 → MCP manager → stdio JSON-RPC server（23工具）→ native NDJSON socket（45个 .164 dispatch命令）→ AX/Input/Capture。

本地CLI/UI → host 127.0.0.1 /api/computer-use/*（30条route registrations）→ host helper singleton → 同一native socket。此路不天然经过stdio的bundle gate或图片包装。

高级客户端 → native HTTP listener /mcp（.153所见14工具）→ 静态Tool目录与daemonCmd映射 → daemon dispatch。OAuth和启动static bearer属于这个原生listener，不是Electron host REST认证。

Appshot/PiP → host helper client或native SCStream消费者，按自己的资源生命周期工作；不是每次模型get_app_state的别名。

每一层都有独立输入schema、默认值、错误包装和timer。禁止把“23、30、45、14”混成同一功能总数，也不能凭同名命令承诺同返回值。

## 2 推荐独立实现分层 设计

- ProtocolKernel：NDJSON Request/Reply/Event编解码、id、限长、连接epoch、错误
- TargetRegistry：app/PID/window/ref绑定和权限诊断；compat两类PID解析独立保留
- AXSnapshotEngine：AXWindows、walk、wakeup、serialization
- ElementStore：identity、descriptor、invalidation、bounded unique recovery
- AppStateDiff：PID/window baseline与固定fingerprint
- CaptureService：SCWindow/display、shareable cache、JPEG与metadata
- MappingStore/VisualIndex：pixel-point映射、OCR触发、视觉引用generation
- InputRouter：AX语义、mouse/keyboard/text后端、FocusGuard、delivery/effect分离
- AdapterSuite：stdio ordinary/sky、host REST、CLI、native HTTP MCP分开实现
- PresentationOwner：Electron stack、frame source leases、activity、ActionCursor/native Lens桥接
- AppshotCoordinator：用户触发capture、image/AX事件、附件与上下文安全
- ModelResultAdapter：压缩、图片资产、结构化错误、取消结果与审计

这是推荐设计，不声称原厂文件恰好如此拆分。21文件草图的职责思想保留在 [审查表](../quarantine/RECONSTRUCTION_REVIEW.md)，原错误控制流不迁入设计。

## 3 必须显式的数据单位和身份

TargetIdentity(pid,bundle,window_id,epoch)；AXRef(eN)；VisualRef(vN,pid,captureGeneration)；SkyIndex(app,index)；ScreenshotPoint(px)；DesktopPoint(point)；AXBounds(point)；VisionRect(normalized)；NativePiPPoint(AppKit)。safe多加generation/epoch属于扩展，兼容输出不悄悄加字段。

原生ref优先于调用方bundle目标的分支必须保留；审批、动作、补图可能各取不同target，这正是需要safe目标交叉校验的原因。单独记录 requested_target、resolved_target、approval_target、capture_target，不能拿一个app字符串覆盖整个操作。

## 4 端到端状态

OBSERVED → VALIDATED → TARGET_RESOLVED → APPROVAL_DECIDED → DISPATCHED → NATIVE_REPLIED/UNKNOWN → RECEIVER_VERIFIED → PRESENTED。

DISPATCHED之后timeout/cancel/断线不是FAILED_WITH_NO_EFFECT；真实结局可能UNKNOWN。补图失败不回滚已发生动作。工具返回ok、MCP调用完成、UI成功、CLI句子、模型摘要不能跳过RECEIVER_VERIFIED。每个mutation唯一op_id，绝不自动重放。

## 5 状态所有权

ElementStore长期counter、currentSnapshotRefs与descriptor；DiffStore前一全量；MappingStore旧截图几何；VisualStore旧OCR框；ShareableContentCache OS窗口枚举；ActionCursor最后动作点与8秒TTL；Presentation tombstone滑动10分钟；pump cache可无TTL。各自刷新条件不同，必须分别测试。

取消以owner释放资源，不扩散成未经证明的全局清理。safe新增generation让late completion不能发布到新owner；compat记录原竞态，不把修复描述成原厂事实。

## 6 最小可用闭环

协议fake → 只读AX → ref/diff → 合成截图坐标 → 受控AX语义动作 → 指针/键盘与旁路焦点见证 → 真实模型结果。PiP、Appshot和原生HTTP MCP可后置；不能先把动画做好就声称后台CU可靠。
