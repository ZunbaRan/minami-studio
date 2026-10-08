# 原始 stdio MCP 局部 tool.select_text

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36260–36293`（inclusive），原字节半开区间 `[1355824, 1357682]`；区间SHA256 `8c90454c8f0527fe229d347442e12def2b7d8486b439efcac2bccd9b465ba799`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36260

```javascript
36260  server.registerTool(
36261    "select_text",
36262    {
36263      description: "Select a run of text inside an editable element \u2014 or place the cursor immediately before/after it \u2014 without touching the rest of the field. Use this instead of set_value when the user's existing text must survive, and instead of faking a selection with key chords. Pass prefix/suffix when the same text appears more than once.",
36264      inputSchema: {
36265        ref: external_exports3.string().describe("Element index/ref from the latest get_app_state."),
36266        text: external_exports3.string().describe("Text to locate within the editable element."),
36267        prefix: external_exports3.string().optional().describe("Text immediately before the target, to disambiguate repeats."),
36268        suffix: external_exports3.string().optional().describe("Text immediately after the target, to disambiguate repeats."),
36269        selection_type: external_exports3.enum(["text", "cursor_before", "cursor_after"]).optional().describe("Select the text itself (default), or collapse the cursor before/after it."),
36270        ...targetShape
36271      }
36272    },
36273    async (args, _extra) => gated("select_text", args, async () => {
36274      const target = normalizeTarget(args);
36275      await daemon.call("select_text", {
36276        ref: args.ref,
36277        text: args.text,
36278        prefix: args.prefix,
36279        suffix: args.suffix,
36280        selection_type: args.selection_type ?? "text"
36281      });
36282      return respond(`selected ${JSON.stringify(args.text)} in ${args.ref}`, target);
36283    })
36284  );
36285  var playbookOnce = new PlaybookOnce();
36286  var skyIndexMap = /* @__PURE__ */ new Map();
36287  function skyRefFor(app, index) {
36288    const refs = skyIndexMap.get(app);
36289    if (!refs || index < 0 || index >= refs.length) {
36290      throw new Error(`element_index ${index} is not valid for "${app}" \u2014 call sky_get_app_state first, then use an index from its text.`);
36291    }
36292    return refs[index];
36293  }

```
