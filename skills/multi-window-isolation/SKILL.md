---
name: multi-window-isolation
description: 同一个app有多个窗口，需要确保ref、截图和结果属于正确窗口时使用。
---
# 多窗口隔离
## 前置条件
保存初始窗口身份，给自有文稿写不同CX前缀。依据TextEdit CX04及Finder CX05/06。
## 推荐步骤（含具体工具调用示例）
1. 每次新建后`get_app_state({bundle:"com.apple.TextEdit",depth:3})`记录window.id。
2. `get_app_state({bundle:"com.apple.TextEdit",window_id:A,depth:3})`查到A的文本区ref再写入；验证B内容不变。
3. 菜单动作后再执行一次不带window_id的快照，检查实际当前窗口是否换了；必要时再回到指定窗口。
4. 处理一个关闭/保存表单后，再快照下一个窗口，不预先批量安排所有关闭按钮。
## 已踩的坑 / 不要做的事
- window_id不是app级菜单命令的隔离保证。Finder cmd+shift+d本轮显示过另一个桌面窗口232233，原232221仍停留在原状态。
- screenshot映射按pid缓存；换窗口或尺寸后先重新get_app_state再像素点击。
- AX即时回读不证明持久保存：CX04 A改值后短暂回读成功，关闭表单时回显旧值；最终须保存/重开验证。
- 不使用“全部关闭”清理，会触及用户既有窗口。
## 验证点（怎么确认成功）
A、B的window.id、CX正文与截图都一致；修改A后B原文保持。所有测试窗关闭后既有窗口仍保留。
## 清理
逐个确认属于本轮，再关闭；保存表单只对本轮文稿点删除。若出现与预期不同的窗口/对话框，停止沿用旧ref。
