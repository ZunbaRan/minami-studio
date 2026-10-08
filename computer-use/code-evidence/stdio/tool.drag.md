# 原始 stdio MCP 局部 tool.drag

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36147–36176`（inclusive），原字节半开区间 `[1351087, 1352207]`；区间SHA256 `71e726eb27536fbca57f317e63067e0a933e29a3f596424cf8b2c92625a2c701`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36147

```javascript
36147  server.registerTool(
36148    "drag",
36149    {
36150      description: 'Mouse drag from one point to another. Coordinates default to screenshot pixels; pass coord_space="screen" for raw points. Returns a post-action screenshot.',
36151      inputSchema: {
36152        start_x: external_exports3.number(),
36153        start_y: external_exports3.number(),
36154        end_x: external_exports3.number(),
36155        end_y: external_exports3.number(),
36156        coord_space: external_exports3.enum(["screenshot", "screen"]).optional(),
36157        button: external_exports3.enum(["left", "right", "middle"]).optional(),
36158        ...targetShape
36159      }
36160    },
36161    async (args, _extra) => gated("drag", args, async () => {
36162      const target = normalizeTarget(args);
36163      await daemon.call("drag", {
36164        start_x: args.start_x,
36165        start_y: args.start_y,
36166        end_x: args.end_x,
36167        end_y: args.end_y,
36168        coord_space: args.coord_space ?? "screenshot",
36169        button: args.button ?? "left",
36170        pid: target.pid,
36171        bundle: target.bundle,
36172        show_cursor: true
36173      });
36174      return respond(`drag ok (${args.start_x},${args.start_y} \u2192 ${args.end_x},${args.end_y})`, target);
36175    })
36176  );

```
