> 来源：用户提供的 .164 研究资料 `analysis/mirror-ui/behavioral-contract.md`；原文件 SHA256 `0987dbe5713195393b4a1f9723c44e5e6ad269a58dabe606cb1e3b3dea259c35`；全文件 1–164 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Alma 0.4.164: mirror, cursor and Appshot behavioral contract

Static analysis only. No extracted application code was executed; no application, helper, target endpoint or target UI was launched. This is original behavioral description/pseudocode, not a source reproduction. Paths below are relative to `extracted/asar/out` unless specified. `evidence-index.json` gives full SHA-256, exact UTF-8 byte offsets, character offsets, and original line numbers. Most main code is minified onto line 1; offsets stated here are Unicode-character offsets, not bytes.

## 1. Architecture: three different visual systems

1. **Electron unified PiP stack**: one BrowserWindow with a stack of browser/computer presentation records. HTML polls a local JSON frame endpoint, renders JPEG and optional normalized cursor. This is the 0.4.164 dismissal-suppression implementation.
2. **Native helper Lens and native window PiP**: native classes LensOverlay, PIPManager/PIPSession/PIPLens. These can render native cursor effects and a ScreenCaptureKit window stream. They are not the same object or state machine as Electron PiP. Presence of native symbols is not evidence that the normal Electron auto-mirror uses native PIPSession: the traced Electron pump calls shot/shot_display instead.
3. **Appshot**: a user-triggered still-image capture plus source-app metadata/accessibility text, animated toward Alma's composer. Unlike the passive mirror, this deliberately brings Alma forward and focuses its composer.

High confidence for all three distinctions. Native-specific detail and addresses appear in `native-cursor-contract.md`.

## 2. Unified PiP state and exact dismissal fix

Evidence: main/index.js around 412660–427300, functions np/upsert, rp/invalidate, op/hide, tp/render.

State:
- optional BrowserWindow
- map from item ID to presentation {id, kind, label, threadId, workspace, displayId, targetBundle, targetPid, createdAt, updatedAt}
- active item ID
- most recently fitted item ID
- completing-item set
- dismissal map keyed `(item ID, thread ID or empty string)`, joined by a NUL separator
- programmatic-close flag and stack-close subscribers

Original pseudocode for the reopening fix:

    present(item, automatic):
        if automatic and item ID is not live:
            key = (item ID, item.threadId or empty)
            if dismissal exists:
                if now - dismissal > 600000 ms:
                    remove dismissal
                else:
                    dismissal = now
                    return without presenting
        if not automatic:
            clear every dismissal whose item ID matches
        update existing item or insert a new one
        new item becomes active; existing item keeps current selection
        clear completing flag for that ID
        ensure window, rebuild HTML, show inactive if hidden

The 10-minute period is a **sliding quiet period**, not a fixed cooldown after the first close. Continued automatic activity refreshes the tombstone. Therefore an agent that keeps working does not reopen a dismissed mirror simply because 10 minutes elapsed since dismissal. A genuinely different thread is a different suppression key. Manual presentation clears all thread-specific tombstones for that item ID. Tombstones are memory-only; the persisted JSON is geometry only.

Close distinctions:
- Close button with multiple items: tombstone selected item, mark completing, rebuild view, delete item after 420 ms; keep others.
- Close last item/window: on `closed`, tombstone every live item unless programmatic-close flag is set; clear stack and notify subscribers.
- Programmatic hide: set flag, close window, clear maps; **no dismissal tombstone**. Later automatic activity may reopen.
- Invalidate: mark completing and schedule deletion after 420 ms; no tombstone. Empty stack leads to programmatic hide.
- Existing item upsert while completing clears the flag but does not cancel the already scheduled deletion. This is a static race candidate, not a demonstrated runtime failure.
- Dismissal check applies only when ID absent. An automatic refresh during the 420 ms retirement interval can update a still-live dismissed item; timer still eventually deletes it.

The report can substantiate this implementation in 0.4.164; attribution as a historical fix additionally depends on release notes/diff evidence from the pinned version-comparison evidence.

## 3. Selection, source-switching, layout and focus

- Browser identity = `browser:` plus workspace or `sole`; computer identity = `computer:desktop` (one shared desktop item).
- Records list in creation-time order. If current active ID disappears, select newest remaining item. New insertion steals active selection within the panel; existing updates do not.
- Selecting a chip resets fit state and reloads the document. Label and thread/workspace/display use existing values when omitted; target bundle/PID update together when either explicitly provided, and change resets fit state.
- The computer module retains last target bundle/PID until 90 seconds inactivity or explicit end. A new bundle/PID replaces remembered target; an action lacking target retains previous target.
- A pump looks up current target bundle/PID on every capture, so changes take effect without new pump. Its display fallback ID is captured when pump is first created: updating the record's displayId alone does not recreate it. This stale-display possibility requires a runtime test.
- Default size 380×250; minimum window size 220×150. Stored size is restored, but stored x/y/displayId are not reused for initial placement in the traced path.
- Initial position is near bottom-right of main window, above composer, clamped to main display work area with 16 px edge gap. Without suitable main window, use cursor's nearest display bottom-right.
- Chooses main app window, otherwise largest visible non-PiP Electron window as anchor. Follows anchor move/moved deltas. Following movement does not perform the initial-placement clamp again.
- Async composer measurement has a 500 ms timeout and adjusts y only if user has not moved the initially placed panel.
- Fit-to-content only once per active ID until reset: preserve width, derive aspect-ratio height, cap at half work-area height, requested minimum 120 px; preserve bottom edge and clamp vertical placement to an 8 px gap. BrowserWindow minimum-height constraints may affect actual 120 vs150 outcome.
- Always-on-top floating window, hidden from taskbar, visible on all workspaces/fullscreen. `showInactive()` is used on automatic presentation. This supports intended no-focus opening but is not proof of all OS-version/workspace behavior.
- Explicit expand focuses/reveals Alma; navigates target thread if possible; browser presentations also send reveal-browser for the workspace. Thus no-focus is not promised for expand.
- Whole image surface is draggable/view-only; hover controls and chips opt out of drag. There is no pointer-to-target control forwarding in this HTML.

## 4. Capture versus renderer loop

### Computer mirror

Evidence: chunks/pipFrameSources-BwOu2Plt.js; computerUsePip-BTut449V.js; main/index.js Hp/zp at 531235.

- First frame HTTP request lazily creates one computer pump per item.
- Timer interval is round(1000/3)=333 ms; one nominal capture in flight.
- If in flight >4 seconds, drop busy flag; do not cancel underlying operation. Next tick can start a second operation. Late completions share output path and state, hence overwrite/race is possible.
- Skip capture while elapsed time since **agent computer activity** is <1200 ms. It is not a human-input idle detector. Activity is recorded before the PiP-enabled preference check.
- Try native target-window `shot` at max_width1024 if bundle or numeric PID exists. On error/null, fall back to `shot_display`, max_width1024, quality0.5, optional initial display ID.
- Read generated temporary JPEG to base64; update cached frame, normalized cursor and failure count; fit panel from returned dimensions. Failure does not clear previous successful frame.
- Log first failure and every fifteenth repeated failure. No expiry of cached frame is checked by frame endpoint.
- Stop clears interval, removes pump map entry, and best-effort deletes JPEG. Stopping does not cancel an in-flight capture; it may recreate the file afterward.
- Closing stack stops all computer pumps through onPipClosed subscription. Session inactivity end stops computer pump before invalidating presentation. Invalidation alone while other stack items remain does not call this stop function; a computer timer can remain until stack close/session timeout. Treat this as a lifecycle test candidate.

### Browser mirror

Evidence: main/index.js 454331–461980.

- Resolve in-app-browser target, ensure shared CDP screencast, set its `pip=true` lease flag.
- Screencast uses JPEG quality55, max1024×768, everyNthFrame1; acknowledge every received session frame.
- Frame endpoint returns cached latest screencast data. Before first stream frame, it issues Page.captureScreenshot quality55 with viewport/HD-aware clip when relevant.
- Subscribers and HD subscriber subset are distinct from PiP lease. New subscriber immediately receives cached latestFrame if present. Unsubscribe stops stream only if no PiP lease and no subscribers; otherwise reapplies detail mode.
- HD subscribers use additional quality80 captureScreenshot path, with busy/dirty coalescing. PiP cached stream remains baseline quality55. Detailed HD render logic is outside this UI contract.
- Stream sets page HTML white background through user-origin CSS, repeated on dom-ready. Teardown removes dom-ready callback and debugger listener; no inserted CSS removal is evident in this teardown.
- stopPipStreamFor clears PiP lease and stops only if no regular subscribers.
- Browser panel visible suppresses automatic PiP. Panel-visible IPC also hides matching preview and stops its PiP lease. Navigation triggers automatic preview before/after loading; it does not imply every browser tool action re-presents.
- HTTP browser hide/toggle explicitly stops PiP lease; generic stack close does not have a traced browser stop subscriber (only computer pump subscriber found). Browser stream may persist after user closes stack. Verify resource cleanup in runtime.

### HTML render polling

- Only active item is polled; interval is 220 ms **after response completion**, not an exact4.55fps schedule.
- Successful JPEG sets image and hides waiting state. Successful response with cursor maps normalized point into top-centered, contain-fit image; horizontal letterbox offset `(panelWidth - scaledImageWidth)/2`, vertical offset0.
- Cursor marker is a22px synthetic ring with .12-second position animation. Missing cursor on successful frame removes ring. Frame failure hides image and shows idle, but does not explicitly remove existing cursor class; network exception/non-OK response leaves prior display unchanged.
- Completing document stops new polls. beforeunload flips alive=false. A request already pending can finish and schedule one more timeout, whose next entry exits.
- Every upsert rebuilds HTML via data URL. Cached computer/browser frame source survives document reload; cursor naturalWidth may briefly refer to previous image dimensions until new JPEG loads. Needs source-switch test.

## 5. Activity and preference lifecycle

Computer PiP enabled defaults true unless settings explicitly false; settings read/parse failure also defaults true. Activity always marks last-activity timestamp. Enabled activity records optional target, auto-presents, resets90s timeout. Suppressed automatic present returns normally, so the timeout still resets. Disabled activity does not actively close existing presentation inside this module; renderer setting switch calls invalidate for computer:desktop.

Automatic middleware path list names get_app_state, click, perform_secondary_action, drag, type/type_text, press/press_key, set_value, scroll, raise, launch_app. The successful REST launch_app handler is registered earlier and ends the response, so that route does not traverse this later middleware. Notably simple windows/snap/shot/shot_display/lens are not in that middleware list. It asynchronously notes activity without awaiting before passing request to handler; mirror scheduling does not determine action success.

## 6. Appshot state machine and notifications

Evidence: main/index.js XY manager around2998170–3006900; preload appshots bridge; renderer App-CMj0T-97.js useAppshotShortcut and composer consumers; PluginNotificationListener-B2BL27X5.js appshot atoms/serialization.

States and subscription:
- Supported only macOS with helper available. State reports supported, platform, configuredHotkey, isActive=(subscription exists AND hotkey non-null), last error.
- Setting non-null hotkey installs monitor, update and disconnect listeners once, then starts native monitor. Success commits configured hotkey and clears error.
- Start refusal records monitor_refused or ax_not_granted; exception daemon_unreachable. Both unsubscribe listeners. Previous configuredHotkey is not explicitly cleared on that failure branch, so configured and active can differ.
- Null setting/disarm unsubscribes, clears hotkey/error, best-effort native stop.
- Disconnect with configured hotkey schedules one rearm after1500ms; checks current hotkey at firing. Rearm refusal/error only logs in that callback, no exponential retry shown. isActive is not a liveness probe and can remain true during reconnect.
- Prewarm creates animation overlay asynchronously and pings helper; warm overlay failure is logged independently of ping result. Restore applies stored hotkey. Before quit disarms and closes overlay.

Capture:
1. Manual captureNow and native `down` share a capturingNow guard; overlapping invocation returns/drops. Native key-down also plays shutter; manual captureNow does not invoke sound path.
2. Generate request ID; send starting notification before target resolution.
3. Use frontmost descriptor supplied with key event if found+bundle; otherwise ask helper for frontmost excluding Alma bundle.
4. Failures send request-correlated reason: frontmost_lookup_failed, no_target, capture_failed (capture failure adds message).
5. Capture native bundle/PID/optional window ID into appshots directory under userData.
6. If windowFrame+readable image+Alma window available, measure composer target up to5 tries with80ms gaps; fallback132×132 bottom-right inset32. Start non-awaited1100ms full-desktop animation.
7. Deliberately restore/show/focus Alma. On macOS temporarily make visible across workspaces and undo on first blur.
8. If animation was attempted, fire capture to renderer after715ms; otherwise immediately. Attempt flag does not guarantee animation actually rendered.

Animation overlay:
- One prewarmed transparent Electron window spanning bounding union of all display bounds; resize to current union before each animation.
- Not focusable, ignores mouse events, screen-saver window level. Uses showInactive; source/destination converted from global screen coordinates by union origin subtraction.
- Overlay hides on animation promise resolution or rejection. Started promise has a50ms fallback but overall animation completion has no independent timeout in the traced wrapper.
- Composer geometry predicts attachment row growth (64px bottom-pinned vs32px centered) and aims at a56px thumbnail box. Cross-display scale/negative-coordinate correctness needs physical display validation.

Renderer lifecycle:
- starting sets phase; setting target=new navigates from existing chat route to root before capture arrives; otherwise current composer.
- fired sets success and pending capture, with new monotonic consumption token and image/app metadata.
- failed sets failed and resets idle after4s only if same request still current.
- both root/new-chat and chat composer consume pending token once, read local image via bridge, attempt attachment upload, fallback dataURL on upload failure, attach JPEG, focus text area, store hidden context keyed original image path, clear pending in finally.
- This attaches a draft image; no auto-send occurs in this path.
- Delayed appshot-context-update fills only an existing hidden context whose AX text is empty. Early update before context insertion is dropped. Existing nonempty AX text never overwritten. This is an important race test.
- Remove attachment removes its hidden context. Serialization follows attached paths, skips empty AX, caps each AX context at4000 characters plus truncation indicator. Source app/title metadata accompany context. Rendering strips serialized appshot blocks from displayed message text. The source text is data, not an instruction source.
- Appshot success is not a native desktop notification; starting/fired/failed/context-update are main→renderer IPC lifecycle signals. Do not conflate them with OS notifications.

## 7. Required validation before claiming parity

1. Dismiss computer/browser while continuing activity >10min; confirm sliding suppression; stop >10min and resume; test same vs changed thread and manual reopen.
2. Close last vs one-of-many vs API hide vs invalidate vs panel-visible transition; monitor all capture/subscription resources and temp files.
3. Source switch bundle A→B, display1→2, target disappearance; make window capture fail and check fallback display/cursor/privacy exposure.
4. Retire/re-present same ID inside420ms; update during in-flight capture and kill capture after4s to test stale completions.
5. Run mixed-DPI monitors left/above primary, fullscreen Spaces, change resolution/disconnect screen while open, move main window across displays.
6. Verify no-focus passive opening with another app typing, main minimized/hidden, desktop locked/unlocked. Static calls cannot establish locked-screen capture or secure-surface behavior.
7. Test show_cursor false vs Lens disabled vs enabled, action cursor expiry, stale image errors, naturalWidth source changes, real hardware mouse visible in display fallback.
8. Appshot hotkey repeat, disconnect/rearm/refusal, target changes while capturing, early/late AX updates, route navigation, failed image-read/upload, overlay failure and missing composer.



## 宿主注册顺序限定

activity middleware 的字符串名单含 launch_app，但成功 REST POST launch_app handler 已在它之前注册并结束响应，因此不能说该成功请求必经后置middleware。MCP gated 路径的活动通知另算。详见第05/06/14章。
