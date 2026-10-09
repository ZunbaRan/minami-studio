# 成功录像索引

时间为按片段时长累加的近似起点；拼接时间戳调整合计约 0.009 秒。每一行均可对应 LOG.md 和 evidence/ 的同编号证据。

| 起点 | 编号 | 操作 | 效果 |
| --- | --- | --- | --- |
| 00:00.000 | [003](../clips/003_add-telegram.mov) | 添加账户/Telegram | 切换 Telegram 配置，显示 Bot Token、测试 Chat ID、创建/取消 |
| 00:08.192 | [006](../clips/006_account-enable-toggle.mov) | 添加账户/启用此账户 | 未提交表单复选框由勾选变为空；未创建账户 |
| 00:16.192 | [007](../clips/007_add-email.mov) | 添加账户/Email | 显示 Chatwoot 邮箱导入、刷新列表、Gmail/Apple/Yahoo/163/QQ/Outlook模板、邮箱凭据 |
| 00:24.375 | [009](../clips/009_add-dingtalk.mov) | 添加账户/钉钉 | 显示 Stream 模式 App Key、App Secret、Robot Code |
| 00:32.615 | [010](../clips/010_add-wecom.mov) | 添加账户/企业微信 | 显示 WebSocket 长连接 Bot ID、Secret、Corp ID、Corp Secret |
| 00:40.802 | [011](../clips/011_cancel-add-account.mov) | 添加账户/取消 | 弹窗取消：返回渠道页；未创建、未保存，现有2个连接保持 |
| 00:48.998 | [012](../clips/012_chatwoot-tab.mov) | 网关/Chatwoot tab | 显示客服平台连接状态、服务器URL、控制台/检查状态；外部控制台未打开 |
| 00:57.242 | [022](../clips/022_avatar-menu.mov) | 主侧栏/头像 | 打开数字形象选择页；可见8种形象、名称编辑、上传自定义头像、关闭；未更换形象 |
| 01:05.443 | [023](../clips/023_avatar-name-editor.mov) | 数字形象/名称编辑 | 名称进入带下划线的编辑状态；保留原名称，未输入 |
| 01:13.668 | [024](../clips/024_avatar-upload-picker.mov) | 数字形象/上传自定义头像 | 打开原生文件选择弹窗；未选择、未上传文件 |
| 01:21.885 | [026](../clips/026_cancel-upload-ax.mov) | 上传文件弹窗/取消（AX） | 弹窗取消：原生文件选择框关闭；未上传任何文件 |
| 01:30.067 | [027](../clips/027_close-avatar.mov) | 数字形象/关闭 | 返回网关渠道页，头像与名称保持原值 |
| 01:38.267 | [028](../clips/028_gateway-integrations-ax.mov) | 网关/集成（AX恢复） | 进入用户连接页：飞书、钉钉、Google Drive；连接授权入口只读未执行 |
| 01:46.413 | [029](../clips/029_gateway-whitelist-ax.mov) | 网关/联系人白名单 | 显示7名联系人、个人/群聊、渠道/状态筛选和搜索；权限开关/加入/移除只读 |
| 01:54.520 | [031](../clips/031_whitelist-set-search.mov) | 白名单/测试搜索（AXValue） | 搜索框落字、联系人结果变为0；set_value 比 type_text 稳定 |
| 02:02.677 | [032](../clips/032_clear-whitelist-search.mov) | 白名单/清空测试搜索 | 测试词已清除，恢复原7名联系人 |
| 02:10.782 | [033](../clips/033_email-whitelist.mov) | 网关/邮箱白名单 | 显示精确邮箱和域名规则、添加/单项删除/清空全部；写入类按钮只读 |
| 02:18.943 | [034](../clips/034_general-settings-ax.mov) | 设置/通用（AX恢复） | 显示开机自启动、每月备份、版本更新、OpenTelemetry；现有配置只读 |
| 02:27.050 | [035](../clips/035_workspace-settings.mov) | 设置/工作区 | 显示默认工作区路径 /Users/lu/WiseProject/Lawrence |
| 02:35.185 | [036](../clips/036_workspace-location-options.mov) | 工作区位置/下拉 | 展开当前路径和自定义入口；未选择新目录 |
| 02:43.395 | [037](../clips/037_provider-settings.mov) | 设置/服务商 | 关闭工作区下拉并进入 Claude Code 状态页；登录/文档会离开目标窗口，未执行 |
| 02:51.528 | [038](../clips/038_provider-codex.mov) | 服务商/Codex | 显示已登录 ChatGPT、刷新状态、退出登录、文档；退出登录未执行 |
| 02:59.677 | [039](../clips/039_provider-opencode.mov) | 服务商/OpenCode | 显示1个已配置服务商和23个可用服务商；登录/移除/连接测试未执行 |
| 03:07.685 | [040](../clips/040_provider-api-key-dialog.mov) | OpenCode/OpenAI API密钥配置 | 打开空白API密钥与Base URL表单，保存禁用；未输入凭据 |
| 03:15.813 | [041](../clips/041_cancel-provider-api-key.mov) | API密钥配置/取消 | 弹窗取消：返回服务商列表，已配置数量仍1 |
| 03:23.835 | [042](../clips/042_channel-agent-settings.mov) | 设置/频道智能体 | 导航与选中项变化；等待复查仍停在加载动画，配置内容未加载（覆盖受限） |
| 03:31.978 | [043](../clips/043_voice-settings.mov) | 设置/语音 | 显示Whisper引擎、快速/优化/翻译、语言和模型下载；配置与模型未改 |
| 03:40.192 | [044](../clips/044_voice-language-options.mov) | 语音/语言下拉 | 展开自动/简繁中文/英日韩法德西俄10项；保留Auto-detect |
| 03:48.355 | [045](../clips/045_web-settings.mov) | 设置/Web配置 | 关闭语言下拉，显示登录配置、飞书SSO回调、去渠道配置/复制和高级连接信息 |
| 03:56.412 | [046](../clips/046_system-settings.mov) | 设置/系统 | 显示守护进程、6个Docker服务、9个主机服务、数据与连接、日志；停止/重启未触发 |
| 04:04.578 | [047](../clips/047_collapse-docker-services.mov) | 系统/Docker服务折叠 | 收起服务卡片，露出主机服务、数据、日志及环境区域 |
| 04:12.753 | [048](../clips/048_expand-host-services.mov) | 系统/主机服务展开 | 显示gateway、web、docs、lawrence-api、webhook、memory、qmd-mcp、suit-host、opencode共9个服务 |
| 04:20.810 | [049](../clips/049_collapse-host-services.mov) | 系统/主机服务折叠 | 收起卡片，恢复数据与连接/日志可视入口 |
| 04:28.893 | [050](../clips/050_expand-data-connections.mov) | 系统/数据与连接 | 显示数据库已初始化、管理端心跳待审批及连接信息 |
| 04:37.083 | [051](../clips/051_collapse-data-connections.mov) | 系统/数据与连接折叠 | 收起连接信息，露出日志入口 |
| 04:45.153 | [052](../clips/052_system-logs.mov) | 系统/日志展开 | 显示日志面板、All/仅错误、刷新与打开目录入口；未打开外部目录 |
| 04:53.357 | [053](../clips/053_logs-errors-only.mov) | 系统/日志仅错误筛选 | 日志列表切换为暂无日志，未修改服务状态 |
| 05:01.530 | [054](../clips/054_inbox-ax.mov) | 主侧栏/工作区会话（AX恢复） | 进入工作区会话页，显示项目列表、历史会话、MCP、文件及输入框；未发送消息 |
| 05:09.642 | [055](../clips/055_conversation-mcp-menu.mov) | 会话/MCP状态下拉 | 展开MCP Servers，3/3已连接；未刷新或修改工具配置 |
| 05:17.713 | [056](../clips/056_conversation-files-pane.mov) | 会话/文件侧栏 | 关闭MCP弹层并打开文件/Skills侧栏，显示工作区文件；未编辑文件 |
| 05:25.838 | [057](../clips/057_conversation-skills-pane.mov) | 会话侧栏/Skills | 页签切换成功，显示加载动画与Refresh入口；内容加载受限 |
| 05:34.042 | [059](../clips/059_task-board.mov) | 主侧栏/任务生命周期 | 离开会话侧栏，显示任务列表/计划任务、工作区筛选、新建及状态分类 |
| 05:42.142 | [060](../clips/060_new-task-dialog.mov) | 任务/新建任务 | 打开工作区、标题、Markdown描述、优先级、来源会话表单；创建禁用 |
| 05:50.288 | [061](../clips/061_task-description-preview.mov) | 新建任务/描述预览 | 由Markdown编辑切换到暂无内容可预览；未填写或创建任务 |
| 05:58.440 | [062](../clips/062_cancel-new-task.mov) | 新建任务/取消 | 弹窗取消，返回原任务列表；任务仍2项 |
| 06:06.607 | [063](../clips/063_scheduled-tasks.mov) | 任务/计划任务 | 显示周期/单次计划、状态筛选、最近运行；立即运行/启用/删除均未执行 |
| 06:14.688 | [064](../clips/064_agent-library.mov) | 主侧栏/Agent团队 | 进入Agent列表，显示组织架构和新建智能体入口；当前列表为空 |
| 06:22.768 | [065](../clips/065_new-agent-dialog.mov) | Agent/新建智能体 | 进入适配器选择步骤：Claude Code、Codex、OpenCode与取消；未创建 |
| 06:30.997 | [066](../clips/066_agent-codex-config.mov) | 新建智能体/Codex配置 | 进入名称、角色、模型、提示词、描述配置；未填写或创建 |
| 06:39.138 | [067](../clips/067_cancel-new-agent.mov) | 新建智能体/取消 | 退出创建流程，Agent列表仍为空 |
| 06:47.278 | [068](../clips/068_agent-organization.mov) | Agent/组织架构 | 组织架构页显示尚未配置智能体 |
| 06:55.503 | [069](../clips/069_file-workspaces.mov) | 主侧栏/上下文治理中心 | 进入工作区列表，显示Skills、数据保护及各工作区设置；未切换或删除工作区 |
| 07:03.678 | [070](../clips/070_governance-skills.mov) | 上下文治理/Skills | 显示全局Skills卡片、搜索、预览、导入/目录及开关；未启停或删除技能 |
| 07:11.870 | [071](../clips/071_data-protection.mov) | 上下文治理/数据保护 | 显示识别规则、智能识别、快速扫描、数据脱敏、上传和手动规则入口；未改全局脱敏 |
| 07:20.035 | [072](../clips/072_data-smart-recognition.mov) | 数据保护/智能识别 | 显示选择文件并发送开始分析、指令输入和禁用扫描按钮；未发送 |
| 07:28.147 | [073](../clips/073_data-quick-scan.mov) | 数据保护/快速扫描 | 切换为粘贴文本提取PII规则界面，扫描禁用；未运行 |
| 07:36.255 | [074](../clips/074_data-redaction.mov) | 数据保护/数据脱敏 | 显示文件脱敏、文本脱敏、文件还原、文本还原四入口；未处理真实文档 |
| 07:44.402 | [075](../clips/075_applications.mov) | 主侧栏/运行总览 | 九宫格入口实际为运行总览：智能体、任务、成本、活动和时间范围筛选 |
| 07:52.412 | [077](../clips/077_analytics-activity.mov) | 运行总览/活动 | 后台进入活动列表，显示类型筛选和历史运行事件；未启动新运行 |
| 08:00.525 | [079](../clips/079_restore-settings.mov) | 清理/返回设置 | 退出活动页，返回设置；无对话框 |
| 08:08.617 | [080](../clips/080_restore-original-gateway.mov) | 清理/恢复原网关页面 | 恢复网关→渠道→自定义渠道/全部；无弹窗。邮箱末态为Command failed，与初始在线不同，未操作现有账户连接开关 |
