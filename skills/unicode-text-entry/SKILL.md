---
name: unicode-text-entry
description: 后台输入中文、emoji或带下划线的测试名称，选择AX与Unicode输入路径时使用。
---
# 中文与 Unicode 输入
## 前置条件
确认目标是自有可编辑字段；先获取当前ref或验证键盘焦点确实在该字段。CX01/02/03/05/06/07实测。
## 推荐步骤（含具体工具调用示例）
1. 有编辑区ref时：`type_text({bundle:"com.apple.Notes",ref:T,text:"CX07_Field\n中文 😀",input_method:"ax"})`；或对自有全文使用set_value。
2. 需要局部改字：select_text(text,prefix/suffix,selection_type:"text")后AX插入。
3. Finder执行“重新命名”后，`type_text({bundle:"com.apple.finder",text:"CX06_Move",input_method:"unicode"})`；再单独 `type_text({bundle:"com.apple.finder",text:"\n",input_method:"physical"})`提交。
4. TextEdit新文稿中input_method:unicode实测中文与emoji成功，并实际保存为RTF。
## 已踩的坑 / 不要做的事
- auto无ref走auto_key_events，中文不能依赖它（用户提供的已确认parity）。
- physical遇下划线报action_unsupported，真Alma同样；不要把带下划线文件名和确认换行合为physical串。
- Notes新建后无ref Unicode本轮报告typed但正文没变；带ref AX插入成功。输入计数不是落字验证。
- 新建文件夹后先看是不是重命名编辑态；仅选中图标时键入名称不等于改名。
## 验证点（怎么确认成功）
回读AX值并看标题/截图；保存后再用允许的ls/md5/文件内容检查。中文与emoji都核对。
## 清理
仅清除自己的字段/文稿。若清理受阻，保留CX前缀与明确待办，不能把空白残留当清理完成。
