> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/PARITY_SURFACE.md`；原文件 SHA256 `45784ca2ec41ed4178cb6894da209e08f2ba33aa30e1002a52b0d23e42e40871`；全文件 1–63 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native command parity boundary

Evidence cross-check: analysis/host/host-contract-report.md lines61–69 identifies native helper forwarding; analysis/mirror-ui/behavioral-contract.md identifies actual Electron mirror pump shot/shot_display; remote_input is exposed through host/remote WebSocket plumbing, not the view-only mirror UI; analysis/mcp/REPORT.zh-CN.md maps23JS tools to13 distinct native commands. Mere forwarding is distinguished from an observed default caller. No45-command whole-system implementation-ready claim is made.

Categories:

- CORE-MCP: direct current JS MCP adapter call path
- CORE-HOST: host helper forwarding is recovered, but a specific normal UI invocation may be optional/untraced
- CORE-MIRROR: actual default Electron mirror frame path traced; mirror is view-only
- CORE-APPSHOT: actual Appshot native workflow/host path traced
- OPTIONAL-NATIVE: native/administrative surface exists, no default JS/Electron caller established in inspected reports

| Command | Category | Contract source / implementation boundary |
|---|---|---|
| ping | CORE-HOST | UTILITY_COMMANDS; daemon health/connection |
| permissions | CORE-MCP | UTILITY_COMMANDS |
| grant | CORE-MCP | UTILITY_COMMANDS |
| apps | CORE-HOST | UTILITY_COMMANDS; distinct regular-GUI-app listing |
| list_apps | CORE-MCP | APP_USAGE_CONTRACT + APP_INTENTS_METADATA; exact history source/merge/sort and emitted registry metadata |
| windows | CORE-HOST | UTILITY_COMMANDS / FINDINGS10 |
| snap | CORE-HOST | FINDINGS2–4; not wrapper post-action path |
| launch_app | CORE-MCP | MCP/native dispatch/native launch; host contract |
| open_url | OPTIONAL-NATIVE | UTILITY_COMMANDS shell+quiet opener; no JS23 registration |
| intent | OPTIONAL-NATIVE | UTILITY_COMMANDS execution shell; metadata is core via list_apps (APP_INTENTS_METADATA), URL-builder execution templates deferred |
| get_app_state | CORE-MCP | FINDINGS2–11; native diff report |
| click | CORE-MCP | Native event/ref algorithms + WIRE_SCHEMA targeting |
| type | CORE-HOST | Native ref text algorithms |
| type_text | CORE-MCP | Native text algorithms + MCP report |
| press | CORE-HOST | Native ref key algorithms |
| press_key | CORE-MCP | Native key algorithms + MCP report |
| perform_secondary_action | CORE-MCP | Native event/ref algorithms |
| drag | CORE-MCP | Native event algorithms |
| set_value | CORE-MCP | Native ref algorithms |
| select_text | CORE-MCP | Native ref algorithms |
| scroll | CORE-MCP | Native event/ref algorithms |
| lens | CORE-HOST | REMOTE_LENS_EXTRA_CONTRACTS; native overlay is separate from Electron PiP |
| pip_open | OPTIONAL-NATIVE | PIP_EXTRA_CONTRACTS; not traced as Electron mirror implementation |
| pip_close | OPTIONAL-NATIVE | PIP_EXTRA_CONTRACTS |
| pip_status | OPTIONAL-NATIVE | PIP_EXTRA_CONTRACTS |
| pip_arm | OPTIONAL-NATIVE | PIP_EXTRA_CONTRACTS |
| pip_disarm | OPTIONAL-NATIVE | PIP_EXTRA_CONTRACTS |
| mcp_start | OPTIONAL-NATIVE | Native standalone MCP service control shell; HTTP/OAuth/RPC parity deferred |
| mcp_stop | OPTIONAL-NATIVE | Same |
| mcp_status | OPTIONAL-NATIVE | Same |
| mcp_allow | OPTIONAL-NATIVE | Same; security policy is separate from user-facing confirmations |
| mcp_deny_all | OPTIONAL-NATIVE | Same |
| mcp_whitelist | OPTIONAL-NATIVE | Same |
| mcp_arm_peer | OPTIONAL-NATIVE | Same |
| raise | CORE-HOST | UTILITY_COMMANDS; host middleware exists, runtime AXRaise behavior unverified |
| shot | CORE-MIRROR | UTILITY_COMMANDS / FINDINGS capture / mirror reports |
| shot_display | CORE-MIRROR | UTILITY_COMMANDS; display fallback captures system cursor pixels |
| remote_input | CORE-HOST | Host/remote WebSocket input route; not default view-only mirror input. REMOTE_LENS_EXTRA_CONTRACTS |
| stealth_stats | OPTIONAL-NATIVE | Dispatcher diagnostic path; exact record contract requires native diagnostic supplement |
| turn_ended | OPTIONAL-NATIVE | Dispatcher releaseAll gate; verify host call before promoting to CORE |
| shutdown | CORE-HOST | APPSHOT_EXTRA_CONTRACTS shutdown + host lifecycle |
| appshot_monitor_start | CORE-APPSHOT | APPSHOT_EXTRA_CONTRACTS |
| appshot_monitor_stop | CORE-APPSHOT | APPSHOT_EXTRA_CONTRACTS |
| appshot_frontmost | CORE-APPSHOT | APPSHOT_EXTRA_CONTRACTS |
| appshot_capture | CORE-APPSHOT | APPSHOT_EXTRA_CONTRACTS |

The native standalone MCPServer is not interchangeable with the product's traced JS stdio MCP bridge. Its OAuth grants/peer-whitelist HTTP transport is a distinct optional product capability. Control-shell wire schemas do not establish OAuth or full-RPC interoperability. Keep that backend disabled/unsupported in a core clone until implemented; do not expose an insecure permissive substitute.

Core static protocol/algorithm reconstruction is not runtime verification: TCC, private API behavior, focus races, AX fidelity, ScreenCaptureKit scaling and app launch remain macOS acceptance-test gates. PIP/Appshot/native-extra supplement documents likewise separate static contracts from live OS proof.
