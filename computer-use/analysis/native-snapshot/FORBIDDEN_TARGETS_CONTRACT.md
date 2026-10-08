> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/FORBIDDEN_TARGETS_CONTRACT.md`；原文件 SHA256 `e0d81bc189ef6b8d61a8b6ad9e180b305286efa6868ee190ea5e2d4acb3f114f`；全文件 1–100 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# ForbiddenTargets policy: static closure

Sample0.4.164 arm64, no target execution and no live user data read. All claims A: instruction branches and literal data inspected. This records original behavior, not authorization to override safety controls in any assistant or deployment.

## Exact deny predicate

`ForbiddenTargets.isForbidden(bundleId:)`0x100032250 returns false for nil; otherwise Swift Set<String>.contains against a static18-entry set. There is no lowercasing, prefix/wildcard matching, executable-path check, signing team check, localized app-name match, or semantic app-category classifier in this predicate.

Set initializer0x100032050 allocates18 capacity (0x100032088), reads18 Swift string pairs beginning0x1000b03e0 (base0x1000b03b8+0x28, read0x1000320c8), loops exactly18 (0x1000320bc), and stores set0x1000b1f90. Exact case-preserving strings:

1. com.apple.systempreferences
2. com.apple.security.pluginkit
3. com.apple.security-notification
4. com.apple.preference.general
5. com.apple.loginwindow
6. com.apple.SecurityAgent
7. com.apple.PassphraseAgent
8. com.apple.PasswordBreachAgent
9. com.apple.tccd
10. com.apple.universalaccessAuthWarn
11. com.apple.WindowServer
12. com.apple.dock
13. com.apple.launchpad
14. com.apple.notificationcenterui
15. com.apple.controlcenter
16. com.apple.spotlight
17. com.apple.ScreenSaver.Engine
18. com.apple.ScreenSaverEngine

`forbidden-bundle-constants.json` records each slot VA, raw64-bit string words and backing-text VA. Most use Mach-O chained pointer encodings and Swift long strings; they are **not raw runtime pointers**. In this sample their resolved backing text spans0x100092fc0–0x1000931b0. Two are small Swift strings: com.apple.tccd at0x1000b0460 and com.apple.dock at0x1000b0490. The first word includes Swift representation flags; its low length bits specify the literal length. The extracted bytes were directly checked against mapped Mach-O sections. Use exact listed bytes, not similar current Apple app names.

## PID check algorithm

`check(pid:allowOverride:)`0x1000322bc:

    if allowOverride: return
    if pid absent: return
    app = NSRunningApplication(processIdentifier:pid)
    if app absent: return
    bundle = app.bundleIdentifier
    if bundle absent: return
    if bundle not in forbidden set: return
    throw CUError(
        code: "forbidden_target",
        message: "target app " + bundle + " is on the CUA blocklist for user-safety reasons",
        hint: <semantic description: explicit force_forbidden override is mentioned for genuinely required system-privacy workflows; long UI wording is paraphrased, not a byte-exact fixture>
    )

Shortcircuits0x1000322d8/2ec/30c/320; exact membership0x10003235c; CUError construction0x100032418. Error code literal0x100092e60; suffix0x100092e80; long hint0x100092ec0. Missing/unresolvable app is a pass for **this gate**, not proof that later action succeeds.

## Bundle check algorithm

`check(bundleId:allowOverride:)`0x10003249c:

    if allowOverride or bundle absent or bundle not in set: return
    throw CUError(
        code: "forbidden_target",
        message: "target bundle " + bundle + " is on the CUA blocklist for user-safety reasons",
        hint: "Pass `force_forbidden: true` to override."
    )

Shortcircuits0x1000324b0/4b8/4ec; CUError construction0x1000325ac; short hint0x100092f90. This variant does not resolve running applications; an exact forbidden bundle is rejected even if not running.

## Dispatcher integration and exact coverage

Only direct calls to these check functions in the inspected disassembly are dispatcher0x100076968 (PID) and0x1000769c0 (bundle). That establishes this source-level gate's reachable call sites, not the absence of OS/host/plugin policy elsewhere.

PID-gated commands:

    click, perform_secondary_action, drag,
    type, type_text, press, press_key, scroll, set_value

Bundle-gated commands:

    intent, open_url

Static sets proof in DISPATCH_INVENTORY.md; key data/control0x100076708–67f0. `force_forbidden` read through bool helper0x100076924; absent/null/noncoercible -> optional tag2, then low bit0=>false. Bool true or nonzero Int=>true; string "true" is not accepted by helper. Wrapper/public schemas may not expose this field; do not add it to MCP tools on the strength of native availability alone.

For the action set:

    actionPID = resolveActionPid(args)  // see WIRE_SCHEMA
    check(pid:actionPID, allowOverride:args.bool("force_forbidden") ?? false)

Proof0x10007695c–968. It does not resolve the AX element ref to discover Entry.pid before checking. Consequently a ref-only action may pass nil-PID preflight and later resolve an e-ref's cached owner in AXBridge. A supplied PID can also differ from ref owner. This is an original coverage limitation; use a stronger final-resolved-target gate in a safer clone and mark that as an intentional deviation, rather than falsely documenting original protection as comprehensive.

`select_text`, `launch_app`, `raise`, `remote_input`, all snapshot/capture/list commands and native administrative/PIP/Appshot commands are not members of these two dispatcher sets. In particular list_apps does not filter out forbidden apps through this gate; snapshotting/listing may still describe them. No original all-actions blockade should be inferred.

## Conformance examples (use synthetic identities, no system interaction)

- exact com.apple.SecurityAgent -> true; lowercased com.apple.securityagent -> false
- exact com.apple.dock -> true; com.apple.dock.extra -> false
- nil bundle -> false; unknown bundle -> false
- PID resolving to a listed bundle -> forbidden_target with `target app` message + long hint
- direct listed bundle -> forbidden_target with `target bundle` message + short hint
- unresolvable PID -> this check returns; later action may separately fail
- original override false/nil -> normal gate; true/nonzeroInt -> gate returns
- ref-only click: preflight nil PID, no ref-owner lookup at this stage
- select_text and remote_input do not enter this dispatcher gate

No static unknown remains in this exact set/predicate/error/dispatcher contract. Remaining acceptance testing concerns OS bundle identity, other security layers and target ref mismatch behavior, not missing policy constants.
