> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/FINDINGS.md`；原文件 SHA256 `862a209ef9a83e49eade0b4eb30b4da6e03dc1918463eb36ee65e82290738066`；全文件 1–298 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Alma 0.4.164 native daemon / snapshot / capture supplement

Static-only analysis of the arm64 slice. Target was never launched. Every address below is an unslid arm64 VA in the exact 0.4.164 sample. A = branch/dataflow inspected; B = surviving symbols/data; C = consequence/inference. Raw disassembly is intentionally excluded from this distribution. Address ranges refer to the independently acquired same-hash official sample. Convenience string comments are not independently authoritative.

## 1. Native socket execution model (A)

`Daemon.run` 0x100073f6c:

1. Derive socket parent directory and create it with intermediate directories (errors from this preliminary directory creation are swallowed at 0x1000740ec).
2. Unlink socket path (0x100074110), create `socket(1,1,0)` / AF_UNIX SOCK_STREAM (0x100074120–12c).
3. Reject UTF-8 path length >=104 bytes (0x100074174–178); close new socket on rejection. sockaddr_un storage/bind length is106 (0x100074300).
4. bind; chmod socket to0600 (`0x180`, 0x1000743d8); listen backlog4 (0x1000743ec).
5. Start idle timer, asynchronously run accept loop, install signal handlers, run main RunLoop (0x1000744b8–4738).

`handleQueue` is expressly concurrent: construction calls `.concurrent` at0x100073b70; label `com.yetone.alma.cu.handle`. Accept loop dispatches each accepted descriptor asynchronously at0x100074dac. **Different peers can execute requests concurrently.** This is not proof of a global action lane. Individual clients process their lines synchronously.

Connection worker 0x10008ab80 onward:

    buffer = empty Data
    recv scratch size = 8192 bytes
    while true:
        n = recv(fd, scratch, 8192, flags=0)
        if n == 0: finish
        if n < 0:
            if errno == EINTR(4): retry
            else: log and finish
        append scratch[0:n] to buffer
        while buffer contains LF(10):
            line = bytes before first LF
            remove prefix including LF
            if line empty: continue
            response = processLine(line, context)  // synchronous
            context.send(response + LF)
    context.teardown(); close(fd)

Evidence: recv0x10008abdc; line search0x10008ac00/34; processLine0x10008acf0; send0x10008add0. No maximum accumulated line size, CR stripping, timeout cancellation check, or EOF-tail processing appears in this loop. A caller disconnecting during a synchronous dispatch does not cancel that dispatch here; disconnect is observed when receive resumes. This statement is scoped to the socket transport, not every asynchronous subsystem.

`processLine` 0x100075e98 updates lastActivity **before JSON decoding** (0x100075f38–74); constructs JSONDecoder and JSONEncoder; sets withoutEscapingSlashes (0x100075ffc–608c); decodes Request; synchronously dispatches at0x100076260; wraps success or CUError failure under original request ID. Other thrown errors become CUError.internalError(localizedDescription). Decode errors become invalidArg and use ID `?` (0x10007614c–154). The exact encoding-failure fallback JSON is now documented in WIRE_SCHEMA.md.

`ConnectionContext.send` queues writes. Its queued body0x1000867cc checks weak context, alive flag and daemon, locks writeLock, sends until all bytes sent, retries EINTR, and unlocks. This prevents partial JSON writes interleaving on one peer. `teardown`0x100075b20 sets alive=false, unsubscribes all AppshotEvents subscription tokens, empties subscription array. It does not roll back action state, clear AX refs, or clear screenshot mappings.

### Idle lifecycle

Native initializer default is **600 seconds**, IEEE754 immediate0x4082c00000000000 at0x100073bf4. However native CLI main itself defaults900 seconds (0x100001c34–3c,0x100001f48–50), and wrapper explicitly passes900 via `--idle-seconds`. Thus ordinary CLI/wrapper usage is900, while initializer API default is600. Preserve this three-level distinction.

Timer runs on main queue, starts now+30s and repeats30s (0x1000749f8/4a40). Callback0x100083214:

    if BareModifierMonitor.shared.currentHotkeyName != nil:
        lastActivity = Date.now
        return
    if Date.now - lastActivity <= idleTimeoutSec: return
    if isShuttingDown: return
    isShuttingDown = true
    AXBridge.restoreAllEnhancedUI()
    if listenFd >= 0: close(listenFd); listenFd = -1
    unlink(socketPath)
    exit(0)

Comparison is strict exceeded threshold at0x10008338c–390. Hotkey refresh0x1000832c4–3320; restoration/close/unlink/exit0x100083500–538. This is process exit, not graceful draining of every peer. Concurrent requests can also interleave snapshot-store operations: do not assume an entire AX snapshot is under one lock. Same-resource serial lanes in a safer reimplementation are an intentional deviation from this observed transport.

## 2. get_app_state vs direct snapshot

### Native parameters/defaults (A)

At get_app_state dispatch:

- bundle optional string; pid optional Int32; window_id optional UInt32
- depth default6 (0x100077cfc–7d10)
- interactive_only defaulttrue (0x100077d30–40)
- screenshot_max_width default1600 (0x100077d64–78)
- include_screenshot defaulttrue (0x100077d94–7da8, composed at0x100078858)
- auto_launch defaulttrue (0x100077dcc–7e30)
- wakeup_seconds default1.5 (0x100077e04–18)
- disable_diff defaultfalse (0x100078c50–84)
- screenshot_path optional string (0x100078d3c–74); default path constructed from timestamp milliseconds and `.jpg`

Native casts include checked conversions: negative/out-of-range window_id and pid outside Int32 can trap at conversion paths rather than becoming a tidy validation error. A replica should choose checked input validation as a declared safety deviation rather than copy crash behavior.

When auto-launch allowed, bundle is supplied, pid absent and no running application of bundle found, it calls launchWithFrontmostPreserved then waitUntilReady (0x1000787d8–800). Snapshot call0x10007883c receives requested/default depth, filter and wakeup budget.

When include_screenshot is true, enumerate AX windows and find snapshot's chosen window (`first(where:)`0x1000825a0). If its AX element exists, call unminimizeIfNeeded (0x100078920). If actually unminimized, attempt a new AX snapshot with same options except wakeupSeconds=0 (0x100078944–958). Replace snapshot only on success; failure is swallowed. Thus asking for state with a screenshot can restore a minimized window. It does not promise no visible UI state changes.

Then call snapToDictDiffed before capture (0x100078c84), attach menu_shortcuts when available, and only attempt capture if include_screenshot=true and snapshot.windowId exists (0x100078d24–30). Capture failure attaches screenshot_error to otherwise successful AX result (0x100078e90–8f04); it does not undo the diff baseline already updated.

### Direct `snapshot` (A)

The literal command is `snap` (not `snapshot`, comparison0x1000771e4). Its separate native dispatch branch calls AXBridge.snapshot at0x10007735c then **plain** snapToDict at0x100077380. Defaults depth6/filtertrue/wakeupSeconds0 at0x1000772c0–7330. It does not call AppStateDiff.apply. Therefore separately invoked native command `snap(depth:0)`:

- runs beginSnapshot and can prune invalid AX entries or alter currentSnapshotRefs
- traverses only root (and only emits root if filter permits)
- does **not** reset/update AppStateDiff baseline
- does not overwrite screenshot mapping merely by taking this direct AX snapshot

Do not conflate an explicit get_app_state(depth:0), which does use diff and can reset its baseline, with native direct snapshot(depth:0). **Cross-layer correction: wrapper post-action uses get_app_state(depth:0), not cmd=snap; therefore the wrapper post-action DOES update/reset the relevant AppStateDiff baseline.**

## 3. AX snapshot and tree walk (A unless marked)

Snapshot entry0x1000119a0 checks AXIsProcessTrustedWithOptions (0x100011b84), resolves app, enables enhanced UI, establishes deadline now+wakeupSeconds, calls ElementStore.beginSnapshot **once** (0x100011bf8), then walks.

Window choice helper0x100012774:

    assert windows not empty
    if requestedWindowId exists:
        if any window.id matches: return first matching window
    if any window.focused: return first focused window
    return windows[0]

Explicit missing window ID falls through to focused/first rather than failing in this helper. Focused flag verified by WindowInfo.focused getter0x1000109bc and member byte+0x41. If AX window enumeration fails or yields zero windows, snapshot uses WindowList.topWindow(pid) for metadata instead and retains empty AX output (0x100011da0–e08). AXWindowInfo enumeration ordering is a separate dependency, not specified by this helper.

Walk0x1000128e4 has a remaining-depth implementation after Swift optimization:

    walk(element, remainingDepth, interactiveOnly, pid, snapshotId, store, out, parentRoles):
        role = try? copyAttr(element, 'AXRole') as String ?? ''
        actions = copyActionNames(element)
        interactive = !actions.empty || interactiveRoles.contains(role)
        children = try? copyAttr(element, 'AXChildren') as [AXUIElement] ?? []
        if !interactiveOnly || interactive:
            read other serialized fields
            descriptor = ElementDescriptor(..., parentRoles suffix limit)
            ref = store.register(element, snapshotId, pid, descriptor)
            out.append(serialized element)
        if remainingDepth - 1 < 0: return
        for child in children, original AX order:
            walk(child, remainingDepth-1, ..., parentRoles+[role])

It is preorder DFS, filtered parents do not prevent child traversal, and filter is **not** `enabled && interactive`. AX action presence alone suffices (0x1000129bc–cc); role set is fallback0x1000129d0–9f4. Children are read even at remainingDepth0. There is no 200-node global cap in this walk; the200 cap belongs to descriptor recovery, not snapshots. Depth0 may emit root; negative depth also reaches current-node processing before skipping children.

Interactive roles static set16, initialized0x100013b60 from array0x1000aeec8:
AXButton, AXCheckBox, AXRadioButton, AXPopUpButton, AXMenuButton, AXMenuItem, AXTab, AXLink, AXTextField, AXTextArea, AXComboBox, AXSlider, AXIncrementor, AXDisclosureTriangle, AXCell, AXRow.

The AXDisclosureTriangle string requires decoding Mach-O chained/fixup pointer, not treating on-disk pointer bits as a raw VA; literal verified0x100091fa0. Other strings fit Swift small-string representation. Role, actions, children path0x100012924–2b18; registration0x10001357c; output before recursion0x100013714–7d4.

### Wakeup retries

If first walk emits >1 element, ax_status='populated', wakeup_attempts=1, wakeup_duration_ms=0 (0x100011e10–1c, 0x100012144–16c). Otherwise if deadline remains, retry up to three times using sleep schedule [0.15,0.25,0.4] seconds (raw doubles at0x10008f088); each sleep is min(schedule[i], max(0, deadline.timeIntervalSinceNow)). On each retry re-enable enhanced UI, clear output array, enumerate/choose window and walk again. **No second beginSnapshot call occurs inside retry loop.** Thus the same snapshot generation's currentSnapshotRefs influences repeated walks.

Success after retry uses ax_status='woke_up'. Failure/low output returns 'no_wakeup_budget' if supplied wakeupSeconds<=0, else 'empty_after_wakeup'. `wakeup_attempts` counts initial attempt plus performed retries; maximum4. `wakeup_duration_ms` is the sum of measured sleep durations using monotonic uptime nanoseconds, integer-divided by1,000,000 (0x100011ea8–1efc and0x100012230–250); it is not total wall-clock duration of AX traversal.

## 4. Snapshot schemas / diff coupling

SnapshotResult native layout (constructor0x100011958): snapshotId String+0x00; app object+0x10; optional UInt32 windowId+0x18/tag+0x1c; optional title+0x20; optional CGRect bounds+0x30/tag+0x50; elements array+0x58; wakeupAttempts+0x60; wakeupDurationMs+0x68; axStatus String+0x70.

snapToDict0x100087418 produces snapshot_id, ax_status, wakeup_attempts, wakeup_duration_ms, app{bundle,name,pid}, window{id,title,bounds}, elements. Bounds dictionary uses x,y,w,h. SerializedElement optional fields are now proven omitted when absent (see section 9 / WIRE_SCHEMA). SnapshotResult container-level optional semantics must be checked individually against AnyCodable/Response serialization; this is not a blanket STOP for already-closed element fields. General JSON field byte ordering remains unpromised.

snapToDictDiffed0x100088504 maps full SerializedElements to dictionaries, calls AppStateDiff.apply with PID/window key, replaces emitted elements with diff elements, adds elements_are_diff and unchanged_element_count and nonempty removed_refs. Consult ../native/FINDINGS.md for fully proven10-field fingerprints and rounded bounds. disabled=true still updates baseline. The diff function does not determine OCR threshold.

## 5. Screenshot paths, geometry and cache

### Actual get_app_state capture path (A)

Closure0x100082650 tail-calls Capture.captureWindow0x10003f738 at0x1000826c4. This is the ScreenCaptureKit path. **It does not first call captureWindowFast.** Only direct caller of captureWindowFast found in this disassembly is0x1000712e0 in another subsystem.

Capture.captureWindow resolves an SCWindow through ShareableContentCache (fully traced policy in section8). If none, throws internalError. With SCWindow:

- SCContentFilter(desktopIndependentWindow:window) at0x10003f890
- SCStreamConfiguration init0x10003f8a8
- scale=NSScreen.main?.backingScaleFactor ?? 2.0 (0x10003f8c0–9c4), not selected window's screen scale
- pointWidth=max(frame.width,1); pointHeight=max(frame.height,1)
- width=Int(pointWidth*scale); height=Int(pointHeight*scale), truncation toward zero
- if maxWidth exists and maxWidth>=1 and maxWidth<width: height=max(1,Int(height*maxWidth/width)); width=maxWidth
- showsCursor=false; capturesAudio=false (0x10003fafc–fb0c)
- macOS>=14: ignoreShadowsSingleWindow=true (0x10003fb10–30)
- minimumFrameInterval=CMTime(value:1,timescale:60) (0x10003fb34–5c)
- macOS>=14 branch calls SCScreenshotManager.captureImage(filter,configuration,completionHandler)0x10003fbf0; older branch throws internalError, not a demonstrated fast-path fallback
- writeJPEG(image,path,quality0.85)0x10003fd64–78; return actual CGImage width/height (0x10003fdec/fdf8)

Capture.captureWindowFast0x10003f448 is a separate optional-result API: CGWindowListCreateImage options8 and image flags9; reject nil or width/height<=1; optional downscale only when positive maxWidth is smaller than source; high interpolation3; JPEG0.85; nil on write error. Do not apply it as get_app_state fallback without labeling deviation.

### Coordinate mapping / lifetime (A + scoped negative evidence)

Only successful screenshot with snapshot.windowBounds present writes lastMapping[pid]. It stores snapshot AX window origin and point size, actual captured image pixel width and height, selected windowId; write0x1000790b0 guarded at0x100079014–1c. Pixel dimensions can derive from SCWindow frame while mapping point bounds derive from AX snapshot: preserve this distinction and test disagreements.

    desktopX = originX + screenshotX * pointWidth / pixelWidth
    desktopY = originY + screenshotY * pointHeight / pixelHeight

Translator0x100082890 uses PID only, locks mappingLock, no bounds clamp or expiry. Failed capture, absent screenshot, missing bounds and direct snapshot do not replace mapping here. Symbol-offset cross-reference inspection found init, reads, this writer and deinit, **no TTL/window-close/app-exit invalidation** for this mapping in the inspected binary. It persists for daemon lifetime unless same PID mapping is overwritten. PID reuse and window changes are stale-mapping hazards.

settlePrelude0x10008277c uses lastMapping[pid].windowId when present; otherwise WindowList.topWindow(pid). It calculates cheapWindowPixelHash for that window. Thus stale mapping affects not only coordinate conversion but action-settling window choice.

## 6. OCR trigger / references (A)

OCR is attempted only after successful get_app_state screenshot AND raw snapshot.elements.count<=1:

- SnapshotResult copied to local base x19+0x14a0 at0x100078c10–38
- elements member+0x58 => x19+0x14f8
- load count0x1000790c4–c8; unsigned >1 skips at0x1000790d0
- VisualIndex.index(path,maxResults:80)0x1000790d4–e0

It is **not** triggered by a nearly empty diff result, and is not run when include_screenshot=false or capture failed.

VisualIndex.index0x1000337c4:

1. Load disk URL, CGDataProvider, CGImageSource image index0. Read actual image W,H.
2. VNRecognizeTextRequest recognitionLevel1 (fast), usesLanguageCorrection=false, recognitionLanguages=['en-US','zh-Hans'].
3. VNImageRequestHandler(CGImage, empty options), perform request.
4. Traverse returned observations in Vision order, topCandidates(1). Skip observations without candidates and skip empty text (length test0x100033d48–58); there is no inspected confidence threshold/sort.
5. For accepted nonempty candidate, increment local accepted counter starting0, construct ref='v'+decimal(counter), retain full text, confidence.
6. Vision normalized lower-left bbox(x,y,w,h) becomes screenshot-pixel top-left bbox:
   x'=x*W; y'=(1-y-h)*H; w'=w*W; h'=h*H (0x100033e14–3c).
7. Stop when accepted count reaches maxResults (0x100033e68–6c).
8. Image/load/Vision error path returns empty regions rather than a public OCR error.

If regions nonempty, dispatch replaces visualRefs[pid] with ref→CGRect under visualLock (0x10007910c–200), and emits visual_regions array of {ref,text,bounds:{x,y,w,h},confidence} (mapper0x100080568). These bounds are screenshot pixel coordinates, not desktop coordinates. Ref numbers restart per indexing call; dictionary is PID-keyed. Empty OCR, skipped OCR and failed capture do not clear the old visualRefs dictionary in this path. Cross-reference inspection found init, click reads, this nonempty replacement and deinit; no independent expiry found. Visual refs therefore may remain usable but stale after no-OCR calls.

## 7. Remaining verification boundaries

The second pass closed native Request/Response/AnyCodable encoding in WIRE_SCHEMA.md, cache policy in section8, serialized keys in section9, window order in section10, and emitted-value construction in section11. Those are no longer unresolved static gaps.

Remaining gates: Swift/Foundation extreme numerical and localization behavior; actual AX app fidelity and malformed attributes; asynchronous ScreenCaptureKit cancellation/error ordering; multi-peer shared-state interleaving; TCC/signature identity; private OS behavior; mixed-DPI/moved/minimized windows, PID reuse and stale mapping/visual refs. These require controlled runtime evidence, not guessed compatibility.

## 8. Second-pass closure: ShareableContentCache (A)

This closes the SCWindow resolution/cache-policy part of STOP2 above. Cancellation/runtime timing remains unproven.

The dependency is `ShareableContentCache`, a Swift actor (defaultActor_initialize at0x10003db50; unownedExecutor witness). Defaults: displayTTL30s0x10003dc94; windowTTL2s0x10003dc9c. Initial content=nil, fetchedAt=distantPast, inFlight=nil, lastSuccess=distantPast (0x10003db54–8c).

    actor fresh(maxAge):
        if content != nil and Date.now - fetchedAt < maxAge:
            return content
        if inFlight != nil:
            return try await inFlight.value
        task = Task { await SCShareableContent.getShareableContentWithCompletionHandler }
        inFlight = task
        try:
            result = await task.value
            content = result
            fetchedAt = Date.now
            lastSuccess = fetchedAt
            inFlight = nil
            return result
        catch:
            invalidate()  // content=nil; fetchedAt=distantPast
            inFlight = nil
            throw CUError.scDenied()

TTL strict comparison0x10003df74–78; in-flight branch0x10003dfdc–e058; task creation/install0x10003e05c–e0c4; completion writes0x10003e27c–360; error invalidate/normalization0x10003e430–494. The creator failure is normalized to scDenied; existing in-flight joiner's unwind path is separately0x10003e3a8 and may surface task's original error, so do not collapse every concurrent error identity without testing. Request callback0x10003e588 is unfiltered `getShareableContentWithCompletionHandler:`.

    window(id):
        content = await fresh(maxAge:2)
        if first content.windows item with windowID==id: return it
        invalidate()
        content = await fresh(maxAge:2)
        return first content.windows item with windowID==id, else nil

Evidence first fresh0x10003ec64; first search0x10003edc0; invalidation virtualcall0x10003ee68 (vtable slot+0xe8 points0x10003dd80, validated on-disk fixup target); retry0x10003ee8c; second search0x10003efe0; nil0x10003f054. Invalidation resets only content and fetchedAt, **does not itself cancel/clear inFlight or reset lastSuccess** (0x10003ddd0–de18).

## 9. Second-pass closure: SerializedElement JSON keys (A)

`SerializedElement.toDict`0x100011338 always emits six keys:

    ref: String
    role: String
    enabled: Bool
    focused: Bool
    actions: [String]
    children_count: Int

Initial literal construction0x10001139c–1498, count6 at0x1000114f8. Optional fields are inserted only when present, otherwise **omitted**, not emitted as null:

- subrole String, member+0x20, presence0x100011518
- role_description String, +0x30, presence0x100011568
- title String, +0x40, presence0x1000115bc
- value String, +0x50, presence0x100011608
- description String, +0x60, presence0x100011654
- selected Bool, +0xa2, optional tag2 means absent0x1000116ac
- bounds {x:Double,y:Double,w:Double,h:Double}, +0x70, absent tag+0x90 checked0x1000116f8

There is no emitted `identifier`, parent ref, nested children, traversal depth or parentRoles key in this method. Identifier belongs to ElementDescriptor recovery metadata, not serialized output. `children_count` is raw AX children count, not count after interactive filtering. The static element serialization is flat, preorder traversal list. Bounds insertion0x100011744–1810. An internal no-value path removes bounds0x10001184c; ordinary absent CGRect branches directly to return.

## 10. AX window enumeration order (A)

AXBridge.windows(of:)0x1000109e4 copies `AXWindows` from application; cast failure/nil yields empty list, while copyAttr errors propagate to caller. It reads AXFocusedWindow separately and marks focused by CFEqual (0x100010d24). It iterates the original AXWindows order and appends WindowInfo without sorting (loop0x100010b6c–0x100010e88). Reads title (default empty string), AXPosition and AXSize (each missing point/size defaults0,0), AXMinimized (defaultfalse), and `_AXUIElementGetWindow` for CGWindowID. Window ID output is initialized0 and API return code ignored at0x100010ddc–dec, so0 may survive. Missing geometry does not itself filter window. `first focused else first` therefore means original AX order, not z-order sorting invented by the replica. CG WindowList fallback has a different source/order and should not be silently substituted when AX windows exist.

## 11. AX emitted-field construction (A)

Additional closure of STOP3 from inspected walk0x1000128e4:

    role = (try? AXRole as String) ?? ''
    subrole = try? AXSubrole as String
    role_description = try? AXRoleDescription as String
    title = first NONEMPTY String among:
        AXTitle
        (AXTitleUIElement as AXUIElement).AXValue
        AXLabelValue
    value = try? AXValue as String
    if no String value: value = (try? AXValue as NSNumber)?.stringValue
    description = (try? AXDescription as String) ?? (try? AXHelp as String)
    enabled = (try? AXEnabled as Bool) ?? true
    focused = (try? AXFocused as Bool) ?? false
    selected = try? AXSelected as Bool
    identifier = try? AXIdentifier as String // descriptor only, not emitted
    bounds = if both AXPosition and AXSize decode successfully:
                 CGRect(position,size)
             else nil

Title chain0x100012c10–e34, successful original title nonempty test0x100012d14; titleUIElement string/nonempty tests0x10001386c–894; labelValue nonempty test0x100012f34. The AXTitleUIElement→AXUIElement cast at0x100012d68 uses unconditional-cast flags7: malformed AX value can trap; a hardened implementation should deliberately return absent instead. Value conversion0x100012e5c/2ed4 and0x100012e8c/2f7c–f9c; unlike title, an empty String value is accepted. Description0x1000130a4–b8 accepts empty String and therefore does not fall back to AXHelp when it is merely empty. Defaults true/false/absent at0x100013158/1b8/214. Bounds0x10001339c–418.

Descriptor parentRoles captures **last8** ancestor roles (0x100013424 subtract8, overflow branch0x100013904 constructs suffix), distinct from refetch matching up to last3. Descriptor title has its own nonempty/optional handling0x100013444 onward; do not assume descriptor title population and JSON title are identical solely from shared source fields. Full JSON retains no identifier or ancestor list.
