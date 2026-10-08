> 来源：用户提供的 .164 研究资料 `analysis/mcp/REPORT.zh-CN.md`；原文件 SHA256 `48142212c09a9322c4c2829ad55a93f7761ee5f56ed00883eea7e12a51f571ef`；全文件 1–189 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Alma 0.4.164：官方样本、MCP 与 CLI 静态接口分析

## 结论与边界

本报告直接读取官方 macOS ARM64 更新包，未运行 Alma、其 CLI、MCP JavaScript 或 Mach-O helper。结论分为「代码可证」「待动态验证」。本文还原接口与控制流，不提供原始专有实现或提示词的长篇转载。仅此文不足以宣称复刻完成；native 的窗口事件、AX 生命周期、抓图几何、并发和取消需要 macOS 实测。

最重要的结果：
1. MCP 是 stdio JSON-RPC 入口，转接 Unix domain socket 的逐行 JSON 协议。CLI 则经本地 HTTP host API；两条路径不可混为一谈。
2. 23 个 MCP 工具已确认：11 个普通动作/状态工具、10 个 sky 兼容工具、2 个权限工具。没有公开 MCP OCR/bbox 工具。
3. 同一套 native 动作经不同包装会产生不同模型可见结果。普通状态返回独立 JPEG image block；sky 状态返回 JSON 文本里的截图 URL；动作后的补图则返回 image block。
4. ref-only 操作可以在 native 中定位元素，但包装层不会凭 ref 推导补图目标。未显式提供 bundle/PID，动作成功后可能只有文本。
5. `press_key` 的 delivered=false、menu_ax_press 被 MCP 保留为不同摘要；CLI 忽略该响应体而打印成功句。这是「工具层成功」不能代替「事件实际送达」的具体证据。
6. MCP 执行超时、MCP 请求取消、native 事件取消不是同一个操作。本包装未将 abort signal 或超时转成 daemon cancel。
7. 新样本 MCP 文件 SHA256 与旧 0.4.153 报告记录完全一致。该层能做字节级跨版本对应；native、host、CLI 均变化，不能沿用旧 native 地址。

## 样本证据链

- 官方首页：https://alma.now/ ，归档 evidence/home.html；1537–1546 行给出更新源 https://updates.alma.now 与 latest-mac.yml
- 官方 metadata：https://updates.alma.now/latest-mac.yml ，归档 evidence/latest-mac.yml
- metadata version：0.4.164；releaseDate：2026-10-06T05:52:23.497Z
- 下载 URL：https://updates.alma.now/alma-0.4.164-mac-arm64.zip
- 下载大小：489,040,837 bytes
- SHA256：2bca9d726ab88e3f68290d0aa82a231cbd0491d2242d6d1ddb638ad7bd236901
- feed SHA512 base64：lluVfJj9XNV3G0WRVloeWRXMeukHbkvhb+GWIEhMpYguBjQMdjVixvN9Bi/OxTw1EToTVHe1/8hG9EypK2BTSg==，已与下载内容完全核对
- 下载的是官方更新 ZIP，非实际启动安装；ZIP 的 Alma.app 静态解包。DMG 链接同时由 feed 证明存在，但本阶段不必下载第二份同版本容器
- App Info.plist 版本0.4.164；host最小macOS12；独立 helper com.yetone.alma.computer-use 最小macOS13，LSUIElement=true
- app.asar 使用自写 Python 数据读取器解析，header为(4,19468416,19468412,19468407)，内容基址19468424；共74,157条目录记录；未执行目标模块
- 主证据索引：evidence/sample-manifest.json、evidence/zip-inventory.txt、evidence/asar-inventory.json、evidence/component-hashes.json

以下简称：
M = extracted/Alma.app/Contents/Resources/cli/alma-computer-use-mcp.mjs
C = extracted/Alma.app/Contents/Resources/cli/alma
H = extracted/asar/out/main/index.js
N = extracted/Alma.app/Contents/Resources/Alma Computer Use.app/Contents/MacOS/AlmaComputerUse

组件SHA256：
- M d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976
- C 2f156839ea5aec2eb4bc8bc117ff2bbd0ed73cae00d090ad04ea19266e506eeb
- H df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175
- N 453d60872ac801f44497b34d2f68edf7d0fee497420ac44c5d05d785c62b8551

## 1. 传输与生命周期（M:35761–35929,36506–36514）

调用链：agent MCP client → stdin/stdout JSON-RPC → Zod input校验 → 工具handler → DaemonClient → Unix socket JSONL → native response → MCP content。CLI链另见后文。

### helper定位与socket隔离
- 环境 ALMA_CU_HELPER 的现存路径优先；其次 ALMA_RESOURCES_PATH 加 helper bundle内的固定路径；再寻找相对CLI目录的三个computer-use候选目录
- socket位于用户 Library/Application Support/Alma。定位到helper时，用helper**路径字符串**的SHA1前8位形成computer-use-<tag>.sock；不是按二进制内容hash命名。无helper路径则使用computer-use.sock
- 所以不同安装路径可能隔离daemon；同一路径升级的版本是否安全重连，要由host/native的版本清理逻辑补足
- 首次连接失败才尝试spawn；参数 daemon、--socket、对应路径、--idle-seconds、900；detached=false；stdin忽略、stdout/stderr管道，stderr转发
- 建连共享connecting promise；启动后最多4秒重试，每次失败等待100ms。这里没有独立的 connectOnce socket timeout；操作定时器从ensureConnected完成之后才创建

### 协议行为契约
- 请求结构：id（8随机字节的16位hex）、cmd、args；UTF-8 JSON后加LF
- 响应关联：id；ok为真时resolve(data)；否则创建Error(message)，附code和hint
- 单连接可挂多个pending请求；这是客户端并发能力，不能据此推断native是否并行执行
- readBuffer累积任意分片；按LF拆包；空行忽略；非法JSON忽略；未知/迟到id忽略
- 默认请求超时20秒；显式状态与post-action补图30秒
- timeout只删除pending并reject，不重发动作，不发送取消；因此超时后**操作是否已经发生未知**
- 连接close会拒绝所有pending并清空socket；未见close时重置readBuffer，因此断线边界是否可污染下一连接属于待测试的恢复边角
- 未见客户端帧大小限制、socket认证token或请求幂等键；socket文件权限、peer校验由native负责，本文不据此断言系统安全性质

## 2. MCP工具完整契约

通用Target：bundle:string?、pid:integer?、window_id:integer?。schema中三项都是optional，尽管描述称bundle/pid至少一个；普通动作normalizeTarget会过滤空bundle及非正PID/window，PID/window下取整。get_app_state另有自己的规范化。

下表是重述的schema和关键行为，不是导出的实现代码。问号表示可选。

| 工具 | 参数（除Target外） | native cmd / 特殊点 | M行号 |
|---|---|---|---|
| launch_app | bundle必填，activates:boolean?=false | launch_app；gated；只返回JSON文本，无补图 |35990–36006|
| list_apps | days:int?最大90，默认14 | 非正数回退14；无gated |36011–36023|
| get_app_state | Target，depth:int?最大20默认6；interactive_only?=true；screenshot_max_width:int?默认1280；auto_launch?=true | get_app_state，include_screenshot强制true，30秒；无gated；window需正数；depth负数回退6 |36029–36076|
| click | ref? 或 x:number?+y:number?；coord_space:screenshot/screen?；button:left/right/middle?；click_count:int?最大3；strategy:auto/physical/ax? | ref优先；坐标路径才转发bundle/PID；window_id不传动作，只补图用；show_cursor=true |36077–36116|
| perform_secondary_action | ref? 或 x?+y?；coord_space? | ref优先；show_cursor=true；普通接口无action字段 |36118–36145|
| drag | start_x/start_y/end_x/end_y:number必填；coord_space?；button? | drag；转发bundle/PID但非window_id；show_cursor=true |36147–36175|
| type_text | text:string；ref?；input_method:auto/physical/unicode/ax? | type_text；默认auto；返回JS UTF-16 length，不等同Unicode字符数 |36177–36198|
| press_key | key:string | press_key；delivered=false与via=menu_ax_press特判 |36200–36220|
| scroll | ref:string；direction:up/down/left/right；pages:int?最大20 | scroll；pages非正回退1；show_cursor=true；native payload无bundle/PID |36222–36242|
| set_value | ref:string；value:string/number/boolean | set_value；native payload仅ref/value |36244–36258|
| select_text | ref/text必填；prefix?/suffix?；selection_type:text/cursor_before/cursor_after? | select_text；默认text；native payload无bundle/PID |36260–36285|
| sky_list_apps | 无 | list_apps；映射app信息；无gated |36294–36310|
| sky_get_app_state | app:string；disableDiff:boolean? | get_app_state(bundle=app,disable_diff)；gated；默认20秒，不是普通入口的30秒 |36312–36342|
| sky_click | app；element_index:int?或x/y?；click_count:int?；mouse_button:left/right/middle/l/r/m? | ref来自map；坐标强制screenshot；没有strategy、window_id；count没有最大3约束 |36344–36367|
| sky_press_key | app/key | keysym别名规范化后press_key，保留delivered/菜单区别 |36369–36386|
| sky_type_text | app/text | type_text；无ref/input_method |36388–36397|
| sky_scroll | app/element_index:int/direction:全拼或u/d/l/r；pages:number? | pages直接默认1；无integer/max20限制 |36399–36417|
| sky_set_value | app/element_index:int/value:string | 与普通value联合类型不同 |36419–36428|
| sky_drag | app/from_x/from_y/to_x/to_y | 强制screenshot坐标，映射start/end字段 |36430–36446|
| sky_perform_secondary_action | app/element_index:int/action:string | 将action直接传native；普通接口没有此参数 |36448–36457|
| sky_select_text | app/element_index:int/text；prefix?/suffix?；selection_type? | 先map index→ref，再select_text |36459–36481|
| permissions | 无 | permissions；无gated |36483–36492|
| grant | 无 | grant；无gated；后续需调用permissions确认 |36494–36503|

所有普通动作均有Target用于补图，但只要动作是ref路径，就不一定把这些目标参数发往native。因此复刻时要明确「动作目标」与「补图目标」是两个概念；不应盲目把两者当作同一OS实体。

## 3. 状态、截图与diff

### 普通get_app_state（M:36042–36076）
- 请求固定include_screenshot=true；返回的res被浅复制后删除screenshot字段，其余内容序列化为JSON text block
- 若bundle有匹配playbook，在上述状态之前附加playbook；普通入口每次都附加，而非once
- 若screenshot.path存在，读取本地文件，base64作为image/jpeg block；读失败转为额外文本
- 没有path时，若screenshot_error有值，追加错误文本。不会用data_url/url兜底
- 本包装没有OCR请求，也没有AX失败后自动OCR的分支；AX空时仍可能返回截图，之后由模型按像素操作。是否native内部有OCR不能由此否定
- 删除screenshot对象意味着宽高、比例等截图元数据未必作为原对象送到模型；window/elements等其它字段保留。其精确结构取决于native

### post-action补图（M:35930–35976）
- normalizeTarget后的bundle或PID至少一个才抓图；仅window_id或ref不会抓
- 调get_app_state，include_screenshot=true、interactive_only=true、depth=0、screenshot_max_width=1280，timeout30秒
- 不传auto_launch和disable_diff，故依赖daemon默认行为；已由native确认get_app_state(depth0)会经过diff并条件抓图/更新mapping；direct native snap不经过diff
- 读取screenshot.path并产生JPEG image block；不可读/无path转文本，原动作结果不会因此标isError
- 除press_key特判外，多数动作忽略native成功返回data，摘要只能证明daemon调用没有抛错，不能证明输入内容实际改变

### sky状态与索引（M:35580–35626,36287–36342）
- 每个MCP进程维护skyIndexMap，以调用者的app字符串为key；同一程序别名可能形成不同缓存
- 无既存indices或disableDiff=true时强制full tree；否则请求daemon差分默认值
- 原样信任elements_are_diff、unchanged_element_count；diff时carryOver旧ref数组，新增ref追加稳定显示index；非diff时从空数组重建
- 仅带string ref的元素进入显示；role去AX前缀；label优先title、description、value、role_description中的非空string；数字/boolean value不会被选为标签
- bounds四舍五入成位置尺寸；只呈现focused和disabled标记；这是一种有损文本视图，不是完整AX树
- 包装没显示处理删除ref/tombstone；已有ref如何被native失效不能从稳定index推断
- sky_get_app_state返回**单个text block**内的JSON对象，含app、screenshot:{url}|null、text；URL取data_url优先、url其次，不读取path。因此native仅给path时sky截图为null
- sky状态playbook按已解析bundle在该MCP进程内once；PlaybookOnce.reset定义存在，但业务段未见调用
- skyRefFor只校验map存在及index范围，不核对OS元素是否仍有效

## 4. 权限、活动、日志与错误

M:35666–35759的wrapper行为：
- ALMA_API_URL默认http://localhost:23001
- check_approval是GET，bundle与可选app_name为query；无bundle、HTTP非2xx、网络/解析异常时wrapper按approved=true处理
- gated只用args.bundle；它不会根据PID/ref解析bundle后再次检查。拒绝时返回普通text content，没有isError:true
- 这仅证明此MCP包装的可用性优先/fail-open行为。host配置是否限制工具、HTTP route是否另有gate、native TCC和权限是否允许动作，由另层证据确定；不能直接写成产品整体绕过权限
- notePipActivity与logAction是fire-and-forget的HTTP POST，错误吞掉；因此日志/PiP不是动作执行的同步屏障
- 日志包含tool_name、bundle_id、pid、原args、duration_ms和错误文本；某些args可包含用户输入文本；日志存储/裁剪/访问控制需host确认
- gated成功后await focusGuardWarning；每30秒缓存focus_guard.arm_failures是否>0；查询异常清为false；警告不会取消动作
- SDK处理工具exception时返回text+isError:true（M:34722–34782）。daemon错误对象的code/hint虽然附加在Error上，普通tool exception包装只保留message；不得假设客户端收到完整structured native error
- gated拒绝与press_key delivered=false都不是isError工具异常。复刻test harness必须断言内容语义，不能只看MCP isError

## 5. 取消和超时分层

- SDK接收notifications/cancelled后abort request controller（M:33165附近），给handler传signal（33285–33323）
- handler promise完成后，如果signal已aborted，SDK抑制响应；这并不自动停止handler内部副作用（33324–33348）
- 本应用handler忽略_extra；sky handler不接extra；DaemonClient.call只收cmd,args,timeout，没有AbortSignal
- 因此「MCP请求已取消」最多在本层可证成停止返回结果，不可证成native按键/拖拽立刻终止
- timeout移除pending；迟到native response被忽略；此时补图可能未完成或操作已经发生，不能自动重试有副作用动作
- host整段任务停止、MCP进程终止、helper shutdown、macOS事件已经排队的剩余行为必须分别验证

## 6. CLI：独立HTTP路线与行为差异（C:13,58–80,8297–8773）

CLI默认HTTP同为localhost:23001。api()仅在HTTP非2xx退出错误；2xx解析JSON但不统一检查delivered或其它语义。

发现22个canonical功能命令（其中若干不在MCP公开）：status、doctor、grant、apps、launch_app、list_apps、windows、get_app_state、snap、click、perform_secondary_action、drag、type_text、press_key、set_value、type、press、scroll、lens、raise、shot、shutdown，加help共23项；另有launch别名。

关键差异：
- CLI get_app_state能--no-shot、--shot-out、--shot-max-width、--all；MCP普通状态强制截图且不让指定输出path（C8462–8506）
- CLI snap是AX-only独立命令；shot是独立抓图，默认/tmp/alma-cu-<timestamp>.jpg；MCP没有这些工具
- CLI click像素路径仅支持--pid，没有bundle/coord_space；ref路径有strategy；target/window验证强弱不同（C8549–8583）
- CLI type_text支持--bundle、--ref、--input-method；key只有--pid；其请求完成即打印成功文本（C8628–8659）
- CLI press_key明确忽略响应体（8657–8658）；不可用CLI输出作为事件送达测试断言
- CLI set_value把true/false/可转换number转型，否则保留string（8662–8677）
- type是ref+text+replace（默认true，--append设false）；press是ref+key；二者不同于自由键盘输入type_text/press_key（C8680–8703）
- --no-cursor只把show_cursor设false并传递给部分动作；其OS物理鼠标语义须native确认，不能把它当作禁止移动用户指针的开关（C8545）
- lens on/off/toggle经HTTP；toggle先POST空对象读取，再POST反值，不是原子toggle（C8718–8736）
- raise、shutdown为可到达CLI/HTTP动作，未出现在23个MCP注册工具中。MCP描述里的不前置约束不能替代检查native raise行为（C8739–8768）

## 7. 面向复刻的实现边界与验收建议

应分四层重建：
1. Native契约：target解析、snapshot/ref生命周期、AX遍历与diff、window截图/坐标变换、后台事件分派、投递结果
2. Daemon服务：request id关联、队列/并发策略、断线/超时、idle寿命、权限、结构化错误
3. Adapter：普通MCP、sky兼容、HTTP/CLI明确各自参数、图片载荷、错误与缓存差异；这些差异可能是兼容测试的重要观察面
4. Host UX：设置批准、动作日志、任务停止、PiP/Lens/AppShot与模型截图的分离

建议用独立写成的、无目标代码依赖的fixture检验：
- JSONL拆包/合包/非法行/未知id/迟到响应/连接关闭
- 超时后禁止自动重放动作；cancel通知后仍要观察native是否继续
- ref-only与bundle/PID补图差异；window_id只参与补图产生的可能目标偏差
- get_app_state无path、有path、路径读取失败；sky仅path、有data_url、有url的三个形态
- diff增加/修改/删除、full reset、不同app别名、snapshot后post-action depth0对refs的影响
- press_key delivered=false、menu_ax_press、普通成功三类；MCP与CLI结果不等价
- 负数/0/小数/超上限参数，尤其普通与sky click_count/pages schema差异
- 权限服务器离线、非2xx、严格拒绝、PID-only/ref-only；只在隔离测试环境并经授权检查，不对真实用户应用执行

静态已补齐OCR触发门槛、ref删除/恢复和多peer并发；仍未运行证明native真实命中率、零瞬时焦点抢占、OCR识别实效、ref运行竞态、异步取消副作用、Retina/多屏几何、TCC体验和PiP/Lens/Appshot资源释放。旧版本动态证据应明确版本，不能伪装成当前样本实测。

## 附加一致性校验

ASAR header SHA256 6b421efa8ddf526d11d833f95ae98f34c875473ffb0be76630f2615e5d1a8e11 与 Info.plist 的 ElectronAsarIntegrity 匹配；main、preload、package.json 内容hash也分别与ASAR内建integrity记录相符（evidence/asar-integrity-check.json）。这证明提取一致性，不等于在Linux上完成Apple签名信任或公证验证。

原创机器契约：protocol-catalog.json、source-locators.json；13组合成验收向量：synthetic-conformance-vectors.json。向量尚未针对Alma或复刻程序执行，不得列为已通过测试。
