# 05 · AppCommandRegistry intent 执行：.153 静态闭合与实现边界

## 结论先行

`dispatch(bundleId:intent:params:)` 是“校验 → 构建 URL → 打开 → 返回 URL”的有副作用事务，不是纯 URL builder。它已调用 `openQuietly` 一次；HTTP/MCP 或 daemon 的调用者成功后再次打开 URL 会造成重复副作用。入口重试也不是幂等操作。原重建 Swift 不能覆盖下面的机器级证据。

本章只把 .153 的执行链闭合为可实现规格。既有 .164 材料证明的是 intent 的列表元数据；不能由两版名称相同推导 .164 的 builder、打开方式、超时或错误处理也相同。没有运行目标程序、注册 intent 或原始探针；下列测试是独立实现验收设计，未宣称动态通过。

## 1. 证据层次与可复核入口

- **P153，一手静态事实**：直接读取 .153 原始 annotated disassembly 和 universal binary 中的 arm64 slice。仅证明该样本的静态指令、控制流和数据，不证明应用实际响应
- **C164，既有版本契约**：[APP_INTENTS_METADATA](../../analysis/native-snapshot/APP_INTENTS_METADATA.md) 与 [intent-metadata](../../contracts/intent-metadata.json) 已有的 .164 元数据结论，本次仅复核文档内容，没有重新验证 .164 执行函数
- **R，研究重建／实现建议**：把寄存器流解释为类型、模块边界及测试替身；不是声称获取原作者源代码
- **U，未闭合**：依赖操作系统、目标应用或未纳入本次范围的行为，必须显式保留

一手摘录：[intent-excerpts.md](../../code-evidence/native-http/intent-excerpts.md)。每项 I01–I48 给出原路径、SHA-256、版本、架构、强度、闭区间原行号、VA、符号；二进制原字节使用精确文件 offset 范围，行号不适用。文本按原行摘出，不用重建 Swift 冒充原文。

原始来源与指纹：

|来源|SHA-256|性质|
|---|---|---|
|`comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt`|`543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5`|P153，原始注释反汇编|
|同目录 `AlmaComputerUse.bin`|`b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3`|P153，universal 原始二进制；arm64 slice 起点 `0x128000`|
|`comparison_cu_inputs/extracted/Alma_0.4.164_复刻契约与验收语料/analysis/native-snapshot/APP_INTENTS_METADATA.md`|`fb565814c4326ac15d38d414cfe560f770e37f484360d7d304f0ef38f96e367f`|C164，既有契约|
|同包 `contracts/intent-metadata.json`|`3ad9444279c7756559ac050656ac47db54f66b2ad5bc021f1c567a5fea9a4631`|C164，独立功能元数据转录|

原始函数边界：entries initializer 行 45404–46077，builder closures 行 46078–46983；`intents(for:)` 行 46984–47027；`dispatch` 行 47028–47499；`openQuietly` wrapper 行 47500–47505；specialization 行 47648–48162。部分 thunk 与回调位于后续地址，已单列 I21、I22。VA 全为 arm64 未加 slide 地址。

## 2. 调用契约与错误顺序（P153）

Swift 符号给出的输入是 `bundleId:String`、`intent:String`、`params:[String:String]`，正常返回 `Foundation.URL`，可抛错。这里不规定外层 JSON 如何变成 String 字典，也不把内部错误种类直接当作 JSON-RPC 数字码。

1. 懒初始化注册表。`intents(for:)` 对 bundle 做 Swift String 字典查找；未注册返回空数组（I01）
2. `dispatch` 对同一 bundle 做查找；未注册时抛 `CUError.invalidArg`。没有按应用展示名、路径、后缀、大小写别名进行匹配的分支（I02、I03）
3. 在该 bundle 的有序 Intent 数组中逐个比较 intent 名称。使用 Swift String 相等语义；不能改成大小写不敏感或前缀匹配。未找到时列出该数组的所有已知名称，按原数组顺序以 `, ` 连接（I02、I07、I08）
4. 按 `requiredParams` 数组顺序检查字典键是否存在。找到 bucket 后直接继续，没有读取值来检查长度；不是通用的“必填且非空”规则（I04）。首个缺失字段先报错，builder 与 opener 都不执行（I10）
5. 将整个 params 字典传给选中 builder，调用一次。未遍历 optionalParams 作拒绝检查，也没有统一拒绝额外字段的分支（I04）
6. builder 返回 nil 时抛 `CUError.invalidArg`，不尝试打开（I05、I06）
7. 成功 URL 被复制到返回槽，再以该 bundle 作为 preferredBundleId 调用 `openQuietly`。打开抛错则清理返回槽并将错误向上传递；只有打开成功才正常返回 URL（I09）

“精确”指 Swift String equality 和字典语义，不应额外宣称 UTF-8 逐字节比较；本样本的 bundle/name 都是 ASCII，验收重点是保留其大小写及完整标识。

### 错误分支矩阵

|条件|内部分类|可观察内容，按原指令解释|副作用|
|---|---|---|---|
|bundle 未注册|`invalidArg`|指出该 bundle 没有已注册 intent，并提示使用其他交互方式|0 次打开|
|bundle 已注册，intent 未命中|`invalidArg`|`unknown intent`、请求名称、bundle、`known intents` 有序列表|0 次打开|
|required key 缺失|`invalidArg`|指出 intent 与第一个缺失参数名称|0 次打开|
|builder 返回 nil|`invalidArg`|指出该 intent 无法从给定参数构建有效 URL|0 次打开|
|打开等待超时|`internalError`|`NSWorkspace.open(` + URL.absoluteString + `) timed out after 5s`|已提交 1 次打开；不撤销、不自动重试|
|打开 completion error 非 nil|`internalError`|`NSWorkspace.open(` + URL.absoluteString + `) failed: ` + error.localizedDescription|已提交 1 次打开；不自动换应用重试|

上表只恢复分支、字段和必要短语；完整错误拼接证据在 I03、I06–I10、I17–I19。URL 可能包含用户数据，独立实现的日志/展示应另设脱敏策略；不能为满足字面兼容而复制真实探针参数。

## 3. .164 元数据契约与 .153 新证据的界线

下表的名称／顺序／required／optional 取自 **C164**，描述均为中文释义。P153 initializer 与原始数组字节也呈现这些 7 个 bundle、15 个 Intent 的对应结构；但两版执行等价性仍未证明。跨 bundle 的行顺序仅为说明，不等于 list_apps 的行排序。

|exact bundle|按数组顺序的 intent|必需参数|可选参数|释义|
|---|---|---|---|---|
|`com.netease.163music`|`launch`|[]|[]|启动音乐应用|
|同上|`play_song`|[song_id]|[]|选择歌曲|
|同上|`open_playlist`|[playlist_id]|[]|进入歌单|
|同上|`play_daily_recommendation`|[]|[]|进入每日推荐|
|同上|`open_history_recommend`|[]|[]|进入历史推荐|
|同上|`open_route`|[route]|[]|进入指定路由|
|`com.apple.Music`|`launch`|[]|[]|启动 Music|
|同上|`open_url`|[url]|[]|打开链接|
|`com.spotify.client`|`launch`|[]|[]|启动 Spotify|
|同上|`play_uri`|[uri]|[]|打开 URI|
|`com.apple.mail`|`compose`|[]|[to, subject, body, cc, bcc]|准备邮件编辑窗口|
|`com.apple.Safari`|`open_url`|[url]|[]|打开链接|
|`com.tencent.xinWeChat`|`launch`|[]|[]|启动微信|
|`com.tinyspeck.slackmacgap`|`launch`|[]|[]|启动 Slack|
|同上|`open_channel`|[team_id, channel_id]|[]|进入频道或会话|

P153 数组闭合（I46）：`song_id` 在 `0x1000ac038`；`playlist_id` 在 `0x1000ac070`；`route` 在 `0x1000ac0a8`；Music `url` 在 `0x1000ac0e0`；`uri` 在 `0x1000ac118`；Mail 五项 optional 在 `0x1000ac150`；Safari `url` 在 `0x1000ac1c8`；Slack 两项 required 在 `0x1000ac200`。这是原字节读取，不是从 .164 数组地址向前推算。

不要从描述中的“数字 ID”“完整 http/https 链接”或推荐的 route 列表制造校验规则：真实 builder 的分支如下。

## 4. URL builder 的实际数据流（P153 + R 解释）

下列箭头表达从反汇编恢复的数据流，不是原始 Swift 源码。`Q(s)` 仅是本章简写：调用 `addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)`；返回 nil 时保留原输入串。不得把它替换成强制百分号编码所有查询保留字符的另一算法。

|bundle / intent|闭合的数据流|证据|
|---|---|---|
|NetEase / launch|常量 `orpheus://` → URL(string:)|I23|
|NetEase / play_song|取 song_id → `orpheus://song/?id=` + Q(song_id) → URL(string:)|I24、I25；记录绑定 I42|
|NetEase / open_playlist|取 playlist_id → `orpheus://playlist/?id=` + Q(playlist_id) → URL(string:)|I26、I27|
|NetEase / play_daily_recommendation|常量 `orpheus://route/dailyRecommend` → URL(string:)|I28|
|NetEase / open_history_recommend|常量 `orpheus://route/historyRecommend` → URL(string:)|I28|
|NetEase / open_route|取 route，若 String 长度为零则 nil；否则 `orpheus://route/` + Q(route) → URL(string:)|I29、I30；绑定 I43|
|Music / launch|常量 `music:` → URL(string:)，不是自行补上斜线|I31|
|Music / open_url|取 url → 直接 URL(string:)|I40 的指针 `0x10002fed0` → I22 的 thunk → I35|
|Spotify / launch|常量 `spotify:` → URL(string:)|I31|
|Spotify / play_uri|取 uri → 直接 URL(string:)|I31 的 key wrapper → I35 shared builder|
|Mail / compose|to 缺失则空串；`mailto:` + Q(to) → URLComponents；按 subject/body/cc/bcc 顺序加入存在键的 URLQueryItem；非空 queryItem 数组才赋给 queryItems；最后取 components.url|I32–I34、I47；绑定 I44|
|Safari / open_url|取 url → 直接 URL(string:)|I41 → I35|
|WeChat / launch|常量 `weixin://` → URL(string:)|I36|
|Slack / launch|常量 `slack://` → URL(string:)|I36|
|Slack / open_channel|取 team_id、channel_id → `slack://channel?team=` + Q(team_id) + `&id=` + Q(channel_id) → URL(string:)|I37–I39；绑定 I45|

### 必須保留的细节

- `open_route` 的空值检查属于它自己的 builder。`route:""` 通过 dispatch 的 presence 检查，却随后成为“构建 URL 失败”；`route` 缺失先成为“缺必需参数”。不能合并这两类错误
- `play_song`、`open_playlist` 没有数字解析、数字范围或显式空串分支。空串仍会流入 URL 构造；Foundation 是否返回 URL 应由匹配平台的 URL 实现决定
- Music/Safari/Spotify 的 shared builder 是参数查找后直接 URL(string:)。没有新增 scheme/host 白名单，也没有把一个应用的链接转换为另一种 URI；元数据描述不是安全过滤器
- route 未按描述列出的候选值作枚举检查，且用了 queryAllowed 而非 pathAllowed。为“改善”效果换编码器会改变样本行为
- Mail 的 to 不作为 queryItem；其缺失为 `mailto:` 空收件人路径。subject/body/cc/bcc 只检查是否存在；空串键也会生成 queryItem。其编码交给 URLComponents/URLQueryItem，不复用手拼 Q 的处理
- Slack 按 team_id 在前、channel_id 在后构造；没有可见的非空、格式或前缀验证。测试不得使用原始探针的 workspace/channel 标识
- URL(string:)／URLComponents 的具体规范化、容错和百分号输出是 Foundation 依赖。这里只闭合调用数据流；未经同平台验证，不能宣称跨平台字符串输出逐字节一致
- 所有列出的 builder 均只返回 URL?，未调用 NSWorkspace；打开的副作用归 dispatch → openQuietly 所有

## 5. openQuietly 的单次打开状态机

### 配置（P153）

I11 的三个 setter 实参均为 false：`activates=false`、`addsToRecentItems=false`、`hidesOthers=false`。原反汇编把 classref 注释为 bad class ref；本次读取二进制绑定记录（I48）将 `0x1000aa4a0` 的 bind ordinal 715 解析为 `_OBJC_CLASS_$_NSWorkspaceOpenConfiguration`，因此配置类型也已闭合。

这证明发给 Workspace 的配置，不能保证所有第三方应用最终都不抢焦点。未看到针对这条路径的焦点修复或应用内成功校验；不要把名称 Quietly 写成普遍的行为保证。

### 选路与 fallback（P153）

1. preferredBundleId 非 nil 时，以它调用 `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`
2. 若返回应用 URL，以只含目标 URL 的数组调用 `openURLs:withApplicationAtURL:configuration:completionHandler:`。该路径提交后直接跳过 fallback（I12–I14）
3. preferredBundleId 为 nil，或应用 URL 查找返回 nil 时，调用 `openURL:configuration:completionHandler:`，由系统常规 URL 处理机制决定目标（I14、I15）
4. **fallback 发生在打开前的应用查找阶段**；指定应用打开的 completion 报错，不会再转去通用 openURL

因此一次进入 opener 只走一种 Workspace open API。所谓“一次副作用”应验收为一次打开请求；它不表示目标应用内部只发生一次动作，也不表示请求后能撤销。

### completion、同步等待与错误（P153）

- 创建计数为 0 的 semaphore；error 初始 nil，signaled 布尔初始 false
- Workspace completion adapter 不检查返回的 NSRunningApplication，只转发 error（I22）
- 回调先存 error，再查看 signaled；首次设为 true 并 signal，后续调用不重复 signal（I21）。该代码不等于证明任意线程并发下具备额外锁保护
- 提交打开后，以 DispatchTime.now()+5 秒等待。超时直接抛 internalError；没有可见的取消或再次打开操作（I16、I17）
- 非超时则看保存的 error：非 nil 转为包含 localizedDescription 的 internalError；nil 正常返回。返回 app 为 nil、error 也 nil 不会因 app 缺失被拒绝（I18–I22）
- 成功只表示这层完成了打开请求且没有报告 error；不证明歌曲已播放、频道已切换、网页已加载，更不证明邮件已发送

## 6. 独立实现边界（R，非原始实现）

建议拆成以下接口责任，而不是照抄重建文件：

- **RegistryStore**：持有 exact bundle → 有序 Intent 数组。Intent 带 name、释义、required、optional、纯 builder 引用；保持原始数组顺序
- **IntentDispatcher**：独占上述查找、presence 检查、一次 builder、一次 opener、成功后返回 URL 的流程。外层只编码返回值，不再次打开
- **URLBuilder**：纯计算，可注入兼容 Foundation 的 URL/Components 与编码器。参数来源未通过外层类型验证时，外层的错误归属另行定义
- **QuietOpener**：封装应用 URL 解析、固定配置、两条互斥 open 路径、回调与 5 秒等待；可用测试替身模拟 callback/timeout，不需要打开真实应用
- **错误桥接**：保留 invalidArg/internalError 与必要消息字段，交给所在入口已有的 envelope/MCP 映射；不要把本章内的 Swift 分类擅自变成一种新 JSON-RPC 编码

兼容模式与安全策略应分开声明：若产品要额外限制 URL scheme、拒绝可疑地址或要求交互确认，属于独立实现的显式策略层，不能称为 .153 中已发现的原生校验。相同请求重试可能再次打开，应由外层对是否重试作明确决策；本次未发现可声明为原生 dedup/idempotency 的证据。

## 7. 合成验收设计（R；均未运行目标）

测试替身记录 builder 调用次数、传入完整字典、Workspace 方法、URL 数量、preferred bundle、配置值与 completion 时序。所有字符串均用新生成的合成值，地址采用 example.invalid，不复制业务对象标识或真实通讯内容。

|编号|输入／替身条件|必须断言|
|---|---|---|
|IT-01|注册 bundle 精确名称与仅大小写变化的近似名称|精确查找；近似名称不别名化；intents(for:) 未注册给 []，dispatch 未注册报 invalidArg|
|IT-02|bundle 命中，intent 未知|不调用 builder/opener；known intents 按 registry 数组顺序，以 `, ` 连接|
|IT-03|两个 required 均缺失，随后仅缺第二项|按 required 顺序报告首缺；builder/opener 均为 0|
|IT-04|required key 的值为 ""；选用可记录参数的 stub builder|presence 检查放行；stub builder 收到空串，不提前发“缺参数”|
|IT-05|required 齐全，附加未列出的键|dispatcher 不统一拒绝；完整字典传入一次 builder|
|IT-06|builder 返回 nil|invalidArg 的 URL 构建错误；opener 0 次|
|IT-07|builder 返回 URL，opener 成功|builder 1 次、opener 1 次；返回同一 URL；HTTP/MCP 外层绝不再次打开|
|IT-08|builder 返回 URL，opener 抛错|保留 opener 错误，正常返回值不存在；不得自动 retry 或第二次 open|
|IT-09|preferred bundle 对应应用 URL 存在|仅指定应用 openURLs 被调用；数组只有 1 个 URL；通用 openURL 为 0|
|IT-10|preferred 为 nil 或应用 URL 未查到|仅通用 openURL 1 次；不作为“bundle 未注册”的同一错误|
|IT-11|指定应用打开 completion 返回 error|internalError，含错误描述；通用 openURL 仍为 0|
|IT-12|所有打开路径|三个配置均 false；静态断言不能替代真实焦点验收|
|IT-13|completion 在期限内 error=nil/app=nil|此层成功；不追加 app 非空条件|
|IT-14|completion 未在期限内发生|以 5 秒门槛返回超时 internalError；已提交的打开不重试、不声称撤销|
|IT-15|同一 callback 顺序调用两次|只 signal 一次；测试不把该布尔当作未证明的并发锁|
|IT-16|route 缺失、route=""、route 为合成未知路由|依次得到缺参、builder nil、继续构建；无候选路由枚举拒绝|
|IT-17|song_id / playlist_id 使用非数字与空串|没有自造数字/非空校验；与兼容 Foundation 的 builder oracle 比对结果|
|IT-18|Music/Safari url、Spotify uri 为同一合成字符串|三者都走对应参数到 URL(string:)；不自加 host/scheme 校验、补前缀或改 URI|
|IT-19|编码器正常与模拟返回 nil|前者用编码值；后者保留原串；覆盖空格、中文、百分号与查询保留字符|
|IT-20|Mail 无参数、to 存在、四个 query 参数缺失/空串/任意组合|to 默认空串；queryItem 顺序固定 subject/body/cc/bcc；只省略缺失字段，不省略存在的空串|
|IT-21|Slack 合成 team/channel 含需编码字符|拼接顺序 team 后 id；每一值独立执行 Q；不复制真实 Slack 标识|
|IT-22|各 launch 与固定推荐 intent|只构建已列常量；Music 为 music:、Spotify 为 spotify:，其余斜线严格按样本|
|IT-23|.164 profile 仅装入既有元数据|允许验证名称/顺序/参数字段；不把 .153 执行测试结果标为 .164 通过|

Foundation 特征测试可以在受控 macOS 环境只构建 URL、不调用 Workspace；目标应用级验收应独立获得授权，避免播放、切换频道或打开真实邮件编辑器。需要实际用户动作成功率的测试属于下一层验收，不在本次静态读取结果中。

## 8. 未闭合项与不可扩大结论（U）

- .164 的 dispatch、各 URL builder、openQuietly、配置、timeout 与错误分支没有由本次 .153 证据证明
- 两版原始描述文字的 byte-exact parity 不在范围；本章只给必要功能释义和接口标识
- 外层命令参数类型转换、target 解析、安全检查、JSON/JSON-RPC 错误 envelope 由各入口章节负责；本章不凭内部函数签名臆造入口行为
- macOS/Foundation 不同版本对相对 URL、空串、Unicode、保留字符与错误文本的精确表现，尚无动态对照
- installed app 的 URL 注册、缺失应用时系统选择、目标应用是否接受 URI，以及执行后实际可见状态都未验证
- 配置为不激活不代表第三方 app 绝不激活；没有在此链中验证 focus-restoration 保证
- timeout 后 callback 仍可能到达；原指令无取消过程。竞态、进程退出、主线程调用限制与重复回调并发安全不在已闭合保证内

交付结果是带来源的功能规格与测试设计；不是可直接执行的替代实现，也不构成任何已完成目标动作的声明。
