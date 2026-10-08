# 原始 stdio MCP 局部 tool.sky_scroll

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36399–36418`（inclusive），原字节半开区间 `[1362912, 1363633]`；区间SHA256 `2b19d29554a436d3df79844e0724ab4b98a2bc028db2503b2d53d6176bc28b01`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36399

```javascript
36399  server.registerTool(
36400    "sky_scroll",
36401    {
36402      description: "Codex-compatible: scroll an indexed element in an app window.",
36403      inputSchema: {
36404        app: external_exports3.string(),
36405        element_index: external_exports3.number().int(),
36406        direction: external_exports3.enum(["up", "down", "left", "right", "u", "d", "l", "r"]),
36407        pages: external_exports3.number().optional()
36408      }
36409    },
36410    async (args) => gated("sky_scroll", { bundle: args.app }, async () => {
36411      await daemon.call("scroll", {
36412        ref: skyRefFor(args.app, args.element_index),
36413        direction: normalizeDirection(args.direction),
36414        pages: args.pages ?? 1
36415      });
36416      return respond("scrolled", normalizeTarget({ bundle: args.app }));
36417    })
36418  );

```
