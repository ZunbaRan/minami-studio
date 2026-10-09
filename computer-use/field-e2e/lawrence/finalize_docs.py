#!/usr/bin/env python3
"""Finalize the tour documentation from the recorded operation evidence."""
import collections
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent
records = [json.loads(p.read_text()) for p in sorted((root / 'evidence').glob('*_record.json'))]
assert len(records) == 80
kept = [r for r in records if r['status'] == 'success']
failed = [r for r in records if r['status'] == 'fail']
assert len(kept) == 61 and len(failed) == 19

workarounds = {
    1: '首次录屏进程受沙箱限制；在已有录屏权限的执行环境重试。添加账户的初次打开归因不确定，不把该次当成功。',
    2: '当前弹窗与预期不符，重新截图识别实际页面；没有继续盲点原 tab。后续 012 切换成功。',
    4: '聚焦无法由截图确认；取得深层 AX 后优先 set_value。该字段本轮未验证可写。',
    5: '投递字符数不证明落字；白名单搜索的 set_value 在 031 成功，此账户字段未验证。',
    8: '窗口 ref 不支持 AXScrollDownByPage；需找到支持滚动的容器，本轮未验证 Chromium 滚动替代法。',
    13: '后台像素点击没有路由变化；028 当前 AXLink 的 AXPress 成功。',
    14: '双击未解决问题，停止同坐标重试；改用 028 的 AXLink。',
    15: '只见悬停；029 使用深层 AXLink 成功。',
    16: '只见悬停；034 使用深层 AXLink 成功。',
    17: '菜单项回调已调用，但应用未显示偏好设置；034/079 的页面设置入口有效。',
    18: '菜单项回调无可见效果；024 的明确上传按钮能打开文件框，但用途不同，不能替代通用 Open。',
    19: '像素点只悬停；054 当前侧栏 AXLink 导航成功。',
    20: '右键没有显示菜单，不猜测隐藏菜单项；该入口的正常 AXLink 可导航。',
    21: '没有可辨认的焦点，停止盲按 Return；使用深层 AX ref 操作。',
    25: '原生文件框的像素取消无效；026 对当前 enabled 的“取消” AXButton 执行 AXPress 成功。',
    30: 'type_text 的 AX 路径返回成功不等于字段变更；031 set_value 成功，032 清空恢复。',
    58: 'Close 的 AXPress 未收起侧栏；059 离开会话路由。恰好完成的 Skills 加载与关闭动作不可混淆。',
    76: '超出验收窗口后才见成本页，同时出现前台/鼠标变化；暂停并核对，来源未定，不算稳定成功。',
    78: '无 ENABLED 菜单项持有 ctrl+F2，后台路由 suppressed；没有通过激活目标或全局点击绕过。',
}

def esc(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')

menus = json.loads((root / 'evidence/initial.json').read_text())['menu_shortcuts']
menu_lines = ['| 菜单路径 | chord（原始显示） | 本轮验证 |', '| --- | --- | --- |']
for item in menus:
    combo = item['combo']
    result = {'cmd+,': '017：已投递，无可见效果', 'cmd+o': '018：已投递，无可见效果'}.get(combo, '只读列出，未执行')
    menu_lines.append(f"| {esc(' → '.join(item['path']))} | `{esc(combo)}` | {result} |")
menu_lines.append('| 菜单访问探针（非 menu_shortcuts 项） | `ctrl+F2` | 078：suppressed |')
failure_lines = ['| 编号 | 失败操作 | 分类与观察 | 原因边界 / 绕法 |', '| --- | --- | --- | --- |']
for r in failed:
    failure_lines.append(f"| {r['number']:03} | {esc(r['element'])} | {esc(r['effect'])} | {workarounds[r['number']]} |")

skill = root / 'skill-draft/SKILL.md'
body = skill.read_text()
body = body.replace('<!-- MENU_TABLE -->', '\n'.join(menu_lines))
body = body.replace('<!-- FAILURE_TABLE -->', '\n'.join(failure_lines))
body = body.replace('共执行 80 次操作，达到本轮预算上限。', '共执行 80 次操作：61 次成功、19 次失败；成功片段合并为 8 分 16.7 秒视频，达到本轮预算上限。')
assert '<!-- MENU_TABLE -->' not in body and '<!-- FAILURE_TABLE -->' not in body
skill.write_text(body)

probe = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration,size:stream=codec_name,width,height,pix_fmt', '-of', 'json', str(root / 'out/lawrence-tour.mov')], check=True, capture_output=True, text=True)
media = json.loads(probe.stdout)
(root / 'out/media.json').write_text(json.dumps(media, indent=2) + '\n')
summary_path = root / 'out/summary.json'
summary = json.loads(summary_path.read_text())
summary.update(video_duration_seconds=float(media['format']['duration']), video_size_bytes=int(media['format']['size']), failure_categories={'无效果': 16, '报错': 2, 'suppressed': 1}, successful_dialog_cancellations=5, exhaustive=False, stop_reason='80-operation budget reached', original_route_restored=True, target_bounds_unchanged_in_observations=True, foreground_cursor_anomaly='076: origin undetermined; paused until read-only check showed Paseo foreground again', final_runtime_difference='Email wise channel: Command failed; existing channel controls were not operated', skill='skills/lawrence-exploration/SKILL.md', skill_path='/Users/lu/Documents/data/project/alma-reverse/minami-studio/skills/lawrence-exploration/SKILL.md')
summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')

index = ['# 成功录像索引', '', '时间为按片段时长累加的近似起点；拼接时间戳调整合计约 0.009 秒。每一行均可对应 LOG.md 和 evidence/ 的同编号证据。', '', '| 起点 | 编号 | 操作 | 效果 |', '| --- | --- | --- | --- |']
offset = 0
for r in kept:
    sec = offset % 60
    index.append(f"| {int(offset // 60):02}:{sec:06.3f} | [{r['number']:03}](../clips/{pathlib.Path(r['clip']).name}) | {esc(r['element'])} | {esc(r['effect'])} |")
    offset += float(r['media']['format']['duration'])
(root / 'out/VIDEO_INDEX.md').write_text('\n'.join(index) + '\n')

report = '''
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
'''
log = root / 'LOG.md'
original = log.read_text().split('\n## 本轮汇总与覆盖边界')[0]
log.write_text(original.rstrip() + '\n' + report)
print('Finalized skill, 80-operation log, media metadata, summary, and 61-clip index.')
