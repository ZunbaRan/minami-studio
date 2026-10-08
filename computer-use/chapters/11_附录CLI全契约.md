> 来源：用户提供的 .164 研究资料 `chapters/11_附录CLI全契约.md`；原文件 SHA256 `00d97500f0abbdf631b9d1afd61a35546c71a56ec4c440849dad2255a15dea06`；全文件 1–352 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# 附录 B 全部 CLI 命令逐字段契约
22个功能canonical命令，加help共23项；launch是launch_app别名，总24个可识别字符串。这里是JavaScript CLI，不是native helper的daemon/version/help启动CLI。

## 共用解析器
- base_url：ALMA_API_URL || http://localhost:23001
- valued_flags：--foo=value OR --foo value; scans full args, returns first matching value
- boolean_flags：exact --foo presence only; --foo=true does not count
- json_flag：Only commands explicitly branching asJson honor it; not a universal raw-output mode.
- numeric_coercion：parseInt/parseFloat may accept numeric prefix; most integer flag paths do not validate finite/range; JSON.stringify(NaN/Infinity) emits null.
- target：digits-only string becomes PID; any other nonempty string becomes bundle (negative PID-like string becomes bundle)
- pre_action_common_parser：After snap handling and before action selection, button is validated against left/right/middle, click_count parsed, showCursor=!no-cursor. Thus an invalid --button can fail even an unrelated later command.
- unknown_subcommand：stderr usage hint then exit1
- http：Content-Type application/json; body JSON.stringify when body argument is defined; no per-request AbortSignal/timeout; non2xx prints HTTP error and exit1; JSON decoded only if response content-type contains application/json; otherwise text; fetch exceptions print connection error and exit1
- semantic_success：HTTP2xx alone returns body; callsite determines meaning. Some callsites ignore body entirely.
- safety_note：This catalog describes quirks for compatibility testing, not a recommendation to copy misleading success or lax validation. Prefer explicit typed outcome in a new implementation.

## help
别名：[]
位置参数：[]
flags与默认：


HTTP顺序：
无HTTP调用。

输出与退出语义：Usage text; also used when subcommand missing. No HTTP.
证据：CLI行[8323, 8366]；半开byte [392291, 394410]；范围SHA256 c89fe8ff022a37a4cff3b558f46457518a5f72f662d5376f28afda805c51a4fe

## status
别名：[]
位置参数：[]
flags与默认：


HTTP顺序：
1. {"method":"GET","route":"/api/computer-use/status","body":null,"body_note":"null here means no body argument, not JSON null"}

输出与退出语义：prettyPrint native host status
证据：CLI行[8368, 8372]；半开byte [394411, 394578]；范围SHA256 d3c4e106b0a0a9b46cf8da140938039819bca47c36019d35ba20b37ec729ea83

## doctor
别名：[]
位置参数：[]
flags与默认：


HTTP顺序：
1. {"method":"GET","route":"/api/computer-use/status","body":null,"body_note":"null here means no body argument, not JSON null"}
2. {"method":"GET","route":"/api/computer-use/ping","body":null,"body_note":"null here means no body argument, not JSON null"}
3. {"method":"GET","route":"/api/computer-use/permissions","body":null,"body_note":"null here means no body argument, not JSON null"}

输出与退出语义：Helper path/platform, daemon version/uptime, AX and screen recording grant status. If AX missing gives instruction.
- If status.available false: prints helper missing and exits1 before ping/permissions.
- Missing AX grant alone does not exit1.
证据：CLI行[8374, 8393]；半开byte [394579, 395741]；范围SHA256 d31f962693d3ef08444552f8d2d5e8aa2d166c37163ec29b7af79ace6675d4e8

## grant
别名：[]
位置参数：[]
flags与默认：


HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/grant","body":null,"body_note":"null here means no body argument, not JSON null"}

输出与退出语义：Branches on response.accessibility; already granted or requested-dialog summary. Does not poll.
证据：CLI行[8395, 8400]；半开byte [395742, 396072]；范围SHA256 49cc434cbb8d884a08f449726ab684d5c02fa391dd2b55624763ec8e9ce56a47

## apps
别名：[]
位置参数：[]
flags与默认：
- json：{"boolean":true}

HTTP顺序：
1. {"method":"GET","route":"/api/computer-use/apps","body":null,"body_note":"null here means no body argument, not JSON null"}

输出与退出语义：--json pretty JSON; otherwise active marker, PID, bundle, name per app
证据：CLI行[8402, 8413]；半开byte [396073, 396547]；范围SHA256 90e9f771445018833d9c0c4a56459fdb7d5005a64678e95d01bdfa3a72075f41

## launch_app
别名：["launch"]
位置参数：["bundle"]
flags与默认：
- activates：{"boolean":true,"default":false}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/launch_app","body":{"bundle":"args[2]","activates":"presence of exact --activates"},"body_note":""}

输出与退出语义：app name or bundle, pid, foreground/background label from response.activates
- Missing/falsy bundle exits1.
证据：CLI行[8415, 8425]；半开byte [396548, 397113]；范围SHA256 08938d14a5b943fa24e0ca7154555c50df02580f4b48e79f177c68db751a84a8

## list_apps
别名：[]
位置参数：[]
flags与默认：
- days：{"destination":"days","conversion":"parseInt(value,10)","default":"omitted; daemon default"}
- json：{"boolean":true}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/list_apps","body":{"days":"only when truthy flag value, parseInt"},"body_note":""}

输出与退出语义：--json pretty JSON; otherwise active/running marker, pid, bundle, name, optional use_count
- No local days min/max bound.
证据：CLI行[8427, 8443]；半开byte [397114, 397885]；范围SHA256 e8edda1879acda413b2d21091d18d79a3fa534cfcdc7ad598c9d972a4ad439d4

## windows
别名：[]
位置参数：[{"argument":"target","parse":"digits-only => pid=parseInt; otherwise bundle=string; missing => {}"}]
flags与默认：
- json：{"boolean":true}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/windows","body":{"target":"parsed target"},"body_note":""}

输出与退出语义：--json raw JSON; otherwise window focused marker,id,title,width/height, minimized flag
- Requires truthy parsed bundle or pid; pid0 rejected.
证据：CLI行[8445, 8462]；半开byte [397886, 398671]；范围SHA256 d39c34f28ed166cc54abdae98b29c7bbe4b1d0659389633ee7b70ba951119563

## get_app_state
别名：[]
位置参数：[{"argument":"target","parse":"digits-only => pid=parseInt; otherwise bundle=string; missing => {}"}]
flags与默认：
- window：{"destination":"window_id","conversion":"parseInt(value,10)","default":"omit"}
- depth：{"destination":"depth","conversion":"parseInt(value,10)","default":"omit"}
- all：{"boolean":true,"effect":"interactive_only=false"}
- no-shot：{"boolean":true,"effect":"include_screenshot=false"}
- shot-out：{"destination":"screenshot_path","conversion":"string"}
- shot-max-width：{"destination":"screenshot_max_width","conversion":"parseInt(value,10)","default":"omit"}
- json：{"boolean":true}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/get_app_state","body":{"target":"parsed target","window_id":"optional parsed window","depth":"optional parsed depth","interactive_only":"false iff --all else omitted","include_screenshot":"false iff --no-shot else omitted","screenshot_path":"truthy --shot-out else omitted","screenshot_max_width":"truthy --shot-max-width parsed else omitted"},"body_note":""}

输出与退出语义：--json pretty native data; otherwise app/window header,screenshot path+size or error,snapshot_id,element rows. No image emitted to stdout.
- Requires truthy target.
- No screenshot files opened; prints paths only.
- Rows: ref,role,subrole,title else value truncated60 else description truncated60; disabled uses !enabled.
证据：CLI行[8464, 8506]；半开byte [398672, 401024]；范围SHA256 f99fc9426bf5aea2f374a815b315559639e969c74b80d1a6139043845a1aef9e

## snap
别名：[]
位置参数：[{"argument":"target","parse":"digits-only => pid=parseInt; otherwise bundle=string; missing => {}"}]
flags与默认：
- window：{"destination":"window_id","conversion":"parseInt(value,10)","default":"omit"}
- depth：{"destination":"depth","conversion":"parseInt(value,10)","default":"omit"}
- all：{"boolean":true,"effect":"interactive_only=false"}
- json：{"boolean":true}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/snap","body":{"target":"parsed target","window_id":"optional","depth":"optional","interactive_only":"false iff --all"},"body_note":""}

输出与退出语义：--json native data; otherwise app/window/snapshot and element rows
- Requires truthy target.
证据：CLI行[8508, 8539]；半开byte [401025, 402722]；范围SHA256 4ae3ab39b4645ea217b02bbe6c1fb77f3ea3918e6dcc9de5b07216e3747ce3db

## click
别名：[]
位置参数：["ref OR --pixel x y"]
flags与默认：
- button：{"values":["left","right","middle"],"default":"left"}
- clicks：{"destination":"click_count","conversion":"parseInt(value,10)","default":1}
- no-cursor：{"boolean":true,"effect":"show_cursor=false; default true"}
- pixel：{"boolean":true,"consumes":"two following args parsed float"}
- pid：{"destination":"pid","conversion":"parseInt(value,10)","default":"omit"}
- strategy：{"default":"auto","local_enum_validation":false}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/click","body":{"pixel_branch":"x,y,button,click_count,show_cursor,pid?","ref_branch":"ref,strategy,button,click_count,show_cursor"},"body_note":""}

输出与退出语义：pixel: coordinates with response.button/clicks; ref:response.clicked/strategy/button/clicks
- Pixel branch selected by exact --pixel anywhere; finite x/y required.
- Ref branch requires truthy args[2].
- No coord_space sent; no bundle flag; pid only forwarded in pixel branch.
- click_count uses parseInt without bounds/finite validation.
证据：CLI行[8554, 8583]；半开byte [403171, 404794]；范围SHA256 055b214dc60a291c2746be352c9907ceee3ca0d068e030f2f3b39f2bf3205896

## perform_secondary_action
别名：[]
位置参数：["ref OR --pixel x y"]
flags与默认：
- pixel：{"boolean":true,"consumes":"two following floats"}
- pid：{"destination":"pid","conversion":"parseInt(value,10)","default":"omit"}
- no-cursor：{"boolean":true,"effect":"show_cursor=false; default true"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/perform_secondary_action","body":{"pixel_branch":"x,y,show_cursor,pid?","ref_branch":"ref,show_cursor"},"body_note":""}

输出与退出语义：Generic secondary-click summary; response ignored
- Finite coords or truthy ref required.
- No explicit action string or coord_space.
证据：CLI行[8585, 8609]；半开byte [404795, 406000]；范围SHA256 87e102fff0d45d9cd5f9c3a3e36db1944da7f58cae9080986ff7e095210c6c73

## drag
别名：[]
位置参数：["x1","y1","x2","y2"]
flags与默认：
- pid：{"destination":"pid","conversion":"parseInt(value,10)","default":"omit"}
- button：{"values":["left","right","middle"],"default":"left"}
- no-cursor：{"boolean":true,"effect":"show_cursor=false; default true"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/drag","body":{"start_x":"parseFloat x1","start_y":"parseFloat y1","end_x":"parseFloat x2","end_y":"parseFloat y2","button":"buttonArg","show_cursor":"!hasFlag(no-cursor)","pid":"optional"},"body_note":""}

输出与退出语义：Coordinate summary; response ignored
- All four parsed floats must be finite.
- No coord_space/bundle/window parameter sent.
证据：CLI行[8611, 8626]；半开byte [406001, 406828]；范围SHA256 ae0c8e864f466a26d122d31a5f10b7f2e939b06c0769ada2ce974e01db4a9950

## type_text
别名：[]
位置参数：["text"]
flags与默认：
- pid：{"destination":"pid","conversion":"parseInt(value,10)","default":"omit"}
- bundle：{"destination":"bundle"}
- ref：{"destination":"ref"}
- input-method：{"destination":"input_method","alias":"input_method","default":"omitted; daemon chooses"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/type_text","body":{"text":"args[2]","pid":"optional","bundle":"optional truthy","ref":"optional truthy","input_method":"truthy input-method OR input_method"},"body_note":""}

输出与退出语义：Text length in JS UTF-16 code units; response ignored
- Only undefined text rejected; empty text allowed.
- No local method-enum validation.
证据：CLI行[8628, 8646]；半开byte [406829, 407651]；范围SHA256 f99950b9325d93d93e2a24fcbfdaa3cbc009264991a7a3315d232fd9e6f8cc1b

## press_key
别名：[]
位置参数：["combo"]
flags与默认：
- pid：{"destination":"pid","conversion":"parseInt(value,10)","default":"omit"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/press_key","body":{"key":"combo","pid":"optional"},"body_note":""}

输出与退出语义：Generic pressed summary; ignores delivered/route even for delivered=false
- Falsy combo exits1.
- No bundle/ref flag.
证据：CLI行[8648, 8660]；半开byte [407652, 408175]；范围SHA256 aa4b98999e5381d2ea8aa86416498741a44c72d252f64fdba284fba4fce99805

## set_value
别名：[]
位置参数：["ref","value"]
flags与默认：


HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/set_value","body":{"ref":"ref","value":"exact true/false -> bool; nonempty Number-convertible -> number; else original string"},"body_note":""}

输出与退出语义：Generic assignment summary; response ignored
- Truthy ref and defined raw value required.
- Number conversion uses JS Number, not parseInt; whitespace-only retained string.
证据：CLI行[8662, 8678]；半开byte [408176, 408920]；范围SHA256 45e5c7ec6a99b8fec647170a2862558beed63eddb108e51e6b24695ae7b2c5fb

## type
别名：[]
位置参数：["ref","text"]
flags与默认：
- append：{"boolean":true,"effect":"replace=false; otherwise true"}
- no-cursor：{"boolean":true,"effect":"show_cursor=false; default true"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/type","body":{"ref":"ref","text":"text","replace":"!hasFlag(append)","show_cursor":"!hasFlag(no-cursor)"},"body_note":""}

输出与退出语义：response.length and response.typed
- Truthy ref and defined text required.
证据：CLI行[8680, 8691]；半开byte [408921, 409477]；范围SHA256 a8d86b88cc36bd4803c5148297e73e1d0ea63c702ba2c1545c0ccad70639d4f1

## press
别名：[]
位置参数：["ref","key"]
flags与默认：
- no-cursor：{"boolean":true,"effect":"show_cursor=false; default true"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/press","body":{"ref":"ref","key":"key","show_cursor":"!hasFlag(no-cursor)"},"body_note":""}

输出与退出语义：response.pressed
- Truthy ref/key required; no local key enum.
证据：CLI行[8693, 8703]；半开byte [409478, 409930]；范围SHA256 ec577cd192301a0918025bb210524b95ce5bd5b495113d92b0339f2cd1bbd2fe

## scroll
别名：[]
位置参数：["ref","direction"]
flags与默认：
- pages：{"destination":"pages","conversion":"parseInt(value,10)","default":1}
- no-cursor：{"boolean":true,"effect":"show_cursor=false; default true"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/scroll","body":{"ref":"ref","direction":"raw string","pages":"parseInt(flag(pages)||1,10)","show_cursor":"!hasFlag(no-cursor)"},"body_note":""}

输出与退出语义：response.scrolled and response.pages
- Truthy ref/direction only; no local direction enum, pages min/max, or finite check.
证据：CLI行[8705, 8716]；半开byte [409931, 410517]；范围SHA256 87f1c87e421a4b8cddf48b8534a79c60068a104e968fa4db31fadaafadf1d57e

## lens
别名：[]
位置参数：["mode?"]
flags与默认：


HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/lens","body":{"enabled":"missing for read-current in toggle case"},"body_note":""}
2. {"method":"POST","route":"/api/computer-use/lens","body":{"enabled":"boolean parsed or inverse read value"},"body_note":""}

输出与退出语义：response.enabled on/off
- on/true/1 => true; off/false/0 => false; toggle/undefined => read then invert.
- Invalid mode exits1.
- Explicit boolean mode makes only final call; toggle is two calls and non-atomic.
证据：CLI行[8718, 8736]；半开byte [410518, 411400]；范围SHA256 823f6f49baf1e00509b5a91ae685ca1c4ef7f262b67e30fd315d9347ffee9527

## raise
别名：[]
位置参数：[{"argument":"target","parse":"digits-only => pid=parseInt; otherwise bundle=string; missing => {}"}]
flags与默认：
- window：{"destination":"window_id","conversion":"parseInt(value,10)","default":"omit"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/raise","body":{"target":"parsed","window_id":"optional"},"body_note":""}

输出与退出语义：Generic raised; response ignored
- Requires truthy target.
- Reachable CLI route does not prove native actually foregrounds.
证据：CLI行[8738, 8750]；半开byte [411401, 411922]；范围SHA256 bd09ca64345a9d378b939e8b239da74a3d8fefc07dace9cc7b004f139d4c0e5d

## shot
别名：[]
位置参数：[{"argument":"target","parse":"digits-only => pid=parseInt; otherwise bundle=string; missing => {}"}]
flags与默认：
- window：{"destination":"window_id","conversion":"parseInt(value,10)","default":"omit"}
- out：{"destination":"out","default":"/tmp/alma-cu-${Date.now()}.jpg"}
- max-width：{"destination":"max_width","conversion":"parseInt(value,10)","default":"omit"}

HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/shot","body":{"target":"parsed, possibly empty","out":"truthy out or default timestamp JPEG path","window_id":"optional","max_width":"optional"},"body_note":""}

输出与退出语义：response.path,width,height
- Unlike windows/state/raise, does not locally require target.
证据：CLI行[8752, 8763]；半开byte [411923, 412489]；范围SHA256 49d001be1990077d311ce753a331d6667cb881a9ae6cb3514eac88775171294f

## shutdown
别名：[]
位置参数：[]
flags与默认：


HTTP顺序：
1. {"method":"POST","route":"/api/computer-use/shutdown","body":null,"body_note":"null here means no body argument, not JSON null"}

输出与退出语义：Generic stopped; response ignored
证据：CLI行[8765, 8769]；半开byte [412490, 412662]；范围SHA256 d218a65def652adefad7b1b40a5be0052deb74a0799a2e81f78ecea3e7b0611c