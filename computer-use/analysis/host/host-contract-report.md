> 来源：用户提供的 .164 研究资料 `analysis/host/host-contract-report.md`；原文件 SHA256 `2a02db8d38fb6015abe1822440a77dca4c5e73f49da1198136245794591d2e8e`；全文件 1–135 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Alma 0.4.164: Electron host and model integration contracts

## Scope and evidence standard

This is authorized static analysis of the supplied official arm64 installer. No Alma application code, helper, or MCP entrypoint was executed. The analysis follows calls across extracted host JavaScript, not just matching strings. `main.pretty.js` and `preload.pretty.js` are local data-only beautifications for inspection, not distributable implementation assets. All line references below use these derived files; byte offsets and original SHA-256 values are in `evidence.json`. Original main is a single 3,130,833-byte line, SHA-256 `df95c2d383730265f251660761a480938989351d2278235366e55366a72c0175`.

“Proven” means a branch/call visible in this sample. It does not mean the branch was exercised or that macOS accepted an action. Native OS behavior, actual installed user preferences, plugin hooks and model decisions remain runtime-dependent. Native AX implementation and PiP/Appshot UI detail are covered by the component reports.

## 1. Architecture: there are two host-to-helper routes

Route A, model/MCP: model selects `computer-use__<tool>` → AI SDK tool wrapper → shared MCP manager → stdio MCP process → helper socket. The MCP process, not the generic host tool adapter, owns the computer-use schema and per-app approval requests.

Route B, local UI/CLI HTTP: renderer or local CLI → loopback Express `/api/computer-use/...` → singleton helper client `Jp` → helper socket. The direct REST methods have no per-app approval check in their handlers. They share the helper but do not transit the stdio MCP adapter.

Appshot and PiP use host-side helper methods as well. Treat UI mirroring, screen snapshots, model state acquisition, and model action execution as separate consumers rather than a single “screen tool”.

The host API listens on 127.0.0.1. The inspected common middleware installs CORS, presence/metrics, JSON/urlencoded 50 MB parsers, gallery static-file serving, and logging; it does not add a blanket bearer-token or per-app authorization check. This is a local trust-boundary observation, not proof of remote reachability or a tested exploit. Other remote-handoff bridges have their own policies and are outside that claim. Evidence: main 71594–71641; listener 88534; direct methods 72793–72928.

## 2. Auto-registration and discovery

On normal startup, before MCP initialization, non-headless host imports `computer-use-register-B_NFTJR3.js`. The registration function returns immediately on non-macOS. It reads `~/.config/alma/mcp.json`, then searches for a bundled `alma-computer-use-mcp.mjs` entrypoint in Resources/cli, Resources/bin, app.asar.unpacked/bin, development ancestor bin folders and app paths.

Packaged launch uses the Electron executable with `ELECTRON_RUN_AS_NODE=1`; development uses `node`. The config key is `computer-use`. A missing entry is installed. A recognized previous Alma entry can have path/command updated. An existing custom entry whose args do not identify the Alma script is preserved. Parsing failure logs a warning and reconstructs config in memory; a successful registration write then replaces the file. There is no evidence here that startup registration itself asks the user for approval. This does not establish OS accessibility/screen-recording permission.

The MCP manager creates a stdio transport, connects (60 s race for stdio), lists tools (15 s race), optionally lists resources/templates (15 s each), and installs resource-change notifications when advertised. Server identity and tool identity are normalized into `<server>__<tool>` names. The manager stores discovered schemas, description and `_meta`; `alma/outputSafetyMode` metadata or a recognized description marker influences generic output compaction. Initialization is independent of whether a tool is currently exposed to the model. Evidence: main 35433–35842, 88454–88465; registration chunk.

## 3. Actual tool availability and authorization layers

Do not equate a fail-open MCP approval request with every authorization layer being absent.

1. Tool selection: per-turn no-tools and image-generation-model branches remove tools; active tool names are selected from explicit choices, automatic selection, accumulated conversation selections and tool search discoveries. Automatic MCP candidates are drawn from enabled MCP server IDs. Standard generation builds an available registry then supplies `activeTools`; the ACP branch has a separate adapter. Evidence 84480–84570, 84720–84786, 86113–86129.
2. Project capability boundary: `resolveAllAvailableTools` calls `aE(registry,threadId)`. A nonempty project `restricted.mcpServers` list filters names by the prefix preceding `__`; built-in tool restrictions are a separate list. Empty lists are unrestricted. Bash and Task get their companion tools. Temporary/no-project contexts have no such project boundary. It is capability filtering, not a filesystem or native-action sandbox. Evidence 25183–25241, 79220–79234.
3. Plugin interception: `eT` wraps MCP execute with `Qk`; when execution context exists, a `tool.willExecute` hook may cancel or replace args. Hooks may also alter successful results. This is extensibility, not evidence an approval hook is installed. Evidence 26202–26365.
4. Product per-app ledger: `/check_approval` consults settings and the app-approval database. Existing approved/nonrevoked rows are allowed and usage bumped. With strict approval disabled or absent, a previously unapproved/revoked bundle is auto-approved and usage bumped. With strict approval exactly true it returns denied. This endpoint does not itself create a confirmation dialog. Actual approval is separately POSTed; revocation separately DELETEd. Evidence 72800–72865.
5. OS permission: helper permission commands and macOS controls are separate. Host checks platform and helper existence, but native permission enforcement belongs to the helper/OS.

The inspected generic MCP wrapper has no per-bundle approval gate. Direct REST action endpoints pass to `Jp` without consulting the approval ledger. The MCP wrapper’s own fail-open/path-specific behavior must be described at that layer, alongside these independent controls. A clean replacement should choose an explicit enforcement boundary and use the same authorization decision for all transports.

Ledger fields are bundle ID, app name, approved/revoked timestamps, use count, last-used timestamp. Action logging is opt-in only when the setting is exactly true; it accepts tool name, bundle, PID, args, duration, screenshot hash and error code. The host writes JSON args, and a retention helper deletes all but newest N rows. No redaction is proven inside this database write path. Evidence 5843–5900, 72866–72899.

## 4. Helper transport and lifecycle

`Gp` resolves the native executable in Resources/Alma Computer Use.app/Contents/MacOS/AlmaComputerUse, then dev/app fallbacks. `Jp.isAvailable` means macOS plus existing executable, not successful permission or handshake.

Socket path is inside Electron userData (fallback home/Library/Application Support/Alma before app readiness). It is `computer-use-<first8 SHA1(executable path)>.sock`, or a plain fallback name when helper missing. This path-based disambiguation separates installs by executable location, not content version.

State machine, reconstructed:

- DISCONNECTED + call → reject unsupported platform, or enter CONNECTING
- CONNECTING → first try existing socket; if successful, attach and READY
- Initial connect fails → spawn helper with `daemon --socket PATH --idle-seconds 900`
- Retry connection every 100 ms for at most approximately 4 s; success → READY; failure → typed helper-unreachable error
- Concurrent connect requests share one connecting promise
- READY + request → allocate random 8-byte hex ID, insert pending promise/timer, write newline-delimited JSON `{id,cmd,args}`
- Reply `{id,ok,data/error}` → resolve/reject matching pending request; unknown IDs ignored
- Timeout → remove pending and reject locally; no cancellation command sent
- Socket close → reject every pending request as helper-disconnected and notify disconnect listeners
- Explicit shutdown → best-effort `shutdown` command (2 s), destroy socket, reject pending, SIGTERM tracked child
- Before quit → initiate shutdown asynchronously

Default command timeout is 20 s. `get_app_state`, `shot`, `shot_display`, and Appshot capture use 30 s. The process is not detached; stderr is forwarded; a child exit clears only the tracked child reference. An existing connected daemon might not be this process’s child; shutdown command nevertheless targets the connected daemon.

Read framing buffers arbitrary chunks and splits on byte LF. Malformed JSON lines are ignored. Event lines are detected by the literal substring `"evt":true`, then parsed and dispatched by `appshot.monitor` or `appshot.update`; other event topics do nothing. The host serializer convention therefore matters: equivalent JSON whitespace around the event flag would not take this optimized event path. Listener exceptions are isolated. The inspected implementation does not reset the partial read buffer explicitly on socket close; that deserves a reconnection test. No per-request connection epoch is visible.

Evidence main 16330–16678; original byte anchors 532978 (helper resolver), 533615 (client), 536295 (call), 536825 (connect), 537721 (socket wiring).

## 5. Command surface at the direct host client

The helper client forwards ping, permissions, grant, apps/list_apps, launch_app, windows, snap, get_app_state, click, perform_secondary_action, drag, type/type_text, press/press_key, select_text, set_value, scroll, lens, raise, shot, remote_input, shot_display, Appshot monitor start/stop/frontmost/capture, and shutdown.

Direct REST normalizations include default empty body, text default empty string, `replace` and `show_cursor` default true, scroll pages default 1, launch `activates` true only on explicit true. Errors with known client/permission/stale-reference codes map to HTTP400; other helper errors to HTTP500; code/message/hint are retained. App activity middleware notifies PiP asynchronously without blocking actions. It covers a listed subset of methods, not every observation or command; launch_app is registered before this middleware and terminates its response, so route order should be considered when claiming that particular REST call triggers the middleware.

## 6. Cancellation is not end-to-end

There are at least four different clocks:

- host generic watchdog: normally 5 min; long-task/background branch 4 h; explicit positive timeout gets 15 s grace capped at 30 min; environment overrides exist
- generic MCP manager `callTool`: 10 min
- direct helper request: normally20 s or capture30 s
- helper connection-start retry: approximately4 s

`Qk` derives a child AbortController from tool context and aborts it on timeout. It races execution against the watchdog. However, generic MCP execute accepts only its args and calls `manager.callTool` without forwarding the second context/AbortSignal. A wrapper timeout can return a textual timeout result while the underlying operation continues. The generic timeout message says termination, but that wording is not proof of actual native termination.

`stopGeneration` aborts model generation, clears thread state, marks in-flight tool parts output-error, and kills the tracked Bash-child set with SIGTERM then SIGKILL after3 s. The inspected MCP transport and native-helper client are not registered in that Bash set. No `stopServer`, `stopAll`, helper shutdown, or native cancel call is present in this stop function. MCP clients close during server/application teardown or explicit refresh/stop, not ordinary model stop. Helper request timeout likewise removes pending state without native cancel.

Therefore the proven conclusion is narrower and useful: cancellation intent is not propagated from generic host execution into MCP or the native request through this call chain. Whether an already-enqueued native operation finishes depends on native semantics. Clean implementation must document stop latency and use operation IDs, cancellation acknowledgments and post-cancel state refresh, rather than only marking UI stopped. Evidence 26185–26320, 35710–35731, 83056–83118, Bash registration33636, global teardown88680.

## 7. Model output adaptation, errors and images

MCP output conversion is generic and content-block based. Text becomes model text; MCP image/audio data with MIME becomes model file content with inline data; text/blob embedded resources become text/file; resource links become text references; unknown content blocks JSON-stringify. Empty content falls back to JSON-stringified result. Only a host-created exception sentinel is explicitly converted into error-text.

A resolved MCP result carrying `isError:true` is not tested by this adapter. It follows the same ordinary-content conversion. The wrapper also reaches successful `tool.didExecute` handling for resolved results. This loses the distinction between transport failure and tool-level error unless the model interprets text; recommend preserving the error bit and structured code in a replacement.

The host wrapper’s pre-call vision guard is name-based for screenshot tools and image-file Read. It is not a universal check on any computer-use observation capable of returning an image. The MCP output adapter does not itself gate image blocks by model capability. A separate vision-model fallback preprocessor scans user message images, not every tool result. Provider-specific downstream behavior remains to test.

Two different persistence shapes must not be conflated:

A. Top-level tool output `image_base64`: `qm` recognizes output-available tool/dynamic-tool parts with top-level image_base64 (at least16 characters) or image_cache_file. Host externalizes bytes as `inline-<first16 SHA256>.<mime-derived extension>` in gallery cache, rewrites output to image_cache_file, and can rehydrate before model conversion. Rehydration accepts basename-only cache IDs, avoids traversal, and leaves missing entries unchanged with warning. The memo key for a data URL is length plus prefix/suffix, not its full digest; file identity uses actual full-buffer hash. Memo clears after exceeding256 entries. Gallery serves with one-day HTTP cache headers.

B. MCP `content:[{type:image,data,mimeType}]`: this does not match top-level image_base64 externalization. Generic output compaction preserves image/audio/file binary fields. Storage sanitizers explicitly skip `tool-computer-use__` parts; the generic sanitizer also preserves objects containing MCP image content. Thus the inspected generic image-cache path is NOT evidence all MCP computer screenshots are deduplicated off-message. The native/MCP snapshot cache, if any, is a separate layer.

Storage exempt does not imply unlimited model history: normalization has a10,000,000-character cap and other model-context compaction may still occur. Avoid claiming screenshots are always retained or always dropped.

Evidence main35733–35842 (adapter), 25990–26082 (binary preservation), 19293–19304 (shape detector), 70028–70132 (storage), 71319–71538 (cache), 40244–40320 (user-image fallback), 85340–85383 (rehydration/conversion).

## 8. Appshot subscriptions and preload boundary

Native Appshot event transport is push-capable on the same request/reply connection. Host offers separate listener sets for monitor events, context updates and disconnects. `on...` methods return unsubscribe closures. Appshot monitor_start carries configured hotkey or empty string, frontmost carries exclude_bundle_id, capture receives caller args. Preload exposes only Appshot state, hotkey, capture-now and prewarm calls plus starting/fired/failed/context-update subscriptions, each returning removal closures. This is a narrow IPC façade; direct helper command access is not exposed as a single arbitrary-command preload primitive in this inspected section. Evidence main16450–16499,16609–16638; preload193–213. Appshot UI capture/rearm details are in the mirror/UI report.

## 9. Clean implementation acceptance scenarios

These are original suggested tests, not claims the sample passed them.

1. Concurrent first requests spawn one daemon per install/socket and share one connection attempt.
2. Existing daemon reuse works; stale socket and missing helper fail predictably without duplicate live helper races.
3. Split/combined JSON frames, malformed lines, event whitespace and unknown reply IDs do not corrupt later replies.
4. Disconnect with partial frame clears framing state; reconnect cannot resolve requests from a previous connection epoch.
5. Permission denial, revocation and strict-mode setting are consistently enforced across MCP, REST and direct UI pathways; PID/ref-only targeting cannot silently change enforcement.
6. Stop during an AX mutation reports separately “cancel requested”, “cancel acknowledged”, and final observed state; no background typing after the UI says stopped.
7. MCP `isError:true` survives model conversion as error status; permission/stale-ref errors remain machine-actionable.
8. Nonvision models receive no binary tool image accidentally; image-bearing get_app_state is tested, not only screenshot-named tools.
9. Restart/replay rehydrates cached tool images safely, handles missing files, preserves image MIME/coordinate metadata and uses full content identity.
10. MCP screenshots and top-level screenshots both obey documented disk/history/token budgets.
11. User closure of mirror remains respected while agent activity continues; new explicit user-open succeeds (see mirror state report).
12. Appshot monitor events, updates and disconnects cannot leak into a newly selected thread or invoke removed subscribers.

## 10. Important nuance: model compaction is different from storage preservation

The computer-use storage exemption described above does NOT exempt it from `Qk`'s model-result compactor. Generic MCP names containing `__` default to compact mode unless `_meta['alma/outputSafetyMode']` or a description marker overrides. In the supplied computer-use MCP business area no such marker/metadata was found in a direct literal search; the MCP component report can independently confirm. The MCP compact profile has a2,600-character serialized target, default string limit1,000, and inherited field-specific `text` limit600. Long strings are archived and replaced with head/tail excerpts plus retrieval notices. A scale loop reduces text budgets when the serialized result remains over target, but protected image binary data is never shortened, so the number is a compaction target, not a hard image-size ceiling. Image-bearing results can therefore retain the full image while reducing AX/text context substantially.

This processing occurs before `toModelOutput`. `rawToolResults` bypasses compaction but not generic sanitization; `/api/tools/invoke` explicitly sets it true for PTC inner calls. Thus direct model MCP invocation and PTC invocation can expose different text budgets even when the underlying MCP result is identical. Tests should compare these paths. Evidence main25807–25842 (mode recognition), 25840–25968 (profiles), 25990–26053 (recursive compaction and binary protection), 26312–26332 (mode/scale/raw branch), 79065–79079 (PTC raw context).

### Final route inventory and override verification

`host-http-routes.json` now enumerates all30 static `/api/computer-use` route registrations with individual zero-based UTF-8 byte offsets, methods, defaults, field forwarding, helper calls, timeout/error mapping and activity middleware order. It separately lists helper methods reachable through WebSocket/Appshot IPC but lacking a corresponding HTTP route under this prefix. An entire-file search of the latest bundled MCP entrypoint finds zero instances of both host-recognized compaction override literals (`alma/outputSafetyMode` and `alma-output-safety`). The JSON records the MCP file hash and exact search counts; this replaces the earlier provisional business-area-only observation. Runtime hooks and raw-result invocation contexts remain separate controls.
