# Native socket 管理命令与服务状态

## 1. 版本明确的控制契约

本节主要为 **C164**，来源：既有 `analysis/native-snapshot/MCP_CONTROL_EXTRA_CONTRACTS.md`；原始 `.164` VA 是该专题已核实的未slide地址。它只证明七个 socket 控制命令及 start/stop/add/list/status，不证明 `.164` 整条 OAuth/HTTP与`.153`相同。`.153`本轮独立相符片段另列§4。

这些结果均在 native NDJSON `data` 包裹内，不是 HTTP JSON-RPC result 直接格式。管理输入 `bundle_id` 与业务 app target 的 `bundle` 不能互换。

| cmd | 输入 | 成功 data | C164 依据 |
|---|---|---|---|
| mcp_start | port:int?；token_path:string? | 状态对象 | start0x1000546fc；dispatcher0x10007ce54 |
| mcp_stop | 无 | {stopped:true} | stop0x100055818；调用0x10007cf8c |
| mcp_status | 无 | 状态对象 | statusSnapshot0x100054f7c；调用0x10007d18c |
| mcp_allow | team_id?、bundle_id?、pid?、ttl_seconds? | allowed:true以及四项输入回显，nil变null | addWhitelist0x10006348c；调用0x10007d4e8 |
| mcp_deny_all | 无 | {cleared:true} | clearWhitelist0x100063714；调用0x10007d2bc |
| mcp_whitelist | 无 | {entries:[...]} | whitelistList0x100063770 |
| mcp_arm_peer | pid required；ttl_seconds?=120 | armed:true、pid、有效ttl_seconds | dispatcher0x10007d5c4–0x10007d838 |

## 2. 启动/停止及文件

C164：

- port 能转 UInt16 的0…65535值作为可选端口；缺失、无法解析或超范围均回退 nil/.any。不是固定端口，也不是65536 trap
- listener 已存在：立即返回当前status，新port/token_path忽略，不重绑定、不轮换token
- stopped→start：生成新的启动bearer，选择token_path；nil时采用 `(HOME ?? NSHomeDirectory())/.alma/cu/mcp-token`。空字符串是已提供值，不能偷偷当nil
- 创建父目录，UTF8写token，调用chmod0600；该函数未检查chmod返回值。读写/Network错误沿普通错误机制传播
- 等待boundPort!=0：期限2秒，每0.01秒检查；超时取消listener并抛 `MCP listener failed to bind within 2s`
- stop先在queue取消跟踪连接，再取消listener；listener=nil、port=0。该函数没有unlink token文件，也没有清oauth_client_id/token_path/whitelist/grant/code maps
- `mcp_deny_all` 只清whitelist，不等于撤销全部已发OAuth token

因此必须分开管理“网络是否运行”“启动文件还在不在”“白名单记录”“pending code”“grant有效期”，不能用单一 running Bool 表示所有授权状态。

## 3. Status、whitelist 与陷阱

C164 status有**10个字段**（0x100054f7c–0x100055428）：

| 字段 | 类型/规则 |
|---|---|
| running | listener!=nil 的Bool |
| port | UInt16整数；停止/未绑定为0 |
| url | port!=0时http://127.0.0.1:<port>/mcp，否则null |
| oauth_base | port!=0时http://127.0.0.1:<port>，否则null |
| oauth_client_id | 存储的非空String，否则null |
| token_path | 存储的非空String，否则null |
| tool_count | native static tools数组计数，不能填stdio23 |
| active_grants | 存储grant map计数 |
| pending_codes | 存储pending-code map计数 |
| whitelist_size | 存储whitelist数组计数 |

count在锁内快照，其他listener/port/string随后独立读，整体不应视作一个原子事务。count本身不清除到期条目；名字active_grants不证明所有记录当前有效。

WhitelistEntry序列化为四个始终存在的键：team_id:String|null、bundle_id:String|null、pid:Int32|null、expires_at:Unix epoch seconds Double|null。保持数组存储顺序，不排序、不省略null，不把过期记录自动过滤出list响应（C164 mapper0x10006391c–0x100063d54）。

mcp_allow：三项identity至少一项present；全nil→invalidArg `need at least one of team_id / bundle_id / pid`。可选字符串不trim、未要求非空；空team_id通过presence边界。PID窄化Int32，越界在原始分支会trap，不能把所有输入都写成温和invalidArg。省略TTL=无expiry；零/负TTL构造当前/过去expiry，没有正值钳制。addWhitelist只追加，重复项不去重。

mcp_arm_peer：缺pid时错误为带ASCII反引号的 missing `pid`；默认TTL120秒；由请求pid建立PID-only条目，不从socket ConnectionContext推导pid。越界Int32同样是原始trap边界。NaN/infinity尚未动态验证。

## 4. 本轮独立 P153 交叉点

[启动摘录](../../code-evidence/native-http/05-lifecycle-excerpts.md)给出：start唯一直接writeTokenFile点D153:84767；TCP loopback interface D153:84808–84826；超时2s错误D153:85050；token文件chmod0600 D153:104028–104029。

[白名单摘录](../../code-evidence/native-http/04-whitelist-excerpts.md)给出 `.153` clearWhitelist 只改数组的函数D153:99988–100011，以及`.153`内AND/外OR匹配和过期判定。这补充既有`.164`专题未闭合的历史版本匹配语义，但**不能宣称`.164`内AND/外OR也已由本轮直接证明**。

## 5. 研究性状态模型与实施边界

```text
listener: stopped -> starting -> running -> stopping -> stopped
startupBearer: absent -> generated+fileAttempt -> retained (独立于OAuth)
pendingCode: issued(now+60s)[P153] -> removed-on-exchange -> success/failure
accessGrant: issued(now+3600s)[P153] -> expired -> removed-on-validation
whitelistEntry: appended -> expires-at(optional) -> cleared-by-deny-all
```

这是独立实现的状态分解，不宣称恢复原始完整 class。需要强化版的原子文件写、symlink防护、stop撤销、统一grant清理，可另设 DESIGN profile；不要未经说明改变C164/P153版本限定的历史契约。
