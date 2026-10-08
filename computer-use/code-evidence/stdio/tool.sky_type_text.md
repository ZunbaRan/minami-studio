# 原始 stdio MCP 局部 tool.sky_type_text

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36388–36398`（inclusive），原字节半开区间 `[1362433, 1362912]`；区间SHA256 `d362fe289925a763e7b4fd944560c94ad18ce3e54db86500f79a66a429868f49`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36388

```javascript
36388  server.registerTool(
36389    "sky_type_text",
36390    {
36391      description: "Codex-compatible: type text into the current focus in an app window.",
36392      inputSchema: { app: external_exports3.string(), text: external_exports3.string() }
36393    },
36394    async (args) => gated("sky_type_text", { bundle: args.app }, async () => {
36395      await daemon.call("type_text", { text: args.text, bundle: args.app });
36396      return respond(`typed ${args.text.length} chars`, normalizeTarget({ bundle: args.app }));
36397    })
36398  );

```
