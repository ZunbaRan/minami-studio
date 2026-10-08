# 作者报告的旧版探测与合成化转述

来源：用户提供 .153 `evidence/live-probes.md`，原SHA256 `e7f27399d633daaaded3931bd9aa419b122c2a4f2ecc0dd42bf923d58795779e`，全194行。本页不是原始逐字trace；真实应用/窗口标题、用户目录、PID/windowID、client ID、token路径与时间戳不随交付。无probe被本次重跑，全部AUTHOR_REPORTED。

| 原范围 | 保留的非个人技术观察 | 用法与限制 |
|---|---|---|
| 15–23 | helper自身版本字符串与TCC状态输出的示例形状 | 不代表宿主app版本，也不证明当前权限 |
| 25–42 | apps/windows/list_apps的字段形状 | 原个人内容省略；以schema和原构造函数为准 |
| 44–64 | 一次direct snap、disable_diff state和后续state的示例 | 不能推出连续两次snap会diff；部分摘要与原binary构造冲突 |
| 66–100 | 缺target/out/start坐标、未知key/ref、AX不支持等错误类别 | 可作为未来负例方向，不能把省略号当精确错误字符串 |
| 102–112 | 窗口point到pixel的2x样例以及maxWidth等比例缩放 | 一台机器的历史报告不覆盖混合DPI/所有OS |
| 114–130 | nativePiP first-frame false/null到true/age的转变 | 仅候选动态fixture，status字段另有ASM闭合 |
| 132–166 | nativeHTTP 14工具/initialize/resource/prompt名字 | 静态目录继续逐项核验；不附prompt内容或真实鉴权标识 |
| 168–188 | lens、monitor nilhotkey、appshot和shutdown摘要 | Appshot非空AX普通reply摘要与binary image-first冲突，需原始带id事件trace，不能优先摘要 |
| 190–194 | native工具名不等于daemoncmd | 以dispatch与tool.daemonCmd为准 |

合成验收可创建org.example.cu.fixture、窗口标题“Fixture A”、固定测试PID占位符和临时目录；这些都是未来夹具设计，不伪称历史真实运行。不得利用作者个人应用状态生成隐私测试数据。
