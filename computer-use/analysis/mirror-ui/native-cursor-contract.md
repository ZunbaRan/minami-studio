> 来源：用户提供的 .164 研究资料 `analysis/mirror-ui/native-cursor-contract.md`；原文件 SHA256 `986593ccc38d89b0ba185645174a60d01520208f06c6917e49516c923e97a121`；全文件 1–114 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native Lens, action cursor and native PiP supplement

## Evidence convention

Native file: `extracted/Alma.app/Contents/Resources/Alma Computer Use.app/Contents/MacOS/AlmaComputerUse`. ARM64 Mach-O slice begins at fat-file byte1228800. Addresses below are virtual addresses. For addresses in __TEXT shown here, slice offset=address−0x100000000; whole-fat-file offset=1228800+slice offset. SHA-256 and ranges are in `native-evidence.json`. Full original analyst-generated disassembly is in `analysis/native/arm64-disasm.txt`; function call catalog and parser metadata are cross-check aids, not a substitute for the explicitly inspected instructions below.

## 1. Two independently gated pointer representations (high confidence)

Native singleton LensOverlay initialization at0x100041a9c–0x100041ae4 writes halfword1 to object offset0x24, which is little-endian bytes {1,0}. Other inspected methods establish that +0x24 is the optional target-window tag and +0x25 is enabled. Consequently default target is absent and Lens enabled=false.

- setEnabled at0x100041e34–0x100041e70 locks, writes enabled byte+0x25, and calls immediate hide when false.
- showAt at0x100042330–0x100042358 first calls ActionCursor.set(point), then locks/reads enabled; returns from visual work when not enabled.
- Therefore normal show_cursor=true can update the JPEG PiP's synthetic cursor while native desktop Lens is disabled. Setting lens enabled=false is not equivalent to suppressing ActionCursor state.
- Representative clickAtPoint at0x100014554 branches around LensOverlay.showAt if showCursor is false, before performing actual click. Do not generalize this single inspected branch to every action without the native input report's evidence, but equivalent Lens calls are statically catalogued for click/ref, drag, type, press, scroll, secondary action.
- Hiding Lens does not call ActionCursor.clear in inspected Lens hide call catalog; these states must not be coupled by a replica unless deliberately improving behavior.

Original implementation model:

    recordVisualAction(point, showCursor):
        if not showCursor: return
        actionCursor.point = point
        actionCursor.updatedAt = now
        if not desktopLens.enabled: return
        broadcast lens movement
        if targetWindow exists and point not visible in that window:
            hide desktop lens
            return
        choose screen containing converted point
        show/move native lens on that screen

The first four transitions are instruction-proven. The exact target-visibility behavior is additionally proven by the branch/call sequence below; window-visibility helper semantics require the native report's detailed WindowList analysis.

## 2. ActionCursor state and normalization (high confidence)

- State is shared point + timestamp protected by NSLock.
- set updates point/timestamp; clear invalidates state/timestamp.
- current at0x10002a218–0x10002a454 returns a point only if valid state, timestamp present, and elapsed age≤8seconds. It does not return the system's current hardware mouse position.
- normalized(rect) at0x10002a0e4–0x10002a214 requires current point, positive rect width/height, CGRectContainsPoint. Outside target image rectangle returns nil rather than clamping.

    u = (point.x − rect.minX) / rect.width
    v = (point.y − rect.minY) / rect.height

The helper's shot and shot_display response paths call this normalization at0x10007e06c and0x10007e95c. Caller window/display rect selection belongs to the native capture contract.

Example: source screen rect(-1920,0,1920,1080), action(-960,270) gives(u,v)=(.5,.25). Electron panel380×250 and source1920×1080 yield image380×213.75 top-centered; ring position(190,53.4375). Empty lower letterbox is36.25 pixels. No vertical centering offset is added by Electron.

## 3. Capture cursor inclusion is not uniform (instruction-proven)

| Capture route | Cursor flag | Evidence |
|---|---:|---|
| One-shot native window capture | false | w2=0 before setShowsCursor at0x10003fafc–0x10003fb00 |
| One-shot native display capture | true | w2=1 before setShowsCursor at0x100040464–0x100040468 |
| Native PIPSession continuous window stream | true | w2=1 before setShowsCursor at0x10004b2b4–0x10004b2b8 |

All three disable audio in inspected configurations. The native stream uses min interval1/30second, BGRA pixel format, queue depth3, and ignores single-window shadows on macOS≥14. One-shot captures set min interval1/60second; that API configuration does not mean the Electron pump achieves60fps (its timer is333ms plus action cooldown).

Thus there can be three distinct pointer-like visuals: captured hardware cursor (depends route), ActionCursor-derived Electron ring, enabled native Lens effects. A broad “never shows the user's mouse” claim would be false for the inspected display/native-stream configuration.

## 4. Desktop Lens visibility and no-focus intent

After enabled gate, showAt posts movement notification with screenPoint and slideMs. The notification is sent **before** checking whether target window is visible at point (0x100042544 precedes0x100042570). This allows native PiP to consume action movement even when the desktop overlay itself is suppressed.

If target window exists and isWindowVisibleAtPoint returns false, desktop path schedules fade/hide. Otherwise it caches last point, selects NSScreen, converts AX-style coordinate into AppKit screen coordinate using primary screen maximum Y, and moves corresponding overlay slot. Slots are keyed per screen.

activate creates a transparent native window/view, no shadow, ignores mouse events, shows via orderFrontRegardless or orders relative to target window after consulting its window level. Call catalog proves these operations at0x1000430d4–0x100043308; full style-mask/nonactivation flag semantics are not exhaustively decoded here. Do not upgrade no-key-focus intent into proven no-focus behavior on every macOS version.

A repeating visibility watcher calls isWindowOnScreen and, if last point exists, isWindowVisibleAtPoint; either failed test invokes fadeOutAndOrderOut (0x100047d1c–0x100047d9c). Exact interval not established in this supplement. Accessibility reduced-motion preference is read at creation and consulted by movement/pulse. Observer callbacks exist for workspace/accessibility notifications; exact notification-name mapping is not established here, so lock-screen hide must remain a test, not a claim.

Explicit disable dispatches hide immediately. Ordinary hide broadcasts Alma Lens hide and queues fade. Type/click/scroll helpers broadcast named events and call effect methods; enabled gate is present before broadcast in their inspected call neighborhoods. PIPLens uses an image cursor, click pulse and symbol badges, unlike Electron's CSS ring.

## 5. Native PiP lifecycle (call-graph-backed, medium to high confidence)

This is a **separate optional subsystem**, not the auto-mirror dismissal stack.

- PIPManager has sessions keyed native window ID, guarded by lock. Opening existing session dispatches bringToFront and returns status. New open resolves SCWindow through shareable-content cache, constructs session on main queue (semaphore bridge when off-main), registers it and returns snapshot. Evidence0x1000485e8–0x100048f9c.
- Session creates PIPFloaterWindow/content view, desktop-independent window filter, SCStream, adds stream output, orders window forward, starts capture, subscribes to Lens broadcasts, installs target-window destruction AX observer (0x10004a9a0–0x10004bda4).
- Lens events subscribed: almaLensMove, almaLensClick, almaLensTypeBadge, almaLensScrollBadge, almaLensHide. Broadcast sender object is passed through in showAt; exact receiver filtering before handlers is not exhaustively decoded.
- Frame handler enqueues sample buffer to display layer when ready; failed display-layer status flushes; image layer is unhidden and frame-time accounting updated (0x1000530a0–0x10005316c).
- Native close removes session under lock and schedules shutdown. shutdown removes notification observers, removes AX run-loop source/notification, stops capture and orders floater out (0x100049a50–0x100049c7c).
- Stream error schedules session shutdown and onClose callback. Target-window destruction schedules manager.close(windowID). No10min tombstone exists in inspected native manager methods; do not import Electron suppression into claims about native behavior.
- PIPMinimizeArmer is a separate observer-based capability. Its callback may open native PiP after source minimization; destruction disarms, but automatic-open failure retains the armed entry, as closed in PIP_EXTRA_CONTRACTS.md. Only call-graph/branch structure checked here; exact guard policy belongs in runtime unknowns unless separately decoded.

## 6. Native PiP pointer mapping (high confidence arithmetic)

Movement handler reads actual source window rect, rejects point outside source, computes a centered aspect-fit rectangle in native view bounds. Both axes are centered, unlike top-centered Electron image.

    scale = min(view.width / source.width, view.height / source.height)
    fitted.width = source.width * scale
    fitted.height = source.height * scale
    fitted.x = view.minX + (view.width - fitted.width) / 2
    fitted.y = view.minY + (view.height - fitted.height) / 2
    u = (screenPoint.x - source.minX) / source.width
    v = (screenPoint.y - source.minY) / source.height
    nativePoint.x = fitted.x + u * fitted.width
    nativePoint.y = fitted.y + (1 - v) * fitted.height

Evidence0x1000538cc–0x100053cb4: contains check, aspect-ratio branches, normalized division, and explicit1−v at0x100053ba8–0x100053bac. For source1920×1080, view380×250, fitted rect=(0,18.125,380,213.75). A quarter-height action becomes native y=18.125+.75×213.75=178.4375 in bottom-up coordinates. The same physical action is top-down pixel71.5625 in centered view, distinct from Electron's53.4375 due to different top-vs-center fitting.

Do not reuse the native1−v formula in DOM CSS, which is top-down; that would vertically mirror pointer movement. Do not reuse Electron oy=0 in a center-fit native view.

## 7. Explicit unknowns / runtime tests

- Screen lock, secure input, protected media, other Spaces, windows spanning displays, display disconnect, pixel/point scale mismatch
- Whether configured native stream shows cursor when pointer is outside source window; flags prove requested behavior only
- Whether desktop Lens window appears in a whole-display capture and creates visual recursion, or framework filters it
- Minimized/occluded source availability under actual ScreenCaptureKit OS behavior
- Native observer callback filtering when multiple sessions exist and source window moves during an action
- Whether Lens enabled state is ever persisted/reapplied outside inspected initialization; singleton default itself is proven false
- Closing/reopening native session while async stream callback pending; races/retention need instrumented run


## 8. Occlusion is visual policy, not an input gate

Cross-check from native input report: `WindowList.isWindowVisibleAtPoint` at0x100034d50 has observed callers from LensOverlay.showAt0x100042570 and its visibility timer0x100047d80. Actual click routing uses resolveClickWindowID0x100022c38, selects PID windows by containing point then first-window fallback. Therefore hiding Lens on occlusion must not be interpreted as rejecting/delaying a background click. This is a critical separation between presentation safety and event routing.
