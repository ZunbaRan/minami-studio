---
name: save-dialog-handling
description: TextEdit 后台保存或清理自有新文稿，且保存快捷键被抑制时使用。
---
# TextEdit 保存表单
## 前置条件
只保存已获授权的自有文稿；记录 window_id。CX03实测成功保存RTF到桌面，文稿随后关闭。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.TextEdit",window_id:W,depth:3})`，核对正文前缀。
2. `press_key({bundle:"com.apple.TextEdit",window_id:W,key:"cmd+s"})`若 suppressed，停止重复发送。实测替代入口：`click({bundle:"com.apple.TextEdit",window_id:W,ref:CLOSE,strategy:"ax"})`，打开保存/删除/取消表单。
3. `set_value({bundle:"com.apple.TextEdit",window_id:W,ref:NAME,value:"CX03_Field_20261009.rtf"})`。
4. 点“位置”AXPopUpButton；菜单展开后 `get_app_state({bundle:"com.apple.TextEdit",window_id:W,depth:6})` 才能拿到“桌面”AXMenuItem。点击该项，再点保存按钮。
5. 通过允许的只读 `ls`、`md5` 和文件内容核实路径与内容。不要只信 click ok。
## 已踩的坑 / 不要做的事
- 初始位置可能是iCloud，不要默认落在本地桌面。
- 菜单深度4只露出AXMenu，深度6才露出菜单项；菜单未出现在单窗口截图不代表没有展开。
- 关闭按钮打开的是保存且关闭流程，不能假设保存后窗口仍在。
- AX set_value可能不标记dirty；CX03用type_text(input_method:unicode)写入后成功触发表单。
## 验证点（怎么确认成功）
CX03文件445字节，RTF实际含CX03_Save、中文、emoji；保存后窗口消失。核实目标路径、扩展名与正文。
## 清理
只对本轮文件在Finder移到废纸篓，不清空整个废纸篓。关闭自己新建的Finder窗口。CX03的Finder路径确认/右键阶段出现前台变化待归因，不能将该清理序列宣传为已验证的后台安全路径；出现焦点变化应记录并停止重复该路径。
