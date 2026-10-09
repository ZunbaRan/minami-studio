---
name: terminal-driving
description: 后台驱动 Ghostty/终端类应用——unicode+physical 组合输入配方、菜单 chord 门禁、ctrl+c 不可用的后果、多 agent 共享 tty 的互踩风险。
---
# 终端后台驱动（Ghostty 实证）

## 适用

Ghostty、Terminal.app、iTerm2 等终端窗口的后台命令执行。实测环境：Ghostty pid 级投递，窗口在后台/被遮挡。

## 输入配方（实测唯一稳定路径）

两条输入通道各有致命缺陷，**必须组合**：

| 通道 | 能 | 不能 |
|---|---|---|
| `type_text input_method:"unicode"` | 字符 100% 精确（`-` `+` `|` `%` `"` `~` 全对） | **Enter 不执行**——`\n` 不会提交命令 |
| `type_text input_method:"physical"` | Enter/Backspace（`\n`/`\b`）有效 | 会被系统 IME 改写：中文输入法下 `-`→`——`、数字可能变 `@@@` |

✅ **配方**：`unicode` 打命令全文 → `physical` 单独发 `\n` 提交。清行用 `physical` 发一串 `\b`。

❌ 不要用 physical 打命令正文（IME 改写）；不要指望 unicode 的 `\n` 执行命令。

## press_key 菜单门禁

`press_key` 只对**有 enabled 菜单项**的 chord 生效（`menu_ax_press` 语义）：

- `cmd+t` 新标签 ✅（Ghostty New Tab 菜单项）
- `cmd+w` 关标签 ❌ suppressed——**用 `exit` 命令关 tab**
- `ctrl+c` ❌ suppressed——**后台无法中断已运行的命令**。别跑会长挂的命令；跑死了只能等或 kill 进程。

## 多 agent / 共享 tty 互踩（实测事故）

同一终端窗口是**共享 tty**：两个 agent 或 agent+用户同时输入，文本会**逐字节交叉**——实测 `date "+%H:%M"` 被外来字符拼成 `dquote>` 续行态。防御：

- 给自用窗口**固定 window_id**（多窗口终端 app 有兄弟窗口，uid 漂移后要重新 `get_app_state` 确认——窗口销毁后 wid 会换）
- 每条命令带唯一 sentinel（`echo CU-MARK-$$`）并截图/读屏回验输出
- 发现串入外来文本：补 `'`/`"` 闭合续行态，或 `physical` 发 `\b` 清行重来

## 验证

终端 AX 树不稳定（常空或陈旧），**截图是真相**。输入区元素是 `AXTextArea`（role_description "text entry area"），但落字与否以屏幕回显为准——`typed N chars` 回执不等于进了 tty。
