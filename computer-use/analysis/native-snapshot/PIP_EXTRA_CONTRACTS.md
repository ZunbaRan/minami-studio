> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/PIP_EXTRA_CONTRACTS.md`；原文件 SHA256 `f0be9c431ba0815146323bb1d997b7ef249ae43eeb56cfc4f367f618f98adfcf`；全文件 1–279 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native PiP command contracts, Alma 0.4.164 arm64

## Scope and closure

**Closed by inspected instructions:** all five command argument keys, coercion helpers, selector precedence, defaults, top-level response shapes, nested session/armed status fields, custom PiP error messages, checked-integer traps, duplicate behavior, and minimization callback success/failure disposition. These are native daemon commands, not Electron auto-mirror IPC and not public MCP tool schemas.

**Partial only at the framework/runtime boundary:** actual ScreenCaptureKit/AX permission, protected-content, minimized-window, AppKit geometry enforcement and async race behavior cannot be proven by a static binary. Framework-generated localized descriptions remain dynamic. These limits do not leave the JSON schema unresolved.

No Alma code was executed. Evidence is static `analysis/native/arm64-disasm.txt`, `arm64-symbols.txt`, `arm64.macho`, and caller dispatch. Helper excerpts created in this directory are listed below. Virtual addresses are full arm64 addresses; the Mach-O slice __TEXT file offset is VA minus `0x100000000`. Static literal bytes were checked from the Mach-O, rather than trusting stale disassembler annotations.

See `WIRE_SCHEMA.md` for the outer newline JSON protocol: a successful command's result below is wrapped in `{id,ok:true,data:...}`; a CUError is wrapped in `{id,ok:false,error:{code,message[,hint]}}`. Object key order is not a compatibility guarantee.

## Shared input interpretation

All argument keys below live inside `args`.

- `str(key)` at `0x100006140`: String cast only; absent/null/wrong type gives nil. Empty String remains present.
- `int(key)` at `0x100006268`: Int, then Double converted to Int by truncation toward zero, then signed decimal String parse. Invalid String gives nil. Nonfinite/out-of-Int-range Double conversion traps rather than producing CUError. See `WIRE_SCHEMA.md` for JSON AnyCodable decoding and bridge nuances.
- `double(key)` at `0x10000671c`: Double, Int converted to Double, or numeric String; invalid/missing gives nil.
- `bool(key)` at `0x1000069a8`: Bool, then Int != 0; no String `"true"`/`"false"` parser. Optional nil is false for the `all` tests here.
- Whenever present, `window_id` is checked-converted to UInt32. Negative or >4294967295 causes a `brk #1` runtime trap, not a clean invalid_arg error. Zero is not rejected by dispatch.
- Whenever parsed, `pid` is checked-converted to Int32. Values outside -2147483648...2147483647 trap. The PIP dispatch resolver does not require positive PID on the direct-ID path.
- Unsupported extra argument keys are ignored. In particular there is no `ref`, `bundle_id`, `display_id`, `size`, `x`, `y`, `show_cursor`, or timeout field parsed by these command branches.

## 1. `pip_open`

Entry `0x10007c42c`; resolver `0x100088f74`; manager `0x1000485e0`.

### Parsed arguments

| Key | Parser | Default / role |
|---|---|---|
| `window_id` | int then checked UInt32 | nil; selects direct-ID path if present |
| `pid` | int then checked Int32 | nil; optional metadata on direct-ID path, otherwise app selector |
| `bundle` | str | nil; read only on no-window_id app-resolution path |
| `title` | str | nil; metadata on direct-ID path, preferred title on app-resolution path |
| `width` | double | nil |
| `height` | double | nil; not even parsed if width did not parse |

### Window resolution

Equivalent branch logic:

    if window_id parses:
        checked UInt32(window_id)
        pid = optional checked Int32(args.int("pid"))
        resolved = (window_id, pid, args.str("title") ?? "")
        // No resolveApp call and no ownership cross-check here.
        // bundle is ignored.
    else:
        app = resolveApp(bundle: args.str("bundle"),
                         pid: optional checked Int32(args.int("pid")))
        windows = (try? AXBridge.windows(app)) ?? []
        if windows.empty:
            throw internal("App has no windows to mirror.")
        selected = selectWindow(windows, args.str("title"))
        resolved = (selected.id, app.processIdentifier, selected.title)

`selectWindow`, in enumeration order:

1. If requested title is nonempty, return the first exact title equality match
2. Otherwise, still for a nonempty requested title, return the first whose title `contains(requestedTitle)` using Swift/Foundation String.contains without case-folding options
3. If title is absent/empty **or neither title match exists**, choose first `focused == true`
4. Else choose first window

A mismatching title is a preference, not an error. The fallback flag is definitely **focused**, not minimized or main: WindowInfo getter `0x1000109bc` reads byte +0x41; this is the flag tested at `0x100089244–248`. No minimized filter is present in this selection.

`resolveApp` is the shared AXBridge helper (`0x10001024c` wrapper, actual `0x100019718`): live explicit PID first; if unavailable, `bundle` exact bundle ID first match; if none, exact localized application name first match. With neither usable selector, error label is `pid=0`, not a frontmost-app default. See `WIRE_SCHEMA.md` for its app-not-found error.

Resolution evidence: direct-ID path `0x100088fa4–0x100089060`; app path `0x100089080–0x1000890d4`; exact/contains `0x1000890dc–0x10008921c`; focused/first `0x100089220–0x100089298`; no-windows error `0x10008929c–0x1000892fc`. AX window enumeration errors are caught and replaced with an empty array at `0x1000890b8–0x1000890cc`, thereby losing the underlying AX error.

### Preferred size and title

Only if width **and** height parse and each compares >0 is `CGSize(width,height)` passed as the preferred size. Otherwise the entire preferred size is nil; a valid one-dimensional value is not used by itself. This is silent defaulting, not invalid_arg. Width is tested at `0x10007c980–984`, height at `0x10007c98c–994`, with nil tagging `0x10007c694–6a0`/`0x10007c970–99c`. NaN fails these comparisons; positive infinity is not explicitly rejected by dispatch.

For a new session with nil preferred size (`0x10004ad14–0x10004ada4`):

    sourceW = max(SCWindow.frame.width, 1)
    sourceH = max(SCWindow.frame.height, 1)
    aspect = sourceW / sourceH
    width = min(max(sourceW / 3, 240), 960)
    height = width / aspect

A provided positive pair replaces both calculated dimensions without aspect-ratio normalization. Constructor also sets the floater minimum size to 200×150 at `0x10004aec0–0x10004aed8`; actual enforcement by AppKit is a runtime boundary. The returned frame is the actual native window frame, so do not claim it always equals the requested content size.

An empty resolved title is changed to nil before manager.open (`0x10007c6a8–0x10007c7c0`). New-session title is `provided nonempty title ?? SCWindow.title ?? ""`, proven in both main-thread path `0x1000489f4–0x100048e48` and queued construction `0x100050b34–0x100050b7c`. `Session.title` stays the raw title; window chrome is separately labeled `Alma PIP` or `Alma PIP — <title>`.

### Response

    {
      "opened": true,
      "session": {
        "window_id": 123,
        "pid": 456,
        "title": "Window title",
        "has_first_frame": false,
        "last_frame_age_ms": null,
        "floater_frame": {"x": 0.0, "y": 0.0, "w": 640.0, "h": 360.0}
      }
    }

Illustrative values only. Exact fields/types are defined under status below. A direct-ID open without pid produces `session.pid:null`; manager does not derive PID from SCWindow's owning application.

Existing session keyed by window_id: queue `bringToFront`, return its existing status. Do not replace session title/PID/size or report opened=false. The dispatcher always sets `opened:true` after successful manager.open (`0x10007c864–0x10007c8c4`). Existing check occurs at manager entry `0x1000486dc–0x100048714`, before fresh SCWindow lookup; status return `0x1000488b4–0x1000488c0`.

For a new session, SCWindow is looked up by ID through ShareableContentCache and the session is constructed on the main thread. Capture startup uses an async completion handler; a successful open response does **not** promise that a first frame has arrived. Off-main creation blocks via semaphore with an unbounded wait at `0x100048c70`; no request timeout field is used here.

### Errors

- App-resolution errors from shared `resolveApp`
- `internal`: `App has no windows to mirror.`
- `internal`: `No SCWindow with id <UInt32> (window closed or off-screen?)` from `0x100049534–0x100049618`
- ShareableContentCache / ScreenCaptureKit / session-construction errors can propagate. Queued construction preserves a CUError; a non-CUError is wrapped as `internal(error.localizedDescription)` at `0x100048d08–0x100048df4`. The exact OS-localized description is not a fixed Alma string
- Checked-number traps described above

There is no error merely because the requested title did not match or width/height were absent/invalid/nonpositive.

## 2. `pip_close`

Entry `0x10007c70c`; manager single close `0x100049774`; close-all `0x100049d14`.

| Key | Parser | Role |
|---|---|---|
| `all` | bool | absent/invalid/false means single-window mode; true/nonzero Int means all |
| `window_id` | int then checked UInt32 | required only when `all` is false |

`all` is read first. If true, window_id is ignored, including invalid or out-of-range input. Close all then return:

    {"closed":"all"}

Otherwise missing/unparseable window_id throws `invalid_arg`, exact message:

    missing "window_id" (or pass "all": true)

For parsed UInt32 return:

    {"closed":true,"window_id":123}

`closed` is false if there was no matching session; that is a successful response, not an error. Bool means whether manager removed a session. Shutdown is queued after removal; reply is not proof every async stream shutdown operation has finished.

All branch and string result `0x10007c70c–0x10007c7b4`; ID/missing branch `0x10007c8e8–0x10007c96c`; response `0x10007cac0–0x10007cb80`. This command does not disarm minimize observers.

## 3. `pip_status`

Entry `0x10007c9e8`. No args are read; there is no single-ID selector.

    {
      "sessions": [SessionStatus, ...],
      "armed": [ArmedStatus, ...]
    }

Both arrays are always present, empty when none. Native code maps dictionary values/entries under each manager's own NSLock; it does not sort the results. The two lists are fetched separately (`0x10007ca3c`, `0x10007ca74`), so the combined result is not one atomic cross-manager snapshot.

### SessionStatus (six exact fields)

Implementation `PIPSession.statusSnapshot`, `0x1000490a4–0x1000493e8`:

| Field | JSON type | Meaning |
|---|---|---|
| `window_id` | integer | Session's UInt32 source window ID converted to Int |
| `pid` | integer or null | Session's optional Int32, sign-extended if present |
| `title` | string | Stored title, including empty String if no title available |
| `has_first_frame` | boolean | Stored first-frame flag; initialized false |
| `last_frame_age_ms` | integer or null | null if stored last-frame timestamp equals 0; otherwise Int((CACurrentMediaTime() − timestamp) × 1000), truncation toward zero |
| `floater_frame` | object with numeric `x`, `y`, `w`, `h` | Current floater NSWindow.frame in native AppKit coordinates, not source window bounds |

Nil values are retained as JSON null by the optional dictionary/AnyCodable path; pid and last_frame_age_ms are not omitted. There are no `running`, `fps`, `frame_count`, `source_bounds`, `width`, `height`, or error-string fields in this status.

Field producers: window_id `0x100049110–148`; pid `0x10004914c–194`; title `0x100049198–1c8`; has_first_frame `0x1000491cc–210`; last_frame_age_ms `0x100049208–2b0`; floater_frame `0x1000492b4–388`. Timestamp-age computation has finite/Int range traps (`0x1000493ec–3f4`); these are not ordinary expected runtime errors.

### ArmedStatus (three exact fields)

Dictionary mapper `0x10004a1ec–0x10004a698`, construction `0x10004a2f4–0x10004a378`:

    {"window_id":123,"pid":456,"title":"Window title"}

window_id = key as Int; pid = stored signed Int32 as Int; title = stored nonoptional String. Missing/empty title was stored as `""`, so title is not null. No bool armed flag, observer ID, timestamp, expiry, or preferred size is included.

## 4. `pip_arm`

Entry `0x10007cbc8`; resolver `0x100089414`; armer `0x10004e480`.

### Parsed arguments / resolution difference

Reads `window_id` via int→UInt32, `title` via str, `pid` via int→Int32, `bundle` via str. No width/height or size is read.

The direct path requires **both** parsed window_id and parsed pid:

    if window_id != nil and pid != nil:
        resolved = (window_id, pid, title ?? "")
    else:
        app = resolveApp(bundle, pid)
        windows = (try? AXBridge.windows(app)) ?? []
        if windows.empty:
            throw internal("App has no windows to arm.")
        selected = same selectWindow rules as pip_open
        resolved = (selected.id, app.processIdentifier, selected.title)

Consequently `pip_arm({window_id:123,bundle:"Example"})` without pid resolves Example and chooses a window; it does **not** guarantee arming window 123. With no pid/bundle, window_id alone reaches shared app resolution and fails. Conversely explicit window_id+pid avoids app-resolution liveness/ownership validation, then the armer checks that ID occurs in that PID's AX windows. Direct path `0x100089444–46c` then `0x1000896f0–71c`; no-ID/no-PID path starts `0x100089470`.

Selection is exact title, contains title, focused, first; no title match error. Empty title becomes nil when passed to the armer (`0x10007cd58–0x10007cf10`); armer stores nil as empty String.

### Response

    {"armed":{"window_id":123,"pid":456,"title":"Window title"}}

The inner title is the resolved String, including `""`. `armed` is an object, not a Boolean or an array. Construction `0x10007d05c–0x10007d14c` then shared dictionary assembly `0x10007bd44–0x10007bd8c`.

Arming an already armed window ID is a no-op success: armer returns after its locked lookup (`0x10004e4e4–0x10004e524`). It does not update stored PID/title or replace observers. Dispatch still replies using this call's resolved tuple. Therefore a duplicate arm's response metadata can differ from later pip_status.armed metadata; status reports the original registration.

For a fresh entry, armer reads AXWindows for the supplied PID, finds first AX element whose `_AXUIElementGetWindow` ID equals window_id, creates AXObserver, adds AXWindowMiniaturized and AXUIElementDestroyed notifications, adds its source to main run loop, then stores (pid, element, title, observer). `_AXUIElementGetWindow`'s return code is not checked; output starts at zero. A zero ID can therefore behave unusually, rather than being explicitly rejected.

### Errors and success caveat

- Shared app-resolution error
- `internal`: `App has no windows to arm.` (AX enumeration errors swallowed by resolver)
- `internal`: `No AX window element for windowId=<UInt32> pid=<Int32>` if AXWindows lookup fails, is absent, casts incorrectly, is empty, or has no matching ID. Producer `0x10004e580–0x10004e698`
- `internal`: `AXObserverCreate failed: <AXError integer>` when AXObserverCreate reports nonzero or returns no observer; producer `0x10004e9b0–0x10004ea6c`
- Checked-number traps as above

Both AXObserverAddNotification return codes are ignored (`0x10004e854`, `0x10004e890`). A successful armed response proves the code registered/stored an observer attempt, not that every application actually supports those notifications.

### Minimize/destroy disposition (newly closed lifecycle detail)

Observer callback `0x100052754–0x100052c64` first requires nonnil context and a nonzero window ID obtained from the callback's element. Other notifications are ignored. Matching AXWindowMiniaturized queues the closure at `0x100052cd8`; AXUIElementDestroyed queues disarm at `0x100052c68`.

On queued minimize:

1. If PIPManager already contains that ID, disarm the entry and return (`0x100052d48–0x100052d7c`)
2. Else read armer's entry; if removed in the meantime, return (`0x100052db0–dd4`)
3. Open using stored ID/PID/nonempty title, no preferred size (`0x100052de4–0x100052e34`)
4. On successful open, release returned status and disarm (`0x100052fa0–0x100052fb4`)
5. On failed open, print `PIP auto-open on minimise failed for wid=<id>: <error>\n` to stderr and retain the armed entry (`0x100052e38–0x100052f9c`)

**Correction to a broader earlier lifecycle summary:** error does not auto-disarm here. The arming is one-shot on successful/existing open, but a failed attempt remains eligible for a later notification. The prior command response is not replaced by a later failure response.

## 5. `pip_disarm`

Entry `0x10007cc90`; armer single disarm `0x10004eabc`; all `0x10004ec88`.

Same argument contract as pip_close: `all` bool default false, otherwise required int→UInt32 `window_id`. With all true, skips window_id parsing and returns:

    {"disarmed":"all"}

Single mode:

    {"disarmed":true,"window_id":123}

False means no entry existed, still success. Missing/unparseable ID produces exactly the same `invalid_arg` message as close:

    missing "window_id" (or pass "all": true)

Disarm removes the dictionary entry under lock, then removes main-run-loop source and both AX notifications; it returns whether an entry existed (`0x10004eabc–0x10004ec14`). Notification-removal return codes are ignored. It does not close a live PiP session.

Caller evidence: all branch `0x10007cc90–0x10007cd1c`; missing branch `0x10007ce74–0x10007cef4`; UInt32 checks `0x10007cfcc–0x10007cfdc`, traps `0x10007d1a0/1a4`; response `0x10007cff0–0x10007d058` sharing single-close tail.

## Exact residual gaps and replication tests

No unresolved parsed argument keys or response field names remain for these five commands. Remaining verification belongs to runtime/system behavior, not guessed schema:

1. Under each macOS/permission state, enumerate native ScreenCaptureKit/AX localized errors; these are not fixed strings in the binary
2. Observe AppKit-enforced frame for extreme/tiny/preferred sizes, display configuration, and cascade positioning; reported `floater_frame` is actual NSWindow.frame
3. Test timing: open before first frame, async capture failure, close while frame callback pending, armed callback queued while user disarms, simultaneous duplicate opens/arms
4. Test framework capability failures: ignored AX add/remove notification errors and whether minimized/offscreen windows remain shareable
5. Shared generic argument helper dynamic casts, nonfinite numeric String input and trapping integer conversions need fixture tests on Swift/Foundation for byte-exact parity; the actual branches are documented, no Alma runtime was invoked

Useful parity fixtures: all=true plus invalid window_id; all="true" plus no ID; nonexistent single close/disarm; direct pip_open without pid; direct pip_arm with/without pid; unmatched title with focused fallback; AX enumeration failure; only one valid dimension; zero/negative dimension; repeated open preserving prior metadata/size; repeated arm echoing new metadata while status retains old; no first frame producing null age; failed minimize auto-open retaining armed entry.

## Evidence excerpt files

- `pip-open-resolution.asm` (`0x100088f74–0x100089410`)
- `pip-arm-resolution.asm` (`0x100089414–0x100089898`; includes a short next-function prefix)
- `pip-session-status.asm` (`0x1000490a4–0x1000493f4`)
- `pip-armed-status.asm` (`0x10004a1ec–0x10004a698`)
- `pip-arm.asm` (`0x10004e480–0x10004eab8`)
- `pip-arm-return.asm` (`0x10007d05c–0x10007d14c`)
- `pip-disarm-missing.asm`, `pip-disarm.asm`, `pip-status-lock.asm`
- `pip-manager-open.asm`, `pip-open-on-main.asm`, `pip-scwindow-lookup.asm`, `pip-session-init.asm`, `pip-manager-close.asm`
- `pip-arm-callback.asm` covers observer routing; minimize body `0x100052cd8–0x10005306c` remains in full `arm64-disasm.txt`
