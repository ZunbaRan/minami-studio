---
name: field-preflight
description: 在用 agent_computer_use 开始真实 Mac 后台外场测试前，核验工具授权与前台光标哨兵，并准确记录环境阻塞。
---
# 后台外场测试预检

## 前置条件

用户已授权测试范围，GUI 只走 agent_computer_use MCP，测试文档使用唯一 `CX<number>_` 前缀。不得改源码/配置、激活目标 app、移动用户光标或操作既有用户数据。

本手册根据 2026-10-09 CX00 的实际阻塞诊断编写。它验证的是预检失败如何判断与记录；不代表 TextEdit、Finder、Notes 等真实任务已测通。证据见 [RUNLOG](../../computer-use/field-e2e/RUNLOG.md) 和 [BUGS](../../computer-use/field-e2e/BUGS.md)。

## 推荐步骤（含具体工具调用示例）

1. 先读本会话实际暴露的工具 schema。此次是23工具闭集，无 `pip_*`、`press`；`get_app_state` 不接受文档设想中的 `include_screenshot` 参数。无法调用的能力应记为入口限制，不能编造工具或换用另一套GUI自动化。
2. 运行只读哨兵 `/tmp/cu-review/frontmost.sh`，确认返回非空前台 bundle、pid 和有效光标坐标。保存时间与原始值。每项任务前后都需采样；采样间瞬时变化无法由这两个样本排除。
3. 做最小的只读MCP预检：

   ```text
   agent_computer_use.permissions({})
   agent_computer_use.list_apps({"days":1})
   agent_computer_use.get_app_state({
     "bundle":"com.apple.TextEdit",
     "auto_launch":false,
     "depth":2,
     "interactive_only":true
   })
   ```

   快照例子只适合已经运行的目标；`auto_launch:false` 避免预检制造窗口。实际调用一次发现授权层阻塞即可停止依赖操作；此次三次探测用于确认共同失败面，不是要求每次重复三遍。
4. 若看到 `MCP tool call requires approval, but approval policy is never`，记录为工具运行环境 blocker。没有daemon返回，不得归类为AX失败、应用不支持或Alma wire差异。停止GUI任务，不通过shell/socket绕过对被测MCP的授权限制，不修改授权配置。
5. 若哨兵值为空，不能继续宣称后台安全。读取脚本，查看它是否隐藏了stderr；可单独运行原有只读采样命令暴露诊断：

   ```sh
   osascript -e 'tell application "System Events" to get bundle identifier of first process whose frontmost is true'
   swift -e 'import Cocoa; print(NSEvent.mouseLocation)'
   ```

   此次前者返回 `-10827`，后者首先报ModuleCache写入 `Operation not permitted`。只记录可观察原因；不能将后续级联SDK错误直接当作独立故障。
6. 预检恢复后重新获取所有状态，再执行任务。只有拿到应用效果和有效哨兵，才能给真实任务标记通过。真Alma同请求用于定性产品差异，不能解释一个尚未到达daemon的授权拒绝。

## 已踩的坑 / 不要做的事

- 哨兵exit 0不等于采样成功：脚本最后的echo可掩盖前面失败，实际输出可能全空。
- 看见工具名称不等于能调用：本轮三个MCP均被授权层拒绝。
- 不把“计划20项”写成“执行20项”；阻塞后的类别清单应标为未执行。
- 不把未变化与无法观测混为一谈；空基线无法证明前台/光标安全。
- 不为了测试PiP擅自改工具配置或换通道；入口例外需由任务明确允许。
- 不把当前机器上的一次错误推广为所有macOS环境的结论，也不基于未执行的GUI任务编写成功步骤。

## 验证点（怎么确认成功）

预检成功需要同时满足：MCP请求取得真实工具结果；快照能识别目标；前台bundle/pid与光标坐标有效。若任何一项缺失，记录精确错误及阻塞层，不进入有副作用的任务。本轮未满足这些条件。

## 清理

只有预检失败且确认没有GUI动作执行时，可记录“无测试数据待清理”。若此前已创建数据，列明唯一前缀、窗口/文件/笔记标识与清理状态，不把未清理项省略。保留RUNLOG和BUGS作为本次产出，不删除用户既有窗口或文件。
