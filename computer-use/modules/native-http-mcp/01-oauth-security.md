# OAuth、安全边界与令牌状态机

证据：P153。主源 D153 = `evidence/disasm.annot.txt`，来源路径、SHA256、行号/VA 见[认证摘录](../../code-evidence/native-http/01-oauth-excerpts.md)、[白名单摘录](../../code-evidence/native-http/04-whitelist-excerpts.md)、[启动摘录](../../code-evidence/native-http/05-lifecycle-excerpts.md)。`.164` 的 socket 管理契约另见[生命周期页](04-lifecycle-control.md)，不以 `.153` 认证推定 `.164` 同样实现。

## 1. 两条可用的 Bearer 路径

D153:87419–87429 先比较传入 bearer 与 server 保存的启动 token；相同直接进入认证通过路径。比较不相同才在 D153:87620–87627 调用 isValidAccessToken。

```text
收到 Bearer 字符串
  -> 等于 startupToken ? 通过
  -> 否：accessGrants[token] 存在且未过期 ? 通过
  -> 否：HTTP401 Invalid or expired bearer token\n
```

启动 token 由 start 生成并写到 token 文件，OAuth token 由 serveToken 生成、进入 grant map、返回 HTTP 响应。完整 serveToken 函数（D153:89041–90714）没有 writeTokenFile 直接调用；全反汇编只有 start 的一个直接 callsite（D153:84767）。**不能让换码更新或覆盖启动文件**。未在此认证入口发现 startupToken 的一小时期限；一小时只属于 OAuth AccessGrant，不能把两类 TTL 混用。

## 2. authorize 请求和 PendingCode

端点：`GET /oauth/authorize`。D153:88281、88313、88344、88373、88395、88430、88459 可定位读取键：

| 输入键 | 已证实行为 | 仍不能推断 |
|---|---|---|
| response_type | 要求等于 code；否则400文本错误 | 其他 OAuth flow 支持 |
| code_challenge_method | 要求 S256 | plain 支持 |
| code_challenge | 必须非空；保存到 pending | challenge 格式/长度完整规范校验 |
| redirect_uri | 必须非空；保存，并用于302 Location | 预注册 allowlist、scheme/host 校验、系统浏览器可信来源 |
| client_id | 读取并存储在 pending | 必须等于 status.oauth_client_id；不应从字段存在推定完整客户端注册 |
| state | 读取，非空时带回 Location | CSRF/Origin 防护已闭合 |
| alma_arm_pid | 可选，Int32 解析成功则保存；缺失或解析失败成 nil | token 请求必填 pid，或从 HTTP socket 提取 PID |

直接数值证据：D153:88734–88742 以 `0x404e000000000000` 的 Double 调 Date.addingTimeInterval，即 **60.0 秒**。D153:88755–88757 将 PID 与 optional tag 写到 PendingCode +0x30/+0x34。

研究性记录结构：PendingCode 包含 `codeChallenge:String`、`redirectUri:String`、`clientId:String`、`armPid:Int32?`、`expiresAt:Date`。字段名也可由原始 reflection strings 交叉核对；这不是原 Swift 源码声明。

302 行为：原函数按 redirect 字符串是否含 `?` 选择 `&`/`?` 后拼 code；state 使用 Foundation.urlQueryAllowed 做百分号编码（D153:88785–88830、88891–88924）。本页不提供真实 code，也不将该策略描述成严格 RFC URLComponents 构造器；特殊 `#`、嵌入查询分隔符、非法 URI、换行等需独立安全测试。

## 3. token 交换的真实顺序

端点：`POST /oauth/token`，form parser 读取 `grant_type`、`code`、`redirect_uri`、`code_verifier`、`client_id`（D153:89205、89232、89259、89288、89317）。没有该路径必填 `pid` 的依据。

1. 检查 grant_type 等于 authorization_code
2. 持锁 **removeValue(code)**，取出并消耗 pending code（D153:89359–89385）
3. 检查取出的 code、到期时间以及 redirect URI；后续失败不会自动把 code 放回
4. 传入 client_id 非空时与 pending.clientId 比较；缺失/空字符串走跳过比较分支（D153:89741–89753）
5. 对 code_verifier 做 PKCE S256 后比对 challenge
6. 读取 pending.armPid：nil 跳到发放路径；present 才调用 SecCodePeer.verifySigning 和 whitelist 检查
7. 生成 access token；Date.now + **3600 秒**；将 grant 写入 map 后返回 token 响应

顺序的重要性：一次错误 verifier/redirect/client 请求可能已消耗 code。因此不能把“失败可重试同一码”当兼容承诺。并发兑换应由 map 的锁与 removeValue 确保最多一次取出，而不是先读取再异步删除。

PKCE：D153:100423–100443 的 CC_SHA256 路径与 D153:105394–105473 的 Base64 结果 `+→-`、`/→_`、去掉 `=` 共同支持 S256 base64url；不能只比较 raw SHA256 bytes 或普通 Base64 字符串。固定算法在本报告仅由原始实现取证，不依赖记忆猜测标准版本。

## 4. 可选 PID 的签名和白名单

`SecCodeCopyGuestWithAttributes(kSecGuestAttributePid)` → `SecCodeCopySigningInformation` 读取 team/bundle。原始直接调用点在 token 路径 D153:89840–89841；被查询 PID 来自之前保存的 PendingCode。该函数返回可选签名属性，不能把命名为 verifySigning 的函数当成已证明完整 certificate requirement / notarization / hardened-runtime 验证。

WhitelistEntry.matches 的静态分支（D153:84191–84365）及 token 内联逻辑（D153:89950–90027）表明：

- 有 expiry 且 now > expiry：不匹配；无 expiry 不做此期限拒绝
- 条目设置 PID 时，候选 PID 必须相同
- 条目设置 teamId 时，候选 teamId 必须相同
- 条目设置 bundleId 时，候选 bundleId 必须相同
- 条目至少设置一项身份；全空条目不能匹配
- **条目内部 AND，多个条目之间 OR**，不是单个条目的三个字段任意一个吻合即放行
- PID-only 条目本身不要求有非空 team/bundle；不能宣称每一个授权 grant 都必然具有签名身份

PID present 且所有条目不匹配：返回403，JSON包含 `error_description:"peer not in whitelist"`；stderr 记录拒绝原因。这里只保留模板，不附私人 PID/team/bundle 的运行值。

### 不能证明的身份保证

查到“PID X 的签名为 Y”与证明“当前 HTTP 连接属于 PID X”是两个不同命题。该材料没有闭合后者。且 nil armPid 路径会跳过签名/whitelist，startup bearer 也可直接通过。不得宣称所有 localhost 进程都被签名白名单挡住、所有调用都绑定原进程、token 不可转交或防止本机 bearer 泄露。

## 5. AccessGrant 生命周期

研究性 grant 字段：token、clientId、peerPid?、peerTeamId?、peerBundleId?、expiresAt。D153:90373–90380 采用 Double `0x40ac200000000000` = **3600.0**；D153:90470–90479 返回 `expires_in=0xe10` = **3600**。

isValidAccessToken 持锁查 grant，再对 now 与 expiry 作 `>` 比较；过期时删除并失败（D153:90782–90878）。相等边界按静态分支不触发 `now > expiry` 的拒绝；实施时用可注入时钟精确覆盖临界值。`active_grants` 是 map 当前记录数，不保证每条已通过本次时钟过滤。

`mcp_deny_all` 只清 whitelist，并不清 grants；停止监听也不等于撤销 token。`.164` 控制契约明确 map 保留边界，见下一页。对 `.153` 未闭合的 stop/start 组合跨 map 生命周期，应保留测试缺口，不臆造“stop自动全撤销”。

## 6. 安全实施策略必须与兼容事实分开

DESIGN：独立产品应明确选择“历史兼容 profile”或“强化 profile”。强化内容可包括更严格的 redirect allowlist、显式同意、code/token size limits、速率限制、Origin/Host 验证、更可靠的 caller proof、统一撤销和安全 token-file 创建。这些都值得设计，但不能以“修好”名义静默替代上述原始行为，同时还宣称 byte/semantic parity。

认证 token、code、verifier、真实目标应用/窗口标识不得出现在 fixture 或日志交付中。只用虚构 namespace、占位值和内存 fake；本次文档只读静态，不授权运行认证服务、授予桌面权限或进行真实输入。
