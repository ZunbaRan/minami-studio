---
name: error-recovery
description: 遇到输入校验、未知应用、失效ref、空diff或动作返回成功却无效果时使用。
---
# 错误面与恢复
## 前置条件
保留原始错误文字、工具名、参数、任务编号和前后状态。疑似实现问题要与Alma同请求对照，不能自行加规则或修代码。
## 推荐步骤（含具体工具调用示例）
1. 未知应用：`get_app_state({bundle:"com.example.CX20_missing",auto_launch:false,depth:1})`→No running app matched com.example.CX20_missing.。
2. 未知引用：`click({bundle:"com.apple.TextEdit",ref:"e99999999",strategy:"ax"})`→No element known for ref e99999999. Run snap first.。
3. 空key：`press_key({bundle:"com.apple.TextEdit",key:""})`→missing "key"。上述三项均与Alma逐字一致。
4. 真实失效测试：对已关闭的本轮TextEdit窗旧ref做select_text，本轮返回element_not_found，而非必须ref_stale。恢复流程同为重新gas并按当前标题定位。
5. select_text只允许text/cursor_before/cursor_after。非法枚举被MCP校验层以-32602拒绝；不要用native socket未校验结果冒充同一层对照。
6. 普通gas是差量：elements_are_diff=true时合并removed_refs及变化节点；需要完整树可用`sky_get_app_state({app:B,disableDiff:true})`，其index独立于eN。大树不要无脑用sky默认深度。
## 已踩的坑 / 不要做的事
- cmd+s等后台suppressed已对照为parity，不激活app绕过。
- opt别名在本实现报unknown modifier，Alma可解析；本轮BUG-CX02。可用alt拼写，但仍需接受真正suppressed。
- menu_shortcuts可能显示cmd+key13等本实现差异，不能照抄这种字符串当已验证chord。优先菜单路径、当前AX按钮和已验证cmd+w/cmd+1等标准名。
- typed/click ok不等于有效；必须检查内容、窗口、文件存在性。菜单打开后不能复用旧菜单ref，它可能已变成不同命令。
- 若哨兵变化，记录观察；没有因果证据不要把用户正在操作归咎于工具。
## 验证点（怎么确认成功）
错误来自哪一层、是否有状态改变、Alma返回是否一致、恢复后是否拿到新ref，都需明确。本轮CX20前后WeChat/(182.8164,807)一致。
## 清理
错误探针不要产生无关数据；关闭用来制造旧ref的自有测试窗。若探针意外开表单，重新快照找到取消动作；不能随便按旧删除按钮。
