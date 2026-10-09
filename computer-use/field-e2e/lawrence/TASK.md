# LAWRENCE-TOUR — WiseStudio 全功能遍历 + 成功录像 + 手册沉淀

你是 Codex CLI，拥有 `minami_studio` MCP（23 工具 + Skill 手册通道）和 bash。

## 目标对象（固定，别换 pid）

- Electron 应用 **WiseStudio**（项目名 lawrence）：pid **86359**，bundle `com.github.Electron`
- 主窗口 window_id **234415**，bounds (156,33) 1309×874，标题 "WiseStudio"
- 已知约束：AX 树几乎为空（Chromium 自绘，只有 ~4 个元素）→ **主要走截图 + 坐标点击**；menu_shortcuts 可读（cmd 系 chord 可用）

## 硬约束

- 全程后台操作：不抢用户前台、不动用户鼠标、不移动/缩放 WiseStudio 窗口（否则录像画面会抖）
- 不修改任何真实数据：探索性输入只用测试值（如 `codex-tour-01`）；遇到保存/删除/发送类确认弹窗，**截图记录后取消**不真执行
- 开始前先调 `Skill` 工具读 `computer-use/screenshot-coordinate-clicks`、`computer-use/error-recovery`、`computer-use/context-menu-driving`

## 工作目录（已建好）

`/Users/lu/Documents/data/project/alma-reverse/minami-studio/computer-use/field-e2e/lawrence/`
- `clips/` 每次成功操作的录像片段
- `out/` 最终合并视频
- `LOG.md` 逐操作日志

## 每次操作的标准流程（严格遵守）

1. `get_app_state`(screenshot) 看清当前页面，选定一个**尚未探索过**的可交互元素
2. 后台启动录像：`screencapture -l 234415 -V <6~12 秒> clips/NNN_<动作简述>.mov &`（按操作预期时长取 V；NNN 从 001 递增）
3. 用 MCP 执行该操作（click 坐标 / type_text / press_key 菜单 chord / scroll / set_value）
4. 等录像结束后 `get_app_state` 再截图，判断"可见效果"
5. 判定：
   - **成功** = 操作已投递且产生可观察效果（页面变化/弹窗/状态变化/输入落字）→ 保留片段，LOG.md 记一行：`NNN | 元素/操作 | 方法 | 效果`
   - **失败或无效果** = 被 suppressed/无变化/报错 → **删除该片段**，LOG.md 记一行：`NNN | 元素/操作 | 方法 | FAIL:原因`
6. 若操作打开了弹窗/新页面：先**用同样流程探索该页面**（每个子页面/弹窗至少点遍明显控件），再退回主页面继续

## 遍历范围（系统性，别只点表层）

- 主页面所有可见按钮/链接/tab/卡片/侧栏项
- 顶部菜单栏：用 `press_key` 菜单 chord 或 click 菜单名打开每个菜单，**逐菜单项过一遍**（危险的项只看不点）
- 页面内导航：每个 tab/侧栏入口进入后重复同一探索流程
- 对话框/设置页/二级页面：进入→探索→退出，逐层
- 合理预算：40–80 个操作；探索穷尽或到预算上限停。宁慢勿漏——**"把所有功能都点一遍看一遍"是目标**

## 交付物（全部落进工作目录/repo）

1. `clips/` 保留的全部成功片段（NNN 递增命名）
2. `out/lawrence-tour.mov`：ffmpeg 合并所有保留片段为单一视频
   `ffmpeg -f concat -safe 0 -i clips.txt -c copy out/lawrence-tour.mov`（若 concat copy 失败，重编码 `-c:v libx264 -pix_fmt yuv420p`）
3. `LOG.md`：每操作一行（含失败原因分类：suppressed/无效果/报错/弹窗取消）
4. **`/Users/lu/Documents/data/project/alma-reverse/minami-studio/skills/lawrence-exploration/SKILL.md`**（repo 内新建）：给低等级模型的 Lawrence 操作手册——YAML frontmatter(name/description)，正文含：app 概况与 AX 特点（Chromium 空树→截图坐标流）、可点击元素清单与坐标锚点、菜单 chord 表、每条踩坑记录（什么操作失败/为什么/绕法）、顺利操作配方（什么方法稳定）、探索时的注意事项

## 清理

- 结束时 WiseStudio 保持原窗口原页面状态；不留开着的对话框/弹窗（探索时的弹窗要逐个退回）
- clips.txt、中间脚本可留在工作目录；不要删除 LOG.md
- 汇报：操作总数、成功/失败数、合并视频路径与时长、SKILL.md 路径
