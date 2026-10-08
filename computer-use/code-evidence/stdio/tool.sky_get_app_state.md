# 原始 stdio MCP 局部 tool.sky_get_app_state

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36312–36343`（inclusive），原字节半开区间 `[1358295, 1360089]`；区间SHA256 `5b47c3822d0320d92289c6ecd70b39e9bdf687f84207f614a52d386d76f5650b`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36312

```javascript
36312  server.registerTool(
36313    "sky_get_app_state",
36314    {
36315      description: "Codex-compatible: capture the current state, screenshot and accessibility text for an app window. Returns {app, screenshot:{url}|null, text}; the text numbers each element so you can pass element_index to the other sky_ verbs.",
36316      inputSchema: {
36317        app: external_exports3.string().describe("App id, display name or process name from sky_list_apps."),
36318        disableDiff: external_exports3.boolean().optional().describe("Return the full accessibility tree instead of a diff from the previous tree.")
36319      }
36320    },
36321    async (args) => gated("sky_get_app_state", { bundle: args.app }, async () => {
36322      const haveIndices = (skyIndexMap.get(args.app)?.length ?? 0) > 0;
36323      const raw = await daemon.call("get_app_state", {
36324        bundle: args.app,
36325        disable_diff: args.disableDiff === true || !haveIndices
36326      });
36327      const elements = raw.elements ?? [];
36328      const bundle = raw.app?.bundle || args.app;
36329      const instructions = playbookOnce.shouldSend(bundle) ? playbookFor(bundle) ?? void 0 : void 0;
36330      const diffNote = raw.elements_are_diff === true ? `(diff: ${elements.length} changed, ${raw.unchanged_element_count ?? 0} unchanged. Indices below are stable; elements not listed are unchanged since your last read. Pass disableDiff for the full tree.)` : void 0;
36331      const { text, refByIndex } = renderAppStateText(elements, {
36332        instructions,
36333        diffNote,
36334        carryOver: raw.elements_are_diff === true ? skyIndexMap.get(args.app) : void 0
36335      });
36336      skyIndexMap.set(args.app, refByIndex);
36337      const shot = raw.screenshot;
36338      const url2 = shot?.data_url ?? shot?.url;
36339      return {
36340        content: [textBlock(JSON.stringify({ app: args.app, screenshot: url2 ? { url: url2 } : null, text }, null, 2))]
36341      };
36342    })
36343  );

```
