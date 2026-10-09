---
name: cross-app-data-transfer
description: 需要把计算或其他应用中的结果搬到Notes和TextEdit并保存时使用。
---
# 三应用数据搬运
## 前置条件
先确认各app的窗口与自有测试对象；Calculator允许清零。数据可以由模型从AX读出再通过工具输入，无需覆盖系统剪贴板。
## 推荐步骤（含具体工具调用示例）
1. Calculator逐个AX按钮AC→1→2→3→乘→7→等于；`get_app_state({bundle:"com.apple.calculator",depth:6,interactive_only:false})`读到123×7及861。
2. Notes只写本轮自有笔记：`set_value({bundle:"com.apple.Notes",ref:OWN_NOTE_TEXT,value:"CX07_Field_20261009\nCX19_Transfer: 123 × 7 = 861"})`；实际字符串用换行，回读内容。
3. `press_key({bundle:"com.apple.TextEdit",key:"cmd+n"})`，重新读新window.id；`type_text({bundle:"com.apple.TextEdit",window_id:W,text:"CX19_Transfer_20261009\n123 × 7 = 861\nCalculator → Notes → TextEdit",input_method:"unicode"})`。
4. 按[保存面板手册](../save-dialog-handling/SKILL.md)保存为CX19_Transfer_20261009.rtf；通过Finder定位、读取简介，允许时ls/md5/读取文件核对。
5. 每一步先验证成功，再发下一步操作，避免异步菜单动作尚未完成就打开新表单。
## 已踩的坑 / 不要做的事
- 不把同一个ref跨app使用，也不把别处示例ref当当前值。
- Notes切换笔记后AXTextArea可能沿用同一ref！本轮删除后e1139变成原用户笔记Auto ok，绝不能继续写它。
- 同app不同window必须各自快照；坐标映射按pid，不提供跨窗口隔离。
- set_value回读只是当前UI状态，最终保存文件才验证落盘。
## 验证点（怎么确认成功）
本轮三处均为861；RTF473字节，MD5 bf38d0e852f3b25be22116279afbf1e9，文件正文含完整等式与三app名称。该MD5只标识现场证据，不作为未来文件固定期望。
## 清理
AC回0；关闭TextEdit测试窗；Notes通过当前“更多”AXShowMenu→删除，146回145；Finder仅删除CX19文件。原生最近删除/废纸篓状态在RUNLOG中单独列明，不声称永久擦除。
