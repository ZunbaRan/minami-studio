---
name: background-menu-chords
description: 后台菜单快捷键被suppressed、需要决定是否换AX操作时使用。
---
# 后台菜单快捷键
## 前置条件
先快照目标app；始终保持用户前台。依据CX02/03/05/10和Alma对照。
## 推荐步骤（含具体工具调用示例）
1. `press_key({bundle:"com.apple.TextEdit",key:"cmd+n"})`本轮通过菜单AXPress新建窗口。
2. 检查文字返回是否NOT delivered/suppressed。被抑制后寻找具体控件ref：TextEdit保存可从本轮文稿关闭按钮进入保存表单；格式可点工具栏复选框。
3. Calculator的cmd+2与cmd+1本轮有效；每次菜单动作后重新确认window.id/模式。
## 已踩的坑 / 不要做的事
- TextEdit cmd+s、cmd+alt+f和Finder cmd+shift+n本轮后台被抑制；属于无enabled菜单持有者的正确语义。
- 本实现opt别名解析错误，真Alma接受；用alt可绕过解析，但不能让本来disabled的菜单派发。
- menu_shortcuts出现一个chord不等于它现在enabled。
- 快捷键是app菜单动作；window_id不能当作一定只影响那个文稿的保证。操作后先确认实际结果窗口。
## 验证点（怎么确认成功）
返回派发结果，加上新窗口、模式变化或内容变化证据。不能因pressed/click ok就跳过效果检查。
## 清理
关闭本轮新建窗口、恢复本轮改的视图/模式。禁止激活app补救suppressed。
