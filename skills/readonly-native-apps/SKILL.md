---
name: readonly-native-apps
description: 后台只读检查Music、日历、提醒事项、Maps或Mail，避免创建业务数据时使用。
---
# 原生 app 只读任务
## 前置条件
使用本机实际bundle：com.apple.Music、com.apple.iCal、com.apple.reminders、com.apple.Maps、com.apple.mail。先哨兵与浅层快照。依据CX12–15。
## 推荐步骤（含具体工具调用示例）
- Music：欢迎页“开始聆听”后停在主页；歌曲AXCell无AXPress，strategy:physical点击ref可进入空歌曲库。本轮未播放或购买。
- 日历：进程运行但空树时，`press_key({bundle:"com.apple.iCal",key:"cmd+0"})`恢复日历窗口。对“下一月/上一月”AX按钮做往返浏览，本轮10月→11月→10月。
- 提醒事项：浅层快照可读取列表状态；对搜索字段set_value写CX前缀并清空，只证明字段写入，不自动等同搜索已提交。
- Maps：`press_key({bundle:"com.apple.Maps",key:"cmd+n"})`本轮打开新地图窗口。只查看地图，不添加地点/路线。
- Mail：`press_key({bundle:"com.apple.mail",key:"cmd+0"})`恢复邮件显示窗口。只读窗口标题的计数/既有选择，不点新建、回复、转发、删除。
## 已踩的坑 / 不要做的事
- running=true不等于有窗口；empty_after_wakeup也不等于权限坏了。
- AXCell没有AX动作时strategy:ax会明确unsupported；先看actions再选策略。
- 不触发购买试用，不修改提醒完成状态，不主动打开未读邮件改变已读状态。
- 现有用户内容不写入公开日志；只记录工具结果与必要窗口元数据。
## 验证点（怎么确认成功）
查看真实页面而非仅click ok；日历往返后月份恢复；Music歌曲页出现空资料库提示；Mail没有新草稿/发送动作。
## 清理
清空本轮搜索文本；关闭本轮新开/恢复的测试窗口；不要关闭原来可见的用户窗口。没有新建业务数据就无需删除用户内容。
