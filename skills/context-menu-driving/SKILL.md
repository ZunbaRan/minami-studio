---
name: context-menu-driving
description: 在 Finder 或 Notes 的上下文菜单中按当前标题安全执行操作时使用。
---
# 上下文菜单操作
## 前置条件
先获取目标控件与窗口；确认对象归属。CX06实测菜单ref会在不同菜单间复用。
## 推荐步骤（含具体工具调用示例）
1. Finder切换列表视图后，`get_app_state({bundle:"com.apple.finder",depth:6})`，找到title等于目标文件名的AXCell。
2. `perform_secondary_action({bundle:"com.apple.finder",ref:CELL,window_id:W})`。
3. 再快照菜单，按title、enabled选择当前项。`click({bundle:"com.apple.finder",ref:CURRENT_ITEM,strategy:"ax"})`。
4. 操作后重新读取状态；若出现确认窗，核对完整对象名。
5. cell菜单无法点击时，先重新确认当前选中对象，尝试工具栏菜单的AXShowMenu：Notes“更多”→删除备忘录、Finder“操作”→移到废纸篓，本轮均成功。`perform_secondary_action`与普通`click`可能得到不同可用菜单状态，操作后必须再gas。
## 已踩的坑 / 不要做的事
- CX06同一个e1073上一菜单是“立即删除…”，下一菜单是“清倒废纸篓”！ref不是永久语义ID，换目标必重读当前菜单。
- secondary click ok只表示调用完成，不保证当前菜单已经出现；没有菜单证据就不要点旧菜单ref。
- sky的element_index来自sky_get_app_state文本，不等于e编号。`e509`不能直接写element_index:509。
- sky_perform_secondary_action传action:AXConfirm仍开菜单，Alma同样；不要当通用AX动作接口。
## 验证点（怎么确认成功）
菜单标题指向本次对象；选项enabled；操作后的结果或确认窗口与预期一致。若弹出完全无关表单，停下，保留状态并查并发操作/重新快照。
## 清理
关闭自有菜单/测试窗；删除仅限本轮明确归属对象。不要为消除菜单而激活app。
