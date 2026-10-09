---
name: textedit-editing
description: 后台编辑 TextEdit 富文本并精确替换重复文本时使用。
---
# TextEdit 后台编辑
## 前置条件
使用 minami_computer_use；先采样前台与光标。新建测试文稿，保留所有既有窗口。本文依据 CX01/CX02；ref 和 window_id 只是当次示例，必须重新获取。
## 推荐步骤（含具体工具调用示例）
1. `get_app_state({bundle:"com.apple.TextEdit",depth:3})`。记录既有 window.id。
2. `press_key({bundle:"com.apple.TextEdit",key:"cmd+n"})`，再快照确认新 window.id 和 AXTextArea ref。
3. 在自有文稿整体写入：`set_value({bundle:"com.apple.TextEdit",window_id:W,ref:T,value:"CX01_Field rich text\n中文与 emoji 😀"})`。
4. `select_text({bundle:"com.apple.TextEdit",window_id:W,ref:T,text:"CX01_Field rich text",selection_type:"text"})`；对“粗体”AXCheckBox 使用 `click({bundle:"com.apple.TextEdit",ref:B,strategy:"ax",window_id:W})`。
5. 重复串替换：`select_text({bundle:"com.apple.TextEdit",ref:T,text:"apple",prefix:"green ",selection_type:"text"})`，再 `type_text({bundle:"com.apple.TextEdit",ref:T,text:"梨",input_method:"ax"})`。CX02验证 red apple 保留、green apple变为green 梨。
## 已踩的坑 / 不要做的事
- 本轮 cmd+alt+f 被 suppressed；不要激活 app。上述定点替换成功，不等于已验证系统查找条。
- 本实现 `opt` 不识别，真 Alma 接受（BUG-CX02）；使用 alt 别名仅解决解析问题。
- set_value 会替换全文，只用于确认归属的测试文稿。不要用它修改用户既有文本。
- AX写值在本轮可能未使文稿出现“已编辑”；界面有字不证明已保存。
## 验证点（怎么确认成功）
重新快照检查 AXTextArea.value、粗体checkbox.value=1，并看截图。格式操作与输入后均核对窗口id。任务后复查前台和光标。
## 清理
对该窗口 AXCloseButton 使用 strategy:ax。若出现“要保留此新文稿”表单，核对为本轮新建文稿，再点“删除”；否则确认窗口消失。既有窗口不得一起关。
