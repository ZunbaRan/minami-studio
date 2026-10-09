---
name: heavy-ax-tree-strategy
description: Finder、Notes 等复杂窗口的快照过大、空diff或索引不明时使用。
---
# 快照深度与 diff
## 前置条件
工具是agent_computer_use；先选bundle和窗口。本文首批依据Finder CX05/CX06，Notes实测另见notes-lifecycle。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.finder",depth:3,interactive_only:true,screenshot_max_width:800})` 先定位window.id与主要控件。
2. 需要文件cell或展开菜单才升到depth6。更深之前优先切列表视图/缩小目标窗口范围。
3. 看`elements_are_diff`、`removed_refs`、`unchanged_element_count`。elements=[]且elements_are_diff=true不是AX空树。
4. 不易维护diff时：`sky_get_app_state({app:"com.apple.finder",disableDiff:true})`获得完整编号文本，再使用sky_*对应的element_index。
## 已踩的坑 / 不要做的事
- 自然get_app_state本轮schema没有disable_diff或include_screenshot；不要假装能传这两个参数。sky支持disableDiff但没有window_id。
- 多窗口切换会影响当前快照和pid截图映射，不能混用另一窗口的图和坐标。
- 不把一次快照的未出现元素当已删除；diff需要结合removed_refs处理。
## 验证点（怎么确认成功）
实际窗口id、标题、目标元素标题一致。sky完整文本能解释原来的空diff。
## 清理
只需关闭本次新建测试窗，恢复临时视图；不改用户文件或系统选项。

现场补记：CX08的scroll动作虽报不支持，后续读取滚动条子按钮并对AXDecrementPage执行click(strategy:"ax")两次，实际回到顶部。以截图和行bounds确认，不把offscreen负y的row当可见目标。
