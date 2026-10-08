# 来源完整性、修正清单与未闭合项

## 1. 工作范围

默认UNSELECTED。本模块仅写入Markdown设计、合成验收说明和有界原始片段。原始输入只读。没有上传文件、执行Alma/helper、运行旧重建代码、监听端口、兑换真实授权码、读取真实token文件或操作桌面。

本页路径是来源定位文本，不是要求读者拥有同一绝对工作目录。交付包内的原始证据见[证据索引](../../code-evidence/native-http/README.md)。原始二进制只作只读数据源，不随包交付。

## 2. 整文件来源指纹

| 来源 | SHA256 | 用途 |
|---|---|---|
| `comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/disasm.annot.txt` | `543703cdfb815fb3bcab348eff7212e0eb787b7f5d3d3d8a95e7bf2f0ad330e5` | P153原始静态 |
| `comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/AlmaComputerUse.bin` | `b4d8e4257c025650c60d8b173ca51080905ed2f38018c439e1f6bc2a7d7801a3` | P153原始静态 |
| `comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/strings.txt` | `a4e57b91bdf03126e561c900dda971d165c7aba7080e5851cc74aba2a46df2f9` | P153原始静态 |
| `comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/symbols.demangled.txt` | `db3ea7e569dc14040708d2dad9d0cb2872c0f970de10d5025dd7d0ec1313eb3a` | P153原始静态 |
| `comparison_cu_inputs/extracted/alma-computer-use-0.4.153-reconstruction/alma-computer-use-0.4.153/evidence/live-probes.md` | `e7f27399d633daaaded3931bd9aa419b122c2a4f2ecc0dd42bf923d58795779e` | R153作者历史摘要，仅脱敏转述 |
| `comparison_cu_notes/host_mcp_comparison.md` | `bb7b0eb1955723258d375224a33cc78ed27de546c8e845e0398c56fd993973f8` | 校准入口，不替代原始证据 |
| `comparison_cu_inputs/extracted/Alma_0.4.164_复刻契约与验收语料/analysis/native-snapshot/MCP_CONTROL_EXTRA_CONTRACTS.md` | `a8560c4e860124ba726ac1b8e32ca638cd4b6bd04609df0c182ef97840a676bb` | C164既有专项契约 |
| `comparison_cu_inputs/extracted/Alma_0.4.164_复刻契约与验收语料/analysis/native-snapshot/APP_INTENTS_METADATA.md` | `fb565814c4326ac15d38d414cfe560f770e37f484360d7d304f0ef38f96e367f` | C164既有专项契约 |
| `comparison_cu_inputs/extracted/Alma_0.4.164_复刻契约与验收语料/contracts/intent-metadata.json` | `3ad9444279c7756559ac050656ac47db54f66b2ad5bc021f1c567a5fea9a4631` | C164既有专项契约 |

## 3. 原函数地图

D153的完整来源及SHA在上表；所有VA只适用于.153 arm64。原始函数带Swift修饰名，证据页逐段保留完整符号；本表仅给可读短名。

| 函数/块 | 原始行范围 | 核对内容 |
|---|---|---|
| WhitelistEntry.matches | 84191–84365 | 过期、PID/team/bundle AND及至少一个identity |
| MCPServer.start | 84533–85084 | 启动token文件、loopback interface、2s绑定deadline |
| statusSnapshot / stop | 85085–85383 / 85641–85731 | 字段/连接停止局部交叉；完整.164控制契约另列C164 |
| readRequest | 86066–86692 | 累积header/body、Content-Length、65536单次read |
| handleRequest | 86693–88192 | 路由、bearer二选一、JSON-RPC分类错误 |
| serveAuthorize | 88193–89040 | optional alma_arm_pid、60秒pending、302构造 |
| serveToken | 89041–90714 | consume-before-check、PKCE、optional PID、3600秒grant |
| isValidAccessToken | 90715–90878 | grant查表、到期比较及删除 |
| dispatchMCP | 90879–92160 | 方法表、initialize固定常量 |
| callTool | 92161–92737 | immutable registry名称门、cmd映射、text输出 |
| readResource | 92738–93276 | catalog URI与未知URI |
| jsonSanitise | 93277–94092 | 已定位，全部类型分支尚未闭合 |
| tools initializer | 94093–99782 | 14tool、schema keys/types、required/enum/范围 |
| add/clear/list whitelist | 99822–100394 | 记录生命周期，clear不等于grant撤销 |
| jsonObject | 103665–103748 | schema type/properties/required |
| generateToken / writeTokenFile | 103749–104061 | 文件职责与chmod；随机源质量完整评估尚未闭合 |
| send / parseHeaderBlock / parseQueryString | 104354–105256 | close/header大小写/percent decoding |
| pkceS256 / SecCodePeer | 105257–105785 | Base64URL变换、PID查询签名信息 |
| AppCommandRegistry | 45404–48162及后续thunks | 精确查表、15builder、单次open、配置/timeout |

## 4. R153 作者报告的合规使用

作者live-probes摘要报告过启动状态、随机客户端标识、token文件位置、14tool列表、initialize能力、资源与prompt名称、允许/查询白名单。这里只转述功能现象，不复制作者用户名路径、端口、随机OAuth标识、进程/窗口标识、token、应用标题或通讯内容。该摘要包含省略和解释，不能作为原始HTTP逐字节golden fixture，更不能标成本轮或.164复测。

目录名称、schema常量、initialize常量、OAuth期限与PID来源已另找P153原始静态证据；其证据强度不能由历史live标签代替。仍是R153的项目必须保留该标签。

## 5. 对不可靠重建的拒绝清单

- PendingCode300s、grant无限期：与原字节常数冲突
- token表单pid必填、所有peer已认证：与optional authorize字段及nil路径冲突
- 换码写startup文件：没有原始直接调用，职责混淆
- callTool未知名default直通：丢失原始14目录名称门
- HTTP工具app_command、截图output_path、scroll.pages:number：与原始目录冲突
- type_text/scroll漏required、click漏middle/maximum3、pip_open只1字段：目录不完整
- initialize回显protocolVersion、server version0.1.0、resources能力不同：与P153常量冲突
- send后立即cancel替代contentProcessed：丢失原始异步完成边界
- dispatch intent后再open：重复副作用
- 把success/open配置当作绝对后台不抢焦点保证：扩大静态证据含义

拒绝这些错误不表示发现原产品漏洞；其中多项是研究重建代码偏离原件。安全风险评价必须明确被评价对象。

## 6. 未闭合清单与下一次取证停止条件

| OPEN | 需要的证据 | 何时可收口 |
|---|---|---|
| .164原生HTTP/OAuth整个支路 | 对应.164函数、静态数据、版本匹配 | 每条关键行为独立对照后，而非复用.153VA |
| 完整HTTP畸形输入 | 全parser分支 + 授权环境的合成报文测试 | framing/body/duplicate头/非法长度/percent/加号都有确定结果 |
| OAuth完整错误字典和全部状态清理 | 原始静态字典、code/grant/control所有写入点 | 失败类别与clear/stop/start/expire行为逐一闭合 |
| caller identity安全保证 | 连接归属证明与威胁模型 | 不能仅有自报PID的签名查询 |
| schema逐字描述和序列化顺序 | 小段精确目录输出/原始常量 | 如产品确需字节级兼容，另行范围批准；本包默认仅语义 |
| jsonSanitise完整类型表 | 整函数类型case数据流 | null/number/Date/URL/Data/异常值等逐项闭合 |
| 资源订阅/取消/会话语义 | 对应处理分支/消息流 | capability声明与真实功能分开核验 |
| token随机源与文件安全 | generateToken原始全过程、文件创建/权限/竞态 | 不能只用chmod0600作为完整安全保证 |
| 跨macOS/目标app行为 | 受控测试与明确授权 | FoundationURL/focus/真实app响应，不用静态配置代替 |

本包本次收口范围是静态文档与证据整合，不是产品运行或上述OPEN自动实施。需要动态观察时由用户选择任务并授权环境；没有该选择前保持UNSELECTED。

## 7. 本次文档验证记录

2026-10-07，静态文档验收：

- 本模块17个交付文件全部为Markdown；原始来源没有写入变更
- 107段反汇编有界摘录核对：62段带原行号摘录逐行与source匹配并重算片段SHA256；另外45段Intent连续原文也独立逐行复核匹配
- 带行号摘录核对1835原行；Intent连续原文核对1241原行。行数表示摘录总量，不去重，也不代表整个二进制已审计
- 所有本模块相对Markdown链接在当前整合目录可解析
- 未见作者探针用户名路径、随机OAuth标识、原始窗口/进程标识或完整产品instructions/prompt；公开registry bundle与协议固定名字保留用于接口准确性
- 上述通过仅指文档、来源定位和隐私检查。AU/RP/LC/IT测试用例全部仍为DESIGNED_NOT_RUN，没有真实运行结果
