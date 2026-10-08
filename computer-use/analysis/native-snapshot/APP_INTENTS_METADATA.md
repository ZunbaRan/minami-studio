> 来源：用户提供的 .164 研究资料 `analysis/native-snapshot/APP_INTENTS_METADATA.md`；原文件 SHA256 `fb565814c4326ac15d38d414cfe560f770e37f484360d7d304f0ef38f96e367f`；全文件 1–118 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# list_apps intent metadata contract (Alma 0.4.164, arm64)

## Scope

This is the built-in metadata exposed on ordinary MCP `list_apps` rows as `intents`. It is part of the default listing surface even though the raw daemon `intent` execution command and its URL-building implementations are a separate optional extension. This document closes exact bundle keys, ordered intent names, and ordered required/optional parameter names. Human-readable descriptions below are **paraphrases, not byte-exact description text**. Long original descriptions are not reproduced. `APP_USAGE_CONTRACT.md` specifies row selection/merge/sort and full output shape.

Primary evidence is the static initializer `AppCommandRegistry.entries` at **0x10002f184–0x10002fc08**, lookup `intents(for:)` at **0x1000309d4–0x100030a80**, the mapper **0x100080884–0x1000810a8**, and raw data in `analysis/native/arm64.macho`. All VAs are unslid arm64. No executable or registered intent was run.

## Lookup and emitted schema

- Mapper calls `intents(for: bundleId)` only for non-nil bundle (`0x100080924–940`). Nil bundle produces [] at `0x100080948`.
- Registry is lazy initialized once (`0x1000309ec–9f8`, `0x100030a68–a78`) and held at `0x1000b38a0`. Exact Swift String dictionary lookup at `0x100030a14–a20`: no lowercasing, suffix matching, identifier aliasing, wildcard, or fallback by name/path. An unregistered bundle yields [] (`0x100030a44–a48`).
- The initialized dictionary has exactly **7 keys**; capacity7 at `0x10002f884`, seven inserts `0x10002f89c–fb5c`, seven literal tuples destroyed at `0x10002fb90`. They contain **15 total intents** in the per-app order below. No system introspection or installed-app API contributes new intent metadata.
- Output for each intent: `{name:String, description:String, required_params:[String], optional_params:[String]}`. The mapper copies all four values; it does not emit the stored URL builder closure. Four dictionary literal values are built `0x100080cb0–d50`; capacity4 `0x100080d54`; order-preserving append loop `0x100080fd4–fe8`.
- These arrays are metadata listing parameter **names**, not per-parameter typed JSON schemas. Do not manufacture enum schemas or claim the descriptions enforce additional validations. Full URL-building behavior is outside this closure.
- `sky_list_apps` drops the entire `intents` field in its adapter mapping.

## Exact ordered registry facts

| Exact bundle key | Index | Exact intent name | required_params | optional_params | Description meaning (paraphrased) |
|---|---:|---|---|---|---|
| com.netease.163music | 0 | launch | [] | [] | Start NetEase Music quietly |
| com.netease.163music | 1 | play_song | [song_id] | [] | Select a NetEase song by numeric identifier |
| com.netease.163music | 2 | open_playlist | [playlist_id] | [] | Navigate to a NetEase playlist by numeric identifier |
| com.netease.163music | 3 | play_daily_recommendation | [] | [] | Navigate to daily recommendations |
| com.netease.163music | 4 | open_history_recommend | [] | [] | Navigate to past recommendations |
| com.netease.163music | 5 | open_route | [route] | [] | Navigate through the app's route bridge; metadata describes multiple route candidates |
| com.apple.Music | 0 | launch | [] | [] | Start Music in the background |
| com.apple.Music | 1 | open_url | [url] | [] | Open an Apple Music link |
| com.spotify.client | 0 | launch | [] | [] | Start Spotify in the background |
| com.spotify.client | 1 | play_uri | [uri] | [] | Play content identified by a Spotify URI |
| com.apple.mail | 0 | compose | [] | [to, subject, body, cc, bcc] | Prepare a mail composition with optional addressing and content |
| com.apple.Safari | 0 | open_url | [url] | [] | Open a full HTTP/HTTPS address in Safari |
| com.tencent.xinWeChat | 0 | launch | [] | [] | Start WeChat |
| com.tinyspeck.slackmacgap | 0 | launch | [] | [] | Start Slack |
| com.tinyspeck.slackmacgap | 1 | open_channel | [team_id, channel_id] | [] | Navigate to a Slack channel or direct-message conversation |

The table order across different bundles is explanatory only: app rows still follow AppUsage's sort. Within each bundle the displayed intent order is exact.

## Instruction proof by group

Intent in-memory stride is0x40: name String at +0, description String +0x10, requiredParams array +0x20, optionalParams array +0x28, URL builder function/context +0x30/+0x38. Heap arrays begin elements at +0x20. Stored closures are cited only as boundary evidence, not executed or reproduced.

### NetEase Music

- Key: C-string **0x100092810**, loaded `0x10002f1f0–204`; dictionary insertion `0x10002f89c–8e0`
- Six-element array uses count/capacity pair `(6,12)` from raw **0x10008efd0**, loaded/stored `0x10002f230–238`
- `launch`: name small-string stores `0x10002f24c–25c`; description reference `0x10002f240` to **0x100092830**; both parameter arrays empty `0x10002f268–270`
- `play_song`: name `0x10002f2b4–2cc`; description **0x100092870** reference `0x10002f284`; required array **0x1000b0128** initialized `0x10002f2a4–2b0`; required/optional stored `0x10002f2d8`
- `open_playlist`: name `0x10002f308–328`; description **0x1000928b0** reference `0x10002f2ec`; required array **0x1000b0160** `0x10002f2f8–304`; arrays stored `0x10002f33c`
- `play_daily_recommendation`: name C-string **0x1000928f0**, reference/store `0x10002f34c–36c`; description **0x100092910**, reference `0x10002f360`; empty arrays `0x10002f388`
- `open_history_recommend`: name C-string **0x100092990**, reference/store `0x10002f398–3bc`; description **0x1000929b0**, reference `0x10002f3ac`; empty arrays `0x10002f3d4`
- `open_route`: name small-string stores `0x10002f404–41c`; description **0x100092a00**, reference `0x10002f3e4`; required array **0x1000b0198** `0x10002f3f4–400`; arrays stored `0x10002f430`

### Apple Music

- Exact key `com.apple.Music` is encoded in immediate words `0x6c7070612e6d6f63` / `0xef636973754d2e65`, assembled `0x10002f8fc–920` and inserted at `0x10002f950`
- Two-element array uses raw header `(2,4)` **0x10008fc80**, loaded `0x10002f464–478`
- `launch`: `0x10002f484–494`; description **0x100092b30** reference `0x10002f474`; empty arrays `0x10002f4a0`
- `open_url`: `0x10002f4d4–4e8`; description **0x100092b60** reference `0x10002f4b4`; required array **0x1000b01d0** `0x10002f4c0–4d0`; arrays stored `0x10002f4f8`

### Spotify

- Key C-string **0x100092ba0**, reference `0x10002f50c`, dictionary insertion `0x10002f978–9b8`
- Two-element array: header copy `0x10002f54c–550`
- `launch`: inherited name registers stored `0x10002f55c`; description **0x100092bc0** reference `0x10002f548`; empty arrays `0x10002f570`
- `play_uri`: `0x10002f5a0–5bc`; description **0x100092be0** reference `0x10002f584`; required array **0x1000b0208** initialized `0x10002f590–59c`; required pointer at `0x10002f5c0`, optional empty pointer `0x10002f5cc`

### Mail

- Exact lower-case `com.apple.mail`: key immediate suffix `0xee006c69616d2e65` assembled `0x10002f9dc–9e8`; inserted `0x10002fa1c`
- One-element array raw header `(1,2)` **0x10008e940**, loaded `0x10002f610–61c`
- `compose`: `0x10002f644–658`; description **0x100092c50** reference `0x10002f624`; optional five-string array **0x1000b0240** `0x10002f630–640`; `stp x20,x0,[x23,#0x40]` at `0x10002f664` proves required empty and optional populated, in that order

### Safari

- Key C-string **0x100092ca0**, reference `0x10002f678`; dictionary insertion `0x10002fa40–a84`
- One-element header copied `0x10002f6ac–6b0`
- `open_url`: `0x10002f6d4–6f8`; description **0x100092cc0** reference `0x10002f6b8`; required array **0x1000b02b8** `0x10002f6c4–6d0`; required pointer stored `0x10002f6fc`, optional empty `0x10002f708`

### WeChat

- Exact case-sensitive key C-string **0x100092d00**, reference `0x10002f714`; dictionary insertion `0x10002faa8–fae4`
- One-element header `0x10002f740–744`
- `launch`: `0x10002f748–758`; short description inline `0x10002f75c–778`; empty arrays `0x10002f77c`

### Slack

- Key C-string **0x100092d20**, reference `0x10002f78c`, dictionary insertion `0x10002fb00–b4c`
- Two-element header `0x10002f7c8–7cc`
- `launch`: stored `0x10002f7d0`; short description inline `0x10002f7d4–7f0`; empty arrays `0x10002f7f4`
- `open_channel`: `0x10002f824–840`; description **0x100092d40**, reference `0x10002f804`; required array **0x1000b02f0** initialized `0x10002f814–820`; arrays stored `0x10002f854`

## Raw parameter-array proof

Each static Swift array's `UInt64` count is at base+0x10; elements are16-byte String records from base+0x20. These elements use inline small-string representation: first bytes are UTF-8 characters, top byte of second word is0xe0|length. Primary raw records:

| Static base VA | Count | Element values, in order | Small-string length tags |
|---|---:|---|---|
| 0x1000b0128 | 1 | song_id | e7 |
| 0x1000b0160 | 1 | playlist_id | eb |
| 0x1000b0198 | 1 | route | e5 |
| 0x1000b01d0 | 1 | url | e3 |
| 0x1000b0208 | 1 | uri | e3 |
| 0x1000b0240 | 5 | to, subject, body, cc, bcc | e2,e7,e4,e2,e3 |
| 0x1000b02b8 | 1 | url | e3 |
| 0x1000b02f0 | 2 | team_id, channel_id | e7,ea |

Empty arrays use x20, initialized by loading GOT **0x1000a4e88** at `0x10002f268–26c`; indirect-symbol table identifies **__swiftEmptyArrayStorage**. Raw chained-bind slot value is `0x80100000000001c9`. Thus the empty parameter lists above are proven empty arrays, not unresolved registers or omitted values.

## Conformance checks

- Arbitrary or nil bundle -> []
- Exact bundle casing matters: `com.apple.Music` and `com.tencent.xinWeChat` must not be lowercased before lookup
- NetEase array has6 ordered elements; Music2;Spotify2;Mail1;Safari1;WeChat1;Slack2
- Mail compose has zero required params and exactly5 optional params in `to,subject,body,cc,bcc` order
- Slack open_channel requires both team_id and channel_id in that order
- No description-summary column in this document should be mistaken for the original emitted description string; replicas may preserve functional metadata while explicitly excluding byte-identical prose from parity claims
