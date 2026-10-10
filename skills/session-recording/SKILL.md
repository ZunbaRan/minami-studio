---
name: session-recording
description: 用 record_* 录制 agent 操作会话，再用 zoom_export 出带自动变焦/光标重绘/点击涟漪的成片 mp4。被动工具——需主动 record_start 开始，录完必须 record_stop 收尾。
---
# 会话录制 + 自动变焦导出

minami-studio 的新面能力：daemon 边操作边把屏幕录成 mp4（OS 光标不烧进像素），
同时并行记录光标/点击遥测到 `<out>.cursor.json`；事后 `zoom_export` 一次
渲染出 Screen Studio 风格的自动变焦成片。

## 标准流程

```
record_start {out:"/tmp/session.mp4", fps:60}
   …正常用 click / drag / type_text / get_app_state 干活…
record_stop                        # → {out, frames, duration_s, cursor_telemetry}
zoom_suggest {in:"/tmp/session.mp4"}   # 可选：预览自动聚类出的变焦 region
zoom_export {in:"/tmp/session.mp4", out:"/tmp/session-final.mp4"}
```

## 关键事实

- **录制不烧光标**：成片里的光标是 export 时按遥测重绘的；agent 的
  `click`/`drag`（CGEventPostToPid）和用户的真实点击（session tap）都会进
  遥测，渲染光标跟随 agent 的虚拟指针移动。
- **`zoom_suggest` 干跑**返回 `regions:[{start_ms,end_ms,cx,cy,depth}]`——
  不满意的 region 可以改 JSON 后用 `zoom_export{regions:[...]}` 显式覆盖；
  `auto_zoom:false` + 空 regions = 纯转码（只叠光标/涟漪）。
- **depth** 1–6 → 1.25×/1.5×/1.8×/2.2×/3.5×/5×，默认 3（1.8×）。
- **window_id 录制**只录窗口矩形（display-crop 语义，遮挡录上层）；
  `display_id` 指定整屏。录制中窗口消失会自动 finalize 并广播
  `studio.rec.stopped` 事件。
- **record_pause/resume**：暂停段从成片时间轴里消失（不出黑帧）。
- **zoom_export 是同步阻塞**，吞吐约 1× 实时（60fps 源）；长录像耐心等。
- `motion_blur`（默认开）：运镜时加方向/径向模糊，更像 Screen Studio。
  `audio`（默认开）：源片有音轨则压缩透传。`click_rings`/`show_cursor` 可关。

## 产物消费

成片是普通 H.264 mp4，`ffprobe`/`open` 直接可看。`.cursor.json` 留底后
同一录像可用不同 depth/regions 反复重出。
