# 原始 stdio MCP 局部 tool.sky_set_value

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36419–36429`（inclusive），原字节半开区间 `[1363633, 1364169]`；区间SHA256 `475a586a934e81d424b2accbedfc690b5190887e713a06834d5b6732a878cf40`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36419

```javascript
36419  server.registerTool(
36420    "sky_set_value",
36421    {
36422      description: "Codex-compatible: replace the value of an indexed editable element.",
36423      inputSchema: { app: external_exports3.string(), element_index: external_exports3.number().int(), value: external_exports3.string() }
36424    },
36425    async (args) => gated("sky_set_value", { bundle: args.app }, async () => {
36426      await daemon.call("set_value", { ref: skyRefFor(args.app, args.element_index), value: args.value });
36427      return respond("set value", normalizeTarget({ bundle: args.app }));
36428    })
36429  );

```
