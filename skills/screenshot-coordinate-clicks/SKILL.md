---
name: screenshot-coordinate-clicks
description: AX控件不可达而需要截图像素点击，或遇到OCR v引用时使用。
---
# 截图、坐标与OCR引用
## 前置条件
必须看到本次目标窗口的实际工具截图，并知道其像素宽高；使用agent_computer_use取图和点击。不要用其他GUI驱动绕过被测面。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.calculator",window_id:W,depth:6,interactive_only:false,screenshot_max_width:460})`。
2. 从返回图找按钮中心。CX18实际460×816图的8按钮中心约(177,421)：`click({bundle:"com.apple.calculator",x:177,y:421,coord_space:"screenshot"})`。
3. 再读状态，确认AX静态文本和截图都为8。该坐标只适用于本次图，不能复制到其他布局。
4. 没有AX元素时查看visual_refs。CX18为验证OCR门槛用Music depth:0，返回v1/v2；先检查bbox与截图，不把OCR乱码当真实标签。
5. 普通MCP `click({bundle:B,ref:"v1"})`本轮实际报visual refs require pid or bundle；wrapper的ref分支丢弃目标，Alma等效请求同样报错。需要动作时使用当前图中经人工确认的安全坐标。
## 已踩的坑 / 不要做的事
- 只有带截图的get_app_state建立坐标映射；当前MCP该工具固定截图，不暴露include_screenshot参数。
- 映射按pid保存，window_id不能防止同app的旧图串窗。每次坐标操作前重新gas；动作后截图也可能使用另一宽度，不沿用上一张图的像素。
- AX bounds是桌面点，visual_refs.bounds是截图像素；不要混用。显式screen坐标须自行确认坐标空间。
- OCR只在原始AX节点数≤1时触发；diff空elements不是无AX。Calculator depth0无OCR，Music有低质量OCR，均为实测。
- Music本机与Alma完全相同：visual_refs而非旧契约文字visual_regions，v1=SiQrn、v2=pJ•，confidence0.5。此差异不报实现bug。
- 不能仅凭click ok认定点击有效；Notes菜单像素点击双方均只关菜单。
## 验证点（怎么确认成功）
截图变化和AX值/目标效果至少各一项佐证；CX18确认输入8，再清零。v*点击失败是已对照的入口限制。
## 清理
计算器点当前AC/C并确认0；关闭自有窗口。无需手工删除工具自身生成的/tmp/alma-cu-state-*截图，勿把它们冒充CX命名的业务测试文件。
