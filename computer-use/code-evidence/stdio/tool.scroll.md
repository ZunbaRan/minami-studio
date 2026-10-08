# 原始 stdio MCP 局部 tool.scroll

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36222–36243`（inclusive），原字节半开区间 `[1354431, 1355141]`；区间SHA256 `0972b591e8386fe90c657de6b6ecbf4f6b10656ec2edc985e71ab064e8eb2cce`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36222

```javascript
36222  server.registerTool(
36223    "scroll",
36224    {
36225      description: "Scroll an element (AX-based). Returns a post-action screenshot.",
36226      inputSchema: {
36227        ref: external_exports3.string(),
36228        direction: external_exports3.enum(["up", "down", "left", "right"]),
36229        pages: external_exports3.number().int().max(20).optional(),
36230        ...targetShape
36231      }
36232    },
36233    async (args, _extra) => gated("scroll", args, async () => {
36234      const target = normalizeTarget(args);
36235      await daemon.call("scroll", {
36236        ref: args.ref,
36237        direction: args.direction,
36238        pages: posIntOr(args.pages, 1),
36239        show_cursor: true
36240      });
36241      return respond(`scrolled ${args.direction} \xD7${posIntOr(args.pages, 1)}`, target);
36242    })
36243  );

```
