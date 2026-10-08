# 原生 HTTP MCP、OAuth 与 Intent：校准后的高级模块

默认选择状态：**UNSELECTED**。本模块为来源驱动的设计/证据材料，不自动启动产品实现。

## 结论与版本边界

本模块把 daemon 内嵌 HTTP MCP 作为独立协议面补齐，不能用 stdio MCP 的工具表替代。`.153` 原始 native 目录是 **14 个工具**；JavaScript stdio 目录是另一个 **23 个工具**的适配器。两者共用部分 daemon 能力，不共用名称、schema、认证方式、返回包装或生命周期。

本次工作是**只读静态研究与独立实施契约整理**。没有启动 Alma/helper，没有发出桌面输入，没有兑换真实 OAuth code/token，没有运行上游重建工程。只附有界原始反汇编与少量协议常量字节；没有二进制、完整 SDK、原产品 prompts 或私人探测记录。

证据标签必须随下游引用保留：

| 标签 | 含义 | 允许的结论 |
|---|---|---|
| P153 | 本轮读取 `.153` 原始 arm64 反汇编及必要静态数据 | 对给定版本、函数、分支的直接静态结论 |
| C164 | 既有 `.164` 专项契约中有具体 VA 的静态研究 | 仅该已闭合范围；不代表本轮动态复测 |
| R153 | 作者提供的 `.153` live-probes 摘要 | 历史作者报告；只做脱敏转述，不能视为 byte-exact 抓包 |
| DESIGN | 本报告建议的独立实现/验收设计 | 不是原产品事实 |
| OPEN | 仍需取证的字段、边界或动态行为 | 禁止声称已经兼容 |

### 必须保留的校正

1. PendingCode = **60 秒**，不是 300 秒；AccessGrant = **3600 秒**，不是无限期
2. `alma_arm_pid` 是 authorize 查询中可选值，保存于 PendingCode；不是 token 表单必填 `pid`
3. startup bearer 与 OAuth grants 是两个入口；OAuth token 不覆盖 startup token 文件
4. 验签读取被提供 PID 的代码签名属性，不证明 HTTP 连接实际由该 PID 发起
5. `callTool` 必须先命中静态 registry；不能把未知工具直接当 daemon cmd
6. `snapshot_window → get_app_state`；不能合并或改写为 direct `snap`
7. `screenshot.required=[out]`，不是 `[output_path]`；`type_text.required=[text]`；`scroll.required=[ref,direction]`
8. `AppCommandRegistry.dispatch` 已经打开 URL，外层不得再次 openQuietly

## 阅读顺序

- [01 OAuth、安全范围与状态机](01-oauth-security.md)
- [02 原生14工具及 schema](02-tool-catalog.md)
- [03 HTTP / JSON-RPC / 资源与错误](03-http-jsonrpc.md)
- [04 socket 控制面和服务状态](04-lifecycle-control.md)
- [05 Intent 执行与 URL builder](05-intent-execution.md)
- [06 验收矩阵、实施 tickets 与 agent prompt](06-implementation-and-tests.md)
- [07 来源、差异与未闭合清单](07-evidence-and-gaps.md)
- [原始证据入口](../../code-evidence/native-http/README.md)

## 架构：同一能力，四个入口

```text
native socket mcp_* 管理命令 ──> MCPServer 生命周期/白名单

HTTP client
  ├─ metadata / authorize / token ──> PendingCode / AccessGrant / Whitelist
  └─ POST /mcp + Bearer
       └─ HTTP framing -> JSON object -> dispatchMCP
            ├─ initialize / notifications/initialized
            ├─ tools/list -> 静态14目录
            ├─ tools/call -> registry.name 查找 -> registry.daemonCmd
            │                -> Request(String id,args) -> Daemon.dispatch(ctx:nil)
            ├─ resources/list/read -> tool catalog
            └─ prompts/list/get -> 独立模板目录

JS stdio MCP23 -> JS adapter/host approval/PiP日志等 -> socket daemon
host /api/computer-use REST -> host route/client -> socket daemon
```

这张图是对原始符号和调用点的研究性表达，不是原项目源码。HTTP/native 路径未经过 JavaScript wrapper 的 gated/approval/action-log 分支，不能把那些 host 保障自动移植为 native HTTP 的既有保证。底层 OS 权限、daemon 输入能力、ref 生命周期和焦点策略仍各自有效。

## 模块责任与独立实现接口（DESIGN）

- `NativeHttpListener`：loopback 监听、连接登记、请求读写、终止与解析错误；不管理用户批准
- `AuthState`：分别存启动 token、pending codes、access grants、whitelist；使用可注入时钟、随机源和锁
- `SigningIdentityReader`：只从明确给出的 PID 查询可选 team/bundle；不自称传输层身份认证
- `McpDispatcher`：方法表、typed errors、JSON-safe 输出；不把所有错误变为同一 internal
- `NativeToolRegistry`：不可变 name/daemonCmd/schema 列表，同时驱动 tools/list、resource 与 callTool
- `DaemonBridge`：仅执行注册 cmd，保持 String request ID、nil connection context 与普通 native handler 语义
- `IntentRegistry`：固定 app/intent 元数据、必填参数检查、URL builder、一次 openQuietly

接口拆分是实施建议，原始产品只有本节引用的行为被证明；不可借建议目录名声称恢复了原始工程结构。
