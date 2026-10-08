> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/WIRE_SCHEMA.md`；原文件 SHA256 `d9535af11aca24493a51120e1cc4c59c8866485eb095f71d9b9304cbc381f71b`；全文件 1–110 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native newline-JSON wire schema, Alma0.4.164 arm64

A = inspected instruction/control-flow evidence. This is the native socket protocol, not the wrapper's MCP formatting.

## Request (A)

JSON object:

    {"id":"request-1","cmd":"get_app_state","args":{"pid":123,"depth":0}}

`id` and `cmd` are **required String**. Numeric JSON-RPC-style IDs are not accepted by this decoder. `args` is optional [String:AnyCodable]; omitted or JSON null becomes no args; an array/nonobject fails Request decoding. Unknown extra top-level keys are ignored by synthesized keyed decoding. `Request.from` implementation0x100008294: keyed container8338; required String ID8358; required String cmd83bc; args decodeIfPresent844c. Coding keys3854 and8188.

Missing id/cmd, incorrect types, malformed JSON all go through the same processLine decode failure path. It emits ID `?`, not a partially extracted original id.

## Response (A)

Success:

    {"id":"request-1","ok":true,"data":{"...":"command result"}}

Failure:

    {"id":"request-1","ok":false,"error":{"code":"invalid_arg","message":"example"}}

Error with hint:

    {"id":"request-1","ok":false,"error":{"code":"example_code","message":"example","hint":"example hint"}}

These examples specify shape, not dictionary byte order or a specific command's semantic result. Response.encode0x100003bc8 always encodes id String3c80 and ok Bool3cbc; data and error use encodeIfPresent3cf4/3d5c. ErrorPayload.encode0x100003f54 always encodes code400c and message402c, optional hint4080. Error lives under top-level **error object**, not top-level code/message. Failure constructor0x100003a70 stores data Optional.none (type-word sentinel1) and error payload. Success constructor0x1000039cc stores ok=true and absent error; it wraps supplied Any? as AnyCodable, so nil success payload is present `data:null` (its underlying type word0 differs from Optional.none sentinel1).

Malformed input response:

    {"id":"?","ok":false,"error":{"code":"invalid_arg","message":"malformed JSON: <Foundation localizedDescription>"}}

Prefix manually verified0x1000760e4–f8; localizedDescription0x100076114; invalidArg constructor0x1000040b4/4834 has nil hint. Localization/platform-dependent trailing description is not fixed English text and should not be invented.

Encoding-failure emergency fallback is exactly:

    {"ok":false,"error":{"code":"internal","message":"encode failure"}}

Literal address0x100095610, producer0x1000761c4–dc and second error handler0x10007645c onward. **No id** in this exceptional fallback. Socket writer appends LF. JSONEncoder uses withoutEscapingSlashes; there is no inspected sortedKeys/prettyPrinted setting, so key byte order is not a parity promise.

## AnyCodable decoding (A)

Implementation0x100004884 tries, in order:

1. JSON null: value=nil (0x1000048f8)
2. Bool (4934)
3. platform Int / signed64 on arm64 (4968)
4. Double (499c)
5. String (49d0)
6. [AnyCodable], recursively unwrap to [Any?] (4a48 /4b4c onward)
7. [String:AnyCodable], recursively unwrap to [String:Any?] (4acc /4be0 onward)
8. If all attempts fail, value=nil rather than rethrowing the last scalar/container decode error (4adc–4af4)

Null array members survive as nil optional elements. Object null values survive: unwrap's existential type word0 takes dictionary insertion at4d28→4dc0; only sentinel1 (outer optional none) would take removal path. This distinction is important for nested JSON null, unlike SerializedElement optional **omitted** keys.

## AnyCodable encoding (A)

Implementation0x100004f9c uses single-value container:

- value=nil -> encodeNil (5108)
- bridge to ObjC and CFGetTypeID==CFBooleanGetTypeID -> NSNumber.boolValue -> Bool (5034–50c0), preventing Boolean values from becoming numeric1/0
- NSNumber -> inspect objCType; integral codes c,C,s,S,i,I,l,L,q,Q use integerValue/encode Int; others use doubleValue/encode Double (5150–5414)
- then typed cast paths Bool, Int, Int64, UInt32, Double, Float/CGFloat numeric conversion, String
- arrays and String-keyed dictionaries recursively wrap members in AnyCodable then encode
- unsupported residual type -> String(describing:value), encode String (604c–606c), not JSON serialization of arbitrary object internals

For exact cross-language numerical edge behavior retain Swift/Foundation: JSON nonfinite numbers can fail JSONEncoder; integer narrowing may trap in later command parsing. A hardened clone should validate and report errors as a declared deviation. No need to retain Mach-O layouts in an independent implementation, but preserve null vs missing and Bool vs number distinctions.

## Args helper coercions (A, narrowed contract)

Helpers return nil for absent args/key/JSON null. `str`0x100006140 uses String cast (no arbitrary String(describing:) fallback). `int`0x100006268 tries Int, Double converted via truncation toward zero, then signed decimal String parsing. Double conversion includes finite/range checks which trap, not typed CUError, on invalid range. `double`0x10000671c tries Double, Int->Double, then String->Double. `bool`0x1000069a8 tries Bool then Int!=0 (6afc); it does not parse strings 'true'/'false'. Dynamic cast bridging details may accept more NSNumber subtypes in-process; normal native JSON requests get the above AnyCodable types.

## Target precedence and visual clicks (A)

AXBridge.resolveApp0x100019718:

    if pid supplied and NSRunningApplication(pid) exists: return it
    if bundle supplied:
        if runningApplicationsWithBundleIdentifier(bundle) nonempty:
            return first
        if runningApplications has localizedName exactly equal to bundle:
            return first such application
    throw appNotFound(bundle if supplied else 'pid=' + (pid ?? 0))

Both PID and bundle supplied: valid PID wins without cross-validation; invalid PID may fall back to bundle/name. No target does not silently select frontmost: error label pid=0. PID-first0x100019750–778; bundle lookup97b0; first-element9810; localizedName exact equality0x100019994–9d8; error0x100019a60.

Visual click: ref beginning v takes visual cache path, requires resolveActionPid via pid/bundle. Missing target produces invalidArg ('visual refs (v*) require `pid` or `bundle`',0x100079330). Under visualLock look up visualRefs[pid][ref] (0x10007815c/178); absent -> elementNotFound0x100079a38. Get screenshot-pixel center CGRectGetMidX/MidY0x100079a88/aa0, then call translateScreenshotCoord(pid,center)0x100079ab4. Missing mapping -> internalError rather than interpreting pixel coordinates as desktop. Thus v-ref center always depends on current cached mapping for PID, even if visual ref cache was not refreshed with that mapping. Same-PID windows and stale cache mixtures are a real compatibility risk. Physical delivery is handled by the event/ref supplement.

### resolveActionPid is deliberately different (A)

Do not reuse resolveApp semantics indiscriminately. `Daemon.resolveActionPid`0x1000871b0:

    p = args.int('pid')
    if p exists:
        checked convert to Int32  // out of range traps
        if p > 0: return p  // NO NSRunningApplication liveness check
    b = args.str('bundle')
    if b exists:
        app = try? AXBridge.resolveApp(bundle:b,pid:nil)
        if app absent: app = launchWithFrontmostPreserved(bundle:b)
        if app exists: return app.processIdentifier
    return nil

Positive explicit PID wins even if stale or different from bundle (0x100087200–204 to72ac). Nonpositive PID allows bundle fallback. Missing/failed target returns nil; caller decides error or ref-store fallback. AX `e*` ref methods ultimately target Entry.pid and Entry.element independently of the supplied app metadata, as documented by native input report. Visual `v*` refs use resolvedActionPid and require mapping.

Click strategy default and invalid raw both become enum0/auto (0x100078054–074). Valid enum1 is physical (not a string named 'synth'). Invalid/missing mouse button becomes enum0/left at0x100077fac–fd0. Preserve native fallbacks separately from stricter public MCP input schema.

Required strings use requireStr0x100087a50: missing key, null, non-String, **or empty String** throws invalid_arg message `missing "<key>"`. This is stricter than the optional str helper. Out paths, refs, text and other required-string arguments therefore cannot be empty unless a specific command bypasses requireStr. Source confirmation from inspection of0x100087a50; wire test should cover all four missing cases.
