# 按模块读到代码与验收

每模块沿同一顺序：职责→输入→状态→分支→输出/错误→清理→原代码→实现票→验收。这里是新整合的实现路线；完整字段和算法保留在14章与契约页中。不是产品实现，也未选择运行profile。

1. [控制面与守护进程](01-control-and-wire.md)
2. [AX引用身份与恢复](02-ax-reference-store.md)
3. [快照字段与差分基线](03-snapshot-and-diff.md)
4. [截图坐标映射与视觉引用](04-capture-mapping-ocr.md)
5. [语义动作与后台指针输入](05-pointer-and-ax-actions.md)
6. [键盘文本与焦点保护](06-keyboard-text-focus.md)
7. [stdio MCP与CLI适配](07-stdio-mcp-cli.md)
8. [宿主HTTP与模型结果管线](08-host-model-integration.md)
9. [PiP镜像与三种光标](09-pip-lens-cursor.md)
10. [Appshot图像与异步上下文](10-appshot-context.md)
11. [应用目录意图与原生扩展](11-app-usage-intents-extensions.md)
12. [原生HTTP MCP与OAuth高级模块](native-http-mcp/README.md)（独立 .153深入取证，按证据逐项适配 .164）
