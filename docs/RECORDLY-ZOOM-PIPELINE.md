# Recordly 录屏 + Scale 效果逆向分析

> 调研对象：https://github.com/webadderallorg/Recordly (v1.4.0, main @ clone 2026-10-09)
> 本地镜像：`agent-research-artifact/external/recordly/`
> 目的：评估为 minami-computer-use 增加"自带录屏 + scale 缩放效果"的可行路径。
> 许可证警告：**Recordly 是 AGPL-3.0**，代码不可直接复制进 minami-computer-use。
> 本文只提取架构、算法、常数——数学与思路重新实现不侵权。

## 0. 一句话结论

Recordly 的"scale 效果"**不是录制时的效果，而是后期合成效果**。
它的完整配方是三步：

1. **录制时把鼠标从视频里剔除**（`showsCursor = false`），视频是纯画面；
2. **录制时并行收集光标遥测**（位置 33ms 轮询 + CGEvent tap 点击 + AX 光标类型），存 sidecar JSON；
3. **导出时逐帧重渲染**：视频帧 → 相机仿射变换（缩放锚定 focus 点 + easeOutZoom 缓动 + 光标跟随相机 + 运动模糊）→ 后期重绘光标 → 编码。

不烧鼠标进视频是整个效果的根基——缩放的视频里如果有一个被拉大的 OS 光标会立刻露馅。光标后期重绘还能白得：平滑、样式替换、点击涟漪、bounce、sway。

## 1. 三段式架构

```
┌──────────────────┐   ┌──────────────────┐   ┌─────────────────────┐
│ recordly-screenc │   │ recordly-native- │   │ Electron renderer   │
│ apturekit-helper │   │ cursor-monitor   │   │ (编辑器+导出)        │
│ (Swift, SCK→mp4) │   │ (Swift, CGEvent  │   │ PixiJS + WebCodecs  │
│                  │   │  tap + AX 光标)   │   │ ffmpeg-static(音频) │
└───────┬──────────┘   └───────┬──────────┘   └─────────────────────┘
        │ stdin JSON/stdout 行  │ stdout "STATE:/INTERACTION:" 行
        └──────────┬───────────┘
                   │ Electron main (录制协调 + 33ms 光标位置轮询 + sidecar 写盘)
```

### 1.1 录制段：`electron/native/ScreenCaptureKitRecorder.swift`（1105 行）

独立 helper 进程，Electron main spawn，stdin 接 JSON config，stdout 行协议回报生命周期：
`Recording started`（第一帧被 AVAssetWriter 接受才打印）→ `Recording paused/resumed` →
`Recording stopped. Output path: X`；窗口消失报 `WINDOW_UNAVAILABLE`。

关键配置（`CaptureConfig` / `startCapture`，L85-359）：

| 项 | 值 |
|---|---|
| 帧率 | `minimumFrameInterval = 1/60`，queueDepth=6 |
| 像素格式 | display 录制 `420YpCbCr8BiPlanarVideoRange`；window 录制改 `32BGRA` |
| 颜色 | sRGB, BT.709 matrix |
| **鼠标** | **`showsCursor = false`** |
| 音频 | 可选系统声/麦克风，inline track + 独立 m4a sidecar 双写 |
| 编码 | AVAssetWriter + `AVOutputSettingsAssistant(preset3840x2160)` → H.264 mp4/mov |

**窗口录制的实现方式值得注意**：不是 window-level `SCContentFilter`，而是
**display filter + 逐帧 CIContext crop**（L133-172, `appendCroppedVideoFrame` L473+）：
取窗口所在 display 整屏 → 归一化 crop rect → CIImage crop → pixel buffer adaptor 写入。
语义 = 录的是屏幕上那块区域，遮挡时录到上层内容，与 Alma PiP 的 display 镜像语义一致。
窗口跟踪靠 `windowValidationTask` 轮询，窗口消失即 `WINDOW_UNAVAILABLE` 终止。

pause/resume：暂停期丢帧 + `accumulatedPausedDuration` 重基线 presentation time，
恢复后第一帧 `pendingResumeAdjustment` 修正时间戳。

### 1.2 光标遥测段：`electron/ipc/cursor/` + `NativeCursorMonitor.swift`

两条数据源汇成 `{timeMs, cx, cy, interactionType, cursorType}` 采样流：

- **位置**：Electron main `startCursorSampling()`（telemetry.ts L298-327），
  33ms 递归 setTimeout（带漂移补偿）轮询 `screen.getCursorScreenPoint()`，
  归一化到被录 display 或 window bounds → `cx, cy ∈ [0,1]`。
  相对视频时钟（`getCursorCaptureElapsedMs`，暂停期扣除）。
- **点击/光标类型**：`recordly-native-cursor-monitor` Swift helper，
  `CGEvent.tapCreate` 全局监听 mousedown/mouseup(+button号) → `INTERACTION:mousedown[:N]`；
  `AXUIElementCopyElementAtPosition` + NSCursor 位图签名匹配 → `STATE:arrow|text|pointer|...`。
  Electron 侧 uiohook-napi 作补充/兜底（interaction.ts）。

停止录制时写 sidecar：`<video>` 旁 JSON `{version, samples[]}`（`writeCursorTelemetry`），
`MAX_CURSOR_SAMPLES` 有上限。

### 1.3 合成/导出段：`src/components/video-editor/` + `src/lib/exporter/`

#### Zoom 数据模型（types.ts）

```
ZoomRegion = { startMs, endMs, focus:{cx,cy}, depth:1..6, mode }
ZOOM_DEPTH_SCALES = {1:1.25, 2:1.5, 3:1.8, 4:2.2, 5:3.5, 6:5.0}   # depth3=1.8× 默认
```

#### 自动 zoom 生成（`timeline/zoomSuggestionUtils.ts`）

输入 = 光标遥测；输出 = SuggestedZoomRegion[]。

1. 只取 explicit click 类事件（click/double/right/middle，dwell 启发式只用于补光标类型）；
2. `classifyPostClickBehavior` 按点击后轨迹分类：dropdown-open（向下浏览）、
   text-selection（水平拖拽）、text-field-click（停住不动）、double-click-like、click-like；
3. `buildClickClusters`：相邻点击 gap ≤ 2500ms 合并成簇，focus 取簇内最强点击位置；
4. region = 簇首尾 ± 500ms padding，跳过与已占 span 重叠的簇。

`useFreshRecordingAutoZoom`：新录像进编辑器后自动生成这批 region 落到时间轴。

#### 每帧相机求解（`sceneMotion.ts` → `zoomRegionUtils.ts` → `zoomTransform.ts`）

```
resolveSceneZoomTarget(t) =
    findDominantRegion(regions, t)          # 当前最强 region + strength(0..1) + blendedScale
  → strength = computeRegionStrength(...)   # easeOutZoom ramp
  → focus    = cursorFollowCamera(...)      # 非 manual 时焦点跟光标
  → computeZoomTransform(stage, mask, S, p, focus)  # 仿射
  → applyZoomTransform(Pixi Container)      # scale+position + 运动模糊 filter
```

`computeRegionStrength`（zoomRegionUtils.ts L38-73）时间窗细节：

```
ZOOM_ANIMATION_DELAY_MS      = 500   # region 时间轴整体后移 500ms
ZOOM_IN_TRANSITION_WINDOW_MS = 1522.575  (TRANSITION_WINDOW_MS*1.5)
TRANSITION_WINDOW_MS         = 1015.05   # zoom-out 时长
ZOOM_OUT_EARLY_START_MS      = 500   # zoom-out 比 region.endMs 提前开始
ZOOM_IN_OVERLAP_MS           = 1000

leadInStart = startMs + 1000 - 1522.575   # ≈ startMs - 523 + 500delay
zoomIn 进度: easeOutZoom((t-leadInStart)/1522.575)
zoomOut 进度: 1 - easeOutZoom((t-zoomOutStart)/1015.05)
```

`connectZooms`（L79-186）：相邻 region gap ≤ 1350ms 时不缩回 1.0，
而是用 1000ms 等缩放平移直接切到下一个 focus（"chained pan"），Screen Studio 那种连贯运镜。

`computeZoomTransform`（zoomTransform.ts L421-452）核心公式——锚定 focus 的缩放：

```
focusPx = baseMask.origin + focus * baseMask.size
scale   = 1 + (zoomScale - 1) * progress           # progress=strength∈[0,1]
x = stageCenter - focusPx * zoomScale, 再乘 progress 做线性插值
```

**光标跟随相机**（cursorFollowCamera.ts，201 行）：zoom 内焦点不死钉 region.focus。
维护相机中心 + safe zone = 可见跨度(1/scale)内缩 25%；光标出 safe zone 才把相机
recenter 到光标位（`recenterFocusWhenCursorLeavesSafeZone`）；
`reachedFullZoom` 后进入 zoom-out 段立即冻结焦点，避免缩出时乱晃。

**运动模糊**（zoomTransform.ts L261-419）：相邻帧 camera quad 差分分类
move/zoom → pan 给 directional MotionBlurFilter（13 kernel），
scale 变化给 ZoomBlurFilter 径向模糊，强度随帧间隔自适应（resolveFpsScale）。

#### 光标后期重绘（cursorRenderer.ts + PixiCursorOverlay）

录制里没有 OS 光标 → 导出时按 telemetry 逐帧插值位置画上去：

- `interpolateCursorPosition`：样本间线性插值取当前时刻光标位；
- spring 物理平滑（stiffness/damping/mass 可调）、sway 摆动、运动模糊；
- 点击涟漪（clickEffect）、按下 bounce 缩放；
- 光标形状：`recordly-system-cursors` helper 从系统导出 PNG（tahoe/win10 等主题），
  按 telemetry.cursorType 选帧。

#### 编码导出（`src/lib/exporter/modernVideoExporter.ts`，3792 行）

```
源视频 WebCodecs VideoDecoder 流式解 → 每个媒体帧时间戳 renderFrame(t)
→ PixiJS offscreen canvas 合成(视频+相机变换+光标+webcam+字幕+批注)
→ new VideoFrame(canvas) → VideoEncoder(H.264) → VideoMuxer(mp4)
→ ffmpeg-static 做音频 mux（录制内联音轨 + sidecar m4a）
```

Windows 有 CUDA native compositor 静态布局快路径（`native/`），macOS 走上述通用管线。

## 2. 映射到 minami-computer-use

### 已有地基（可直接复用）

- Swift daemon 已内嵌 SCStream（PiP 镜像管线）——录制器可以**进程内做**，
  不需要 Recordly 的独立 helper 形态；
- CGEvent tap 经验（FocusGuard）——点击遥测直接加一路 passive listen-only tap；
- AX 基础设施——`AXUIElementCopyElementAtPosition` 光标类型探测同款可写；
- socket NDJSON 命令面 + 23 工具 MCP wrapper ——`record_*` 命令族按现有命令注册表扩；
- PiP 浮窗已对 SCStream 帧做显示——**live scale 预览可复用同一渲染路径**。

### 需要新建的三块

| 块 | 做法 | 量级 |
|---|---|---|
| **recorder** | daemon 内 SCStream(60fps,showsCursor=false)+AVAssetWriter→mp4；window 模式 = display filter+CI crop（Recordly 同款语义，遮挡录上层）；pause/resume 抄时间戳重基线方案 | 中（~400 行 Swift） |
| **cursor telemetry** | 33ms CADisplayLink/Timer 轮询 NSEvent.mouseLocation→归一化；CGEvent tap 记点击；AX+cursor signature 记形状；录制结束写 `<video>.cursor.json` | 小（~200 行 Swift） |
| **zoom compositor** | 离线导出：AVAssetReader 逐帧 → CIImage 仿射(computeZoomTransform 纯函数直译)+easeOutZoom+chained-pan+safe-zone 跟焦 → AVAssetWriter；可选 live：PiP 浮窗渲染路径加同一 transform | 中-大（数学可直译，渲染管线是工作量） |

### 关键设计决策（用户需拍板）

1. **scale 后期 vs 实时**：Recordly 全部后期（录制永远是 1.0x 干净素材，
   相机是导出参数）。若我们只要"录完的视频有缩放"，照抄后期方案最稳——
   **录制器本身零侵入**，缩放引擎是一个纯函数管线，甚至可以先做成独立
   `minami-cu-zoom` 小工具验收效果再并入 daemon。
2. **渲染技术栈**：Recordly 用 PixiJS/WebGL+WebCodecs（Electron 内）。
   daemon 是纯 Swift，对应物 = CoreImage 仿射 + AVAssetWriter，或 Metal。
   数学部分（focus 锚定、easeOutZoom、safe-zone recenter、chained pan、
   click-cluster 生成）**全部是纯函数/常数，AGPL 不影响重实现**。
3. **光标**：照抄"不烧进视频+后期重绘"路线，同时白得点击高亮/平滑/换肤。
   需要 macOS 系统光标 PNG——可运行时 CGImage 导出（Recordly 的
   `SystemCursorAssets.swift` 思路）或简化成矢量绘制。
4. **与 Alma parity 的关系**：这是分叉新能力，不受"只对标 Alma"约束；
   但 wire 风格应照旧（NDJSON 命令、错误面、工具命名）。建议命令面：
   `record_start{window_id?|display_id?,out,fps?}`、`record_stop`、`record_status`，
   `zoom_export{video,telemetry?,out,auto_zoom?,regions?}`。

### 风险/未知项

- AVAssetWriter H.264 60fps 在 daemon 进程内的 CPU 开销（Recordly 独立进程隔离了崩溃域）；
- 后期导出逐帧 CI 变换的吞吐（4K60 需要 Metal 加速路径才跑得动实时导出）；
- 光标类型签名匹配要维护 NSCursor 位图样本（Recordly 有现成对照表思路，我们需自建）；
- `SCContentFilter` window 级录制（`init(desktopIndependentWindow:)`）在 macOS 15+
  可获得真·窗口内容（遮挡也录得到被遮窗口）——比 Recordly 的 display-crop 更强，
  Alma PiP 用的就是这条路径，**录制端可以比 Recordly 做得更好**。

## 3. 证据锚点

| 主题 | 文件 | 关键行 |
|---|---|---|
| SCK 录制配置/双轨 crop | `electron/native/ScreenCaptureKitRecorder.swift` | L85-359, L473+ |
| 录制生命周期行协议 | `electron/ipc/recording/mac.ts` | L35-156 |
| 光标采样 33ms+漂移补偿 | `electron/ipc/cursor/telemetry.ts` | L298-327 |
| 光标归一化到 window/display | 同上 | L167-211 |
| CGEvent tap+AX 光标类型 | `electron/native/NativeCursorMonitor.swift` | L179-330, L409-497 |
| zoom 深度表 | `src/components/video-editor/types.ts` | L640-647 |
| 自动 zoom 生成 | `src/components/video-editor/timeline/zoomSuggestionUtils.ts` | 全文 529 行 |
| 每帧相机求解 | `src/components/video-editor/videoPlayback/sceneMotion.ts` | L63-114 |
| zoom 缓动/时窗常数 | `src/components/video-editor/videoPlayback/zoomRegionUtils.ts` + `constants.ts` | L38-73 |
| 仿射变换公式 | `src/components/video-editor/videoPlayback/zoomTransform.ts` | L421-452 |
| 光标跟随相机 | `src/components/video-editor/videoPlayback/cursorFollowCamera.ts` | 全文 201 行 |
| 导出编码链 | `src/lib/exporter/modernVideoExporter.ts` | L2847-3150(渲染), L3542+(编码) |
| 光标重绘 | `src/components/video-editor/videoPlayback/cursorRenderer.ts` | L710, L1638+ |
