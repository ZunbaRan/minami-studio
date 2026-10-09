---
name: finder-file-ops
description: 使用 minami_computer_use 在后台做 Finder 自有文件的定位、重命名、简介和清理。
---
# Finder 文件操作
## 前置条件
先标识自有测试对象 CX编号_；所有删除都核对文件名。CX05/CX06现场依据，不操作用户既有文件。
## 推荐步骤（含具体工具调用示例）
1. `press_key({bundle:"com.apple.finder",key:"cmd+n"})`，快照记录新窗口。
2. `press_key({bundle:"com.apple.finder",key:"cmd+shift+g"})`，`get_app_state({bundle:"com.apple.finder",depth:3})` 找AXTextField；用set_value写绝对路径。字段已聚焦时 `type_text({bundle:"com.apple.finder",text:"\n",input_method:"physical"})`确认。CX06此路径前后哨兵完全一致。
3. 新建文件夹快捷键和工具栏菜单可能disabled；空白区域右键菜单的“新建文件夹”现场为enabled。读当前菜单再AX点击。
4. 文件重命名：右键目标→重新命名→`type_text({bundle:"com.apple.finder",text:"CX06_Move",input_method:"unicode"})`→physical单独换行。原扩展名未被选中时不要重复输入.rtf。
5. 列表视图能在depth6露出带文件名的AXCell。优先按该ref做perform_secondary_action，获取当前菜单再选“显示简介”等项。
6. cell右键无效果时，本轮可用当前工具栏“操作”ref做perform_secondary_action，再depth4读取菜单并点击“移到废纸篓”；必须先确认选中文件。普通click菜单按钮与AXShowMenu不保证等效。
## 已踩的坑 / 不要做的事
- 前往文件夹的“关闭”小X本轮只是清空字段，不一定取消表单。type_text({text:"\u001b",input_method:"physical",bundle:"com.apple.finder"})本轮成功取消；输入换行/AXConfirm也可能返回ok却未前往，必须看window.title与表单是否消失。
- physical字符串含下划线会报action_unsupported，真Alma也一样。标记名称使用unicode。
- CX06拖文件到边栏文稿返回drag ok但文件未移动，Alma同样；不要将drag ok当移动成功。
- 菜单快捷键是app级：操作后默认快照可能已选另一个窗口。始终比较window.id，再决定是否继续使用旧窗口。
- 图标视图较深；换列表比盲目提高depth更好。更换后恢复原视图。
## 验证点（怎么确认成功）
检查名称、路径、简介大小与正文。允许时用ls/md5核对实际文件。CX06重命名保持445字节，简介正文完整。
## 清理
只删除自己前缀的文件。先移到废纸篓；需要永久清理时对单个文件AXCell右键→立即删除，核对确认窗口完整文件名后才点删除。永不点击“清倒废纸篓”。CX06文件与CX05目录最终均逐项永久清理，ls确认不存在。CX19文件已移入废纸篓，永久删除未验证，详见RUNLOG最终复核。
