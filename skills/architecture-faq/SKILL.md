---
name: architecture-faq
description: Minami computer-use 架构答疑——PiP 唤出机制、arm 沿触发、最小化窗口操作、三种光标、MCP 与 socket 的职责边界。遇到"为什么没弹画中画/为什么有两个光标/最小化了还能操作"类问题时读。
---
# 架构答疑与技术手册

本手册回答结构性问题（"为什么不工作/为什么是这个行为"），不教具体操作——操作配方看各专题手册。

## 分层

```
agent ──stdio──> MCP wrapper (29 tools) ──unix socket NDJSON──> daemon ──AX/CGEvent/SCK──> 桌面
                    ↑ 产品面                    ↑ Alma wire（不动）
```

- **MCP 工具面 = 29 个**：Alma 的 23 个 action 工具 + `Skill` + Minami 自己的 5 个 `pip_*`（pip_open/pip_close/pip_status/pip_arm/pip_disarm）。
- **daemon socket = 完整协议面**：含 MCP 未暴露的命令。路径 `~/Library/Application Support/minami-computer-use/computer-use-<tag>.sock`，UTF-8 JSON-lines，一行请求一行响应。socket 直连见 `pip-preview` 手册。

## PiP 画中画

### 唤出只有两条路径，没有"自动"

1. **`pip_open` 显式开**：`pip_open({window_id})` 或 `{bundle|pid, title?}` 让 daemon 解析窗口。可选 `width/height`。
2. **`pip_arm` + 用户最小化自动弹**：`pip_arm({window_id, pid})` 或 `{bundle|pid, title?}` 注册 `AXWindowMiniaturized` 监听；**用户自己**点黄色最小化按钮的瞬间自动 `pip_open`，弹完自动 disarm。

### 常见疑问

- **"窗口最小化了为什么没弹画中画？"** arm 是 per-window opt-in，没人 arm 就不会弹。`pip_status` 的 `armed: []` 可查。且触发是**沿触发**——通知只在"缩下去那一刻"fire；arm 之前已最小化的窗口不会追溯，要还原再缩一次。
- **"最小化是 CU 干的吗？"** 不是。最小化是**用户手势**，daemon 只是 AX 观察者。CU 主动缩用户窗口违反"不动桌面状态"原则。
- **"最小化/遮挡的窗口镜像为什么还有画面？"** ScreenCaptureKit 抓窗口纹理，不依赖屏幕上可见——最小化、被遮挡、后台窗口都能实时镜像（实测 `last_frame_age_ms` 两位数）。
- **"最小化的窗口 agent 还能操作吗？"** 能。AX 点击（strategy=ax）与后台事件投递不依赖窗口可见性。Lawrence 巡演实证：窗口全程最小化，80 次操作照常完成。
- **浮窗标题** `Minami PIP — <title>`；`title` 来自 pip_open/arm 参数或解析到的窗口名。
- **源窗口销毁**会即时回收会话与 arm（元素销毁是权威，不轮询 CG）。

### 三种光标（"为什么浮窗里看到两个鼠标"）

| 光标 | 来源 | 控制 |
|---|---|---|
| 用户硬件光标 | SCStream `showsCursor`（默认 true，Alma parity） | daemon 启动加 `--pip-hide-hw-cursor` 关闭 |
| agent 蓝点 | `ActionCursor`，随 click/drag/scroll/type 更新，PIPLens 渲染 | daemon 启动加 `--lens` 打开（默认关） |
| 徽标 | 点击脉冲/键盘/滚动角标 | 同 `--lens` |

理想画面 = 用户光标不入镜（hide flag）+ 蓝点是"agent 的手"。蓝点只在操作点落入被镜像窗口矩形内时显示，跨 app 操作不会乱入。

## MCP vs socket 的职责边界

- 23 个 action 工具 = Alma parity 闭集，**不加工具、不改语义**。
- 5 个 `pip_*` 是 Minami 产品层新增（Alma 的 agent 面没有 PiP，是 Alma UI 层直连 socket 干的）。wire/错误语义不变，只是入口下沉到 MCP。
- 其他 socket-only 命令（如更多 daemon 管理面）仍需 socket 直连，见 `pip-preview`。

## 探索期录像配方（Lawrence 巡演沉淀）

- 单窗口录像：`screencapture -l <window_id> -V <秒> out.mov`，抓窗口纹理，最小化/遮挡照录。
- "只录成功"流程：先起录像 → 执行操作 → 等录像结束 → 再截图验收 → 成功留片、失败删片。操作间用 `get_app_state` 截图核对可见效果。
- 合并：`ffmpeg -f concat -safe 0 -i list.txt -c copy out.mov`；边界 DTS 非单调告警属输出时基取整，用 `-fps_mode passthrough -enc_time_base demux -f null` 做最终解码核验。
- 详细逐操作证据格式见 `computer-use/field-e2e/lawrence/`（LOG.md + evidence/*.json + out/QA.md）。

## 后台安全底线（每个手册都重复，因为每次都会忘）

- 不抢前台、不动用户光标、不 activate/raise 应用。所有操作后台投递。
- 点击成功 ≠ UI 生效：`ok:true` 后必须再截图/读状态验收。
- ref 会随 UI 变化失效，导航/弹窗后重新取状态。
