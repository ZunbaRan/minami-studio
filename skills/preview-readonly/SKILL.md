---
name: preview-readonly
description: 后台测试Preview打开面板与图片阅读能力，并在路径输入受阻时保持安全退出。
---
# Preview 只读打开图片
## 前置条件
bundle com.apple.Preview；使用已知、只读图片路径。CX11只验证打开面板，尚未完成图片打开或缩放。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.Preview",depth:3})`记录已有窗口。
2. `press_key({bundle:"com.apple.Preview",key:"cmd+o"})`本轮可在后台打开NSOpenPanel。
3. 快照获取位置、搜索、取消、打开按钮；若路径输入/文件选择成功，再以窗口标题及图像确认。
4. 若有图像窗口，重新快照查找缩放按钮；只读缩放后恢复原比例，再关闭本轮窗口。
## 已踩的坑 / 不要做的事
- CX11 cmd+shift+g被suppressed；physical斜杠只返回typed但没有路径表单。没有把它记录成成功。
- 不通过Finder“打开”来强制激活Preview，也不启动其他GUI控制工具绕过被测MCP。
- 不对原图片做旋转、批注或保存覆盖。
## 验证点（怎么确认成功）
必须见到图片窗口与目标图像。NSOpenPanel出现只是部分成功。若没有图片，缩放未覆盖，明确记录。
## 清理
用当前“取消”AXButton关闭测试面板。CX11取消后Post-action screenshot unavailable，符合没有文稿窗口。
