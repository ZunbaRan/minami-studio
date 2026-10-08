> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/UTILITY_COMMANDS.md`；原文件 SHA256 `51f350fea34a0a58b02e4daf776c713e4082fb6a6bbc1cd0cadd09d9f095bcc2`；全文件 1–102 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native utility command contracts

Alma0.4.164 arm64 unslid static evidence. Result schemas below are the `data` inside WIRE_SCHEMA's envelope; errors use its nested error schema. This supplements45-command inventory. Inputs not listed are not parsed by the inspected command body. PIP/Appshot/remote commands have separate contracts; native MCP service is a separate subsystem.

## ping

Args none. Returns `{pong:true,version:"0.1.0",uptime_s:Int}`. uptime_s=Int(NSProcessInfo.processInfo.systemUptime), truncation toward zero; this is **OS uptime**, not elapsed daemon lifetime. Dispatch0x100076a24; version immediate0x100076a90–a98; clock0x100076ae0; cast0x100076b28. The helper protocol version0.1.0 is separate from app release0.4.164.

## permissions

Args none. Returns:

    {accessibility:Bool,screen_recording:Bool,
     focus_guard:{armed:Bool,arm_failures:Int}}

health tuple0x100076bcc; accessibility `isTrusted(prompt:false)`0x100076c38; screen capture permission probe0x100076c6c; nested health keys0x100076cb8–cf0. The SC permission probe uses ShareableContentCache via synchronous async bridge, so it is an actual permission check, not merely a stored preference. Missing permission is a false flag, not itself failure of this command.

## grant

Args none. Calls `isTrusted(prompt:true)`; returns `{prompted:true,accessibility:Bool}`. 0x100076d94–e18. `prompted:true` reports the requesting operation, not proof that permission was granted or UI appeared. Does not grant Screen Recording automatically.

## apps

Args none. Returns `{apps:[{bundle:String?,name:String,pid:Int32,active:Bool}]}`; mapper0x10007fa04 builds exactly four fields bundle/name/pid/active. Native AXBridge.runningApps0x10000fe34 selects data; null/absent bundle semantics follow optional dictionary values (canonical null). This is distinct from list_apps usage-history command. RunningApps selection/sort policy is closed in the follow-on subsection below; do not substitute list_apps.

## windows

Args `bundle?:String,pid?:Int32` using args coercions; same resolveApp PID-first/live-app fallback defined in WIRE_SCHEMA. No implicit frontmost.

Returns `{app:{bundle:String?,pid:Int32},windows:[{id:UInt32,title:String,bounds:{x,y,w,h},minimized:Bool,focused:Bool}]}`. App object contains bundle and pid, not localized name in this branch. Native calls resolveApp0x1000770d0 then AXBridge.windows0x1000770f0; wraps app/windows at0x100077130–74e8. Window mapper0x10007ff34–8027c. Windows retain AX source order; no sorting. Missing app -> appNotFound; AXWindows copy errors propagate via CUError; nil/unconvertible AXWindows yields empty array. See FINDINGS section10 for focused/geometry/ID defaults.

## snap

Literal `snap`, not `snapshot`. Args bundle?,pid?,window_id?,depth=6,interactive_only=true,wakeup_seconds=0. Returns full SnapshotResult dictionary and does not run AppStateDiff or capture. Exact schema/algorithms in FINDINGS sections2–4. This is optional direct-native functionality; current wrapper post-action uses get_app_state and therefore has different diff effects.

## raise

Args `bundle?:String,pid?:Int32,window_id?:UInt32`; checked conversions can trap if out of range. Uses resolveApp then AXBridge.windows. Window selection: explicit matching ID first, else focused first, else first AX window. Calls AXRaise on chosen AX element (0x10001683c); return checked through AX error path; success data `{raised:true}` (0x10007dbc4–be0). It is not guaranteed to activate the application or preserve user focus; AXRaise runtime behavior depends on the app.

Important: empty AX window array reaches BRK in selection0x100016918 rather than a demonstrated friendly no-window error. Hardened replica should return typed error, declaring this difference. Native symbol entry0x100016670; dispatcher0x10007db80.

## shot

Args:

- `out:String` required path; missing/empty/wrong type uses requireStr invalid_arg
- `max_width?:Int`, no native default (nil means no cap)
- `window_id?:UInt32`
- `bundle?:String,pid?:Int32`, used only when window_id absent

Algorithm: if window_id supplied, capture it directly without requiring PID/bundle; otherwise resolveApp and choose **first AX window**, not focused preference. If array empty, internal error message `App has no windows to capture.` (0x10007e810–830). Calls Capture.captureWindow ScreenCaptureKit via runAsync0x10007e508, quality fixed0.85. Failure propagates native failure; no AX-success/screenshot_error wrapper unlike get_app_state.

Result `{path:String,width:Int,height:Int,cursor?:{x:Double,y:Double}}`. Capture image always writes supplied path. Optional cursor is normalized0..1 logical ActionCursor position within **live CG window bounds**; omit when window bounds absent, no current ActionCursor, nonpositive rect size, or cursor outside rect. It is metadata, not a burned-in cursor. Base fields0x10007e8cc–91c; windowBounds0x10007e93c; ActionCursor.normalized0x10007e95c; cursor insertion0x10007e9fc. Successful shot does **not** update Daemon.lastMapping or visualRefs in this dispatch path. Those caches belong to get_app_state screenshot flow.

## shot_display

Args `out:String` required, `max_width?:Int` defaultnil, `display_id?:UInt32` defaultnil, `quality?:Double` default0.6 (IEEE7540x3fe3333333333333 at0x10007dcc4–d0).

Calls Capture.captureDisplay via runAsync0x10007dd18. Result same `{path,width,height,cursor?}`. For cursor metadata uses supplied display ID if present, else CGMainDisplayID, then CGDisplayBounds and ActionCursor.normalized0x10007e058–06c. Underlying SC display selector uses ShareableContentCache display TTL30; image configuration differences vs window capture are detailed in the follow-on subsection below. No AX snapshot, diff or mapping update. Invalid requested display/missing permissions/failing write propagate errors.

## ActionCursor normalization (shared shot/shot_display)

0x10002a0e4: get current logical action cursor; require positive rect width+height and CGRectContainsPoint; x=(point.x-rect.minX)/rect.width,y=(point.y-rect.minY)/rect.height. No clamping to boundary or conversion to screenshot pixels. ActionCursor lifetime itself is described by native input report. This is not necessarily hardware mouse position.

## Nonexistent requested names

No top-level `status` or `frontmost` command in Daemon.dispatch45 inventory. Relevant actual commands are ping/permissions, pip_status/mcp_status, and appshot_frontmost. Do not add aliases while claiming protocol parity.

## Scope boundaries

These contracts close host utility **wire fields** and main control flow; native subprocess/OS scheduling, app-provided AX behavior, SC display capture specifics and private APIs still require capability tests. A host mock can implement the above shapes now; production parity should gate capture until permitted macOS execution verifies dimensions and permissions. Never infer exposure through JS MCP23 from a socket handler's existence.

### Follow-on static closure: apps selection and display capture

`apps` selects NSWorkspace.runningApplications with activationPolicy==0/regular (0x10000ff68–6c), builds bundle/name/pid, uses `(unknown)` when localizedName absent (0x1000100f8–10c), marks active by PID equality with initially sampled frontmostApplication (0x10000fe74 and0x100010134–13c), then sorts case-insensitively by lowercased names (comparison0x1000176ac–6ec). Thus it is ordinary GUI apps, not all running processes. Equal-key ordering follows the inspected stable sort implementation.

`shot_display` Capture.captureDisplay0x10003feb8:

- ShareableContentCache.display(id) gets fresh(maxAge30), chooses matching explicit display ID or first display when absent, invalidates/retries once on no match, then throws if still missing. Picker0x100040c18–0x100040de4; unlike cursor metadata's absent-ID branch, the capture picker does not itself call CGMainDisplayID.
- SCContentFilter(display,excludingWindows:[])0x100040064
- Find NSScreen by deviceDescription['NSScreenNumber'] matching selected SCDisplay.displayID (0x100040198–244); use matched screen backingScaleFactor, else mainScreen scale, else2.0 (0x1000402e8–314)
- width=Int(SCDisplay.width*scale), height=Int(SCDisplay.height*scale); positive smaller max_width downscales proportionally with minimum height1, using truncation
- **showsCursor=true**0x100040464–468 (window capture uses false); capturesAudio=false; minimumFrameInterval1/60
- macOS>=14 SCScreenshotManager.captureImage; older branch internalError0x10004058c; writeJPEG requested quality, return actual image pixel width/height

The metadata cursor still refers to ActionCursor and may coexist with ScreenCaptureKit's actual system cursor pixels. Absent display_id may imply SC first-display capture while cursor normalization uses CGMainDisplayID; preserve and test that distinction instead of silently assuming identical selection.

## open_url (optional native extension)

Args `url:String` required nonempty; `bundle?:String` preferred opener. No PID targeting in body. Parse with Foundation.URL(string:), invalid parse => invalid_arg `invalid url: <supplied text>` (0x10007774c–77f4). Success calls AppCommandRegistry.openQuietly(url,preferredBundleId)0x100077a24 and returns `{opened:<original supplied URL String>,via:<supplied bundle String or null>}` (0x100077b64–7ef0). It does not return `{opened:true}`.

openQuietly0x100031414 creates NSWorkspace.OpenConfiguration with activates=false, addsToRecentItems=false, hidesOthers=false (0x100031528–54c). Preferred bundle resolves its application URL; when usable calls openURLs:[url] withApplicationAtURL; otherwise general openURL:configuration. Uses completion+semaphore wait with5s budget. Timeout -> internal `NSWorkspace.open(<absoluteString>) timed out after 5s`; callback error -> internal `NSWorkspace.open(<absoluteString>) failed: <localizedDescription>` (0x100031994–19ec,31a84–31b1c). The5s error does not itself establish that OS launch/open was cancelled.

Both open_url and intent pass bundleId through ForbiddenTargets dispatcher preflight. This establishes quiet-intent configuration, not a universal OS guarantee of zero frontmost changes.

## intent (optional native registry extension)

Args required nonempty `bundle:String,intent:String`; optional `params:object` default empty. Nonobject params casts unsuccessfully and is treated as empty. Coerce each nonnull params value to String in order String / Int.description / Double.description / Bool=>"true"|"false" / String(describing:value); null is skipped. Evidence params lookup0x100077be4; dict cast0x1000782d4; scalar branches0x1000785dc,78610,7865c,78690; fallback0x100078720.

Calls AppCommandRegistry.dispatch(bundleId,intent,params)0x100077c4c. On success returns `{bundle:<requested>,intent:<requested>,url:<constructed URL.absoluteString>}`0x1000781e0–2270. Registry rejects unknown bundle, unknown intent (includes known-intent list), missing required params, and invalid constructed URL through invalid_arg paths0x100030cc0/31000/31158/30e78; successful built URL is passed to openQuietly0x100031090.

**Scope classification:** no JS MCP23 tool maps to open_url or intent. Their socket schemas are closed above. Registry metadata emitted by core list_apps is reconstructed in APP_INTENTS_METADATA.md; executable URL-builder behavior remains outside this supplement. Treat that registry as an optional native extension, not a implemented core capability. A clone may explicitly return unsupported for this optional extension until it supplies the same registry, but must not claim45-command behavioral parity. Current evidence of default desktop control is the separate JS stdio MCP adapter; use host/mirror reports to decide which administrative/native extensions to include.
