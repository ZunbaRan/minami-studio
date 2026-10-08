# 原始 stdio MCP 局部 tool.grant

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36494–36504`（inclusive），原字节半开区间 `[1366734, 1367053]`；区间SHA256 `ba6756091866db660d090e3d882918999fb94b044b392be2889d641b291a0f46`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36494

```javascript
36494  server.registerTool(
36495    "grant",
36496    {
36497      description: "Trigger the macOS Accessibility permission dialog. Caller should poll `permissions` after.",
36498      inputSchema: {}
36499    },
36500    async (_args, _extra) => {
36501      const res = await daemon.call("grant");
36502      return { content: [textBlock(JSON.stringify(res, null, 2))] };
36503    }
36504  );

```
