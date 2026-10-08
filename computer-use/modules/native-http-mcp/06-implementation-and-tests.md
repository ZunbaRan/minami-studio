# 独立实现 tickets、合成验收与工程 agent prompt

**默认选择状态：UNSELECTED。** 本页是来源驱动的设计与未来实施清单，不是当前已获批/已执行的产品实现。所有用例状态为 DESIGNED_NOT_RUN；本次完成的是原始静态取证与文档验证，没有运行目标或真实认证/桌面动作。

## 1. 选择门与最小顺序

实施前必须明确：目标是`.153历史行为`、`.164已闭合socket控制`，还是独立强化profile。默认不选择任何profile，不因交付技术包自动部署监听器、发token或更改系统权限。

建议依赖链：证据模型 → 不可变目录/错误类型 → fake-daemon RPC → auth state/时钟 → HTTP transport → registry intent纯函数 → opener隔离 → 安全策略差异说明 → 独立平台验证。高风险的真实OS输入最后才做，并且需另行授权。

## 2. 工程 tickets（全部 UNSELECTED）

| ID | 目标与范围 | 依赖 | 交付与退出条件 |
|---|---|---|---|
| NH-01 | 固定版本及来源模型 | 无 | 每条契约含P153/C164/R153/DESIGN/OPEN；fixture禁止将历史报告标成复测 |
| NH-02 | NativeToolRegistry14 | NH-01 | 单一目录驱动list/resource/call；保留name和daemonCmd；snapshot→get_app_state；required/enum与原始数组一致 |
| NH-03 | RPC方法与错误桥 | NH-02 | 请求id独立于native String id；解析/缺method/MCPError/CUError/unknown分开；fake daemon可验证0或1次调用 |
| NH-04 | AuthState与可注入Clock/Random | NH-01 | 分离startupToken/pendingCodes/grants/whitelist；无真实token入测试日志 |
| NH-05 | authorize / PKCE / token事务 | NH-04 | code60s、grant3600s；原子先消耗code；可选alma_arm_pid来源正确；换码不写startup文件 |
| NH-06 | SigningIdentity与whitelist | NH-04,NH-05 | signing读PID替身；内AND外OR；nilPID独立分支；不把属性读取称caller proof |
| NH-07 | loopback HTTP reader/writer | NH-03,NH-05 | 处理碎片header/body和contentProcessed结束；单次64KiB与总大小限额区分；强化限额单独标DESIGN |
| NH-08 | 服务生命周期与控制层 | NH-04,NH-07 | 按选定版本保持start幂等/stop/count/null；所有文件错误可观察；权限/端口窄化分支可测试 |
| NH-09 | Intent registry与纯builder | NH-01 | 精确bundle/name、required presence、有序元数据；URL特征测试；完整见IT-01–IT-23 |
| NH-10 | QuietOpener隔离边界 | NH-09 | 假Workspace验一次open；fallback只用于未解析应用；5s超时不重试；禁用真实副作用fixture |
| NH-11 | 安全强化profile差异 | NH-05,NH-07,NH-10 | 列出redirect/caller/Origin/rate/file等策略与历史差异；不混入兼容结论 |
| NH-12 | 原始样本与独立实现对照审计 | NH-02…NH-11 | 逐项报告静态支持/合成测试/真实平台观测；OPEN未闭合禁止宣布full parity |

禁止替代交付：把重建MCPServer.swift整份复制后只修编译错误；以标准库默认行为替代原始有证据的边界；以“.153/.164大概一致”跳过逐项证明。

## 3. Auth 合成验收矩阵

全部只使用fake clock、fake signer、内存map和synthetic secret。实现完成后才执行独立实现的单元测试；不以这些用例授权调用原产品端口。

| 用例 | 输入/动作 | 期望的版本限定断言 |
|---|---|---|
| AU-01 | 已知startupToken，空grant map | .153认证通过；不调用grant校验或signer |
| AU-02 | 非startupToken但有效grant | .153通过grant分支；不重新查PID签名 |
| AU-03 | 未知/过期bearer | 401 invalid/expired；无daemon调用 |
| AU-04 | 缺header或非Bearer前缀 | 401 missing bearer；精确保留LF；大小写/空白变体按原分支另测 |
| AU-05 | response_type非code | authorize拒绝；pending count不增加 |
| AU-06 | 无S256或空challenge | authorize拒绝；无302 |
| AU-07 | 空redirect | authorize拒绝；不能把空串作为有效redirect |
| AU-08 | 无alma_arm_pid、无法解析pid | pending.armPid=nil；兑换不调用signer/whitelist |
| AU-09 | 可解析alma_arm_pid | pending保存Int32；兑换使用该字段，不读token表单pid |
| AU-10 | 60s前/恰好边界/之后兑换 | 固定时钟核对比较运算；不写300s常量 |
| AU-11 | 两个线程兑换同一码 | 只有一次removeValue取得record；至多一个grant |
| AU-12 | 已消耗code再兑换 | invalid-grant类别；不能重新发token |
| AU-13 | 错redirect/verifier/client后重试 | 首次若已到removeValue，code已消耗；不能恢复pending |
| AU-14 | token client_id缺失/空/非空匹配/非空不匹配 | .153缺失或空跳过非空比较；非空按pending.clientId精确比较 |
| AU-15 | PKCE字节含需base64url转换字符 | SHA256→Base64→+/-、/_、去padding；不能比较普通Base64 |
| AU-16 | PID条目、team条目、bundle条目与复合条目 | 同条目各已设字段全匹配才通过；多条目任一通过即可 |
| AU-17 | identity全空条目 | 不匹配；控制入口应先拒绝其添加 |
| AU-18 | whitelist到期/未到期/无限期 | 到期不匹配，按原Date比较边界；未自动从list消失 |
| AU-19 | PID-only条目且signer无team/bundle | 按已证明PID-only匹配执行，不自加全局签名必填 |
| AU-20 | 成功换码 | grant expiry=now+3600，expires_in3600；startup文件写计数0 |
| AU-21 | grant恰好expiry与after-expiry | .153原比较为now>expiry；过期取用移除，计数随后变化 |
| AU-22 | deny_all后已有grant | 清空whitelist，不能自动宣称grant撤销（C164已闭合清理范围） |
| AU-23 | status含过期但未访问grant | count是原map数量；不是实时有效数 |
| AU-24 | attacker-like pid字段覆盖尝试（synthetic） | token表单pid不成为授权来源；测试保持纯内存，无攻击真实系统 |

## 4. Transport、RPC和目录合成验收矩阵

| 用例 | 输入/动作 | 必须断言 |
|---|---|---|
| RP-01 | CRLFCRLF跨多个read片段 | 累积完成前不dispatch |
| RP-02 | body少于content-length且未EOF | 继续读取；不要把单次片段当完整JSON |
| RP-03 | 未完成header/body时EOF | 连接终止；不制造成功 |
| RP-04 | header非UTF8 | 按400错误分支，无业务副作用 |
| RP-05 | 不同header key大小写 | 规范为lowercase后查authorization/content-length |
| RP-06 | 64KiB以上总body由多次小块组成 | 不把单次receive上限误作既有总limit；强化limit另设profile |
| RP-07 | malformed JSON vs数组顶层 vs缺method | 区分-32700、-32600 Invalid request、-32600 Missing method |
| RP-08 | JSON-RPC String/number/null/missing id | 保留已证实Any?路径；未闭合类型变体列OPEN，不套native String规则 |
| RP-09 | initialize不同请求protocolVersion | .153响应固定2024-11-05；不回显 |
| RP-10 | notifications/initialized无id | .153成功后HTTP200 {}；不照搬stdio零回复 |
| RP-11 | tools/list与resource列表 | 同一immutable registry；数量14、顺序和schema一致 |
| RP-12 | 名称app_command/type/press/mcp_stop/shutdown/appshot_capture | 全部unknown tool，fake daemon调用0次 |
| RP-13 | snapshot_window | 内部cmd精确get_app_state；不得snap |
| RP-14 | screenshot out vs output_path | 目录required只有out；不能从重建继承错误名称 |
| RP-15 | click枚举与计数 | middle存在，coord_space顺序screen/screenshot，click_count1…3 |
| RP-16 | scroll | pages类型integer/min1；required ref,direction |
| RP-17 | pip_open | 6properties全部保留，不降成只window_id |
| RP-18 | 成功daemon result | 单一text content、isError=false；不无端添加image/playbook |
| RP-19 | CUError vs MCPError vs普通Error | -32000 vs原MCP code vs-32603；不能统归500 internal文本 |
| RP-20 | 未挂接daemon | -32000 Daemon not attached，0次dispatch |
| RP-21 | 查询重复键/非法percent/加号/畸形Content-Length | OPEN：建立差异测试，先静态闭合再决定兼容期望 |
| RP-22 | send callback错误/stop并发 | DESIGN：资源释放确定，无立即cancel截断响应；不声称原产品全部竞态已通过 |

## 5. 生命周期合成验收矩阵（C164）

- LC-01：port省略、0、65535、-1、65536；超范围回退.any，不统一trap
- LC-02：running时再次start新端口/路径，返回原状态，零次重写token
- LC-03：token_path缺失与空串区分；HOME缺失走NSHomeDirectory
- LC-04：文件写失败、bind失败、2s超时可观察；不生成假success
- LC-05：status十字段；停止后port0、url/oauth_base null；token内容永不返回
- LC-06：allow无identity报错；空team string通过presence；重复allow追加
- LC-07：TTL省略null、0和负值保留；arm_peer缺TTL=120
- LC-08：PID窄化超界原始trap和独立强化版安全拒绝须分profile，不能混淆
- LC-09：deny_all只清whitelist；stop不unlink、不强称全授权撤销
- LC-10：entries保留null、Unix epoch秒、插入顺序；不由list触发未经证明的过滤

## 6. 可交给工程 agent 的独立实施提示（不是产品原 prompt）

> 以下提示是本次新写的工作说明，选择状态仍为 UNSELECTED。只有用户后续选择具体任务与环境后才用于实施。

```text
任务：实现独立 Native HTTP MCP 模块中明确选定的 tickets。先复述选定版本profile、范围和不确定项，未选定时停在设计评审。不要启动或执行提供的 Alma 二进制，不复制 reconstructed/helper/MCPServer.swift，不读取真实token文件，不发真实桌面动作。

以本模块的 P153 / C164 契约及原始片段为依据。维护一份不可变14-tool registry，name与daemonCmd分离；未知name绝不dispatch。HTTP/native/stdio三层参数和返回结构分开。snapshot_window映射get_app_state，screenshot必填out。

认证分离startup bearer与OAuth access grants。PendingCode60s，AccessGrant3600s。authorize里的可选alma_arm_pid写入pending；token兑换只从pending取该PID。先原子consume code再后续验证；成功换码不得写startup token文件。Whitelist单项内AND、多项OR。签名属性查询不得称为HTTP连接身份认证。额外强化安全措施单列差异profile。

采用fake clock、fake random、fake signer、fake daemon、fake token store与fake Workspace构建可重复测试。Intent dispatch已经承担一次open，外层不重复；URL builder按原函数数据流而非描述自造校验。实施日志与fixtures不得记录secret、真实app/window/channel标识或截图内容。

实现之前给出文件计划、接口和测试；实现之后报告通过/失败/未运行的具体用例、OPEN、与历史样本差异。只能在获授权环境运行独立实现的安全测试。任何真实监听、登录、发token、权限变更、外部打开和桌面输入，按用户授权及确认规则单独处理。不得把单元测试通过称为原产品动态等价。
```

## 7. 完成定义与禁止的结论

文档阶段完成：每个原始片段可追到文件hash/line/VA；表内常量可复核；版本边界清晰；本包无秘密/二进制/完整prompt；相对链接可解析。当前产物达到的是该文档交付定义。

实现阶段完成：被选择的tickets全部通过相应fake测试和批准的平台测试；没有新增可达工具/隐式副作用；所有未测/OPEN清楚列出。没有进行目标动态对照时，禁止写“完整复刻验收通过”。
