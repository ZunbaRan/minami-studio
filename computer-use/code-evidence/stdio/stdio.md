# 原始 stdio MCP 局部 stdio

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36506–36514`（inclusive），原字节半开区间 `[1367077, 1367381]`；区间SHA256 `458ee0254ff200a7ba64827797588010631d007ffa4ddf97460aa14a2165486e`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36506

```javascript
36506    const transport = new StdioServerTransport();
36507    await server.connect(transport);
36508    process.stderr.write("[alma-cu-mcp] ready on stdio\n");
36509  }
36510  main().catch((err) => {
36511    process.stderr.write(`[alma-cu-mcp] fatal: ${err instanceof Error ? err.stack || err.message : String(err)}
36512  `);
36513    process.exit(1);
36514  });

```
