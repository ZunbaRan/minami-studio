---
name: app-launch-focus-safety
description: 冷启动原生app或检查后台操作是否改变用户前台、光标时使用。
---
# 后台启动与焦点检查
## 前置条件
先记录原前台、光标、目标是否运行。只操作任务授权的app；不要为恢复基线而激活旧前台。当前23工具闭集，没有通用窗口枚举、PiP或press工具。
本轮CX16：Stocks启动前未运行，activates:false得到pid8475；Weather得到pid8956。
## 推荐步骤（含具体工具调用示例）
1. 跑哨兵：`swift -e 'import Cocoa; let a=NSWorkspace.shared.frontmostApplication; print(Date(),a?.bundleIdentifier ?? "nil",a?.processIdentifier ?? 0,NSEvent.mouseLocation)'`。
2. `list_apps({days:1})`判断是否冷启动；`launch_app({bundle:"com.apple.weather",activates:false})`。
3. 立即再跑哨兵，再`get_app_state({bundle:"com.apple.weather",auto_launch:false,depth:2})`读取窗口。不要点系统设置或位置授权设置选项。
4. 后台已有进程但无窗口时，只能尝试实际存在的窗口菜单：本轮Calendar/Mail的`press_key({bundle:B,key:"cmd+0"})`可达。之后重新获取window.id。
5. 清理后再采样；若不同，记录具体值、时间、最近调用和是否有用户活动。
## 已踩的坑 / 不要做的事
- `launch_app`明确传activates:false；get_app_state默认会自动后台启动。只读盘点、清理复核要传auto_launch:false。
- Stocks bundle是com.apple.stocks，区分大小写。
- CX16 Weather启动前后同为Paseo/(598,277)；Stocks出现598.484/276.844→598/277的变化，不能忽略，也不能凭两个采样点断言工具移动光标。
- 原frontmost.sh分两次读取bundle与pid，用户切换时可能得到混合记录。单次Swift取同一个NSRunningApplication更容易解释。
- 采样相同不证明中间绝无瞬时抢前台；采样不同也不自动证明是工具造成。
## 验证点（怎么确认成功）
核对launched/activates、返回pid、新window.id及前后哨兵。无有效基线就不能宣称focus通过。
## 清理
只关闭本轮确认创建的窗口。若出现未登记的新window.id，不猜它属于本轮，不关闭用户/其他agent的窗口。CX16测试Stocks/Weather均已关闭；最终auto_launch:false显示两者不再运行。
