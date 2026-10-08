# 原始 stdio MCP 局部 tool.perform_secondary_action

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36118–36146`（inclusive），原字节半开区间 `[1349795, 1351087]`；区间SHA256 `387ce5ad9c48aa3a954c363b2623b534a0ebece41eeadce3bc32c142ceffafc7`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36118

```javascript
36118  server.registerTool(
36119    "perform_secondary_action",
36120    {
36121      description: "Right-click / open context menu on an element or at a pixel. Returns a post-action screenshot.",
36122      inputSchema: {
36123        ref: external_exports3.string().optional(),
36124        x: external_exports3.number().optional().describe("X coordinate (screenshot pixel by default)."),
36125        y: external_exports3.number().optional().describe("Y coordinate (screenshot pixel by default)."),
36126        coord_space: external_exports3.enum(["screenshot", "screen"]).optional(),
36127        ...targetShape
36128      }
36129    },
36130    async (args, _extra) => gated("perform_secondary_action", args, async () => {
36131      const target = normalizeTarget(args);
36132      const payload = { show_cursor: true };
36133      if (args.ref) payload.ref = args.ref;
36134      else if (args.x !== void 0 && args.y !== void 0) {
36135        payload.x = args.x;
36136        payload.y = args.y;
36137        payload.coord_space = args.coord_space ?? "screenshot";
36138        if (target.pid !== void 0) payload.pid = target.pid;
36139        if (target.bundle !== void 0) payload.bundle = target.bundle;
36140      } else {
36141        throw new Error("perform_secondary_action requires either `ref` or both `x` and `y`");
36142      }
36143      await daemon.call("perform_secondary_action", payload);
36144      return respond(`secondary click ok`, target);
36145    })
36146  );

```
