> 来源：用户提供的 .164 研究资料 `analysis/native/FINDINGS.md`；原文件 SHA256 `0f6cfe92c03dfa134db77371bc3f7e24df9b0866f5b0db9d38c8fb80d4ffe612`；全文件 1–144 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Alma Computer Use 0.4.164: native static findings

Status: static control/input pass completed; snapshot/daemon companion provides additional command details. No app or extracted code was executed. This report describes behavioral contracts, not reconstructed proprietary source.

## Sample and evidence conventions

- Target: `extracted/Alma.app/Contents/Resources/Alma Computer Use.app/Contents/MacOS/AlmaComputerUse`
- Universal Mach-O: x86_64 and arm64. All addresses below are **arm64 unslid virtual addresses** from this exact 0.4.164 sample, not 0.4.153.
- ARM64 metadata contains 5,529 symbols and 489 import stubs. Extensive Swift names survive.
- `arm64.json` gives sections, symbols, dylibs, import stubs, and universal-file slice offset. For an address in a section: slice file offset = section.offset + address − section.address; universal offset additionally adds fat_offset.
- `calls.json`, `function-call-catalog.txt`, and `arm64-disasm.txt` supply address-level corroboration. The call catalog can attribute merged compiler aliases to the first alias; consult all symbols at a shared address before inferring semantics.
- Confidence: **A** = instructions/branches/calls inspected; **B** = symbol or schema evidence; **C** = inference requiring runtime verification.
- Important analyzer limitation: string comments are convenience annotations from a lightweight ADRP/ADD tracker, not full dataflow. Some stale-register annotations can be false. Only manually checked literals are relied upon here.

## 1. ElementStore: persistent identity, snapshot generations, recovery

### Stored state (B from symbols; A from access layouts)

Entry contains AX element, snapshotId, pid, optional ElementDescriptor, invalidated flag. Descriptor fields are role, optional subrole/title/identifier/roleDescription, and parentRoles. Store contains table, monotonic counter, lock, observers keyed by PID, currentSnapshotRefs.

### beginSnapshot (A, 0x10000a898)

1. Lock.
2. Clear only currentSnapshotRefs, **not the whole entry table**.
3. Iterate existing table. Read AXRole on each retained AX object (call0x10000aabc); prune entries whose error is −25202/kAXErrorInvalidUIElement (comparison0x10000aacc–aad4).
4. Build snapshot identifier from current formatted date, remove colons, prefix `s_` (0x10000ac54–ad38).
5. Unlock.

Consequences: taking another snapshot does not inherently invalidate all old refs. A shallow snapshot can affect current-generation reuse and table cleanup while old refs remain.

### register (A, 0x10000ad9c)

- Searches retained entries for same PID and CFEqual(existing.element,new.element), call0x10000af2c.
- Existing matching refs already used within this snapshot are excluded (currentSnapshotRefs membership).
- Otherwise reuse the matching unused ref; failing that increment counter and construct `e` + decimal counter (0x10000b004–b048).
- Creates per-PID AXObserver on demand (0x10000b210), attaches source to **main** CFRunLoop (0x10000b234–b26c), subscribes element destruction notification (0x10000b2fc).
- Adds returned ref to currentSnapshotRefs.

### refetchByDescriptor (A, 0x10000bb3c)

- Starts at AXUIElementCreateApplication(cached PID) (0x10000bca8).
- Uses explicit LIFO stack of (element, depth, ancestor-role list): pops last entry (0x10000bd8c–bda4), pushes children.
- Limits visited nodes to200 (0x10000bdb0), depth expansion stops at12 (0x10000c358).
- Compares role and optional descriptor subrole/title/identifier/roleDescription (read calls0x10000bdd0/bea4/bf70/bfe0/c100).
- Compares up to last3 ancestor roles (0x10000c180–c2bc).
- Collects candidates; stops early after >1 match (0x10000c340–c34c).
- Accepts **exactly one** matching candidate (0x10000c870), replaces cached element under same ref/PID/descriptor/snapshot and resets invalidated=false (0x10000c8ec; table write0x10000c9b4).
- Zero or ambiguous candidates return nil. This is bounded structural identity recovery, not image/OCR matching.
- AXBridge.resolveRef calls this on two stale paths (0x100019ed8 and0x100019fa8).

### Observer cleanup

ElementStore.clear0x10000cb64 iterates observers and removes sources from main runloop (0x10000cca4). Destroy callback mutation is closed in ALGORITHMS.zh-CN.md section2.3: matching retained entries are marked invalidated=true, not deleted immediately.

## 2. Ref target precedence is independent of supplied app metadata

**A:** AXBridge.click(ref,store,strategy,button,count,showCursor) has no external PID/window argument. It resolves Entry at0x100013f6c. AX action uses Entry.element (0x1000141dc). Synthetic fallback reads Entry.pid from entry+0x18 (sp+0x60 at0x100014364) and passes it to EventDispatch.click at0x100014388. Geometry comes from the resolved element's live AXPosition/AXSize and center computation0x10001400c/14024.

Secondary action likewise resolves ref at0x100014654, performs AX action on that element, or routes cached PID to EventDispatch.secondaryClick0x100014804.

Thus wrapper approval/post-shot target metadata can disagree with actual ref target unless wrapper validates it; no such external identity is even available to these native AXBridge ref methods.

## 3. AppStateDiff

**A:** key(pid,windowId)0x10002a56c yields decimalPID + `:` + decimalWindowID, or `-` when absent. Cache is therefore PID/window-scoped.

apply(elements,key,disabled)0x10002a63c:

- Builds ref→fingerprint from elements with a string `ref`.
- Fingerprint fields, in fixed order: role, subrole, title, value, description, role_description, enabled, focused, children_count, actions. Static array0x1000aff10–0x1000affa0.
- Present values rendered as `key=value` through Swift textual formatting. Fields joined using `|` (0x10002ac24).
- Bounds separately fingerprints x,y,w,h; floating bounds round to nearest integer (`frinta`0x10002ab10, integer conversion0x10002ab50), comma-joined and appended as bounds text.
- If disabled or no prior cache, returns complete input elements, no removed refs, zero unchanged, isDiff=false; **still updates baseline**.
- Else preserves input order for added/changed elements, counts equal fingerprints as unchanged, computes old refs absent from new ref map, sorts removed refs (sort call0x10002b498), updates baseline, sets isDiff=true.
- Daemon.snapToDictDiffed calls apply0x100088658 and emits `elements_are_diff`, `unchanged_element_count`, and nonempty `removed_refs` (0x100088734 onward).

Consequence: consumer must apply deltas to the correct PID/window baseline; disabled snapshots are baseline resets, not bypasses of state. Subpixel movement that rounds to same integer does not change bounds fingerprint. Fields outside fixed list do not independently trigger a delta.

## 4. Keyboard delivery and foreground predicate

### hasKeyWindow exact Boolean (A, 0x10002d6b0)

Return true iff AXFocusedWindow copy succeeds, its value is nonnull, and NSRunningApplication(pid)?.isActive is true (0x10002d718–d760). Name does not mean merely the existence of a retained focused AX window.

### pressKey (A, 0x1000203c4)

After parsing and establishing focus protection:

1. Evaluate hasKeyWindow(pid) at0x100020744.
2. If false, independently read target NSRunningApplication.isActive at0x10002077c.
3. If either check true, create paired keyboard down/up events; flags are applied to both. Mark both with synthetic sentinel. Dispatch each through dynamically resolved per-PID post function (indirect calls0x10002086c/20888).
4. A second hasKeyWindow evaluation0x1000207a4 contributes to KeyDelivery result.
5. If target is neither key-window-confirmed nor active, enumerate menu shortcuts (0x1000208e8). Skip disabled shortcuts. Parse matching key code and modifier bits masked0x1e0000 (0x100020990–209b0). On match perform AXPress (0x100020a08).

Stable-state simplification: `(AXFocusedWindowExists && active) || active` = `active`; actual code takes sequential observations and can race, so preserve original tests in faithful behavior descriptions.

This does not establish arbitrary background keyboard reliability. It demonstrates deliberate background menu-action fallback.

## 5. Focus-steal interception (A)

FocusStealPreventer.begin0x100027f78 installs CGEventTap (0x100027fa4), attaches source, enables it. Failure updates health counters/logs rather than magically guaranteeing focus safety.

Callback specialized implementation0x100029a10 region:

- Re-enables tap on disable notifications.
- Reads CGEvent integer field42 (eventSourceUserData) and lets own sentinel0x414c4d414e4f464c pass (0x100029b80–29ba0).
- Converts CGEvent to NSEvent; considers type13, or type14 with subtype8 (0x100029bc8–29be8).
- Treats NSEvent.data1 as target PID; drops event (returns null) when shouldDrop(pid) is true (0x100029bf0–29c08).
- State includes disallowed PIDs, optional only-allow PID, and temporary activation allowances.

Private behavior and OS/app compatibility require runtime verification. Static presence of this defensive layer is not proof of perfect background isolation.

## 6. Screenshot mapping and OCR

### Coordinate cache (A)

Daemon.lastMapping type is `[Int32: ScreenshotMapping]` (PID-keyed, **not PID/window keyed**). translateScreenshotCoord0x100082890 locks, looks up PID, and computes:

- desktopX = capturedOriginX + screenshotX * capturedPointWidth / screenshotPixelWidth
- desktopY = capturedOriginY + screenshotY * capturedPointHeight / screenshotPixelHeight

Arithmetic0x10008292c–82940. No bounds clamp or recency validation in this function. Missing cache returns nil. Mapping struct also stores window information; the latest snapshot supplement establishes that no independent TTL/window-close/app-exit invalidation was found in inspected xrefs; runtime stale-cache effects remain untested.

### OCR is real reachable fallback, not only linked classes (A)

Daemon.dispatch directly calls VisualIndex.index(imagePath,maxResults) at0x1000790e0, maxResults80. Branch preceding call checks raw SnapshotResult.elements count<=1 (proven in native-snapshot/FINDINGS.md section6); this is internal snapshot fallback rather than a public MCP OCR tool.

VisualIndex.index0x1000337c4 loads image from disk, constructs VNRecognizeTextRequest, sets recognitionLevel1, language correction false, recognition languages `en-US` and `zh-Hans` (static array0x1000b0518), then performs Vision requests at0x100033a30. Output Region has ref,text,bounds,confidence.

## Open verification work

- Shallow-state/diff and raw-elements OCR threshold are now statically closed in the snapshot supplement; remaining concerns are interleaved runtime effects.
- Per-PID app-exit observer lifetime beyond clear/deinit remains runtime verification; destruction marks invalidated without deleting.
- Pointer fields/window-local routing are specified in ALGORITHMS.zh-CN.md; actual private-SPI behavior across OS/app versions remains unverified.
- Unicode scalar chunking/layout translation are specified in ALGORITHMS.zh-CN.md; interruption release/cleanup remains a runtime gate.
- Native receive/dispatch/teardown and idle branches are statically closed in the snapshot supplement; asynchronous OS side effects remain runtime-dependent.
- Runtime-only: TCC identity/trust, private SPI reliability across macOS versions, menu/AX app differences, race conditions and refetch ambiguity under real UI changes.


## Addendum: finalized control specification

`ALGORITHMS.zh-CN.md` is the detailed independent implementation specification and supersedes shorthand in this initial findings log. `native-contract.json`, `native-test-plan.json`, and `keycode-contract.json` are user-deliverable behavioral data, not original source dumps.

Corrections/precisions: ClickStrategy raw1 is `physical`, not `synth`; environment flag `ALMA_CU_FORCE_SYNTH` is separate. Wire codes use `internal`, `invalid_arg`, `ax_not_granted`, `sc_not_granted`. set_value and select_text, exact AX error mapping, C ABI and TypeVerification are detailed in sections10–12. CGEventPostToPid dlsym failure is fatal; CGEventSetWindowLocation failure is no-op. TypeVerification only detects value change. Per-peer socket processing is synchronous but peers execute concurrently. Direct native `snap` uses plain serialization without diff. MCP post-action is instead `get_app_state(depth=0,include_screenshot=true)`, so it touches ElementStore AND the get_app_state diff baseline. The two paths must not be conflated.
