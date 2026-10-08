# 原始 stdio MCP 局部 tool.sky_drag

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36430–36447`（inclusive），原字节半开区间 `[1364169, 1364842]`；区间SHA256 `1004b65e1579a30a728c5569985f13cab943d96b187036022bf9a17b2b65c9a0`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36430

```javascript
36430  server.registerTool(
36431    "sky_drag",
36432    {
36433      description: "Codex-compatible: drag from one app-window coordinate to another.",
36434      inputSchema: { app: external_exports3.string(), from_x: external_exports3.number(), from_y: external_exports3.number(), to_x: external_exports3.number(), to_y: external_exports3.number() }
36435    },
36436    async (args) => gated("sky_drag", { bundle: args.app }, async () => {
36437      await daemon.call("drag", {
36438        start_x: args.from_x,
36439        start_y: args.from_y,
36440        end_x: args.to_x,
36441        end_y: args.to_y,
36442        bundle: args.app,
36443        coord_space: "screenshot"
36444      });
36445      return respond("dragged", normalizeTarget({ bundle: args.app }));
36446    })
36447  );

```
