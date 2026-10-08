> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/APP_USAGE_CONTRACT.md`；原文件 SHA256 `513c1d2bbc818ad1a97a9dc784c48e2c7748e5b9f25e4af038dd6f538785ec42`；全文件 1–154 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# AppUsage / list_apps exact static contract (Alma 0.4.164, arm64)

## Scope and primary evidence

Static inspection only. No target executable was run, no Spotlight query was issued, and no live application/history data was read. Addresses below are **unslid arm64 virtual addresses**, not file offsets. Primary artifacts: `analysis/native/arm64.macho`, `arm64.json`, `arm64-symbols.txt`, and `arm64-disasm.txt`; ranges can be reproduced by disassembling the same-hash independently acquired sample at the listed VAs; complete raw dumps and vendor binaries are not distributed; this consolidated package separately includes bounded, provenance-labeled .153 disassembly excerpts and task-specific JS snippets under code-evidence. JavaScript source is the shipped `extracted/Alma.app/Contents/Resources/cli/alma-computer-use-mcp.mjs`.

This closes usage-window handling, source/query lifecycle, running-app selection, merging, duplicate behavior, fallback values, final comparator, and emitted row shape. Registry metadata exposed by `intents` is specified in the companion `APP_INTENTS_METADATA.md`; URL builders are a separate native extension.

## 1. Entry points and days

- Public MCP `list_apps`: source lines 36007–36024. Input `days` is optional Zod number, integer, maximum 90, with **no schema minimum**. The handler sends `{days: posIntOr(args.days,14)}`; `posIntOr` requires a finite numeric value greater than zero, then floors it, otherwise returns 14. Consequently valid MCP positive values are integers 1–90, while zero and negative integers are accepted by the schema but become 14. Missing becomes 14; fractions and values above 90 fail schema validation rather than being clamped. No interaction gate wraps this tool. The result is one text content block containing `JSON.stringify(res,null,2)`.
- Native dispatcher branch `0x100076f8c–0x100077004`: reads `days` using the native optional-dictionary `int` accessor at `0x100076fa4`; missing/null value or an accessor parse failure gets literal 14 via `mov w8,#0xe` / `csel x0,x8,x0,eq` at `0x100076fb0–fb4`; calls `AppUsage.listApps(days:)` at `0x100076fb8`.
- Swift default-argument generator `0x10003791c`: `mov w0,#0xe; ret`.
- The native `int` accessor also accepts Double (truncate toward zero) and signed decimal String, after trying Int (`0x100006308–6340`, `0x100006388–6400`, `0x100006404–66bc`; see `WIRE_SCHEMA.md`). Non-finite/out-of-Int-range Double conversion traps at `0x1000066c8–66d0`; that is not the default14 fallback. Ordinary MCP schema validation excludes these non-integer/non-number inputs before native forwarding.
- Native AppUsage has **no positivity or maximum clamp**. It passes the original integer to `recentMetadata` at `0x1000384e8–4f0`. `recentMetadata` holds the argument in x20 from `0x10003b720`; at `0x10003b994–9b8` it constructs Date(), converts x20 with `scvtf d0,x20`, multiplies by IEEE754 bits `0xc0f5180000000000` (= -86400.0), and calls `Date.addingTimeInterval`. Native direct callers can therefore request zero, negative, and >90 windows. Do not incorrectly impose the MCP restriction on the raw daemon contract.
- Public `sky_list_apps`, lines 36294–36310, sends native `list_apps` with `{}`, so native default 14 applies. It returns a JSON text **array** transformed from `res.apps ?? []`: `id = a.bundle || a.name || "unknown"`, `displayName = a.name`, `isRunning = a.running ?? a.active`, `lastUsedDate = a.last_used_at ?? undefined`, `useCount = a.use_count ?? undefined`. Missing/null lastUsedDate/useCount are omitted by JSON.stringify. This differs from the ordinary tool's full native result object.

## 2. Native result shape

Native result is `{apps: [row, ...]}`. Dispatcher builds the `apps` dictionary, with the mapped array at `0x100076ff0–0x100077000` and shared dictionary-return tail `0x100076ec4–0x100076f18`. Each row has **nine** keys, built by mapper `0x100080884–0x1000810a8`:

| JSON key | Type / value | Primary instruction proof |
|---|---|---|
| bundle | String or null | Small-string literal at `0x100080978–994`; AppInfo+0 and +8 read at `0x100080924`; optional nil branch `0x1000809ac–9b8` |
| name | String | Literal `0x1000809bc–9d0`; AppInfo+0x10/+0x18 stored `0x1000809d4–9d8` |
| pid | Int32 promoted to signed integer, or null | Literal `0x1000809dc–9f4`; optional tag at +0x24; `ldrsw` from +0x20 at `0x100080a14` |
| active | Bool | Literal `0x100080a24–a38`; value from AppInfo+0x25 at `0x100080a3c–a48` |
| running | Bool | Literal `0x100080a4c–a64`; value from AppInfo+0x26 at `0x100080a68–a6c` |
| path | String or null | Literal `0x100080a70–a80`; AppInfo+0x28/+0x30, optional test `0x100080a84–ab0` |
| use_count | Swift Int or null | Literal `0x100080ab4–ad0`; value +0x38, optional tag +0x40 at `0x100080ad4–afc` |
| last_used_at | ISO8601 String or null | Literal `0x100080b00–b20`; optional Date copied/tested `0x100080b24–b64`; nil existential is zeroed `0x100080b68–b6c`; nonnil formatting `0x100080ba0–c28` |
| intents | Array of objects, possibly [] | Literal `0x100080c3c–c50`; exact bundle lookup `0x100080930–940`; nil bundle gets empty array at `0x100080948`; empty registry array branch `0x10008101c–1028`; emitted array stored `0x100081040–1048` |

The mapper destroys exactly nine key/value literal entries at `0x10008107c` (`mov w1,#9`) after building `[String:Any?]` at `0x100081050`. Optional fields remain present as null in the canonical native JSON conversion; they are not all omitted like the sky adapter's optional date/count fields.

`last_used_at` uses a newly initialized `NSISO8601DateFormatter` for each present date, then `stringFromDate:`; no formatter options, timezone, fractional-seconds option, or custom format is configured in the mapper. This is Foundation's default ISO8601 formatter behavior. Classref `0x1000ae488` contains raw chained-bind word `0x80100000000002c9`; fixups import index 0x2c9 resolves `_OBJC_CLASS_$_NSISO8601DateFormatter`. Do not substitute Unix epoch numbers or a locale-dependent date formatter.

Each intent has precisely `name:String`, `description:String`, `required_params:[String]`, `optional_params:[String]`; key/value materialization `0x100080cb0–0x100080d50`, dictionary capacity four at `0x100080d54`, array append `0x100080fd4–fe8`. No URL/build closure is emitted. Registry order is preserved by this map. Exact entries are in the companion document.

## 3. Running-app seed

1. Start a `[String:AppInfo]` dictionary and a separate array for rows without bundle IDs (`0x100037cb4–cc4`, `0x100037de4–dec`).
2. Read `NSWorkspace.shared.frontmostApplication`; capture its PID if present (`0x100037ccc–0x100037d30`). Retain a separate presence test, so absence does not make PID 0 active.
3. Read `NSWorkspace.shared.runningApplications` (`0x100037d34–d80`) and enumerate its order (`0x100037e18–e58`).
4. **Include only activationPolicy == 0 (`.regular`)**. Call and `cbnz` skip are `0x100037e5c–e64`. Accessory/prohibited/background apps are excluded from the running seed; the metadata stage is not filtered by activation policy.
5. For each included application:
   - `bundleId = bundleIdentifier` optional (`0x100037e68–ea0`)
   - `name = localizedName ?? "(unknown)"` (`0x100037eac–ef0`); the fallback is the exact lower-case, parenthesized string decoded from immediates 0x6e776f6e6b6e7528 + 0xe900000000000029
   - `pid = processIdentifier` (`0x100037ef8–efc`)
   - `active = frontmost exists && processIdentifier == frontmostPID` (`0x100037f04–f24`)
   - `running = true` (`0x100038068–06c`)
   - `path = bundleURL?.path`, not executableURL (`0x100037f30`, `0x100037ff4`); no URL -> nil (`0x100037fd0–fec`)
   - `useCount = nil`, `lastUsedAt = nil` (`0x10003801c–03c`, `0x100038074–078`)
6. Non-nil bundle IDs are dictionary keys with normal exact Swift String equality. A later running application with the same bundle replaces the entire earlier AppInfo (`find` `0x1000382a8`; found branch `0x100038388–3a4`; insertion `0x1000383d0–444`). No PID/path disambiguation and no explicit case folding are used.
7. Nil bundle rows append separately (`0x1000381e4–264`). They are not deduplicated by name, path, or PID.

## 4. Spotlight history source and query lifecycle

`AppUsage.recentMetadata(days:)` is `0x10003b6fc–0x10003c750`. The source is **NSMetadataQuery**, not Screen Time, an Alma-maintained database, launch logs, recent-document menus, or a recursive filesystem scan.

### Configuration

- Allocate/init NSMetadataQuery at `0x10003b8f4–b904`. Classref `0x1000ae508` raw bind word `0x80100000000002d9`, fixups import 0x2d9 = `_OBJC_CLASS_$_NSMetadataQuery`.
- Set search scopes to a one-element array containing **NSMetadataQueryLocalComputerScope** (`0x10003b940–988`). GOT slot `0x1000a4800` resolves that exact symbol using LC_DYSYMTAB indirect symbols; raw bind word `0x80100000000000f8`.
- Cutoff: current Date plus `-86400.0 * Double(days)` as above. The comparison is inclusive.
- Predicate format at raw C-string VA `0x100093240`: `kMDItemContentType == 'com.apple.application-bundle' AND kMDItemLastUsedDate >= %@`. Construct NSPredicate with the cutoff NSDate at `0x10003b9fc–ba9c`. Equality on content type is exact; this is not a ContentTypeTree/conformance test.
- `valueListAttributes` = `["kMDItemDisplayName", "kMDItemCFBundleIdentifier", "kMDItemLastUsedDate", "kMDItemUseCount", "kMDItemPath"]`. Static Swift array begins VA `0x1000b0730`, count 5 at +0x10, capacity word 10 at +0x18, elements at +0x20. Its large strings point to C-string VAs `0x1000932a0`, `0x1000932c0`, `0x1000932e0`; the last two are inline Swift small strings at `0x1000b0780`, `0x1000b0790`. Array selected at `0x10003babc–bac4`, passed to `setValueListAttributes:` at `0x10003bae8`.
- Query sort descriptor is `NSSortDescriptor(key:"kMDItemLastUsedDate",ascending:false)` (`0x10003bb38–bb60`; w3=0); installed at `0x10003bba8`. Thus metadata is traversed in descending last-used order before the independent final AppInfo sort.

### Execution and fallback

- Create semaphore value 0 at `0x10003bbb4–bbb8`.
- Add default NotificationCenter observer for **NSMetadataQueryDidFinishGatheringNotification**, scoped to this query object, with queue nil (`0x10003bbe4–bbec`, `0x10003bc74–bc88`). Exact notification GOT slot `0x1000a47f8` resolves the named symbol, raw bind word `0x80100000000000f7`.
- Observer closure `0x10003da34–da50` only signals the semaphore (`0x10003da44`).
- Dispatch `startQuery` asynchronously to the main queue (`0x10003bce4`, `0x10003bde8`); closure `0x10003da70–da74` tail-calls `startQuery`. The Bool return of startQuery is not used to produce an error.
- Wait until `DispatchTime.now() + 2.0` (`0x10003be44–be58`, literal `fmov d0,#2`), semaphore wait `0x10003be80`; compare return against timeout (`0x10003be94–bea0`).
- Enqueue `stopQuery` asynchronously on main queue in either case (`0x10003beac`, `0x10003bf78`; closure `0x10003db0c–db10`). Then remove the observer (`0x10003bfd4`). There is no `disableUpdates` call and no synchronous main-queue stop before result extraction.
- **On timeout return []**, discarding any partial query results (`0x10003bfe8–c014`). Consequently list_apps falls back to its regular running-app seed and still returns normal success; it does not expose a timeout error or partial-history flag. This is not a fallback to another usage database.
- On successful gathering, read `resultCount` and iterate `resultAtIndex:` (`0x10003c018–c028`, `0x10003c110–c160`). Rows failing the conditional NSMetadataItem cast are skipped. Zero results returns [].

### Extracted metadata rows

For each NSMetadataItem, build MDEntry with:

| MDEntry member | Value and fallback | Primary range |
|---|---|---|
| bundleId | `valueForAttribute("kMDItemCFBundleIdentifier") as? String`, nil on absent/cast failure | `0x10003c164–c228` |
| name | `(kMDItemDisplayName as? String) ?? (kMDItemFSName as? String) ?? "(unknown)"` | `0x10003c228–c3a8`; FSName immediate construction `0x10003c2d0–2ec` |
| path | `(kMDItemPath as? String) ?? ""` | `0x10003c3ac–c468`; fallback x24=0,x19=0xe000000000000000 at `0x10003c460–464` |
| useCount | `kMDItemUseCount as? Int`, nil on absent/cast failure | `0x10003c468–c538`; destination Swift Int metadata GOT `0x1000a4a70` |
| lastUsedAt | `kMDItemLastUsedDate as? Date`, nil on absent/cast failure | `0x10003c538–c628` |

The final MDEntry write is `0x10003c658–c670`; append preserves query order (`0x10003c694–c6c8`, `0x10003c0a0–c110`). No `.app` suffix is trimmed from names; empty strings are preserved rather than treated as missing. FSName is read as an on-demand fallback even though it is not in valueListAttributes.

## 5. Exact merge and duplicate behavior

After collecting running apps, call recentMetadata once (`0x1000384e8–4f0`) and traverse its rows in returned order (`0x100038508–5e8`). For each metadata entry `m`:

- If m.bundleId exists and currently matches a dictionary row:
  - Preserve that row's bundle, name, pid, active, running (`0x10003866c–6a4` saves fields; `0x10003871c–754` restores them)
  - Preserve its path **if non-nil**; otherwise use m.path (`0x1000386a8–6e0`; `cbnz x26` skips fallback). Empty path counts as non-nil and is not subsequently improved
  - Replace useCount and lastUsedAt with m's optional values **unconditionally**, including nil (`0x1000386e4–718`, `0x100038758–760`)
  - Write the updated row back to the dictionary under that bundle (`0x100038c64–d80`)
- Otherwise make an AppInfo from metadata: bundle/name/path/useCount/date from m, pid=nil, active=false, running=false (`0x1000388ac–914`, notably `strh w8,[x24,#0x24]` with w8=1 encodes optional PID nil plus active false, and `strb wzr,[x24,#0x26]` running false)
  - With a non-nil bundle, insert it into the same dictionary (`0x10003891c–920`, `0x100038b04–c5c`)
  - With nil bundle, append to the separate unbundled-row array (`0x100038a68–afc`)

Important reproducibility edge cases:

1. Matching is **bundle-only**. There is no path/name matching for an unbundled app. A running unbundled row and metadata unbundled row for the same application remain two entries.
2. All bundled metadata rows deduplicate into the dictionary, even if none was originally running. Multiple installations with the same bundle ID become one row.
3. For duplicate metadata bundle IDs, the **first/newest** metadata row provides the name/path of a non-running row, but **each later/older row overwrites count/date**. Since query order is lastUsed descending, the last matching metadata row determines final use_count and last_used_at. Counts are not summed, maximized, or tied to the retained path. No newest-wins test appears in the merge path.
4. A previously running row's name/PID/flags remain the running row's values, even when a newer history entry exists. Dictionary replacement among running instances occurs before history merging, so the last running instance enumerated supplies them.
5. Unbundled rows are never deduplicated, neither running vs history nor metadata vs metadata.

Before final sort, form `Array(dictionary.values)` (`0x100038eb4–f18`, including concrete Dictionary.Values copy helper at `0x100038ef4`), then append the unbundled array (`0x100038f20–f30`). Therefore a fully tied pair of bundled rows has dictionary-enumeration order, not a promised deterministic insertion order. Unbundled rows enter after all dictionary rows, with their original running-then-metadata traversal order.

## 6. Final sort comparator, fully closed

`0x100038f4c` calls specialized sort `0x100039140`. It chooses insertion sort for short runs (`0x1000391dc–1ec`) and `_stableSortImpl` for larger arrays (`0x100039220–224`). The clearest inlined comparator is in insertion sort `0x100039dc0–e88`:

```
if lhs.active != rhs.active: return lhs.active
if lhs.running != rhs.running: return lhs.running
let l = lhs.useCount ?? -1
let r = rhs.useCount ?? -1
if l != r: return l > r
return lhs.name.lowercased() < rhs.name.lowercased()
```

Proof:
- active byte +0x25 comparison `0x100039dc0–dcc`; unequal branches with lhs flag in w22
- running byte +0x26 comparison `0x100039dd0–ddc`; same behavior
- lhs optional count tag +0x40 and count +0x38 at `0x100039de0–dec`; `csinv x8,x8,xzr,ne` produces -1 when nil; rhs analogous `0x100039df0–e14`
- descending signed count: `cmp x9,x8; cset w22,lt` at `0x100039e84–e88`
- lowercasing both names `0x100039e18–e2c`, strict Swift string-less comparison (`w4=1`) `0x100039e50–e60`
- equality returns no swap (`0x100039e3c–e4c` to `0x100039d48`), preserving stable input order for equal keys

**last_used_at is not used by the final comparator.** It filters/sorts the Spotlight input only. There is no bundle, PID, path, or raw-case name secondary tiebreaker. A negative count below -1 can sort behind a nil count because nil is explicitly -1, not a separate missing-value class. Replicas should reproduce Swift lowercased/string comparison semantics rather than locale-aware display-name sorting.

## 7. Minimal implementation sequence and fixture checks

Implement the running snapshot first, query with the specified cutoff/2-second lifecycle, merge as described, combine dictionary values and unbundled rows, stable-sort with the exact four-stage comparator, then map all nine fields and wrap in `apps`.

Static-derived conformance cases (synthetic inputs only):
- MCP missing/0/-2 -> sends14;1/90 preserved;91/fraction fail validation; raw native days0/-2/91 are not clamped
- accessory running app absent from seed; eligible history can still add it as running=false
- nil localizedName -> `(unknown)`; empty localizedName remains empty
- missing metadata display name -> FSName -> `(unknown)`; missing metadata path -> empty String
- same bundle in two running instances -> later instance wins; same bundle then two metadata rows -> later metadata count/date wins, running name/PID/path remain
- nil bundle twice -> two rows, no identity synthesis
- active outranks running/count; running outranks count; count descending with nil=-1; date never breaks ties; lowercased name ascending
- metadata timeout -> running-only successful `{apps:[...]}`
- ordinary list_apps emits null optionals and intents arrays; sky_list_apps emits transformed array, omitting null date/count and all intents
