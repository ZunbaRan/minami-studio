# HTTP framing、JSON-RPC、resources/prompts 与错误

本页除明确 R153/OPEN/DESIGN 外均为 P153 原始静态核验。证据：[HTTP/RPC摘录](../../code-evidence/native-http/03-http-rpc-excerpts.md)。本报告不把旧文档里的“符合 OAuth/MCP”作为整个标准兼容性证明。

## 1. HTTP 接收与连接

- Network.framework `NWListener` / `NWConnection`，TCP，requiredInterfaceType=loopback（D153:84808–84826）
- 累积 Data，寻找 CRLFCRLF；header 以 UTF-8 解码；读 content-length 后等够 body；逐块 receive 的 maxLength 为65536（D153:86177–86601）
- 65536 是**单次接收上限**，不是已经证明的整体 body/header 大小限制。未据此宣称具备请求配额或防慢速请求保护
- parseHeaderBlock 将 header key 小写，value 做字符串处理（D153:104626–104873）；本轮不为重复头、多个 content-length、折叠行等所有畸形输入给出未验证结果
- parseQueryString 对 key/value 调 removingPercentEncoding（D153:105101、105132）。重建注释声称 `+→空格`，但其重建实现本身也未做；在未闭合原函数该分支前，不应自动引入该行为
- 响应包含 Content-Length 和 Connection: close；原始 send 使用 contentProcessed 回调，不能照抄重建中 `send(...idempotent); cancel()` 的立即取消写法（D153:104559–104602）
- 未闭合 chunked encoding、keep-alive 多请求、SSE、DELETE会话、HTTP2、TLS、跨平台网络容错；不能因为名称为 HTTP MCP 就宣称都支持

## 2. 路由和边界

| 正常用途 | method/path | 认证入口 | 依据 |
|---|---|---|---|
| 授权服务器元数据 | GET /.well-known/oauth-authorization-server | 在 MCP bearer gate 前 | D153:86978–87235 |
| 生成授权码 | GET /oauth/authorize?... | 在 MCP bearer gate 前 | D153:87245–87480 |
| 换取 grant | POST /oauth/token | PKCE + 可选 armPid 分支 | D153:87266–87501 |
| RPC业务 | POST /mcp | startup bearer 或有效 access grant | D153:87370–87641 |

细节：authorize 路径处调用 hasPrefix，而不是重建里对拆出的 path 作唯一 exact match（D153:87245–87261）。因此只把上表当正常入口，不声称所有 suffix/问号/方法组合已经穷尽；异常路由需要保留原始分支并建 fixture。

元数据已定位键：issuer、authorization_endpoint、token_endpoint、response_types_supported、grant_types_supported、code_challenge_methods_supported、token_endpoint_auth_methods_supported。值与实际 flow 需要一起核对，不能从 key 名造出 dynamic registration、refresh token、scope 或资源服务元数据功能。

## 3. JSON-RPC 请求和分发

读取 JSONSerialization 的顶层对象并 cast 字典。非对象与解析失败分开；method 要 String，params 的对象化/default 行为需保持原始分支。JSON-RPC id 通过 `Any?` 保存/返回；不要误用 native socket Request.id:String 限制这层。

已定位的方法分支：

| method | 语义 | 证据 |
|---|---|---|
| initialize | 构建固定能力、serverInfo、instructions | D153:90879–91137 |
| notifications/initialized | 空字典分支 | D153:91138–91174 |
| tools/list | 静态工具映射 name/description/inputSchema | D153:91175–91437 |
| tools/call | 取 name/arguments，再 registry gate | D153:91438–91698 |
| prompts/list、prompts/get | 列表与模板 lookup/render | D153:91699–91752、91800–91841、91937–92160 |
| resources/list、resources/read | 自描述资源、URI查找 | D153:91752–91798、91842–91882 |
| 其他 | Method not found | D153:91883–91935 |

成功调用之后，若没有 id 且 method 有 notifications/ 前缀，则 HTTP200 body为 `{}`（D153:88094–88124）。不能直接套用 stdio “所有 notification 零字节回复”的逻辑；未知方法是否到此分支，还受 dispatchMCP 的先行错误影响。

initialize 的 protocolVersion **固定为2024-11-05**，并非回显来请求的版本（D153:90921–90941）。本轮进一步直接读取 `.153` 原始静态表，独立核到 serverInfo name alma-computer-use、version0.2、tools.listChanged=false、prompts.listChanged=false、resources.subscribe=false/listChanged=true；其指针来自initialize，最小原始字节与偏移见[元数据常量](../../code-evidence/native-http/07-initialize-constant-bytes.md)。这些值与R153作者摘要相符，证据现为P153静态，不是动态复测。instructions 只记录存在及“后台操作、避免擅自激活前台”的含义，不复制原始长提示词。

## 4. tool catalog 资源与 prompts

resource URI `alma-cu://tool-catalog` 在 readResource 的原始常量 D153:92774。工具目录内容是 JSON形式的自描述资源；resource MIME 的 application/json 位于D153:93157。未知URI错误为 `Unknown resource uri: <uri>`（D153:93230）。本页不承诺资源订阅真有持续事件机制，仅有 capability 字段不能证明其实现。

R153 作者报告的两项 prompt 名：snapshot_then_click、list_running_and_snapshot；原始 symbols 有 prompts initializer/renderPrompt。此模块只保留用途转述：先取得状态再选元素点击，以及列出应用后获取一个目标状态。模板参数缺省、完整 rendered text、最近使用排序方向和提示的正确性，不应从描述名称直接认定。本次不交付原始 prompt 全文，也不在 agent prompt 中复用它们。

## 5. 分层错误契约

所有文本错误下表中 `\n` 表示末尾 LF，不是字面反斜杠+n。不要把 HTTP status、JSON-RPC code、CUError.code 混成同一字段。

| 层级/条件 | 已核错误 | 原始定位 |
|---|---|---|
| header UTF8/格式失败分支 | HTTP400，Bad headers\n | D153:86392–86413 |
| request-line失败 | HTTP400，Bad request line\n | D153:86951–86971 |
| 缺 Bearer | HTTP401，Missing bearer token\n | D153:87545–87561 |
| token不匹配/过期 | HTTP401，Invalid or expired bearer token\n | D153:87620–87646 |
| 方法不允许 | HTTP405，Method Not Allowed\n | D153:87562–87578 |
| JSON解析抛错 | RPC -32700，Parse error: + localizedDescription | D153:87768–87797 |
| 顶层不是对象 | RPC -32600，Invalid request | D153:87809–87823 |
| method缺失/不是String | RPC -32600，Missing method | D153:87888–87899 |
| missing tool name | MCPError，消息小写 missing tool name | D153:91604；具体码应从邻域取证 |
| 未知工具 | RPC -32602，Unknown tool: +name | D153:92432–92462 |
| 未挂接daemon | RPC -32000，Daemon not attached | D153:92464–92479，raw constant0x10008dea0 |
| 原生 CUError | RPC -32000，localizedDescription | D153:88022–88041 |
| MCPError | 保留该错误自己的 code/message | D153:87958–87977 |
| 未分类异常 | RPC -32603，Internal error: + localizedDescription | D153:88064–88088 |
| authorize非code flow | HTTP400，response_type must be 'code'\n | D153:88688–88705 |
| 缺PKCE/S256/challenge | HTTP400，PKCE S256 code_challenge required\n | D153:88840–88858 |
| 缺redirect | HTTP400，redirect_uri required\n | D153:88859–88879 |
| PID白名单未通过 | HTTP403；JSON error_description=peer not in whitelist | D153:90155–90167、90683–90699 |

OAuth invalid_grant 等错误有原始静态字典记录，但错误细分的完整所有组合尚未在本包闭合，不把重建 Swift 中简化 catch 当 oracle。

## 6. 可移植实现的可观测性（DESIGN）

每个请求记录 transport category、method/tool、时间、错误层级、内部 correlation ID；不记录 token/code/verifier、窗口内容或完整截图路径。只将安全脱敏诊断返回日志。将三类失败分开：解析失败、授权失败、业务执行失败。用 fake daemon 验证 names gate，所有未知工具保证 zero-dispatch。请求取消、服务 stop 和连接结束都要有确定的资源回收路径，不能用“吞掉异常即成功”替代。
