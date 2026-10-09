---
name: pip-preview
description: 通过已获授权的 daemon socket 操作 macOS PiP，验证多应用镜像、最小化一次性触发和定向清理。
---
# PiP 生命周期与镜像验证

## 前置条件

- **入口是 daemon socket，不是 MCP。** 当前 minami_computer_use 的23个 MCP 工具没有 `pip_*`，这与 Alma 的入口限制一致。CX17 已获用户明确授权使用 socket；其他 GUI 编辑、最小化、关闭文稿仍走 MCP。
- 本机被测 socket：`/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock`；Alma 对照：同目录 `computer-use-9bd08bc1.sock`。后续环境应使用当时实际地址。
- 只使用本轮测试源窗口，内容/自定义 PiP title 加 `CX17_` 等唯一前缀。原有 Calculator 可读用，但保留窗口、模式和原值。
- 每个场景前后读取前台和光标。不要 activate app 来解决菜单或截图问题：

```bash
swift -e 'import Cocoa; let a=NSWorkspace.shared.frontmostApplication; print(Date(), a?.bundleIdentifier ?? "nil", a?.processIdentifier ?? 0, NSEvent.mouseLocation)'
```

- 对目标做 MCP `get_app_state({bundle:"com.apple.TextEdit",depth:3,interactive_only:false,auto_launch:false})`，从响应保存 **源 app.pid、源 window.id、正文 ref、AXMinimizeButton ref、AXCloseButton ref**。下方 PID、窗口号和 ref 是 CX17 示例，必须替换为当前返回值。
- 两端先 `pip_status({})`，记下原有 sessions/armed；维护本轮拥有的源 window_id 集合，避免清理其他人的会话。

## 推荐步骤（含具体工具调用示例）

### 1. 发送一个 socket 请求

协议是 UTF-8 JSON-lines，一行请求对应一行响应，读取到换行后结束；不要等待服务端关闭连接。下面不落地脚本文件，只发一次 PiP 请求：

```bash
python3 - <<'PY'
import json, secrets, socket
path = "/Users/lu/Library/Application Support/Alma/computer-use-72097929.sock"
request = {"id": secrets.token_hex(8), "cmd": "pip_status", "args": {}}
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
    conn.settimeout(25)
    conn.connect(path)
    conn.sendall((json.dumps(request, ensure_ascii=False) + "\n").encode())
    data = b""
    while b"\n" not in data:
        part = conn.recv(65536)
        if not part:
            raise RuntimeError("socket closed before response newline")
        data += part
print(json.dumps(json.loads(data.split(b"\n", 1)[0]), ensure_ascii=False))
PY
```

后续替换 `cmd`、`args`，对照时只换 socket 地址和随机 id，保持业务参数相同。记录时间、完整请求、完整响应。连接被拒绝时，先用一个正常 MCP `get_app_state` 使 wrapper 按自身流程恢复 helper，再重试 status；CX17 就这样恢复成功。不要修改配置或另起不明 daemon。

### 2. 两应用 open → 出帧 → 镜像变化

依次发送：

```json
{"cmd":"pip_open","args":{"bundle":"com.apple.TextEdit","pid":64284,"window_id":233332,"title":"CX17_TextMirror"}}
{"cmd":"pip_open","args":{"bundle":"com.apple.calculator","pid":57752,"window_id":230248,"title":"CX17_CalculatorMirror"}}
{"cmd":"pip_status","args":{}}
```

这些示例省略随机 id；实际发送仍加上。open/arm 同时带 bundle、pid、源 window_id，避免仅窗口号的解析歧义。成功响应的业务值在 `data`，先检查 `ok`。

- open 首次返回 `opened:true`、`has_first_frame:false`、`last_frame_age_ms:null` 可正常；后续 status 应有两个源 ID，且出帧后变 true、有数值帧龄。
- 对同一源窗口重复 open，本轮两端都保留原 session，没有产生第三个会话。
- MCP 设置测试文档正文：
  `set_value({bundle:"com.apple.TextEdit",ref:"e40",value:"CX17_A\nMirror 1729\n镜像阶段甲"})`。
  读取 **PiP 浮窗**截图后，再设 `"CX17_B\nMirror 4096\n镜像阶段乙"`，再读同一浮窗截图。不能仅看源文稿变化就声称镜像更新。
- 区分两个窗口 ID：`pip_*` 用**源窗口** ID；拍浮窗用 **helper 的浮窗** ID。本轮 MCP `get_app_state({pid:36812,depth:2,auto_launch:false})` 返回标题 `Alma PIP — CX17_TextMirror` 和浮窗 W233386；随后指定 `window_id:233386`。多窗时先重复 open 目标 session，再读 helper，确认返回标题正确。
- 若没有 helper PID，可在已连接的 macOS socket 上读对端 PID：`struct.unpack("i", conn.getsockopt(0, 2, 4))[0]`（需 `import struct`；Darwin SOL_LOCAL/LOCAL_PEERPID）。不要把源 app.pid 当作 helper PID。PID 每次可能变。

CX17 的被测浮窗截图已核实 A/1729→B/4096；Calculator 镜像显示0。Alma 两窗均出帧、帧龄更新；对 Alma helper pid37196 的 MCP AX 读取返回 `cannotComplete while reading AXWindows`，本轮没有取得它的浮窗截图，不把状态字段当作视觉证据。

### 3. 验证 armed 与 session 独立

```json
{"cmd":"pip_arm","args":{"bundle":"com.apple.TextEdit","pid":64284,"window_id":233332,"title":"CX17_ArmA"}}
{"cmd":"pip_arm","args":{"bundle":"com.apple.TextEdit","pid":64284,"window_id":233332,"title":"CX17_ArmB"}}
{"cmd":"pip_arm","args":{"bundle":"com.apple.calculator","pid":57752,"window_id":230248,"title":"CX17_ArmCalc"}}
{"cmd":"pip_status","args":{}}
{"cmd":"pip_disarm","args":{"bundle":"com.apple.calculator","pid":57752,"window_id":230248}}
{"cmd":"pip_close","args":{"bundle":"com.apple.TextEdit","pid":64284,"window_id":233332}}
{"cmd":"pip_status","args":{}}
```

两端已验证的语义：

|动作|核对结果|
|---|---|
|同一窗口重复 arm|响应回声 ArmB，但 status 仍存第一次 ArmA；只有一条 armed|
|第二个 app arm|两个源 ID 可同时 armed|
|disarm Calculator|Calculator session 仍在|
|close TextEdit|TextEdit armed 仍在|
|再次 close 已关闭窗口|ok:true，data.closed:false|
|再次 disarm 已解除窗口|ok:true，data.disarmed:false|

这不是“close 自动全部清理”的 API。单窗 close/disarm 的布尔字段在本轮两端均直接位于 `data`。

### 4. 最小化触发与一次性消费

1. 定向清理该源的旧 session/armed；用带截图的 MCP get_app_state 使源窗口可见并刷新最小化按钮 ref。
2. 向需要测试的 daemon 发送 `pip_arm`，确认 armed 有目标、sessions 无目标。可同时给两端 arm 同一测试源，使它们观察同一次 GUI 事件。
3. MCP `click({bundle:"com.apple.TextEdit",ref:"e75",strategy:"ax"})` 点击源窗口 AXMinimizeButton。先读 socket `pip_status`，不要先拍源窗口。
4. 本轮结果：目标 session 出现，目标 armed 消失。关闭 session，再用 MCP get_app_state 恢复源窗口；**不重新 arm**，再次点最小化，status 应不再出现目标 session。
5. 重新 arm 后可再次触发。另测“session 已存在时 arm→最小化”：Calculator 两端都仅保留一个原 session，保留原 title，并消费 armed。

带截图的 get_app_state 会恢复最小化的源窗口；MCP 动作还可能附带动作后截图。以事件后 socket status 证明消费，不把后来的源窗口可见性当作最小化未发生。

CX17 两端在**源窗口仍最小化时新建**的会话，约9秒后仍 `has_first_frame:false`；恢复源窗口后两端均出帧。这是本机对照一致的现象，不能报被测实现独有 bug，也不能声称最小化期间已有实时画面。

## 已踩的坑 / 不要做的事

- 不发明 `minami_computer_use.pip_open` 这样的 MCP 工具名，不用 shell/AppleScript 编辑源文稿。
- 不硬编码默认334×220。本轮宽度240，TextEdit高200、Calculator高426；源尺寸和当前环境会影响大小。
- **默认位置存在已确认差异**：ours 两窗返回同一 x1248/y84；Alma 分别为 x1248/y725 与 x1220/y471。这里只确认返回位置/布局不同，不猜坐标系根因。像素点击必须重新 MCP get_app_state，不能直接拿 floater_frame 当截图映射。
- **源窗口关闭后可能残留 PiP**：本轮第二次复现中 ours 在源已关闭43秒后仍有无新帧 session，Alma 已为空。主动按源 ID close 清理，不能只关闭源窗口就结束。
- 本轮“窗口关闭后 armed 仍留存”两端一致；清理时显式 disarm，不据旧契约推断它自动消失。
- stale ref 要重新取快照；不要拿 source 的按钮 ref 去关 helper 浮窗，也不要在清理中点击用户原文稿。
- 前台采样一直是 Paseo，但若干光标变化已单独记为待归因观察；没有隔离用户输入时，不把它们直接定性为 FocusGuard 缺陷。

## 验证点（怎么确认成功）

- 多应用：status 同时含两个本轮源 window_id，单窗关闭不影响另一个。
- 镜像：helper 浮窗截图有 A→B 的实际内容变化；has_first_frame/帧龄作为辅助证据。
- armed：重复 arm 不增加条目；disarm 与 close 独立；首次最小化消费、第二次不重开、重新 arm 可再触发。
- 来源关闭：立即和延后 status 对照；若残留，记录其 ID/帧龄并定向 close，不能把框架异步返回直接当成功清理。
- 前后台：每场景前后哨兵都落盘。相同采样只证明采样点相同，不证明中间没有瞬态。
- 证据见 [RUNLOG CX17](../../computer-use/field-e2e/RUNLOG.md#cx17-获授权的pip续测) 和 [BUGS](../../computer-use/field-e2e/BUGS.md)。

## 清理

1. 对每个本轮拥有的源 ID 发送 `pip_disarm({bundle,pid,window_id})`，再 `pip_close({bundle,pid,window_id})`。源窗口已消失也沿用登记的 ID 清理；本轮此路径成功。
2. 对 ours 和 Alma 分别 status；本轮最终两端均 `sessions:[],armed:[]`。若最初有他人会话，应核对它们仍在，而非要求全局空。
3. 不用 `all:true` 影响未登记会话。重复返回 false 可接受，结合最终 status 验证。
4. MCP 关闭自建文稿，在保存面板点“删除”丢弃本轮未保存内容；原文稿保留。若借用计算器，恢复原模式/数值，本轮开始和结束均为基础模式0。
5. 最后跑哨兵，记录所有残留和限制。CX17 两个自建文稿已丢弃，没有保存测试文件；原 TextEdit W230637 的 `é👩‍💻` 保持不变。
