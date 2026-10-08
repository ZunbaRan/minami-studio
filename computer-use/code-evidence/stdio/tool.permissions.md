# 原始 stdio MCP 局部 tool.permissions

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36483–36493`（inclusive），原字节半开区间 `[1366412, 1366734]`；区间SHA256 `04bd0128565c8f98705ee03cfaae9ac95317b87807e46f35b838deaaaf7af549`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36483

```javascript
36483  server.registerTool(
36484    "permissions",
36485    {
36486      description: "Check whether Alma Computer Use has Accessibility + Screen Recording permissions.",
36487      inputSchema: {}
36488    },
36489    async (_args, _extra) => {
36490      const res = await daemon.call("permissions");
36491      return { content: [textBlock(JSON.stringify(res, null, 2))] };
36492    }
36493  );

```
