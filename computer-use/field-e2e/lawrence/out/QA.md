# LAWRENCE-TOUR 交付核验

- 编号 001～080 连续，61 成功、19 失败；`clips/` 的 61 个 MOV 与成功记录集合完全相等，失败 MOV 均已删除。
- 保留片段：H.264、2754×1884，最短 8.000 秒、最长 8.243333 秒；全部通过 ffprobe。
- 61 段的 0.1 秒与 7.5 秒画面已抽帧，11 张联系表逐张看图，确认对应的页面、弹窗、选中项或输入结果；联系表最后一张的黑色空格是排版留白。
- 合并使用 `ffmpeg -f concat -safe 0 -i clips.txt -c copy -movflags +faststart out/lawrence-tour.mov`。
- 成片 H.264 / yuv420p / 2754×1884，496.711979 秒（8:16.712），121,065,148 字节。
- concat copy 出现边界 DTS 修正，成片与原片时长总和相差约 0.009 秒。默认 null 输出检查的 2408 条信息全部是输出时基取整造成的非递增 DTS 告警；不混同输入解码错误。
- 最终完整检查命令：`ffmpeg -v error -xerror -i out/lawrence-tour.mov -fps_mode passthrough -enc_time_base demux -f null -`，退出码 **0**，日志 **0 字节**。证据为 `evidence/video-decode-passthrough.exit` 和 `evidence/video-decode-passthrough.log`。
- 末态只读截图：`evidence/final-clean.jpg`；原页面及固定窗口已恢复，无弹窗。邮箱连接报错和 076 的前台/鼠标变化来源未定，详情见 LOG.md。没有宣称全程后台约束得到无例外验证。
- 覆盖在 80 次预算上限停止；菜单完整展开、各页面所有控件仍未穷尽。042/057 的成功只表示导航/页签可见变化，不能据此声称内容功能执行通过。
- `skills/lawrence-exploration/SKILL.md` 共 226 行，通过 skill-creator 的 `quick_validate.py`（输出 `Skill is valid!`）；安装文件与本地草稿逐字节相同。
