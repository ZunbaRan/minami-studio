# 原生14工具目录：名称、派发、schema 与未知边界

## 1. 目录级证明

P153：`MCPServer.tools` 静态 initializer 位于 D153:94093–99782，VA `0x10005b9a4` 起。原始数组头 `0x10008deb0` 是 `(14,28)`；每个 Tool 布局有 `name`、`daemonCmd`、`description`、`inputSchema`。`tools/list` 输出三项公共字段 name/description/inputSchema，不输出内部 daemonCmd（D153:91232–91286）。

证据：[目录/派发摘录](../../code-evidence/native-http/02-tool-registry-excerpts.md)、[required 与 enum 原始静态数组](../../code-evidence/native-http/06-static-array-bytes.md)。以下为研究性结构转录；描述文字均为中文改写，未承诺 byte-identical 英文描述。

| 顺序 | HTTP MCP tool | daemonCmd | properties（JSON Schema类型） | required | 主源范围 |
|---:|---|---|---|---|---|
| 0 | ping | ping | 无 | [] | D153:94128–94143 |
| 1 | list_running_apps | apps | 无 | [] | D153:94144–94175 |
| 2 | list_windows | windows | pid:integer; bundle:string | [] | D153:94176–94548 |
| 3 | snapshot_window | get_app_state | pid:integer; bundle:string; wakeup_seconds:number; include_screenshot:boolean | [] | D153:94549–95081 |
| 4 | click | click | ref:string; x:number; y:number; pid:integer; bundle:string; button:string; click_count:integer; coord_space:string | [] | D153:95082–96045 |
| 5 | type_text | type_text | text:string; pid:integer; bundle:string; ref:string; input_method:string | [text] | D153:96046–96776 |
| 6 | press_key | press_key | combo:string; pid:integer; bundle:string | [combo] | D153:96777–97140 |
| 7 | scroll | scroll | ref:string; direction:string; pages:integer | [ref,direction] | D153:97141–97607 |
| 8 | screenshot | shot | window_id:integer; pid:integer; bundle:string; out:string; max_width:integer | [out] | D153:97608–98250 |
| 9 | open_url | open_url | url:string | [url] | D153:98251–98407 |
| 10 | intent | intent | bundle:string; intent:string; args:object | [bundle,intent] | D153:98408–98770 |
| 11 | pip_open | pip_open | window_id:integer; pid:integer; bundle:string; title:string; width:number; height:number | [] | D153:98771–99308 |
| 12 | pip_close | pip_close | window_id:integer; all:boolean | [] | D153:99309–99578 |
| 13 | pip_status | pip_status | 无 | [] | D153:99579–99602 |

说明：表中 properties 是原生HTTP目录字段，不是 daemon 所有可接受参数的完整集合；也不是 JS stdio schema。name 和 daemonCmd 是两个独立字段，即使大部分同名也不能省去映射层。

### 已核枚举、范围及有序 required

| 属性 | 原始目录值 | 证据 |
|---|---|---|
| click.button | [left,right,middle] | 静态数组 VA0x1000ad118；D153:95545–95548 |
| click.click_count | integer，minimum1，maximum3 | D153:95657–95691，VA0x10005d210–0x10005d294 |
| click.coord_space | [screen,screenshot]，顺序如此 | VA0x1000ad170；D153:95839 |
| type_text.input_method | [auto,physical,unicode,ax] | VA0x1000ad1b8；D153:96451 |
| scroll.direction | [up,down,left,right] | VA0x1000ad290；D153:97265 |
| scroll.pages | integer，minimum1 | D153:97368–97392，VA0x10005eccc–0x10005ed2c |
| type_text.required | [text] | VA0x1000ad220；D153:96757 |
| press_key.required | [combo] | VA0x1000ad258；D153:97119 |
| scroll.required | [ref,direction] | VA0x1000ad2f8；D153:97589 |
| screenshot.required | [out] | VA0x1000ad340；D153:98227 |
| open_url.required | [url] | VA0x1000ad378；D153:98387 |
| intent.required | [bundle,intent] | VA0x1000ad3b0；D153:98752 |

jsonObject 辅助函数固定组装 `type:"object"`、`properties`、`required` 三项（D153:103665–103748）。未在此函数加入 additionalProperties:false；不要自行加入后宣称目录完全相同。

## 2. 公共 schema 与实际执行校验不同

- list_windows、snapshot_window、click、pip_open 的 required 空数组，不等于任何空参数调用都能成功。具体 target/ref/坐标约束发生在 daemon handler
- click 的描述暗示 ref 或 x/y/pid 的选择，但不能把人类描述直接改造成已存在的 JSON Schema oneOf
- wakeup_seconds 描述里的时间区间是说明文字，不足以证明 JSON Schema minimum/maximum，不能默默加入硬限制
- `callTool` 中已证明的是**名称门**：从静态14目录找 name，取该条 daemonCmd，再构造 Request 调 daemon；并非通用 daemon passthrough
- 当前原始 callTool 取证未发现按 inputSchema 做统一通用验证的阶段。新增校验可作为 DESIGN 的强化 profile；兼容 profile 必须保留 daemon 的实际参数容错/错误
- `args` 是 intent 的工具参数名，不能据此把内部所有值的类型都断言为任意 JSON；registry builder 参数最终为 `[String:String]`，外层转换细节须独立核查

## 3. 派发与响应

D153:92212–92236 比较静态 tools.name；未找到时 D153:92432–92462 构造 `MCPError(-32602,"Unknown tool: <name>")`。不能添加 default 使用 name 本身。

命中后：D153:92377–92411 从所选 Tool 读 daemonCmd，组装 String request id/args，调用 `Daemon.dispatch`，connection context 为 nil。这是 HTTP request 内部的桥接 Request，不是调用者直接提交整个 native Request，也不要求 JSON-RPC id 为 String。

成功：调用结果经 jsonSanitise/JSONSerialization 转成文本，包装一个 text content item，并有 `isError:false`（D153:92531–92552、92609–92680）。不能照搬 JS stdio post-action 的 image 内容、playbook、gated/approval/action-log 注入。native screenshot 工具返回文件路径相关数据，由调用者后续处理；HTTP 工具目录文字不是一个已证明的图片传输管道。

未知工具和 daemon 异常走 JSON-RPC error，不应全部变为成功 result 中的 isError:true。具体错误见[HTTP/错误页](03-http-jsonrpc.md)。

## 4. 不在此目录里的能力

没有 `launch_app`、`raise`、`type`、`press`、`app_command`、`appshot_capture`、`mcp_*`、`shutdown` 等名字。它们可能在别的接口有意义，但本目录不能通过名称直通让它们可达。管理命令由本地 socket 控制，HTTP MCP 工具不自动暴露。

对照 `.153` 重建文件尤其要纠正：

- 注册 `app_command` 是重建误写，原始 name 是 intent
- screenshot 不叫 output_path；out 是必填名字
- scroll.pages 是 integer，不是 number；ref/direction 是必填
- click.button 包含 middle；click_count 还有 maximum3
- pip_open 有6个公开字段，不能只留 window_id
- type_text required 不能丢掉 text

## 5. 已知/未知清单

已闭合（P153）：14名称及顺序、内部cmd映射、上表参数名/类型、上述required/enum/范围、公共对象壳、目录名称门、成功text包装。

尚未宣称闭合（OPEN）：每个属性的逐字 description 与所有字段序列化顺序、jsonSanitise 对全部非JSON类型的转换、跨所有 OS 的动态 handler 行为、HTTP 客户端读取本地 screenshot path 的权限模型、完整并发/取消语义、`.164` 是否复用相同 native HTTP 目录。

这些未知不阻止按语义实现独立服务，但应阻止“完整原生 HTTP 字节级 parity 已通过”的结论。
