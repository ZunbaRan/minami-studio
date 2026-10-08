# 原始 stdio MCP 局部 tool.sky_click

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36344–36368`（inclusive），原字节半开区间 `[1360089, 1361471]`；区间SHA256 `1cdcf2cb222392d206cf291136e8a9dec2141139374cecbafb7aa73b3376935a`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36344

```javascript
36344  server.registerTool(
36345    "sky_click",
36346    {
36347      description: "Codex-compatible: click an indexed element from the latest sky_get_app_state, or a coordinate in the app window.",
36348      inputSchema: {
36349        app: external_exports3.string(),
36350        element_index: external_exports3.number().int().optional(),
36351        x: external_exports3.number().optional().describe("X coordinate in the app-window screenshot."),
36352        y: external_exports3.number().optional().describe("Y coordinate in the app-window screenshot."),
36353        click_count: external_exports3.number().int().optional(),
36354        mouse_button: external_exports3.enum(["left", "right", "middle", "l", "r", "m"]).optional()
36355      }
36356    },
36357    async (args) => gated("sky_click", { bundle: args.app }, async () => {
36358      const button = normalizeMouseButton(args.mouse_button);
36359      if (typeof args.element_index === "number") {
36360        await daemon.call("click", { ref: skyRefFor(args.app, args.element_index), button, click_count: args.click_count ?? 1 });
36361      } else if (typeof args.x === "number" && typeof args.y === "number") {
36362        await daemon.call("click", { x: args.x, y: args.y, bundle: args.app, coord_space: "screenshot", button, click_count: args.click_count ?? 1 });
36363      } else {
36364        throw new Error("sky_click needs element_index, or both x and y.");
36365      }
36366      return respond("clicked", normalizeTarget({ bundle: args.app }));
36367    })
36368  );

```
