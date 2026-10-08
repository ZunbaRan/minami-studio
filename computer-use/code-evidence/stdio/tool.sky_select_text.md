# 原始 stdio MCP 局部 tool.sky_select_text

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36459–36482`（inclusive），原字节半开区间 `[1365454, 1366412]`；区间SHA256 `8944120a280e8a76f62aed35b28cd9fe21e8213e8869d67f2201b4cf2e782b90`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36459

```javascript
36459  server.registerTool(
36460    "sky_select_text",
36461    {
36462      description: "Codex-compatible: select matching text in an indexed editable element, or place the cursor before/after it.",
36463      inputSchema: {
36464        app: external_exports3.string(),
36465        element_index: external_exports3.number().int(),
36466        text: external_exports3.string(),
36467        prefix: external_exports3.string().optional(),
36468        suffix: external_exports3.string().optional(),
36469        selection_type: external_exports3.enum(["text", "cursor_before", "cursor_after"]).optional()
36470      }
36471    },
36472    async (args) => gated("sky_select_text", { bundle: args.app }, async () => {
36473      await daemon.call("select_text", {
36474        ref: skyRefFor(args.app, args.element_index),
36475        text: args.text,
36476        prefix: args.prefix,
36477        suffix: args.suffix,
36478        selection_type: args.selection_type ?? "text"
36479      });
36480      return respond(`selected ${JSON.stringify(args.text)}`, normalizeTarget({ bundle: args.app }));
36481    })
36482  );

```
