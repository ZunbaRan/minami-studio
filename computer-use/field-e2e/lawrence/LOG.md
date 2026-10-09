# LAWRENCE-TOUR

2026-10-09。固定 pid 86359 / window_id 234415；窗口 (156,33) 1309×874。
初始页面：设置 → 网关 → 渠道 → 自定义渠道（全部筛选）。
截图坐标使用 1280×854 图，每次操作前重新 get_app_state。仅后台操作；不保存、删除、发送真实数据。

编号 | 元素/操作 | 方法 | 效果
--- | --- | --- | ---
001 | 网关/添加账户 | click screenshot(1205,555) | FAIL:无效果；录像报错：sandbox dispatch_source_create returned NULL
002 | 网关/Chatwoot tab | click screenshot(688,559) | FAIL:无效果：目标 tab 未出现；实际显示添加账户/WhatsApp弹窗，归因不明
003 | 添加账户/Telegram | click screenshot(478,245) | 切换 Telegram 配置，显示 Bot Token、测试 Chat ID、创建/取消
004 | 添加账户/账户名称聚焦 | click screenshot(575,382) | FAIL:无效果：截图未见焦点变化，下一步用测试输入验证
005 | 添加账户/测试账户名 | type_text unicode codex-tour-01 | FAIL:无效果：工具回 typed 13 chars，字段仍为空
006 | 添加账户/启用此账户 | click screen(577.34,467.87) | 未提交表单复选框由勾选变为空；未创建账户
007 | 添加账户/Email | click screen(973.12,227.30) | 显示 Chatwoot 邮箱导入、刷新列表、Gmail/Apple/Yahoo/163/QQ/Outlook模板、邮箱凭据
008 | Email弹窗向下滚动 | scroll e14 down 1 | FAIL:报错：Element does not support action AXScrollDownByPage；当前树无 ScrollArea
009 | 添加账户/钉钉 | click screen ← screenshot(798,211) | 显示 Stream 模式 App Key、App Secret、Robot Code
010 | 添加账户/企业微信 | click screen ← screenshot(480,256) | 显示 WebSocket 长连接 Bot ID、Secret、Corp ID、Corp Secret
011 | 添加账户/取消 | click screen ← screenshot(780,778) | 弹窗取消：返回渠道页；未创建、未保存，现有2个连接保持
012 | 网关/Chatwoot tab | click screen ← screenshot(690,558) | 显示客服平台连接状态、服务器URL、控制台/检查状态；外部控制台未打开
013 | 网关/集成 | click screen ← screenshot(356,150) | FAIL:无效果：仍为渠道/Chatwoot页
014 | 网关/集成重试 | click_count=2 screen ← screenshot(356,150) | FAIL:无效果：重试后仍为渠道页，停止重复
015 | 网关/白名单 | click screen ← screenshot(362,190) | FAIL:无效果：仅文字呈悬停样式，内容仍是渠道页
016 | 设置/通用 | click screen ← screenshot(148,73) | FAIL:无效果：仅悬停底色，内容仍是网关
017 | Electron/Preferences… | press_key cmd+, | FAIL:无效果：menu_ax_press 已投递，仍停留网关页
018 | File/Open… | press_key cmd+o | FAIL:无效果：menu_ax_press 已投递，无打开对话框
019 | 主侧栏/收件箱图标 | click screen ← screenshot(38,189) | FAIL:无效果：图标悬停，页面未导航
020 | 主侧栏/收件箱上下文菜单 | perform_secondary_action screen ← screenshot(38,189) | FAIL:无效果：未出现上下文菜单
021 | 后台键盘焦点探针 | type_text physical TAB | FAIL:无效果：未出现可辨认的焦点，不继续盲按 Return
022 | 主侧栏/头像 | click screen ← screenshot(40,98) | 打开数字形象选择页；可见8种形象、名称编辑、上传自定义头像、关闭；未更换形象
023 | 数字形象/名称编辑 | click screen ← screenshot(938,669) | 名称进入带下划线的编辑状态；保留原名称，未输入
024 | 数字形象/上传自定义头像 | click screen ← screenshot(905,711) | 打开原生文件选择弹窗；未选择、未上传文件
025 | 上传文件弹窗/取消（坐标） | click screen ← screenshot(938,615) | FAIL:无效果：原生文件选择弹窗仍在；改用当前AX取消按钮
026 | 上传文件弹窗/取消（AX） | click ref=e163 strategy=ax | 弹窗取消：原生文件选择框关闭；未上传任何文件
027 | 数字形象/关闭 | click screen ← screenshot(1239,40) | 返回网关渠道页，头像与名称保持原值
028 | 网关/集成（AX恢复） | click ref=e245 strategy=ax | 进入用户连接页：飞书、钉钉、Google Drive；连接授权入口只读未执行
029 | 网关/联系人白名单 | click ref=e389 strategy=ax | 显示7名联系人、个人/群聊、渠道/状态筛选和搜索；权限开关/加入/移除只读
030 | 白名单/测试搜索 | type_text ref=e453 input_method=ax codex-tour-01 | FAIL:无效果：输入框仍为空、联系人仍7名
031 | 白名单/测试搜索（AXValue） | set_value ref=e453 codex-tour-01 | 搜索框落字、联系人结果变为0；set_value 比 type_text 稳定
032 | 白名单/清空测试搜索 | set_value ref=e453 空串 | 测试词已清除，恢复原7名联系人
033 | 网关/邮箱白名单 | click ref=e428 strategy=ax | 显示精确邮箱和域名规则、添加/单项删除/清空全部；写入类按钮只读
034 | 设置/通用（AX恢复） | click ref=e222 strategy=ax | 显示开机自启动、每月备份、版本更新、OpenTelemetry；现有配置只读
035 | 设置/工作区 | click ref=e224 strategy=ax | 显示默认工作区路径 /Users/lu/WiseProject/Lawrence
036 | 工作区位置/下拉 | click ref=e798 strategy=ax | 展开当前路径和自定义入口；未选择新目录
037 | 设置/服务商 | click ref=e226 strategy=ax | 关闭工作区下拉并进入 Claude Code 状态页；登录/文档会离开目标窗口，未执行
038 | 服务商/Codex | click ref=e812 strategy=ax | 显示已登录 ChatGPT、刷新状态、退出登录、文档；退出登录未执行
039 | 服务商/OpenCode | click ref=e813 strategy=ax | 显示1个已配置服务商和23个可用服务商；登录/移除/连接测试未执行
040 | OpenCode/OpenAI API密钥配置 | click ref=e851 strategy=ax | 打开空白API密钥与Base URL表单，保存禁用；未输入凭据
041 | API密钥配置/取消 | click ref=e974 strategy=ax | 弹窗取消：返回服务商列表，已配置数量仍1
042 | 设置/频道智能体 | click ref=e228 strategy=ax | 导航与选中项变化；等待复查仍停在加载动画，配置内容未加载（覆盖受限）
043 | 设置/语音 | click ref=e233 strategy=ax | 显示Whisper引擎、快速/优化/翻译、语言和模型下载；配置与模型未改
044 | 语音/语言下拉 | click ref=e1007 strategy=ax | 展开自动/简繁中文/英日韩法德西俄10项；保留Auto-detect
045 | 设置/Web配置 | click ref=e235 strategy=ax | 关闭语言下拉，显示登录配置、飞书SSO回调、去渠道配置/复制和高级连接信息
046 | 设置/系统 | click ref=e237 strategy=ax | 显示守护进程、6个Docker服务、9个主机服务、数据与连接、日志；停止/重启未触发
047 | 系统/Docker服务折叠 | click ref=e1168 strategy=ax | 收起服务卡片，露出主机服务、数据、日志及环境区域
048 | 系统/主机服务展开 | click ref=e1197 strategy=ax | 显示gateway、web、docs、lawrence-api、webhook、memory、qmd-mcp、suit-host、opencode共9个服务
049 | 系统/主机服务折叠 | click ref=e1197 strategy=ax | 收起卡片，恢复数据与连接/日志可视入口
050 | 系统/数据与连接 | click ref=e1202 strategy=ax | 显示数据库已初始化、管理端心跳待审批及连接信息
051 | 系统/数据与连接折叠 | click ref=e1202 strategy=ax | 收起连接信息，露出日志入口
052 | 系统/日志展开 | click ref=e1203 strategy=ax | 显示日志面板、All/仅错误、刷新与打开目录入口；未打开外部目录
053 | 系统/日志仅错误筛选 | click ref=e1351 strategy=ax | 日志列表切换为暂无日志，未修改服务状态
054 | 主侧栏/工作区会话（AX恢复） | click ref=e175 strategy=ax | 进入工作区会话页，显示项目列表、历史会话、MCP、文件及输入框；未发送消息
055 | 会话/MCP状态下拉 | click ref=e1430 strategy=ax | 展开MCP Servers，3/3已连接；未刷新或修改工具配置
056 | 会话/文件侧栏 | click ref=e1431 strategy=ax | 关闭MCP弹层并打开文件/Skills侧栏，显示工作区文件；未编辑文件
057 | 会话侧栏/Skills | click ref=e1689 strategy=ax | 页签切换成功，显示加载动画与Refresh入口；内容加载受限
058 | 会话侧栏/关闭 | click ref=e1690 strategy=ax | FAIL:无效果：侧栏未关闭；Skills列表此时异步加载完成，不能归因为关闭动作
059 | 主侧栏/任务生命周期 | click ref=e1418 strategy=ax | 离开会话侧栏，显示任务列表/计划任务、工作区筛选、新建及状态分类
060 | 任务/新建任务 | click ref=e1986 strategy=ax | 打开工作区、标题、Markdown描述、优先级、来源会话表单；创建禁用
061 | 新建任务/描述预览 | click ref=e2036 strategy=ax | 由Markdown编辑切换到暂无内容可预览；未填写或创建任务
062 | 新建任务/取消 | click ref=e2056 strategy=ax | 弹窗取消，返回原任务列表；任务仍2项
063 | 任务/计划任务 | click ref=e1979 strategy=ax | 显示周期/单次计划、状态筛选、最近运行；立即运行/启用/删除均未执行
064 | 主侧栏/Agent团队 | click ref=e2075 strategy=ax | 进入Agent列表，显示组织架构和新建智能体入口；当前列表为空
065 | Agent/新建智能体 | click ref=e2196 strategy=ax | 进入适配器选择步骤：Claude Code、Codex、OpenCode与取消；未创建
066 | 新建智能体/Codex配置 | click ref=e2216 strategy=ax | 进入名称、角色、模型、提示词、描述配置；未填写或创建
067 | 新建智能体/取消 | click ref=e2245 strategy=ax | 退出创建流程，Agent列表仍为空
068 | Agent/组织架构 | click ref=e2193 strategy=ax | 组织架构页显示尚未配置智能体
069 | 主侧栏/上下文治理中心 | click ref=e2266 strategy=ax | 进入工作区列表，显示Skills、数据保护及各工作区设置；未切换或删除工作区
070 | 上下文治理/Skills | click ref=e2322 strategy=ax | 显示全局Skills卡片、搜索、预览、导入/目录及开关；未启停或删除技能
071 | 上下文治理/数据保护 | click ref=e2429 strategy=ax | 显示识别规则、智能识别、快速扫描、数据脱敏、上传和手动规则入口；未改全局脱敏
072 | 数据保护/智能识别 | click ref=e2945 strategy=ax | 显示选择文件并发送开始分析、指令输入和禁用扫描按钮；未发送
073 | 数据保护/快速扫描 | click ref=e2946 strategy=ax | 切换为粘贴文本提取PII规则界面，扫描禁用；未运行
074 | 数据保护/数据脱敏 | click ref=e2947 strategy=ax | 显示文件脱敏、文本脱敏、文件还原、文本还原四入口；未处理真实文档
075 | 主侧栏/运行总览 | click ref=e2916 strategy=ax | 九宫格入口实际为运行总览：智能体、任务、成本、活动和时间范围筛选
076 | 运行总览/成本 | click ref=e3034 strategy=ax | FAIL:无效果：8秒录像结束验收仍为总览；后续成本页出现且WiseStudio成前台、鼠标改变，归因不明
077 | 运行总览/活动 | click ref=e3205 strategy=ax | 后台进入活动列表，显示类型筛选和历史运行事件；未启动新运行
078 | 原生菜单栏访问 | press_key ctrl+F2 | FAIL:suppressed：后台无ENABLED菜单项持有此chord；未投递，未激活应用绕过
079 | 清理/返回设置 | click ref=e3455 strategy=ax | 退出活动页，返回设置；无对话框
080 | 清理/恢复原网关页面 | click ref=e4180 strategy=ax | 恢复网关→渠道→自定义渠道/全部；无弹窗。邮箱末态为Command failed，与初始在线不同，未操作现有账户连接开关

## 本轮汇总与覆盖边界

共 80 次操作，61 次成功（含 5 次明确弹窗取消），19 次失败。按首要原因归类：无效果 16、报错 2（其中 001 同时无效果且录屏失败）、suppressed 1。失败编号保留在日志中，对应 MOV 已删除。成功片段文件集与 61 条成功记录逐一匹配。

合并视频：`out/lawrence-tour.mov`，H.264 / yuv420p / 2754×1884，496.711979 秒（8 分 16.712 秒），121,065,148 字节。完整片段索引见 [VIDEO_INDEX.md](out/VIDEO_INDEX.md)，结构化统计见 [summary.json](out/summary.json)。

本輪按 80 次预算上限停止，未穷尽所有控件。成功的页面导航不代表页面内每个业务功能已执行；042 频道智能体和 057 会话 Skills 当次仅验证了导航/加载状态。

| 区域 | 到达/验证 | 未深入或受限 |
| --- | --- | --- |
| 网关 | 自定义渠道、Chatwoot、5 种新增账户页、集成、联系人搜索与清空、邮箱白名单 | 现有连接开关/更多菜单、各渠道过滤、授权和凭据提交；新增入口初次打开归因不确定 |
| 数字形象 | 选择页、名称编辑态、文件上传选择框及取消 | 未更换形象/名称、未上传 |
| 设置 | 通用、工作区路径下拉、Claude/Codex/OpenCode、API 空表单、语音语言下拉、Web、系统展开/折叠/日志筛选 | 频道智能体持续加载；配置开关、长页下方模型与全部服务商、服务控制未执行 |
| 会话 | 主页面、MCP 3/3 状态、文件/Skills 侧栏 | 未发送消息、未编辑文件；Close AXPress 无效，离开路由退出 |
| 任务 | 列表、计划、新建表单、Markdown 预览、取消 | 未创建/启用/运行/删除，未遍历所有筛选与表单字段 |
| Agent | 列表、组织架构、适配器选择、Codex 配置页、取消 | 未创建，其他适配器表单未深入 |
| 上下文治理 | 工作区、全局 Skills、规则/智能识别/快速扫描/数据脱敏 | 工作区配置、技能预览/导入、脱敏四类执行页和扫描提交未操作 |
| 运行总览 | 总览和活动成功；成本页稍后看到 | 成本动作未在验收窗口生效，活动详情/各筛选未深入 |
| 原生菜单 | 读取 33 个 chord；测试 Preferences、Open、ctrl+F2 | 前两者无效果，后者 suppressed；各菜单未逐一展开，无 chord 项未覆盖，危险项未执行 |

## 恢复与异常

080 后恢复设置 → 网关 → 渠道 → 自定义渠道 / 全部，无遗留对话框，测试搜索已清空。所有记录到的目标 bounds 均为 (156,33) 1309×874。未提交账户、API 密钥、任务或 Agent 表单，未执行发送、保存、删除和现有连接控制。

不能宣称全程前台和鼠标状态不变：开始及 024 哨兵显示 Paseo 前台、鼠标 (809,359)，076 后哨兵显示 WiseStudio 前台、鼠标约 (847.88,454.63)，来源未定。当时暂停操作并询问用户，尚无归因答复；随后只读确认前台回到 Paseo 才继续。结束哨兵为 Paseo，目标窗口 bounds 未变。证据见 `evidence/sentinel-*.json`。

最终邮箱 wise 渠道显示 `Command failed`，连接计数从初始 2/错误 0 变为 1/错误 1。本轮没有操作现有账户连接开关或配置，未尝试重连；运行状态与初始不同，无法归因。原始与末态截图分别为 `evidence/initial.jpg` 和 `evidence/final.jpg`。

## 录像核验

全部 61 段通过 ffprobe（尺寸一致，片长在 6～12 秒范围），逐段提取起始及末尾帧，11 张联系表已人工看图核验，画面中可见对应页面/弹窗/输入状态的改变，未见整段黑屏。联系表最后一张的空格为排版填充。

合并使用 concat + copy + faststart。拼接出现微小非单调 DTS 修正；默认 null 输出解码检查也会因输出时基取整报告重复 DTS（见 `evidence/video-decode.log`），这不等于 H.264 解码失败。最终使用 passthrough + demux 时基检查，结果单独记录在 `evidence/video-decode-passthrough.exit` 和 `.log`，核验结论见 `out/QA.md`。未把失败操作片段混入成片。

手册位于仓库 `skills/lawrence-exploration/SKILL.md`；本目录 `skill-draft/SKILL.md` 保留同版副本。包含坐标锚点、33 个菜单 chord、19 次失败及可验证绕法、后台 AX/输入/取消/录像配方和未覆盖清单。
