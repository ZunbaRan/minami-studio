> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/APPSHOT_EXTRA_CONTRACTS.md`；原文件 SHA256 `cc0c7d38e852617eedb9fc367e79758f508a996fdd97afa0210df842c384b5b7`；全文件 1–291 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native Appshot commands and shutdown: static contract supplement

Binary: Alma 0.4.164 bundled AlmaComputerUse ARM64 slice. Static disassembly only; the target was never executed. All addresses below are virtual addresses in `analysis/native/arm64.macho`; instruction evidence is in `analysis/native/arm64-disasm.txt` and `analysis/native-snapshot/dispatch.asm`. Swift small-string words were decoded from live MOV/MOVK values rather than inferred from nearby ADRP comments. This document describes native commands; Electron may impose additional defaults or transformations.

## 1. Shared parsing conventions

The request's optional parameter dictionary is accessed through native helpers:

- String helper `0x100006140`: conditional cast to String only. Missing/null/wrong type returns nil; a present empty string remains empty.
- Integer helper `0x100006268`: Int, then Double-to-Int truncation toward zero, then decimal String parsing. Floating nonfinite/out-of-Int-range conversion traps. This means `pid`, `window_id`, and `max_width` are integer-like rather than strict JSON-integer fields.
- No required-string helper is called by the appshot commands below. There is no dispatch-level rejection of unknown parameter keys.

The ordinary daemon response envelope belongs to the shared protocol contract. Shapes below describe the command result, not an additional nested envelope.

## 2. `appshot_monitor_start`

Entry `0x10007ea8c`; main continuation `0x10007ef8c`.

### Parameters and validation

| Key | Native parse | Default | Validation |
|---|---|---|---|
| `hotkey` | optional String | nil | If present and nonempty, must exactly match `DoubleCommand`, `DoubleOption`, or `DoubleShift` |

Missing, wrong-type, null, and empty hotkey are all mapped to optional-enum nil. There is no native default to DoubleCommand. Nonempty unknown/case-mismatched text throws `CUError.invalidArg` with the exact interpolated message:

`Unknown hotkey: <value>. Valid: DoubleCommand, DoubleOption, DoubleShift`

Evidence: parse `0x10007ea8c–0x10007ead8`, error assembly `0x10007eadc–0x10007eb70`, optional conversion `0x100082bd8–0x100082c24`, exact enum string switch `0x10006f2ac–0x10006f304`.

### Subscription and shared monitor state

1. If a ConnectionContext exists, add a subscription to `appshot.monitor` unless that connection's token list already contains that exact topic
2. Likewise subscribe once to `appshot.update`
3. Tokens are stored as `(topic:String, token:UInt64)` in the connection
4. Callback weakly captures the connection and forwards serialized event lines through ConnectionContext.send(line:)
5. Regardless of whether a connection context exists, call global singleton `BareModifierMonitor.start(hotkey:)`

Subscriptions happen before starting the monitor and are not rolled back when its start result reports failure. Repeated start does not duplicate either topic subscription, but does reconfigure the global monitor, including when the caller changes the hotkey. Thus clients do not get independent per-connection hotkeys.

Evidence: monitor dedup `0x100082c28`, update dedup `0x100082cbc`; subscription/store `0x10007ef8c–0x10007f13c`; weak forwarding `0x100089a6c–0x100089ac0` (update thunk at `0x10008b06c` routes through the same implementation).

### Result

```json
{"started":true,"hotkey":"DoubleCommand","supported":true,"error":null}
```

Fields are `started:Bool`, `hotkey:String?`, `supported:Bool`, `error:String?`. `hotkey` echoes the parsed requested enum, not a later read of actual tap state. Nil hotkey is represented as optional nil in the result dictionary.

- `supported` is a fresh `AXIsProcessTrusted()!=0` call (`0x10006db04`)
- `start` first checks `AXIsProcessTrusted`; failure returns `(false,"Accessibility permission not granted")`
- It ensures a monitor run-loop thread, with a semaphore wait bounded at 1 second; absent run-loop returns `(false,"Failed to start Appshots monitor thread")`
- If a run-loop exists it schedules `applyHotkeyOnMonitorThread`, wakes the loop and immediately returns `(true,nil)`
- Therefore `started:true` confirms scheduling, not successful CGEventTap creation
- With nil hotkey, the scheduled operation tears down the old tap, sets current hotkey to nil, and returns without installing a new tap or broadcasting ready

Evidence: result assembly `0x10007f174–0x10007f490` and `0x10007f700–0x10007f728`; start `0x10006db78–0x10006dcf0`; run-loop wait `0x10006dea4–0x10006dee0`; apply nil branch `0x10006df78–0x10006dfb8`.

### Monitor event payloads

All of these use topic `appshot.monitor`:

```json
{"type":"ready","hotkey":"DoubleCommand"}
{"type":"error","message":"CGEvent.tapCreate returned nil — Accessibility not granted to Alma Computer Use, or a higher-priority tap claimed the slot"}
{"type":"down","hotkey":"DoubleCommand","frontmost":{}}
```

- Ready is broadcast after the tap is installed/enabled and current hotkey updated
- Tap failure is asynchronous: it can follow a successful `started:true` command response; the same diagnostic is also written to stderr with `[appshot-monitor] ` prefix
- Down includes `frontmost` only when `Appshot.frontmostWindow(excludeBundleId:"com.yetone.alma")` finds a candidate; absent candidate means the key is omitted, not an empty object
- The down event does not itself invoke `Appshot.capture`; it supplies context for the client to decide what to capture
- The native exclusion for hotkey-triggered lookup is hard-coded to `com.yetone.alma`

Evidence: tap creation/apply `0x10006dfbc–0x10006e47c`; down construction and frontmost attachment `0x10006f758–0x10006fa38`.

### Low-level hotkey detection

Instruction-proven constraints, useful for compatibility tests:

- CGEventTapCreate is invoked with location 1, placement 0, options 1, event mask `0x1000` (`flagsChanged` event type 12)
- Handler ignores event types other than 12
- DoubleCommand checks device-dependent flag pair `(0x8,0x10)`; DoubleOption `(0x20,0x40)`; DoubleShift `(0x2,0x4)`
- It tracks the prior left/right bits; any bit from `0x7e` outside the selected pair clears the pending tap timestamp
- Both selected bits held can fire; a rising selected-side transition can also fire if the prior pending timestamp is at most 0.35 seconds old
- A last-fire timestamp enforces a 0.5-second cooldown; release during cooldown clears pending tap state
- An old pending timestamp is cleared once it exceeds 0.35 seconds

These points come from `0x10006e874–0x10006edc4`; exact host keyboard hardware behavior remains a runtime validation item. The named Double variants should not be simplified to generic keyDown events.

## 3. `appshot_monitor_stop`

Entry `0x10007ee2c`. No parsed parameters. Result:

```json
{"stopped":true}
```

Important asymmetry:

1. With a ConnectionContext, filter its token list for the exact topic `appshot.monitor`
2. Unsubscribe those tokens and remove those same entries from the connection
3. Leave `appshot.update` tokens installed
4. Query the global subscriber count for `appshot.monitor`
5. Stop the global BareModifierMonitor only when that count is zero
6. Return `stopped:true` regardless of whether another connection keeps the monitor active

Without context it cannot remove anyone's subscription, but still performs the count/conditional stop. The stop method schedules teardown onto the run loop if one exists; the response is not a barrier proving teardown completed.

Evidence: dispatch `0x10007ee2c–0x10007ef80`; exact-topic filter `0x10008989c–0x100089a60`; same-topic remove predicate `0x1000845f4–0x100084864`; native stop `0x10006e4a4–0x10006e59c`.

A faithful client must not assume monitor_stop removes update delivery. Repeated stop is harmless at this layer. Connection-disconnect cleanup is a separate daemon path.

## 4. `appshot_capture`

Entry `0x10007f4d8`; async closure/run bridge `0x10007f8f0–0x10007f984`; native capture `0x100070d9c` and continuations.

### Parameters

| Key | Parse and native type | Default / behavior |
|---|---|---|
| `bundle` | optional String | nil; passed to AXBridge.resolveApp |
| `pid` | integer-like → optional Int32 | nil; values outside `[-2147483648,2147483647]` trap rather than structured validation error |
| `window_id` | integer-like → optional UInt32 | nil; negative or >4294967295 values trap rather than structured validation error |
| `out_dir` | optional String | `NSTemporaryDirectory().appending("alma-appshots")` |
| `max_width` | optional integer-like Int | nil; forwarded to capture helper without dispatch clamp |

`max_width` is confirmed from live x20 small-string first word `max_widt` plus final `h`, not an ADRP comment. The dispatch does not parse `output_path`, `format`, `include_ax`, `depth`, `quality`, or `interactive_only` for this command. Empty string out_dir is retained; only nil triggers the default.

Evidence: bundle/pid `0x10007f4d8–0x10007f51c`; Int32 check and window_id `0x10007f7d0–0x10007f85c`; out_dir/default `0x10007f85c–0x10007f8ec`; max_width `0x10007f8fc–0x10007f918`.

### Result schema

```json
{
  "imagePath":"/…/appshot-<epochMilliseconds>-<windowId>.jpg",
  "width":1280,
  "height":800,
  "scaleFactor":2.0,
  "axText":"",
  "app":{
    "bundleIdentifier":"com.example.app",
    "name":"Example",
    "pid":123,
    "windowId":456,
    "windowTitle":"Example window",
    "windowFrame":{"x":0,"y":25,"width":1280,"height":800},
    "iconDataURL":"data:image/png;base64,…",
    "scaleFactor":2.0
  }
}
```

The dimensions above are illustrative, not defaults. Exact top-level fields and types:

- `imagePath:String`: path returned by Capture.Result
- `width:Int`, `height:Int`: actual capture-result dimensions
- `scaleFactor:Double`: main-screen backingScaleFactor, fallback 2.0
- `axText:String`: initially **always empty**, including when Accessibility is available
- `app`: FrontmostWindow dictionary described below

The command returns no native extra `ok`, `found`, image base64, or image bytes in this result dictionary. `CaptureResult.toDict` is `0x100070bac–0x100070d54`; dictionary contains exactly six entries.

### Capture sequence and errors

1. Resolve an application using `AXBridge.resolveApp(bundle:pid:)`; normal resolver errors propagate
2. If explicit window_id is absent, choose `WindowList.topWindow(for:resolvedApp.pid)`
3. If that is absent, throw CUError.internalError with `Target app has no on-screen window to appshot`
4. Create out_dir with intermediate directories enabled; directory-creation error is caught/discarded, so a later image-write error can become the externally visible failure
5. Capture a timestamp `Date.timeIntervalSince1970`, multiply by 1000, truncate to Int, and form `appshot-<milliseconds>-<windowId>.jpg` with NSString.appendingPathComponent
6. Try synchronous `Capture.captureWindowFast(windowId:outputPath:maxWidth:)`
7. If fast capture returns nil, await `Capture.captureWindow(...)`; its thrown errors propagate
8. Look up matching WindowList entry for title/frame metadata when available, and encode the resolved application's icon
9. If `AXBridge.isTrusted(prompt:false)` is true, launch background AX work; do not wait for its text before constructing the response
10. Return capture result with empty axText

Explicit window_id is passed directly into the capture path after resolving the app; the shown dispatch/capture preamble does not validate that this window belongs to the resolved pid. Metadata lookup can therefore fail to find a matching window for a successful capture. Do not assert a guaranteed pid/window consistency check.

Both top-level and app.scaleFactor are read from NSScreen.main.backingScaleFactor, each with fallback 2.0; these are not calculated as outputWidth/windowFrame.width and are not necessarily the target display's scale. Name fallback is `Unknown` when localizedName is unavailable. Evidence: capture selection/error `0x100070ee4–0x100071068`; mkdir/path `0x10007107c–0x10007112c` and `0x10007113c–0x1000712c8`; fast/fallback `0x1000712cc–0x1000713e4`; trust/background `0x100071474–0x100071684`; response construction/scales `0x10007168c–0x10007180c`.

### Background AX update

When trusted, a background operation creates a separate worker queue named `alma-appshot-ax-worker-<timestamp>` and waits on its semaphore for up to 3 seconds. The worker invokes:

`AXBridge.snapshot(bundle:nil, pid:<resolved pid>, windowId:<captured window>, depth:12, interactiveOnly:false, store:<daemon shared ElementStore>, wakeupSeconds:0.2)`

Snapshot exceptions are swallowed and yield empty AX text. The worker converts snapshot data to text, writes it into a shared string box and signals the semaphore. On timeout the waiting operation writes `[appshot] AX snapshot timed out (pid=<pid>)\n` to stderr, then still sends one update with the box's current text. The worker is not cancelled by timeout; there is no second broadcast in the inspected snapshot-worker closure if it finishes later.

Event:

```json
{"evt":true,"topic":"appshot.update","payload":{"type":"axText","imagePath":"/…/appshot-….jpg","axText":"…"}}
```

`imagePath` is the association key; no command request id is included in this event. No trust means no background worker/update from this path. A capture does not subscribe the caller by itself: monitor_start or some other existing subscription must already have subscribed it to appshot.update to receive this event. All subscribers to that topic receive the update. Scheduling gives no guaranteed ordering between the ordinary response and a sufficiently fast update event.

Evidence: background closure `0x100071f60–0x100072754`, 3-second wait `0x100072488–0x1000724e8`, payload `0x1000725cc–0x100072708`, snapshot call `0x1000731f4–0x100073228`, catch `0x10007322c–0x100073244`, store/signal `0x1000737bc–0x1000737d8`.

### AX text rendering details

The background worker's text renderer is distinct from the main snapshot JSON serializer:

1. If snapshot.windowTitle is present and nonempty, begin with `# <windowTitle>` and one empty line
2. For each serialized element, create parts beginning with its nonempty `role`, then its nonempty `title`
3. If its `value` is present, nonempty, and different from `title`, append value and skip description
4. Otherwise append nonempty `description` when available
5. If parts is nonempty, append `- ` plus parts joined by the literal separator ` · ` (space, middle dot, space)
6. Join all lines by LF, without an explicitly appended terminal LF

No ref IDs, coordinates, roleDescription, action list, or tree indentation are emitted by this renderer. A nonempty value suppresses description only when it differs from title. Evidence: title/header `0x10007324c–0x100073318`; role/title/value/description collection `0x100073340–0x10007356c`; element separator and prefix `0x1000735b4–0x1000735e0`; final LF join `0x100073788–0x1000737a0`. SerializedElement getter offsets cross-check the loaded fields: role +0x10, title +0x40, value +0x50, description +0x60.

## 5. FrontmostWindow dictionary and `appshot_frontmost`

The shared `FrontmostWindow.toDict` (`0x10006fc1c–0x100070048`) produces eight entries:

| Field | Type |
|---|---|
| `bundleIdentifier` | String? |
| `name` | String |
| `pid` | Int from signed Int32 |
| `windowId` | Int from UInt32? |
| `windowTitle` | String? |
| `windowFrame` | optional object `{x,y,width,height}`, all CGFloat numeric values |
| `iconDataURL` | String? |
| `scaleFactor` | Double |

Optional values are nil in the Swift `[String:Any?]` dictionary; normal response encoding determines JSON-null representation. They must not be invented when unavailable. The appshot monitor's absent `frontmost` outer key is omitted, independently of these inner optional values.

Additional directly inspected dispatch:

- `appshot_frontmost` entry `0x10007f31c`
- Parameter `exclude_bundle_id`: optional String, default nil
- Calls Appshot.frontmostWindow(excludeBundleId:)
- No candidate: `{found:false}`
- Candidate: `{found:true, ...FrontmostWindow.toDict()}` (fields merged at result top level, not under an `app` or `frontmost` wrapper)

Evidence: parse and no-candidate branch `0x10007f328–0x10007f408`; merge `0x10007f520–0x10007f6fc`. Its helper scans CGWindowListCopyWindowInfo and applies native filtering; exact native frontmost-selection filters are outside this supplement's exhaustive claims.

## 6. Appshot event wire format

`AppshotEvents.broadcast(topic:payload:)`, `0x10006bd54–0x10006c134`, serializes:

```json
{"evt":true,"topic":"appshot.monitor","payload":{"type":"ready","hotkey":"DoubleCommand"}}
```

- Exactly outer keys `evt`, `topic`, `payload`; event has no request id/result envelope
- JSONSerialization options integer 8; one LF byte is appended
- JSON serialization failure is caught and discarded, with no emitted event
- It snapshots callbacks for the topic while locked, unlocks, and invokes them
- Connection callback uses a weak reference and simply sends the serialized line if the connection is still alive

Consumers should identify events by evt/topic and route them independently of id-matched ordinary command responses.

## 7. `shutdown`

Entry `0x10007e55c`; no parameters read. Enqueues shutdown onto DispatchQueue.main, then constructs result:

```json
{"shutting_down":true}
```

The scheduled closure at `0x100089ad8`:

1. Checks daemon's shutdown flag at object offset 0x2c; returns if already set
2. Sets that flag
3. Writes `[alma-cu] shutting down\n` to stderr
4. Calls `AXBridge.restoreAllEnhancedUI()`
5. Closes daemon listen/socket fd and stores -1
6. Unlinks daemon socket path
7. Calls exit(0)

The ordinary response is constructed immediately after scheduling, so a strict flush-before-exit guarantee is not established by this static branch. No graceful waiting for outstanding captures/AX workers is visible here. Evidence: scheduling/result `0x10007e55c–0x10007e698`; closure `0x100089ad8–0x100089c08`.

## 8. Focused compatibility tests (not executed)

1. Start with absent/null/empty/incorrect-type hotkey: subscriptions installed, nil requested hotkey; existing global tap is torn down after scheduling
2. Start with lower-case `doublecommand`: exact invalidArg, no subscriptions added because validation precedes setup
3. Start with trusted AX but tap installation failing: first started=true then asynchronous monitor error
4. Two clients start different hotkeys: latest scheduled configuration applies globally; each receives shared monitor events
5. Stop one of two monitor clients: stopped=true while global monitor remains active
6. Stop only monitor client: monitor token removed, update token remains; later capture updates can still arrive
7. Capture with missing app selectors, explicit pid, bundle and conflicting pid: use resolver's native precedence/error rules
8. Capture pid/window_id boundary and noninteger numeric cases: reproduce Int conversion and narrowing-trap behavior or explicitly document safer divergence
9. Capture with missing out_dir vs empty out_dir; verify generated jpg basename and later failure behavior when mkdir fails
10. Capture without AX permission: nonempty image result plus axText="", no AX update
11. Capture with AX success/failure/timeout: response axText="" in each case; one update when trusted; association through imagePath
12. Capture on non-main display or downscaled image: metadata scaleFactor remains main-screen backing scale
13. appshot_frontmost no candidate yields only found=false; found candidate is flattened into result
14. shutdown repeated or concurrent with capture: flag idempotence and socket teardown; response arrival requires runtime validation
