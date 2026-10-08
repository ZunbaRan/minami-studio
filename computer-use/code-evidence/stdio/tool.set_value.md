# 原始 stdio MCP 局部 tool.set_value

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36244–36259`（inclusive），原字节半开区间 `[1355141, 1355824]`；区间SHA256 `4fd1d7bd6bb09782bee694babc6141dcbf50be2ba954517e42eefa31a4f0541e`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36244

```javascript
36244  server.registerTool(
36245    "set_value",
36246    {
36247      description: "Directly set AXValue on an element (sliders, steppers, text fields). Skips keystroke simulation. Value can be a string, number, or boolean.",
36248      inputSchema: {
36249        ref: external_exports3.string(),
36250        value: external_exports3.union([external_exports3.string(), external_exports3.number(), external_exports3.boolean()]),
36251        ...targetShape
36252      }
36253    },
36254    async (args, _extra) => gated("set_value", args, async () => {
36255      const target = normalizeTarget(args);
36256      await daemon.call("set_value", { ref: args.ref, value: args.value });
36257      return respond(`set ${args.ref} = ${JSON.stringify(args.value)}`, target);
36258    })
36259  );

```
