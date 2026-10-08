> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/DISPATCH_INVENTORY.md`；原文件 SHA256 `1ae2a4684fa565f66b83cd5e11fcad2e0434115a3a92a54c3324fcee6f65cd30`；全文件 1–150 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native Daemon.dispatch command inventory — Alma 0.4.164

## Result and provenance

The inspected arm64 `Daemon.dispatch(_:ctx:)` at **0x1000764e8** contains **45 top-level `cmd` literals**, not 23. Its 52 Swift string-comparison calls divide into 45 top-level command comparisons, four `remote_input.kind` comparisons, and three `type_text` method comparisons. The top-level all-mismatch chain ends at **0x10007f72c**, which constructs `CUError.invalidArg("unknown cmd: " + cmd)`; error construction is at 0x10007f790.

Source binary: `extracted/Alma.app/Contents/Resources/Alma Computer Use.app/Contents/MacOS/AlmaComputerUse`; all VAs are unslid arm64 addresses for this sample. The target was never executed. Input artifacts were `analysis/native/arm64-disasm.txt`, `arm64.json`, `arm64.macho`, and symbol/call metadata. Byte literals were decoded from MOV/MOVK/add/ORR register construction, or mapped into the Mach-O bytes using section address/offset metadata. Convenience disassembly string comments were not treated as proof.

`dispatch-inventory.json` gives each command's two complete Swift string words, compare-call VA, success entry and next mismatch block. `trace_dispatch_failpath.py` independently walks the top-level mismatch control flow and reconstructs all 45 literals. It is a newly authored data-only parser, not target execution. Its one seeded spill value (x19+0x18) is established at 0x100076710–6730 from cstring VA 0x100094b40. `dispatch.asm` is the full local function extract. `dispatch-reachable-calls.json` is an intraprocedural static reachability aid, not a proof that every conditional call occurs at runtime.

The “MCP23” column below means a distinct command directly reachable through one of the 23 JavaScript MCP adapter tool registrations catalogued in `analysis/mcp/REPORT.zh-CN.md`. Those 23 registrations map to **13 distinct native command strings**. The other **32 native commands are not separate tools in that adapter**; some are used by host/helper plumbing or native UI features. This is not an assertion that the native MCPServer exposes the same tool list.

## Complete top-level command list

“Compare” is the call to Swift `_stringCompareWithSmolCheck` at target 0x10008bd04; preceding fast word comparisons reach the same success entry. Handler code is interleaved, so adjacent command entry addresses are not handler end boundaries.

| # | Exact cmd | Compare VA | Success entry | MCP23 | Verified handler role / evidence |
|---:|---|---|---|:---:|---|
| 1 | `ping` | `0x100076a1c` | `0x100076a24` | no | Health result: pong=true, helper version 0.1.0, uptime_s (system uptime, not daemon elapsed time) |
| 2 | `permissions` | `0x100076bb8` | `0x100076bc0` | yes | AX trust, screen-capture permission, focus-guard armed/failure state; calls 0x100076bcc, 0x100076c38, 0x100076c6c |
| 3 | `grant` | `0x100076d8c` | `0x100076d94` | yes | Prompting AX trust check, isTrusted(prompt:true) at 0x100076d9c |
| 4 | `apps` | `0x100076e70` | `0x100076e78` | no | Current running app enumeration, AXBridge.runningApps at 0x100076e78 |
| 5 | `list_apps` | `0x100076f84` | `0x100076f8c` | yes | Usage-informed list, AppUsage.listApps(days:) at 0x100076fb8; days defaults 14 |
| 6 | `windows` | `0x10007703c` | `0x100077044` | no | Resolve app then AXBridge.windows at 0x1000770d0 / 0x1000770f0 |
| 7 | `snap` | `0x1000771e4` | `0x1000771ec` | no | Plain snapshot at 0x10007735c; plain snapToDict at 0x100077380; not diffed get_app_state |
| 8 | `launch_app` | `0x1000773f4` | `0x1000773fc` | yes | Require bundle then async launch; runAsync at 0x100077594 |
| 9 | `open_url` | `0x1000775f4` | `0x1000775fc` | no | AppCommandRegistry.openQuietly(url:preferredBundleId:) at 0x100077a24 |
| 10 | `intent` | `0x100077888` | `0x100077890` | no | AppCommandRegistry.dispatch(bundleId:intent:params:) at 0x100077c4c |
| 11 | `get_app_state` | `0x100077ad8` | `0x100077ae0` | yes | Snapshot + diff + menu shortcuts + optional capture/OCR; 0x10007883c / 0x100078c84 / 0x100078c98 / 0x100078e84 / 0x1000790e0 |
| 12 | `click` | `0x100077f78` | `0x100077f80` | yes | Reference or point paths; AXBridge.click at 0x100079890; clickAtPoint at 0x100078a58 / 0x100079ca4 |
| 13 | `type` | `0x10007847c` | `0x100078484` | no | Reference-oriented AXBridge.type(ref:text:replace:store:showCursor:) at 0x100079e54 |
| 14 | `type_text` | `0x1000792e0` | `0x1000792e8` | yes | Input-method/ref routing; AXBridge.type 0x10007a1b4, Unicode 0x10007a7e0, physical 0x10007a97c, general text 0x10007aac0; verification 0x10007b100 |
| 15 | `press` | `0x1000799b4` | `0x1000799bc` | no | Reference-oriented AXBridge.press(ref:key:store:showCursor:) at 0x10007a4f4 |
| 16 | `press_key` | `0x100079f90` | `0x100079f98` | yes | EventDispatch.pressKey at 0x10007a024, preserves delivery kind |
| 17 | `perform_secondary_action` | `0x10007a2dc` | `0x10007a2e4` | yes | Reference secondary action at 0x10007b4f0 or point click at 0x10007abb8 |
| 18 | `drag` | `0x10007a844` | `0x10007a84c` | yes | AXBridge.drag(from:to:pid:button:showCursor:) at 0x10007b838 |
| 19 | `set_value` | `0x10007ae48` | `0x10007ae50` | yes | AXBridge.setValue(ref:value:store:) at 0x10007ba90 |
| 20 | `select_text` | `0x10007b650` | `0x10007b658` | yes | AXBridge.selectText(ref:text:prefix:suffix:selectionType:store:) at 0x10007c25c |
| 21 | `scroll` | `0x10007b9d4` | `0x10007b9dc` | yes | Reference-oriented AXBridge.scroll at 0x10007c538 |
| 22 | `lens` | `0x10007bee4` | `0x10007beec` | no | Optional enabled/fog settings then status; setEnabled 0x10007bf34; fog setter symbol resolves to shared no-op body 0x100009a9c at call 0x10007bf88 |
| 23 | `pip_open` | `0x10007c424` | `0x10007c42c` | no | Resolve window + PIPManager.open(windowId:pid:title:preferredSize:) at 0x10007c7f4 |
| 24 | `pip_close` | `0x10007c704` | `0x10007c70c` | no | PIPManager.closeAll 0x10007c740 or close(windowId:) 0x10007cae4 |
| 25 | `pip_status` | `0x10007c9e0` | `0x10007c9e8` | no | PIPManager.statusList 0x10007ca3c + PIPMinimizeArmer.statusList 0x10007ca74 |
| 26 | `pip_arm` | `0x10007cbc0` | `0x10007cbc8` | no | PIPMinimizeArmer.arm(windowId:pid:title:) at 0x10007cf10 |
| 27 | `pip_disarm` | `0x10007cc88` | `0x10007cc90` | no | PIPMinimizeArmer.disarmAll 0x10007ccd4 or disarm(windowId:) 0x10007cff0 |
| 28 | `mcp_start` | `0x10007cdd0` | `0x10007cdd8` | no | MCPServer.start(daemon:port:tokenFilePath:) at 0x10007ce54 |
| 29 | `mcp_stop` | `0x10007cf74` | `0x10007cf7c` | no | MCPServer.stop at 0x10007cf8c |
| 30 | `mcp_status` | `0x10007d174` | `0x10007d17c` | no | MCPServer.statusSnapshot at 0x10007d18c |
| 31 | `mcp_allow` | `0x10007d1e0` | `0x10007d1e8` | no | MCPServer.addWhitelist(teamId:bundleId:pid:ttlSeconds:) at 0x10007d4e8 |
| 32 | `mcp_deny_all` | `0x10007d2a4` | `0x10007d2ac` | no | MCPServer.clearWhitelist at 0x10007d2bc |
| 33 | `mcp_whitelist` | `0x10007d404` | `0x10007d40c` | no | MCPServer.whitelistList at 0x10007d464, wrapped in entries |
| 34 | `mcp_arm_peer` | `0x10007d5ac` | `0x10007d5b4` | no | PID path to MCPServer.addWhitelist at 0x10007d788; not an alias of mcp_start |
| 35 | `raise` | `0x10007d6a4` | `0x10007d6ac` | no | AXBridge.raise(bundle:pid:windowId:) at 0x10007db80 |
| 36 | `shot` | `0x10007d8c4` | `0x10007d8cc` | no | Window capture via runAsync at 0x10007e508; cursor normalization 0x10007e95c |
| 37 | `shot_display` | `0x10007da78` | `0x10007da80` | no | Display capture via runAsync at 0x10007dd18; cursor normalization 0x10007e06c |
| 38 | `remote_input` | `0x10007dc58` | `0x10007dc60` | no | Required kind field, then display resolution and pointer/scroll/key/text subdispatch |
| 39 | `stealth_stats` | `0x10007ddb8` | `0x10007ddc0` | no | VictimObserver.stats at 0x10007ddf0; optional resetStats at 0x10007ddfc |
| 40 | `turn_ended` | `0x10007e1a0` | `0x10007e1a8` | no | FocusStealPreventer.releaseAll at 0x10007e1b4 |
| 41 | `shutdown` | `0x10007e554` | `0x10007e55c` | no | Queues shutdown work and returns a shutting_down result; entry 0x10007e55c |
| 42 | `appshot_monitor_start` | `0x10007ea84` | `0x10007ea8c` | no | Connection subscriptions + BareModifierMonitor.start; subscribe 0x10007f020 / 0x10007f0e8, start 0x10007f158 |
| 43 | `appshot_monitor_stop` | `0x10007ee24` | `0x10007ee2c` | no | Connection subscription cleanup 0x10007ee8c; subscriber-count check 0x10007eef0; monitor stop 0x10007ef14 |
| 44 | `appshot_frontmost` | `0x10007f314` | `0x10007f31c` | no | Appshot.frontmostWindow(excludeBundleId:) at 0x10007f354, toDict 0x10007f5b0 |
| 45 | `appshot_capture` | `0x10007f4d0` | `0x10007f4d8` | no | Async Appshot.capture result; runAsync 0x10007f978; toDict 0x10007f9d8 |

## Do not conflate these names

- **`snap` is the native command**, not `snapshot`. At 0x1000771cc–71d4 the literal words are 0x0000000070616e73 and 0xe400000000000000, which decode to `snap`. It calls the Swift function named `AXBridge.snapshot` and then plain `snapToDict`. A function symbol is not a command alias.
- `apps` lists running applications; `list_apps` invokes the usage-oriented list and defaults `days` to 14 (0x100076fb0–fb8). They are distinct branches.
- `type` and `press` are reference-oriented paths; `type_text` and `press_key` are distinct paths, not spelling aliases.
- `shot` and `shot_display` are distinct window/display capture paths. Neither name means `get_app_state`.
- `pip_*`, `mcp_*`, `appshot_*` are actual socket commands. Their presence does not prove registration in the JavaScript MCP23 tool surface.
- Top-level exact names `snapshot`, `pointer`, `key`, `text`, `stealth`, `appshot.monitor`, `mcp`, or `pip` do not appear in this dispatch chain. The result is scoped to this function/sample; it does not exclude commands on other protocols.

## Nested string dispatch and exact literals

`remote_input` requires `args.kind` at 0x10007dc64–dc74, then resolves a display using optional `display_id` at 0x10007deb4–ded4. The four kind comparisons are:

| args.kind | Compare VA | Success entry | Endpoint call |
|---|---|---|---|
| `pointer` | 0x10007df00 | 0x10007df08 | RemoteControl.pointer at 0x10007e7f8 |
| `scroll` | 0x10007e2b4 | 0x10007e2bc | RemoteControl.scroll at 0x10007e780 |
| `key` | 0x10007e6d0 | 0x10007e6d8 | RemoteControl.key at 0x10007e708 |
| `text` | 0x10007ebe4 | 0x10007ebec | RemoteControl.text at 0x10007ec1c |

There is also a top-level `scroll`, with compare VA 0x10007b9d4. Counting the nested `scroll` again as a command is incorrect. Pointer action and mouse-button raw-value initializers are separate enum parsers outside this comparison inventory.

Within `type_text`, 0x1000797c8 compares `auto`, 0x1000797fc compares `ax`, and 0x10007a684 again compares `ax`. These three calls do not add native commands. Further input-method dispatch can occur through raw-value enum parsing, so the three comparisons are not a complete input-method schema.

## Literal-validation details

Small Swift string examples (first word, second word):

- `permissions`: (0x697373696d726570, 0xeb00000000736e6f)
- `pip_status`: (0x746174735f706970, 0xea00000000007375)
- `pip_disarm`: (0x617369645f706970, 0xea00000000006d72)
- `mcp_status`: (0x746174735f70636d, 0xea00000000007375)
- `appshot_capture`: (0x5f746f6873707061, 0xef65727574706163)

The status/disarm suffixes are computed using a preserved x24 value of 0xea00000000006465 loaded at 0x1000773b8–73bc; they are not faithfully recovered by looking at only one basic block. `pip_status` adds 0xf10 to this value at 0x10007c9bc; `mcp_status` reuses the status suffix and the `mcp_stat` prefix at 0x10007d150–174. `pip_disarm` adds 0x90d at 0x10007cc68. The full mismatch trace validates these live registers without traversing unrelated success handlers.

Long literal pointers are Swift tagged backing pointers, **32 bytes before** their text bytes:

| cmd | First string word | Tagged backing pointer | Actual text VA / byte length |
|---|---|---|---|
| perform_secondary_action | 0xd000000000000018 | 0x8000000100094b20 | 0x100094b40 / 24 |
| appshot_monitor_start | 0xd000000000000015 | 0x8000000100094b40 | 0x100094b60 / 21 |
| appshot_monitor_stop | 0xd000000000000014 | 0x8000000100094b60 | 0x100094b80 / 20 |
| appshot_frontmost | 0xd000000000000011 | 0x8000000100094b80 | 0x100094ba0 / 17 |

## Shared dispatch preflight: scope matters

Before the command chain, one literal set contains exactly:

`click`, `perform_secondary_action`, `drag`, `type`, `type_text`, `press`, `press_key`, `scroll`, `set_value`

The set is built at 0x100076708–6790. Membership first updates LensOverlay target-window state, using resolveActionPid and the per-PID screenshot mapping when available (0x100076800–68fc). The `force_forbidden` optional Bool key is read at 0x100076900–6924. Members then pass to ForbiddenTargets.check(pid:allowOverride:) at 0x100076968. A second literal set contains exactly `intent` and `open_url` (0x1000767c8–67f0); those pass `args.bundle` to ForbiddenTargets.check(bundleId:allowOverride:) at 0x1000769c0.

`select_text`, `launch_app`, `raise`, and `remote_input` are not in those two preflight sets. This is a verified dispatcher-level omission; it is not a claim that no lower-level, OS-level, transport, host approval, or native MCP gate applies to them. Do not replace the observed sets with “all actions are checked” in a compatibility manual.

## Startup CLI and defaults

All statements here concern `_main` at 0x100001b30 in the inspected helper, not Electron or the JavaScript adapter:

1. It removes the executable path from CommandLine.arguments (0x100002348–2378). No remaining arguments defaults to subcommand `daemon` (0x100001bb8–1bcc). Otherwise the first remaining argument is the subcommand; a flag in that position is not an implicit daemon invocation.
2. Native subcommand spellings: `daemon`; `version`, `--version`, `-v`; and `help`, `--help`, `-h`. Unknown subcommand writes `unknown subcommand: <value>` and prints help, then exits 2 (0x10000221c–2344). The version output bytes are `alma-computer-use 0.1.0` at 0x1000915f0, independent of the containing Alma app version 0.4.164.
3. Within `daemon`, exact options are `--socket PATH` (compare 0x100001c98), `--idle-seconds N` (0x100001d2c), `--lens` (0x100001dd0), `--no-lens` (0x100001e20), `--help` (0x100001ed4), and `-h` (0x100001f08). No `--idle` alias occurs in the loop.
4. **Actual CLI idle default is 900 seconds**. The loaded Double bit pattern is 0x408c200000000000 at 0x100001c34–1c3c and the no-options path 0x100001f48–1f50. It is passed as d0 to Daemon.init at 0x100001f94–1f98. The initializer's own default is **600** (0x4082c00000000000 at 0x100073bf4), and the built-in help text says “default 600”. This is an observed help/initializer/CLI discrepancy; **do not report 600 as the executable's no-option runtime default**. Separately, the JavaScript wrapper explicitly passes 900.
5. `--idle-seconds` attempts a complete Double parse; it replaces the prior value only on success (0x100001e5c–1e68). Missing option operands fall through without a dedicated error (0x100001ca4–1cac; 0x100001d34–1d40). Unrecognized daemon options are ignored by the final loop continuation (0x100001f0c→1c50). No positive-range clamp is visible in `_main`; special floating-point spellings were not executed or validated here.
6. Lens initially false (0x100001c1c and 0x100001f44); `--lens` sets true, `--no-lens` false; last encountered setting wins. The final value is passed to LensOverlay.setEnabled at 0x100001f64–1f6c.
7. Native default socket path is `homeDirectoryForCurrentUser.path + "/Library/Application Support/Alma/computer-use.sock"`. Home lookup 0x1000025fc, literal bytes 0x100091610 (51 bytes), append 0x10000268c. This is distinct from the wrapper's helper-path-hashed socket override.

## Scope and remaining gaps

- This inventory is complete for **the top-level string-dispatch chain in the inspected arm64 function**. It does not establish parity with the x86_64 slice, a different Alma build, or any dynamically loaded feature.
- No runtime calls, OS permission prompts, network listeners, target subprocesses or automation actions were invoked. Negative tests and exact wire-result assertions remain unexecuted.
- This inventory table alone establishes branch identity and broad function. Detailed dispatcher schemas for utility, PIP, Appshot, remote/Lens and native MCP control commands are in the addenda below; their stated runtime/underlying-endpoint gaps still apply.
- Native MCPServer tool registrations, HTTP paths, token/peer authentication, whitelist matching, expiry and transport behavior are separate scope. Do not infer those from the seven `mcp_*` names alone.
- Exact request decode, response fallback JSON, peer receive/write behavior, idle timer, snapshot, capture and diff algorithms are covered by adjacent specialist findings; this document corrects command spellings and startup defaults rather than replacing those analyses.

## Contract-completion addenda

The initial scope caveat above is superseded for the following dispatcher schemas by detailed static addenda (runtime behavior remains unexecuted):

- `UTILITY_COMMANDS.md`: ping/permissions/grant/apps/windows/snap/raise/shot/shot_display/stealth_stats/turn_ended utility contracts
- `REMOTE_LENS_EXTRA_CONTRACTS.md`: remote_input/lens and common native argument coercion helpers
- `PIP_EXTRA_CONTRACTS.md`: pip_open/close/status/arm/disarm, nested status records and native errors
- `APPSHOT_EXTRA_CONTRACTS.md`: Appshot monitor/capture/frontmost, event lifecycle and shutdown
- `MCP_CONTROL_EXTRA_CONTRACTS.md`: seven mcp_* control shells, status/whitelist records, exact validation/defaults and a clearly separated native-server parity gap

A complete cmd-name inventory is not equivalent to complete endpoint implementation parity. Consult each addendum's closed/partial boundary; native MCP HTTP/OAuth internals and endpoint runtime proofs remain separate work.
