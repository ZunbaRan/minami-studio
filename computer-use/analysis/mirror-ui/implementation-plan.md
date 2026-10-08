> 来源：用户提供的 .164 研究资料 `analysis/mirror-ui/implementation-plan.md`；原文件 SHA256 `9adac2490c08aa6fcf06dbbbac9443d655a576e98a6df7dced65cd29f34025b1`；全文件 1–160 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Implementable mirror/Appshot module plan and acceptance cases

This is an independent reconstruction plan, not Alma source. “Observed” reproduces traced behavior. “Recommended hardening” changes behavior intentionally and must be tracked as such. Native names/API behaviors are interoperability facts. Implement each pure module before adding platform UI.

## Module boundary and build order

1. `PresentationRegistry`: pure map/selection/dismissal logic, injectable clock and scheduler; no capture and no OS calls.
2. `MirrorWindowController`: one platform window, inactive show, content render, close classification, geometry persistence/following, sentinel routing.
3. `ComputerActivityTracker`: retained target, enable preference,1200ms cooldown timestamp,90s inactivity timer.
4. `ComputerFramePump`: per-item timer, target-window capture/fallback, cached JPEG and pointer, resource teardown.
5. `BrowserFrameLease`: CDP subscription state {pipLease, normalSubscribers, hdSubscribers, latest, latestFrame}; idempotent start/stop; no UI assumptions.
6. `FrameRouter`: lookup item→computer pump or browser manager; normalized result envelope; never perform target input from mirror pointer gestures.
7. `MirrorRenderer`: one active-frame polling loop, fit mapping, idle/error/completing rendering; reload/cancel cleanup.
8. `ActionCursorStore`: native lock-protected point/timestamp and8s normalization; independent from Lens visibility.
9. `NativeLensController`: default disabled, per-screen slots, visual effects, visibility watch and broadcast bridge.
10. `AppshotCoordinator`: monitor subscription/guard/frontmost/capture/animation/focus/notification.
11. `AppshotComposerAdapter`: pending token consumption, attach image, hidden context merge, cleanup and serialization.

Dependency rule: item presence controls capture demand; capture does not add or reopen presentations. Native input records activity/cursor but never directly clicks mirror. Appshot animation consumes a completed capture and must not become the capture source itself.

## Presentation data and events

State record minimum:

    Presentation:
        id: string, kind: browser|computer, label: string
        threadId?: string, workspace?: string, displayId?: number
        targetBundle?: string, targetPid?: number
        createdAt: timestamp, updatedAt: timestamp
    Registry:
        items: map<string, Presentation>
        activeId: string|null
        completing: set<string>
        dismissalAt: map<(id, threadIdOrEmpty), timestamp>
        fittedId: string|null
    Window:
        handle: optional
        programmaticClose: false
        closeListeners: set<callback>
        anchorWindow/lastAnchorBounds/moveListener: optional

Observed merge semantics must be reproduced carefully:
- Existing label becomes incoming label if truthy; empty label does not erase.
- Existing thread/workspace/display kept when incoming nullish.
- targetBundle/PID touched only when at least one incoming property is not undefined; then both are assigned, including undefined for the other.
- kind of existing record is not overwritten by update path.
- New item's supplied shape is used plus timestamps.
- Upsert clears completion flag, but no timer-generation guard exists in observed code.

Event matrix:

| Event | Guard | State changes | Side effect |
|---|---|---|---|
| auto present | absent ID and active tombstone | refresh tombstone | none; return |
| manual present | none | remove all tombstones for ID | normal upsert |
| insert | accepted present and absent ID | insert, active=id, fit=null | ensure window, reload HTML, inactive show |
| update | accepted present and present ID | merge, updatedAt; clear completion | reload HTML |
| chip select | ID exists | active=id, fit=null | reload HTML |
| user close selected | stack>1 | tombstone, completing+=id | reload; delayed delete420ms |
| user window close | window closed without programmatic flag | tombstone all; clear stack | detach anchor, notify close listeners |
| programmatic hide | window exists | programmatic flag; clear stack | close window; no tombstone |
| invalidate | ID exists | completing+=id | reload; delayed delete420ms |
| completion timer | scheduled | delete ID even if refreshed meanwhile | empty→hide; else reselect if needed, reload |
| fit | live window, positive dimensions, active ID, not fitted | fittedId=id | aspect resize, persist geometry |

## HTTP/IPC interfaces observed

These are the UI-owned contracts, not a recommendation to expose unauthenticated endpoints. Authentication and HTTP server boundary are outside this report's scope.

| Interface | Input | Normal output/behavior | Error behavior |
|---|---|---|---|
| GET /api/pip/frame | query item string | computer/browser frame envelope | success:false with error string |
| GET /api/pip/state | none | open, activeItemId, items, bounds | HTTP500 error |
| POST /api/pip/present | id, kind, label?, threadId?, workspace?, displayId? | manual upsert; ok:true, activeItemId, items |400 if missing ID or kind not browser/computer;500 catch |
| POST /api/pip/invalidate | id OR threadId | invalidate ID, otherwise all thread items; ok:true, items |400 if neither;500 catch |
| POST /api/pip/hide | none | programmatic hide; ok:true,open:false |500 catch |
| POST /api/pip/move | x:number,y:number | round coords; moved:boolean,bounds |400 on non-number;500 catch |
| POST /api/pip/computer-use-activity | bundle?:string,pid?:number | note activity; ok:true |500 catch |
| GET /api/iab/pip/frame | workspace? | browser frame, sole workspace fallback | success:false error |
| POST /api/iab/pip/:action | show/hide/toggle; body workspace? | open,workspace; hide clears browser lease |500 catch; unknown action causes no operation |
| IPC appshot:get-state | none | supported/platform/configuredHotkey/isActive/error | manager's state |
| IPC appshot:set-hotkey | hotkey or null | manager state | captured error fields |
| IPC appshot:capture-now | none | boolean capture result non-null | no-target/busy unsupported=false |
| IPC appshot:prewarm | none | ok or error | unsupported_platform or ping error |

Important omissions: /api/pip/present does not destructure targetBundle, targetPid or auto from body; it is manual presentation. /computer-use-activity's lightweight endpoint does not pass threadId or displayId; action middleware passes threadId/bundle/PID. This matters for suppression-key consistency.

Frame envelope:
- Common successful payload: success:true,image_base64:string, optional title, optional cursor{x,y}; browser also url.
- Computer absent item error: No such PIP item; not ready: Waiting for the first desktop frame.
- Success:false is a normal JSON response in traced frame handler. Renderer does not show error string; it shows waiting text based on kind.

Preload Appshot subscriptions each wrap IPC callback and return an unsubscribe that removes exactly that listener. Root renderer hook calls all four unsubscribers when unmounting.

## Computer pump pseudocode

    onFrameRequest(item):
        if no pump[item.id]: create pump with item.displayId captured now
        if pump.latest exists: return successful cached frame/cursor
        return notReady

    every333ms(pump):
        if pump.busy:
            if now - pump.startedAt >4000: pump.busy=false
            return
        if now - lastAgentActivity <1200: return
        pump.busy=true; pump.startedAt=now
        try:
            currentItem=registry.lookup(pump.id)
            if currentItem has bundle or numeric PID:
                try captureWindow(maxWidth=1024)
                catch use null
            if capture null: captureDisplay(capturedDisplayId,maxWidth=1024,quality=.5)
            fitActivePanel(capture.width,capture.height)
            pump.cursor=capture.cursor
            pump.latest=readTemporaryJPEGAsBase64()
            pump.failures=0
        catch:
            pump.failures++
            log if first or multiple of15
        finally: pump.busy=false

Recommended hardening, explicitly not observed parity:
- use capture generation IDs and cancellation to prevent stale response/file races
- release pump on per-item removal, not merely stack close; release browser lease on user close
- clear frame+cursor on source transition, and report stale frame age on repeated errors
- include changing displayId in pump identity or update its live parameters
- cancel retirement timer on successful reactivation using per-ID generation
- constrain HTTP payloads and reject NaN/Infinity; observed `typeof number` checks alone are weaker

## Deterministic acceptance tests

Use fake clock/timer, fake window and capture provider; no physical input needed for cases1–12.

1. Insert A/threadT automatically at0, user-close at1000; auto A/T at2000 returns no item and sets dismissal2000. Auto at601999 remains suppressed. Auto at1202000 (gap600001) presents.
2. Equal boundary600000 remains suppressed; only strictly greater expires.
3. A/T suppressed; auto A/T2 presents because key differs. Manual A clears both T and T2 tombstones.
4. Programmatic hide A; immediate auto A succeeds. User window close A+B creates both tombstones.
5. Stack A,B; close activeB marks completing then420ms later removes onlyB; active falls backA. Animation itself cannot perform target input.
6. InvalidateA at0; presentA at100; at420 observed timer still deletesA. Mark expected parity bug; hardened variant expected to retainA.
7. Target update bundleA,pid1→bundleB with PID omitted sets targetPid undefined and targetBundleB. Update with neither target field leaves both unchanged.
8. Pump first request at10000 creates timer but returns waiting. Mark activity at10000; ticks10333/10666/10999 are suppressed and11332 is eligible (elapsed1332≥1200). Zero is a separate never-active sentinel. Repeated action every1000ms can indefinitely defer desktop refresh.
9. Window capture errors→display fallback. Display errors leave last good JPEG/cursor cached, failure increments. First/15th/30th errors log.
10. Busy capture at0 remains pending at4330; watchdog clears busy, next tick can start replacement; stopping does not cancel first operation. Hardened variant prevents old results committing.
11. Browser subscriber +PiP: remove subscriber retains stream; clearPiP stops only with zero subscribers. HD subscription is independent. New subscriber gets latest cached frame immediately.
12. Source1920×1080 / panel380×250 /cursor(.5,.25): DOM location(190,53.4375). Native centered bottom-up location(190,178.4375). Do not flip DOM y.
13. ActionCursor atpoint timestamp0 remains valid at8s, absent after8s. Outside rect or rect zero dimension returns nil. Lens disabled still updates ActionCursor when showAt invoked.
14. Appshot capture guard: second key-down during in-flight capture does not start another capture. Native-down plays one sound; manual capture path no shutter call in traced manager.
15. Native event starting precedes target resolution; no-target must emit matching failed request ID. Fired returns local image metadata, no message auto-submit.
16. Appshot update before hidden context inserted is ignored. Update after insertion with empty AX fills it. Nonempty AX preserved. Remove image clears context.
17. Failed Appshot phase reset after4s must not erase a newer request's phase. Route target=new moves existing chat to root on starting.
18. Capture with image/frame attempts overlay, schedules fired715ms even if overlay subsequently fails. Test primary focus and current window reference at delayed delivery.
19. Native Lens explicit enable renders only where target visibility permits; broadcasts before desktop suppression should still feed optional native PiP.
20. Native capture inclusion tests must separately assert window-shot=false, display-shot=true, native-stream=true. A single global no-cursor assertion is invalid.

## Physical acceptance checks and permission behavior

No source analysis substitutes for these tests: cross-app frontmost preservation; actual mouse unaffected by target-specific input; minimized/hidden/locked displays; screen capture/AX permissions revoked mid-session; fullscreen Spaces; mixed Retina scale; native event-source identity; capture protected surfaces; detached display; overlay recursion.

The UI layer does not prompt for screenshot permission in mirror pump; native failure becomes logged capture error and waiting/stale view. Appshot monitor failure exposes ax_not_granted but cannot establish whether native permission prompt appears without helper contract. Screen permission denial in Appshot capture generates capture_failed. Keep these separate: monitor/accessibility and image/screen-recording permissions are not interchangeable.


## 本次修订 非零时钟与零哨兵

UI.cooldown 使用 last_agent_activity_ms=10000，ticks_ms=[10333,10666,10999,11332]；仅最后一次不再受1200ms门禁抑制。新增 UI.cooldown.zero_sentinel：lastActivity=0 时 age=Infinity，第一个tick就不受此门禁抑制。仍需另检查active pump/inFlight/source等前提。两例均NOT_RUN。
