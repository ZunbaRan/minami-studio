---
name: calculator-driving
description: 后台用macOS计算器进行基本与科学计算，并验证结果、清零恢复模式。
---
# 计算器
## 前置条件
bundle为com.apple.calculator；用户允许本轮计算并在结束清零。记录原模式。CX09/CX10现场验证。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.calculator",depth:5})`，从AXButton.description取数字、加减乘除、全部清除、等于的ref。
2. 全部采用 `click({bundle:"com.apple.calculator",ref:R,strategy:"ax"})`。实测AC→4→2→加→1→7→等于得59。
3. 读结果用 `get_app_state({bundle:"com.apple.calculator",depth:6,interactive_only:false})`；否则非交互AXStaticText会被过滤。
4. 科学模式：`press_key({bundle:"com.apple.calculator",key:"cmd+2"})`本轮由enabled菜单派发成功。模式切换后重新取按钮ref。
5. 5→X的阶乘→等于得到120。读取表达式与结果，同时看截图。
## 已踩的坑 / 不要做的事
- 不假设其他app的cmd+2也有效；以返回delivered为准。
- “模式”按钮AXPress本轮未显示可用弹出菜单，菜单快捷键cmd+2可用。
- 模式改变宽度，旧截图坐标与基本模式按钮ref不可复用。
- 静态结果含方向控制字符，转存数值时保留数字并剔除仅用于显示的控制字符。
## 验证点（怎么确认成功）
CX09静态文本42+17/59；CX10 5!/120。不要只看click ok。
## 清理
点击当前模式“全部清除”，截图确认0。若原为基本模式，cmd+1恢复；不关用户原有计算器窗口。
