# 原始 stdio MCP 局部 tool.list_apps

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36011–36028`（inclusive），原字节半开区间 `[1344295, 1345181]`；区间SHA256 `3beb152fa261736cf596c44c12588c1f0cc768b00ad3002ece33057c6d8aae2e`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36011

```javascript
36011  server.registerTool(
36012    "list_apps",
36013    {
36014      description: "List running apps plus any used in the last N days (default 14), with usage frequency. Use this when picking which app to drive.",
36015      inputSchema: {
36016        days: external_exports3.number().int().max(90).optional().describe("Lookback window for recency (days). Default 14.")
36017      }
36018    },
36019    async (args, _extra) => {
36020      const res = await daemon.call("list_apps", { days: posIntOr(args.days, 14) });
36021      return { content: [textBlock(JSON.stringify(res, null, 2))] };
36022    }
36023  );
36024  var targetShape = {
36025    bundle: external_exports3.string().optional().describe("Bundle id (com.apple.Music). Either bundle or pid is required."),
36026    pid: external_exports3.number().int().optional().describe("Process id. Either bundle or pid is required."),
36027    window_id: external_exports3.number().int().optional().describe("Specific CGWindowID (optional).")
36028  };

```
