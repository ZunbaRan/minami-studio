> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/MCP_CONTROL_EXTRA_CONTRACTS.md`；原文件 SHA256 `a8560c4e860124ba726ac1b8e32ca638cd4b6bd04609df0c182ef97840a676bb`；全文件 1–104 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# Native mcp_* socket-control contracts

Static arm64 analysis, Alma0.4.164 AlmaComputerUse; all VAs unslid. Target never executed. Scope: seven native socket control commands, their input defaults/errors/data shapes, status/whitelist records, and directly called start/stop/add/list mechanics. **This is not a complete native MCP-over-HTTP/OAuth implementation contract.** Those request routes, wire schemas, peer-signing authorization, grant/code lifecycle and native tool registry must be specified separately.

Use shared native str/int/double/bool reader contracts in REMOTE_LENS_EXTRA_CONTRACTS.md. Numeric-looking strings and Double→Int truncation can reach these handlers; narrow conversions are not uniformly errors.

## 1. Complete dispatcher shell table

| cmd | Inputs parsed | Success data | Core call / evidence |
|---|---|---|---|
| mcp_start | port:int?; token_path:str? | Status object in§2 | MCPServer.start0x1000546fc, called0x10007ce54 |
| mcp_stop | none | {stopped:true} | MCPServer.stop0x100055818 at0x10007cf8c; shared dictionary tail0x10007ef18–ef60 |
| mcp_status | none | Status object in§2 | MCPServer.statusSnapshot0x100054f7c at0x10007d18c |
| mcp_allow | team_id:str?; bundle_id:str?; pid:int?; ttl_seconds:double? | {allowed:true,team_id:<String or null>,bundle_id:<String or null>,pid:<Int32 or null>,ttl_seconds:<Double or null>} | MCPServer.addWhitelist0x10006348c at0x10007d4e8; response0x10007d514–d570,d630–d674,d83c–d880,d9ec–da40,dc04–dc1c |
| mcp_deny_all | none | {cleared:true} | MCPServer.clearWhitelist0x100063714 at0x10007d2bc; response literal0x10007d2f8–d30c→e694/ef58 |
| mcp_whitelist | none | {entries:[<WhitelistEntry>,...]} | MCPServer.whitelistList0x100063770 at0x10007d464; wrapper0x10007d40c–d4ac |
| mcp_arm_peer | pid:int required; ttl_seconds:double?=120 | {armed:true,pid:<input narrowed Int32>,ttl_seconds:<effective Double>} | addWhitelist at0x10007d788; response0x10007d794–d838 |

All shapes above are the `data` inside the standard NDJSON response envelope. Extra keys are ignored by these dispatcher branches. `mcp_allow` uses **bundle_id**, unlike app-target commands' **bundle**. `mcp_start` uses **token_path**, not token_file or tokenFilePath.

### mcp_start argument handling

- `port` read0x10007cdec. Values representable as UInt16 (0…65535) are passed as present. Missing/unconvertible values **and parsed integers outside UInt16 range** become nil at0x10007ce20–ce34. This is a silent fallback, not a UInt16 trap or invalidArg. The underlying NWEndpoint.Port(rawValue:) optional is also coalesced to `.any` when absent (0x100054b74–c4c). No fixed default TCP port is encoded here.
- `token_path` optional String read0x10007ce10; nil selects a default token-file path in start. Empty string is present and is forwarded rather than rejected by requireStr.
- If listener already exists (self+0x18), start immediately returns current status0x10005486c–487c. New port/token_path arguments are then ignored; it does not rebind or rotate the token on this already-running path.
- When stopped, start assigns daemon reference, generates a fresh bearer token and chooses token file: explicit token_path if non-nil; otherwise `(environment["HOME"] ?? NSHomeDirectory()) + path component ".alma/cu/mcp-token"` (0x1000548c8–4a44; literal0x100094860). It writes token via0x100067320 before listener construction. The token value is not returned in status.
- Token write creates parent directories (0x10006745c), writes UTF-8 Data (0x1000674ec), then calls chmod0600 (w1=0x180 at0x100067568). The chmod return is not tested in this function. Filesystem/Network framework thrown errors propagate through the ordinary processLine error conversion; no success should be fabricated on write/bind failure.
- Starts NWListener and waits for boundPort!=0, with a two-second deadline and0.01-second polling sleeps (0x100054dd8–4e70; Double constant0x3f847ae147ae147b). On timeout it cancels/clears listener and throws internalError **`MCP listener failed to bind within 2s`** (factory0x100054f0c, text0x100093650).
- Status advertises `http://127.0.0.1:<port>/mcp`; exact HTTP binding/auth behavior remains separate from this control schema.

### mcp_allow validation and expiry

- Reads team_id0x10007d214, bundle_id0x10007d230, pid0x10007d24c, ttl_seconds0x10007d350.
- Requires at least one of the three identity optionals to be present. If all nil: invalidArg **`need at least one of team_id / bundle_id / pid`** at0x10007d390 (text0x100094d60). Optional Strings are not trimmed or required nonempty here; an empty string passes presence validation.
- A present pid narrows to Int32; outside[-2147483648,2147483647] hits trap0x10007d4b0/4b4. Within range, no positive-PID check is present at this dispatcher boundary.
- Missing/unconvertible ttl_seconds is forwarded as nil. addWhitelist then stores no expiry (0x100063580–635bc). A supplied TTL becomes `Date.now + ttl_seconds` (0x100063598–635a4), with no positivity clamp in this function. Zero/negative values therefore construct current/past expiration dates. NaN/infinity outcomes were not run.
- addWhitelist appends a new entry under lock (0x10006360c–63688); no deduplication/replacement occurs in this method. Multiple identical requests can produce duplicate entries. Response echoes optional identities and optional original TTL, not an expiry timestamp.
- Matching rules across team_id/bundle_id/pid and the moment expiry is enforced are deliberately not inferred from add/list alone.

### mcp_arm_peer differences

- pid read0x10007d5c4. If absent/unconvertible, invalidArg **missing \`pid\`** where the characters around pid are ASCII backticks (literal assembly0x10007d5d4–d5f0; factory0x10007d5f8). This differs from requireStr's quoted-key error.
- Optional ttl_seconds read0x10007d720; nil selects Double120.0, bit pattern0x405e000000000000 (0x10007d724–d738). Supplied zero/negative TTL is retained.
- PID narrowing traps at0x10007d9e4/e8 when outside Int32; otherwise no positive-PID check in this branch.
- Calls addWhitelist with **nil teamId, nil bundleId, supplied PID, effective TTL** at0x10007d76c–d788. The dispatcher does not infer PID from the socket ConnectionContext despite the command's name, and it does not return verified signing identity.

### mcp_deny_all and stop scope

- clearWhitelist0x100063714 only replaces the whitelist array with empty under lock (0x10006372c–6375c). Do not describe this as revoking every already-issued OAuth/access grant; those are separate maps and are not cleared by this method.
- stop synchronously cancels tracked NWConnections on its queue (closure0x10006786c–67968), cancels listener, assigns listener=nil and boundPort=0 (0x100055900–55930), then returns {stopped:true}. No token-file unlink is present in this stop function. The inspected code does not clear oauth_client_id/token_path or the whitelist/grant/code maps here; a later status can retain those fields/counts despite running=false.

## 2. Exact Status object

statusSnapshot0x100054f7c–55428 constructs ten fields. Its count snapshots are taken under the server lock; listener/port/string fields are then read separately. Do not assume the entire returned object is one atomic transaction.

| Field | Native data value | Evidence |
|---|---|---|
| running | Bool: listener object != nil |0x100055054–5088 |
| port | integer UInt16 boundPort,0 when stopped/unbound |0x10005508c–50ac |
| url | String `http://127.0.0.1:<port>/mcp` if port!=0, otherwise null |0x1000550b0–517c |
| oauth_base | String `http://127.0.0.1:<port>` if port!=0, otherwise null |0x100055180–521c |
| oauth_client_id | Stored String if nonempty, otherwise null |0x100055220–5280 |
| token_path | Stored token-file String if nonempty, otherwise null |0x100055284–52d4 |
| tool_count | Native MCPServer static tools array count |0x1000552d8–5310; initializer0x10005540c→0x10005db18 |
| active_grants | Stored grant dictionary count |reads0x100054fc8–4fd0, emits0x100055314–5348 |
| pending_codes | Stored pending-code dictionary count |reads0x100054fe8–4ff0, emits0x10005534c–5378 |
| whitelist_size | Stored whitelist array count |reads0x100055008–5010, emits0x10005537c–53ac |

Status does not include bearer token content, connected-peer count, complete entries, or verification of current app permissions. The count getters themselves do not filter expired entries in this function. The field name active_grants is not by itself proof that every counted record is unexpired. `tool_count` is for the **native** MCPServer registry; do not substitute23 from the separate JavaScript MCP adapter.

## 3. WhitelistEntry output record

mcp_whitelist returns {entries: [...]} with each entry:

    { "team_id": <String or null>, "bundle_id": <String or null>,
      "pid": <Int32 or null>, "expires_at": <Unix-epoch seconds Double or null> }

Mapping closure0x10006391c–63d54 proves keys and types:

- team_id0x1000639f0–63ab4
- bundle_id0x100063ab4–63b58
- pid0x100063b58–63bec
- expires_at0x100063bec–63cf0; Date.timeIntervalSince1970 at0x100063cbc

Absent values are explicitly boxed as NSNull in this non-optional Any dictionary. The function iterates the stored array in order, mapping every entry under lock0x1000637cc–638f0. There is no sort, filtering or expiry cleanup in whitelistList itself. As elsewhere, another server operation could mutate the array before this call.

## 4. Minimum static conformance cases

1. mcp_start with no port, port0, negative port,65535,65536; invalid-range inputs take `.any` path rather than trapping
2. While running, repeated mcp_start with different token_path/port returns existing status without applying them
3. token_path nil versus empty; read/write errors propagate; do not invent a success status
4. mcp_allow with no identity -> exact error; empty team_id -> admitted presence check
5. mcp_allow omitted TTL -> null response TTL and expires_at:null; positive TTL -> epoch seconds; zero/negative TTL retained
6. Duplicate mcp_allow calls append duplicate entries and increase raw whitelist_size
7. mcp_arm_peer omitted TTL ->120; missing pid -> backtick-quoted exact error; present pid+negative TTL retained
8. mcp_deny_all empties entries but is not a blanket OAuth grant revocation
9. mcp_stop returns stopped:true; status runningfalse/port0/urlnull/oauth_basenull; file path/client ID and maps may remain
10. Whitelist record null fields must serialize as JSON null, not omitted keys, strings or empty dictionaries

These are specified fixtures, not executed product test results.

## 5. Explicit unresolved native-server scope

The seven socket-control shells and their ordinary field/result/error contracts above are statically covered. Full native MCP server parity still requires: native tool registration schemas, JSON-RPC result/error behavior, HTTP request framing/body limits/connection semantics, OAuth metadata/authorize/token routes, PKCE and redirect validation, signing/peer identity extraction, whitelist AND/OR match semantics and expiry enforcement, access-grant/pending-code cleanup and revocation, and protocol/session negotiation. None of those is interchangeable with the JavaScript MCP23 adapter or host HTTP API. A standalone implementation may defer this server deliberately, but a claim of complete Alma parity may not silently omit it.
