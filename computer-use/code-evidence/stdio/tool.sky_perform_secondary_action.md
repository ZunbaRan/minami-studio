# 原始 stdio MCP 局部 tool.sky_perform_secondary_action

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36448–36458`（inclusive），原字节半开区间 `[1364842, 1365454]`；区间SHA256 `42cd8a64cd65c87818e36a840a23cff63838498e7d05fed986873314ea5f75f1`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36448

```javascript
36448  server.registerTool(
36449    "sky_perform_secondary_action",
36450    {
36451      description: "Codex-compatible: invoke a secondary accessibility action on an indexed element.",
36452      inputSchema: { app: external_exports3.string(), element_index: external_exports3.number().int(), action: external_exports3.string() }
36453    },
36454    async (args) => gated("sky_perform_secondary_action", { bundle: args.app }, async () => {
36455      await daemon.call("perform_secondary_action", { ref: skyRefFor(args.app, args.element_index), action: args.action });
36456      return respond(`performed ${args.action}`, normalizeTarget({ bundle: args.app }));
36457    })
36458  );

```
