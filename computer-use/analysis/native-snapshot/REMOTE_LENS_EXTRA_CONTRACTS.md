> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/REMOTE_LENS_EXTRA_CONTRACTS.md`；原文件 SHA256 `f5c6cd5ceb762b92d901d0dc1192844ddc9daa6d369acbbc7e82a7853951e4d7`；全文件 1–107 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native remote_input, lens, and shared argument readers

Static arm64 analysis of Alma 0.4.164. All addresses are unslid VAs in the same AlmaComputerUse sample as DISPATCH_INVENTORY.md. No target or replica was run. The contracts below are dispatcher-complete for parsed fields, ordinary defaults, success shapes and dispatcher-authored validation errors. Underlying CGEvent allocation, OS delivery, focus, permission and multi-display behavior remain separate runtime concerns.

## 1. Shared native readers: do not substitute strict JSON schemas

The optional dictionary readers first handle absent args, missing key, JSON null, and failed dynamic casts as nil. A nil optional then follows each command's own fallback/error behavior. Direct socket compatibility therefore differs from a stricter MCP schema.

| Reader | Function | Accepted conversion order and boundary |
|---|---|---|
| str | 0x100006140 | Dynamic cast to Swift String (cast at 0x100006200). No numeric-to-string conversion. Empty string is a valid optional String |
| int | 0x100006268 | Int cast (0x100006328), else Double cast (0x1000063ac), finite/range-checked truncation toward zero via fcvtzs (0x1000063bc–6400), else decimal String parse (0x100006404 onward, fallback parser at 0x1000066f0). Nonconvertible values return nil. Out-of-range/nonfinite Double conversion reaches brk instructions 0x1000066c8/cc/d0 instead of CUError |
| double | 0x10000671c | Double cast (0x1000067dc), else Int cast and numeric conversion (0x10000686c–6888), else String cast and complete locale-independent floating parse (0x1000068b4–6994). Failed conversion returns nil |
| bool | 0x1000069a8 | Bool cast (0x100006a68), else Int cast with zero=false and nonzero=true (0x100006af0–6b00). No string-bool parser is present |
| requireStr | 0x100087a50 | Calls str (0x100087a7c), then rejects both nil and empty string (0x100087a80–7a94). Error factory invalidArg at 0x100087ae8, exact message `missing "<key>"` with straight double quotes |

Dynamic-cast behavior above is established for values produced by this helper's AnyCodable decoder; cross-Foundation NSNumber bridging edge cases should be tested rather than generalized. Whitespace-only strings pass requireStr because it checks length, not trimming. Unknown extra dictionary keys are not read by these handlers.

Numeric values are not always safely rejected: a later checked Int32/UInt32 conversion can trap the process. A safer replica may turn these into validation errors, but that is a documented behavior change, not byte-compatible error handling.

## 2. remote_input complete dispatcher schema

Entry 0x10007dc60. This command routes desktop/display input, separately from app-targeted click/press_key/type_text. The command does not parse bundle, pid, window_id, ref, show_cursor, coord_space, or include_screenshot.

### Common fields

| Field | Reader / required | Default or validation | Evidence |
|---|---|---|---|
| kind | requireStr, required | Exact `pointer`, `scroll`, `key`, `text`; empty/missing/type mismatch: `missing "kind"` | 0x10007dc64–dc74; comparisons 0x10007df00/e2b4/e6d0/ebe4 |
| display_id | int, optional | nil uses CGMainDisplayID; parsed value checked to UInt32, negative/>4294967295 traps. Calls CGDisplayBounds for selected ID; no explicit active-display validation in this function | read 0x10007decc; RemoteControl.display 0x100024a14–4a70 |

Display resolution occurs **before** kind subdispatch, even for key/text and unknown kind. Thus malformed out-of-range display IDs can trap before a kind-validation error.

Unknown nonempty kind produces invalidArg with exact message `unknown remote_input kind "<kind>"` (prefix text VA0x100094c80, assembly0x10007f200–f284).

### kind=pointer

| Field | Reader | Default / rule | Evidence |
|---|---|---|---|
| x, y | double, required | Missing or nonconvertible either yields invalidArg: `remote_input pointer requires x and y (0…1 fractions)` | reads0x10007df1c/df3c; error0x10007df64, bytes0x100094ce0 |
| action | str, optional | nil -> `click`; empty string is not nil and errors. Exact enum values: `move`, `down`, `up`, `click`, `double`, `right`, `middle` | parse/default0x10007e368–e384; enum0x100024b4c→0x100026640; rawValue getter0x100024b50–4bfc |
| button | str, optional | nil -> `left`; valid `left`,`right`,`middle`. **Any unknown string also becomes left**, including empty; no invalidArg at this point | 0x10007e7b0–e7d8, MouseButton raw-value parse0x10001b1f0 |

Unknown pointer action error is invalidArg `unknown pointer action "<action>"` (0x10007e3d0–e42c, prefix bytes0x100094d20). Do not silently coerce an invalid action merely because invalid button is coerced.

Coordinates are fractions of the chosen display's CGDisplayBounds. RemoteControl.point at0x100024a74–4b48 clamps finite x/y independently into[0,1], then computes:

    screenX = CGRectGetMinX(bounds) + clamp(x,0,1) * CGRectGetWidth(bounds)
    screenY = CGRectGetMinY(bounds) + clamp(y,0,1) * CGRectGetHeight(bounds)

This uses display origins and full width/height, not width−1/height−1, not screenshot scaling, not a y-flip. NaN/infinity spellings accepted by low-level floating conversion were not run; do not infer finite-validation guarantees from the clamp.

Endpoint: RemoteControl.pointer(action:at:button:) at0x100024eb8, called0x10007e7f8. `right`/`middle` are distinct action enum values in addition to the button field. Persistent down/up/move behavior belongs to that endpoint and must not be rewritten as independent click calls.

### kind=scroll

| Field | Reader | Default / rule | Evidence |
|---|---|---|---|
| x, y | double, required | Same display-fraction clamp; error exact `remote_input scroll requires x and y (0…1 fractions)` |0x10007e2d0/e2f0; invalidArg0x10007e318, bytes0x100094ca0 |
| dx, dy | double, optional | Each independently defaults0 |0x10007e738/e75c; selects0 at0x10007e748–e76c |

Endpoint0x100025b14, called0x10007e780. It rounds each delta to nearest integer with ties away from zero (`frinta` at0x100025bcc and0x100025c08), checks Int32 representability, then passes dy as first wheel and dx as second wheel to CGEventCreateScrollWheelEvent2 (unit raw0, wheelCount2;0x100025c40–5c58). Nonfinite or out-of-range rounded values reach trap instructions0x100025db0–5dc4. It sets the event location, integer field0x58=1, synthetic sentinel field0x2a, then CGEventPost tap raw0. The OS meaning and delivery must be tested; no app PID is supplied in this route.

### kind=key and kind=text

- `kind=key` requires nonempty String `key` (0x10007e6e0–e6f4). Calls RemoteControl.key at0x100025dc8 (call0x10007e708), which uses KeyParser.parse at0x100025de0 and emits a global down/up pair with parsed flags and synthetic sentinel. Key-parser errors propagate; its exact key grammar is covered by the native key contract.
- `kind=text` requires nonempty String `text` (0x10007ebf4–ec08). Calls RemoteControl.text at0x100025fd4 (call0x10007ec1c). It first tries KeyboardLayoutTranslator.keyPresses; on translation failure it falls back to Unicode scalar chunks. It does not share the `type_text` command's ref/input_method/verification result contract.
- x/y/action/button/dx/dy are not read by these two kind branches. display_id still influences the returned display metadata.

### Success result and errors

All four kinds converge on **the same data object**, before the transport wraps it:

    { "ok": true, "display": { "id": <UInt32 as integer>, "width": <Int>, "height": <Int> } }

Construction0x10007ec30–ede8. `id` comes from resolved display0x10007eccc; width/height come from CGRect width/height, truncated toward zero with checked Int conversion0x10007ed0c–edb4. Dimensions describe CG display bounds; they are not screenshot pixel dimensions and do not include bounds origin.

The inner `ok:true` is **in addition to** the ordinary socket response envelope's `ok`. There is no screenshot, action echo, coordinate echo, pressed state or `delivered` field in this command's success data.

Underlying CGEvent errors propagate. Examples directly verified in endpoint code include internalError `CGEventSource creation failed`, `CGEvent creation failed (move)`, `CGEvent creation failed (scroll)`, `CGEvent creation failed (key)` (factories0x1000267b0,0x100025ccc/5d2c,0x100025ef0/5f54). Success means construction/posting returned without a thrown error, not that an application acknowledged the input.

## 3. lens complete dispatcher schema

Entry0x10007beec. Both fields use optional bool reader semantics from§1:

| Field | Missing/nonconvertible | Supplied parsed value | Evidence |
|---|---|---|---|
| enabled | Leave current state unchanged | LensOverlay.setEnabled(value), called0x10007bf34 | parse0x10007bf08; optional sentinel check0x10007bf10–14 |
| fog | Leave current state unchanged | Call LensOverlay.setFogEnabled(value) | parse0x10007bf5c; call0x10007bf88 |

**In this build the fog setter is a no-op**: its symbol aliases the shared function body0x100009a9c, which consists of `ret`. `isFogEnabled` resolves to shared false-return body0x10000a7b4 (call0x10007c004). Therefore result `fog` is always false in this inspected binary, even after `{"fog":true}`. Do not implement a visible fog effect and label it observed compatibility.

Success data is always:

    { "enabled": <current Bool>, "fog": false }

Dictionary assembly0x10007bfc0–c020. No success inner `ok` key, screenshot or settings persistence is added in this path. No dispatcher-authored errors are present. With no args it is a status query. Singleton initial enabled=false, but CLI --lens can set it true before serving.

`setEnabled(false)` hides desktop Lens immediately; it does not by itself clear ActionCursor or disable other input. Native overlay lifecycle, independent ActionCursor state and native-vs-Electron cursor mapping are documented in `analysis/mirror-ui/native-cursor-contract.md`.

## 4. Scope and coverage ledger

Closed statically: remote_input/lens field spellings, native reader behavior, default selection, branch enum, dispatcher errors, data shapes, remote display selection and finite-coordinate mapping. No runtime verification performed.

Remaining endpoint work: full seven-action RemoteControl.pointer transition sequencing, all text fallback timing/chunk edge cases, OS/TCC delivery, hardware pointer/focus effects, and cross-client persistent drag state. Reuse the native input specialist's endpoint supplement when available; do not treat this dispatcher-level document as proof of background/no-focus safety.

Native MCPServer HTTP/auth/whitelist semantics and open_url/intent app-command mapping are not covered by this file. See their own contract status before claiming all45cmd implementation parity.
