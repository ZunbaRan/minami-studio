---
name: notes-lifecycle
description: 后台建立并验证Notes测试笔记，处理AX输入、菜单与清理受阻时使用。
---
# Notes 笔记生命周期
## 前置条件
bundle com.apple.Notes，使用CX编号_前缀；先记录原笔记数。CX07原145，本轮新建后146。不要编辑既有内容。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.Notes",depth:3,interactive_only:true})`找“新建备忘录”按钮；strategy:ax点击。
2. 重新取AXTextArea；`type_text({bundle:"com.apple.Notes",ref:T,text:"CX07_Field_20261009\n中文记录与 emoji 😀",input_method:"ax"})`。
3. 验证正文AX值与列表标题，不能只信typed计数。
4. 列表cell需depth5；可用其AXShowMenu操作打开上下文。本文现场返回cannotComplete但截图确实开了菜单；随后必须重新快照。
## 已踩的坑 / 不要做的事
- 本轮无ref Unicode没有落字，AX ref路径成功。
- 普通click打开更多曾得到disabled的删除项；成功回退是对当前更多菜单按钮perform_secondary_action（AXShowMenu），再gas depth4，本轮得到enabled=true的删除备忘录。
- 上下文菜单的删除在截图可见，但depth6没拿到menuitem；像素点击只关闭菜单，Alma同样。最终通过工具栏更多的AX菜单项删除成功，列表cell菜单的像素删除仍未成功。
- 不反复加深树。一次清理探测depth7花16.8秒仍无菜单项，后续depth6超时30秒。回到低深度。
- 本轮列表scroll报AXScrollUp/DownByPage不支持；后续点击滚动条AXDecrementPage按钮两次，截图验证已回到顶部，完成浏览恢复。
## 验证点（怎么确认成功）
正文与CX列表标题一致；删除必须看到笔记数恢复且目标消失。空白正文、click ok、菜单消失都不算删除验证。
## 清理
已验证路径：gas depth3取当前“更多”AXMenuButton→perform_secondary_action({bundle:"com.apple.Notes",ref:MORE})→gas depth4→按当前title和enabled找到“删除备忘录”→click(strategy:"ax")。CX07最终146→145，目标消失并回到原Auto ok，保留原生最近删除副本。删除后原AXTextArea ref可能对应原用户笔记，立即停止写入。不要激活Notes或删除既有笔记。
