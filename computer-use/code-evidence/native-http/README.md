# Native HTTP 与 Intent 原始证据索引

默认UNSELECTED。这里是有界原始证据，不是可执行源码或完整SDK。除精确摘录/最小数据块外的中文标题、注释与解码均是本次研究说明。版本均为Alma0.4.153 arm64，VA为未slide地址；C164结论只在模块正文按既有专题来源引用。

原始路径和整文件SHA256在每页首或每项下，片段给原行号、函数符号、VA、hash。二进制常量页给slice/universaloffset，binary没有文本行号。没有执行目标、复制完整二进制/SDK、上传或附带私人探针/秘密及原始长prompt。

## 摘录文件

- [OAuth 原始边界片段](01-oauth-excerpts.md)
- [工具目录及派发门原始片段](02-tool-registry-excerpts.md)
- [HTTP 与 JSON-RPC 原始片段](03-http-rpc-excerpts.md)
- [白名单与被提供 PID 签名属性的原始片段](04-whitelist-excerpts.md)
- [服务生命周期与令牌文件原始片段](05-lifecycle-excerpts.md)
- [.153 静态目录原始数据最小片段](06-static-array-bytes.md)
- [initialize 元数据原始常量片段](07-initialize-constant-bytes.md)
- [AppCommandRegistry：.153 原始证据摘录](intent-excerpts.md)

## 使用方式

1. 先读[模块入口](../../modules/native-http-mcp/README.md)确认版本和证据标签
2. 依据行号回到原件，或逐字核对本页摘录；不得用中文研究性概括代替机器指令
3. 常量解码由原数据与消费callsite共同支持；字符串池相邻并不足以证明字段关系
4. 源路径仅用于复核，不要求在交付ZIP中附完整原件
5. 这些静态片段不构成真实认证、桌面或目标应用验收通过的声明
