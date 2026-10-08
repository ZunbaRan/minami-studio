> 来源：用户提供的 .164 研究资料 `chapters/10_附录MCP全契约.md`；原文件 SHA256 `41291417c0a8add9adb9fc1e0559d5e66648ecb790476a002cd786c6010d897e`；全文件 1–449 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

# 附录 A 全部 MCP 工具逐字段契约
本附录为静态Zod契约的独立转录，不是运行tools/list抓包。未断言未知属性strip行为。必需字段在schema层校验；通过schema不代表handler必要条件、ref或OS动作成功。省略与null不同。英文键值保持机器契约原意；数值默认和转发优先级按每项单列。

## launch_app
native cmd：launch_app；应用gate：True；证据：MCP.tool.launch_app

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| bundle | 是 | string | 未单列 |
| activates | 否 | boolean | false |

逐字段转发与优先级：
- bundle：bundle
- activates：activates ?? false

返回约定：native-data-as-pretty-JSON-text
批准目标：bundle only (no PID/ref resolution)

## list_apps
native cmd：list_apps；应用gate：False；证据：MCP.tool.list_apps

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| days | 否 | integer; maximum=90 | 14 |

逐字段转发与优先级：
- days：positive integer days else 14

返回约定：native-data-as-pretty-JSON-text

## get_app_state
native cmd：get_app_state；应用gate：False；证据：MCP.tool.get_app_state

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |
| depth | 否 | integer; maximum=20 | 6 |
| interactive_only | 否 | boolean | true |
| screenshot_max_width | 否 | integer | 1280 |
| auto_launch | 否 | boolean | true |

逐字段转发与优先级：
- bundle：raw bundle
- pid：positive integer pid else omitted
- window_id：positive window_id else omitted
- depth：nonnegative integer depth else 6
- interactive_only：arg ?? true
- include_screenshot：true
- screenshot_max_width：positive integer else 1280
- auto_launch：arg ?? true

返回约定：optional-playbook+JSON-without-screenshot+path-read-JPEG-image-or-text-warning
边角：
- Neither bundle nor pid is schema-required; daemon decides missing-target behavior.
- No disable_diff argument supplied.

## click
native cmd：click；应用gate：True；证据：MCP.tool.click

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| ref | 否 | string | 未单列 |
| x | 否 | number | 未单列 |
| y | 否 | number | 未单列 |
| coord_space | 否 | string; 枚举 screenshot, screen | screenshot |
| button | 否 | string; 枚举 left, right, middle | left |
| click_count | 否 | integer; maximum=3 | 1 |
| strategy | 否 | string; 枚举 auto, physical, ax | auto |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- common：["button","positive click_count else 1","strategy","show_cursor=true"]
- ref_branch：["ref"]
- coordinate_branch：["x","y","coord_space","normalized pid","normalized bundle"]

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)
边角：
- Truthy ref takes precedence. Otherwise both x and y must exist.
- window_id is not sent to action; may be sent to post-action capture.

## perform_secondary_action
native cmd：perform_secondary_action；应用gate：True；证据：MCP.tool.perform_secondary_action

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| ref | 否 | string | 未单列 |
| x | 否 | number | 未单列 |
| y | 否 | number | 未单列 |
| coord_space | 否 | string; 枚举 screenshot, screen | screenshot |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- common：["show_cursor=true"]
- ref_branch：["ref"]
- coordinate_branch：["x","y","coord_space","normalized pid","normalized bundle"]

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)
边角：
- No action string exposed in ordinary tool.

## drag
native cmd：drag；应用gate：True；证据：MCP.tool.drag

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| start_x | 是 | number | 未单列 |
| start_y | 是 | number | 未单列 |
| end_x | 是 | number | 未单列 |
| end_y | 是 | number | 未单列 |
| coord_space | 否 | string; 枚举 screenshot, screen | screenshot |
| button | 否 | string; 枚举 left, right, middle | left |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- forwarded：["start_x","start_y","end_x","end_y","coord_space","button","normalized pid","normalized bundle"]
- show_cursor：true

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)

## type_text
native cmd：type_text；应用gate：True；证据：MCP.tool.type_text

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| text | 是 | string | 未单列 |
| ref | 否 | string | 未单列 |
| input_method | 否 | string; 枚举 auto, physical, unicode, ax | auto |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- forwarded：["text","ref","input_method","normalized pid","normalized bundle"]

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)
边角：
- Displayed text length uses JS UTF-16 code-unit count.

## press_key
native cmd：press_key；应用gate：True；证据：MCP.tool.press_key

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| key | 是 | string | 未单列 |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- forwarded：["key","normalized pid","normalized bundle"]

返回约定：delivery-aware-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)

## scroll
native cmd：scroll；应用gate：True；证据：MCP.tool.scroll

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| ref | 是 | string | 未单列 |
| direction | 是 | string; 枚举 up, down, left, right | 未单列 |
| pages | 否 | integer; maximum=20 | 1 |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- forwarded：["ref","direction"]
- pages：positive integer else 1
- show_cursor：true

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)

## set_value
native cmd：set_value；应用gate：True；证据：MCP.tool.set_value

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| ref | 是 | string | 未单列 |
| value | 是 | anyOf [{"type":"string"},{"type":"number"},{"type":"boolean"}] | 未单列 |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- forwarded：["ref","value"]

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)

## select_text
native cmd：select_text；应用gate：True；证据：MCP.tool.select_text

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| ref | 是 | string | 未单列 |
| text | 是 | string | 未单列 |
| prefix | 否 | string | 未单列 |
| suffix | 否 | string | 未单列 |
| selection_type | 否 | string; 枚举 text, cursor_before, cursor_after | text |
| bundle | 否 | string | 未单列 |
| pid | 否 | integer | 未单列 |
| window_id | 否 | integer | 未单列 |

逐字段转发与优先级：
- forwarded：["ref","text","prefix","suffix","selection_type"]

返回约定：action-summary+conditional-image
批准目标：bundle only (no PID/ref resolution)

## sky_list_apps
native cmd：list_apps；应用gate：False；证据：MCP.tool.sky_list_apps
无业务输入字段。

逐字段转发与优先级：


返回约定：JSON-array-text-app-list-projection

## sky_get_app_state
native cmd：get_app_state；应用gate：True；证据：MCP.tool.sky_get_app_state

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| disableDiff | 否 | boolean | 未单列 |

逐字段转发与优先级：
- bundle：app
- disable_diff：disableDiff === true OR no cached ref indices

返回约定：single-JSON-text-containing-app-screenshot-url-and-rendered-index-text
批准目标：app
边角：
- No snapshot defaults overridden here. Timeout is default 20s.
- State screenshot uses data_url or url; does not read path.

## sky_click
native cmd：click；应用gate：True；证据：MCP.tool.sky_click

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| element_index | 否 | integer | 未单列 |
| x | 否 | number | 未单列 |
| y | 否 | number | 未单列 |
| click_count | 否 | integer | 1 |
| mouse_button | 否 | string; 枚举 left, right, middle, l, r, m | left |

逐字段转发与优先级：
- common：["normalized mouse_button as button","click_count ?? 1"]
- index_branch：["skyRefFor(app,element_index) as ref"]
- coordinate_branch：["x","y","app as bundle","coord_space=screenshot"]

返回约定：action-summary+conditional-image
批准目标：app
边角：
- Index branch wins when typeof element_index is number.
- No max bound on click_count; no show_cursor passed.

## sky_press_key
native cmd：press_key；应用gate：True；证据：MCP.tool.sky_press_key

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| key | 是 | string | 未单列 |

逐字段转发与优先级：
- bundle：app
- key：keysym aliases normalized

返回约定：delivery-aware-summary+image
批准目标：app

## sky_type_text
native cmd：type_text；应用gate：True；证据：MCP.tool.sky_type_text

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| text | 是 | string | 未单列 |

逐字段转发与优先级：
- bundle：app
- text：text

返回约定：action-summary+conditional-image
批准目标：app
边角：
- No explicit ref/input_method.

## sky_scroll
native cmd：scroll；应用gate：True；证据：MCP.tool.sky_scroll

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| element_index | 是 | integer | 未单列 |
| direction | 是 | string; 枚举 up, down, left, right, u, d, l, r | 未单列 |
| pages | 否 | number | 1 |

逐字段转发与优先级：
- ref：skyRefFor(app,element_index)
- direction：normalized direction
- pages：pages ?? 1

返回约定：action-summary+conditional-image
批准目标：app
边角：
- Unlike ordinary scroll, pages is any number with no max or positive normalization.

## sky_set_value
native cmd：set_value；应用gate：True；证据：MCP.tool.sky_set_value

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| element_index | 是 | integer | 未单列 |
| value | 是 | string | 未单列 |

逐字段转发与优先级：
- ref：skyRefFor(app,element_index)
- value：value

返回约定：action-summary+conditional-image
批准目标：app
边角：
- String only; ordinary set_value accepts boolean and number too.

## sky_drag
native cmd：drag；应用gate：True；证据：MCP.tool.sky_drag

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| from_x | 是 | number | 未单列 |
| from_y | 是 | number | 未单列 |
| to_x | 是 | number | 未单列 |
| to_y | 是 | number | 未单列 |

逐字段转发与优先级：
- bundle：app
- start_x：from_x
- start_y：from_y
- end_x：to_x
- end_y：to_y
- coord_space：screenshot

返回约定：action-summary+conditional-image
批准目标：app

## sky_perform_secondary_action
native cmd：perform_secondary_action；应用gate：True；证据：MCP.tool.sky_perform_secondary_action

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| element_index | 是 | integer | 未单列 |
| action | 是 | string | 未单列 |

逐字段转发与优先级：
- ref：skyRefFor(app,element_index)
- action：action

返回约定：action-summary+conditional-image
批准目标：app
边角：
- Unlike ordinary secondary action, explicit action string is forwarded.

## sky_select_text
native cmd：select_text；应用gate：True；证据：MCP.tool.sky_select_text

| 字段 | 必需 | 类型与边界 | 包装默认 |
|---|---|---|---|
| app | 是 | string | 未单列 |
| element_index | 是 | integer | 未单列 |
| text | 是 | string | 未单列 |
| prefix | 否 | string | 未单列 |
| suffix | 否 | string | 未单列 |
| selection_type | 否 | string; 枚举 text, cursor_before, cursor_after | text |

逐字段转发与优先级：
- ref：skyRefFor(app,element_index)
- forwarded：["text","prefix","suffix","selection_type"]

返回约定：action-summary+conditional-image
批准目标：app

## permissions
native cmd：permissions；应用gate：False；证据：MCP.tool.permissions
无业务输入字段。

逐字段转发与优先级：


返回约定：native-data-as-pretty-JSON-text

## grant
native cmd：grant；应用gate：False；证据：MCP.tool.grant
无业务输入字段。

逐字段转发与优先级：


返回约定：native-data-as-pretty-JSON-text

## 共用传输参数
- mcp：stdio JSON-RPC via MCP SDK
- native：Unix-domain stream; UTF-8 JSON lines
- request_fields：{"id":"random 8 bytes encoded as hex","cmd":"command string","args":"JSON object"}
- response_fields：{"id":"request correlation","ok":"truthy success test","data":"successful result","error":{"message":"string","code":"attached to JS Error","hint":"attached to JS Error"}}
- request_timeout_ms：20000
- ordinary_state_timeout_ms：30000
- post_action_state_timeout_ms：30000
- sky_state_timeout_ms：20000
- daemon_idle_seconds：900
- spawn_connect_retry_window_ms：4000
- retry_delay_ms：100
- timeout_starts：after ensureConnected resolves
- socket_scope：helper path string SHA1 first8, not binary hash
- action_auto_retry：false
- late_response：ignored after pending removal
- disconnect：reject every pending; next call reconnects
- cancel_forwarding：No AbortSignal or cancel command in application DaemonClient
- evidence：["MCP.transport","MCP.sdk-cancel","MCP.sdk-handler-abort","MCP.stdio"]

## 共用结果语义
- native_failure：SDK tool error text+isError:true; code/hint not emitted by ordinary error wrapper
- approval_denied：text content without isError:true
- key_suppressed：delivered=false => semantic not-delivered text, not isError
- key_menu_route：via=menu_ax_press => menu route text
- post_action_capture_failure：summary plus warning text, not action error
- ordinary_state_image：read screenshot.path, base64 image/jpeg block
- sky_state_image：data_url || url embedded inside JSON text, path alone ignored
- ref_only_capture：none unless caller separately supplies bundle or positive pid