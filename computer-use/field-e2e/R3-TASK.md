# Round-3 回归+补扫任务(Codex/Astra 执行)

你是外场测试工程师。环境:macOS 真机桌面,两个 daemon socket 可对照:

- **我们的实现**:/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock
  (或经 MCP 工具 `agent_computer_use`,同源)
- **真 Alma 参照**:/Users/lu/Library/Application Support/Alma/computer-use-9bd08bc1.sock
  (直接 socket JSON-RPC,信封 `{"id":N,"cmd":"...","args":{...}}`,行分隔 JSON)

## 铁律

1. **只记录,不改代码**——发现差异写 BUGS.md,不动 Sources/。
2. **前台保护哨兵**:每批操作前后采样 `osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'` + `cliclick p` 光标位置。若前台/光标变化且非用户操作,记录待归因。
3. **真机对照才能下结论**:任何"疑似 bug"必须在 9bd08bc1 socket 上发同一请求拿到真机响应,逐字 diff 后才写入 BUGS.md。主观推断不算证据。
4. **清理**:测试创建的窗口/文档/笔记/PiP 会话全部关闭,恢复现场。
5. 长任务后台跑,macOS 无 `timeout` 命令,用 python socket client(见 scripts/probe.py 惯例或自写)。

## Phase 1:回归验证(上一轮修复的 4 个 bug,验证不丢分)

| # | 修复点 | 验证方法 | 期望值 |
|---|---|---|---|
| R1 | `opt` 修饰键别名 | `press_key` `cmd+opt+f`/`alt`/`option`/`opt` 对 TextEdit,双 socket | 接受并被 suppressed(no enabled owner);`ctl`/`win` 仍拒 `unknown modifier` |
| R2 | `menu_shortcuts` 键名 | 对 Calculator/TextEdit/Notes 各取 `menu_shortcuts`,双 socket diff combo 集合 | 集合**完全相等**;含 `cmd+w` 类 char 键、`ctrl+Left`/`ctrl+Up` 大写方向、`cmd+?` 原样 glyph、`Return/Tab/F1..F12` 大写表名;**无 `key<N>` 残留** |
| R3 | PiP 浮窗定位 | 连续 pip_open 2~3 个(TextEdit/Calculator/Notes),读 `floater_frame` | 首窗 Cocoa 顶右 (vf.maxX-w-24, vf.maxY-h-24),每个后续窗 x/y 各 -28;与真机同开序列逐字相等 |
| R4 | 源窗销毁回收 | pip_open 后 AXPress 关源窗,poll pip_status | 1~2s 内会话消失;`pip_close` 已回收会话 → `{"closed":false,"window_id":W}` |

## Phase 2:补扫(此前未覆盖的面,挑 8~12 项做双 socket 对照)

候选面(自己也可扩展):

- `type_text` 各 strategy 的 `chars`/`via` 字段形状、含 emoji/CJK/换行的 Unicode 分解对
- `click`/`drag`/`scroll` 在无映射、stale 映射、`coord_space` 各值下的回声语义
- `get_app_state` 的 `disableDiff`/`elements_are_diff`/`removed_refs`/`sky_*` 参数边界(空树、超大树、diff 全空)
- `set_value` 对 slider/stepper/checkbox/datefield 等控件族的类型接受集与错误文案
- `select_text` 越界 range、空 prefix/suffix、多命中消歧的失败文案
- `press`/`perform_secondary_action` 对 disabled/hidden 元素的错误路径
- `apps`/`windows`/`app_info` 对 pid 死亡、沙盒 app、多 Space 窗口的枚举
- `shot`/`shot_display` 在窗口移动/缩放/失焦后的 `coord_space` 与映射状态
- `wakeup` 时长边界(0、负数、极大)、中断语义
- 分片/并发/socket 断连重连时的会话与 ref 表存活
- PiP:对同一窗重复 open、对无窗 app open、armed 后窗口销毁(非最小化)、多屏边界
- `menu_shortcuts` 对含子菜单快捷键、disabled 项、separator 的遍历
- 错误响应 schema:所有 error 分支的 `code`/`label`/`data` 键集逐字比对

## 产出

1. `computer-use/field-e2e/R3-VERIFY.md` — Phase1 四项 PASS/FAIL 表 + Phase2 每项结果
2. 新发现追加 `computer-use/field-e2e/BUGS.md` 末节 `## Round-3 回归新发现`(格式沿用既有:现象/我们/真机/证据命令/裁决建议)
3. `RUNLOG.md` 追加一段 run_id=r3 概要

只写文档不改码。开始。
