# 原始 stdio MCP 局部 tool.get_app_state

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36029–36089`（inclusive），原字节半开区间 `[1345181, 1348699]`；区间SHA256 `3d2a6fdc51f54974cd70e9de4894931ed7f62b6f404398c6fd91455396569e47`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36029

```javascript
36029  server.registerTool(
36030    "get_app_state",
36031    {
36032      description: "Snapshot the target app: returns the AX tree + a window screenshot. Call this at the start of every turn before acting. On apps with no AX tree (Qt / custom-drawn) the elements list is empty but the screenshot is still captured so you can click by pixel. AUTO-LAUNCH: if `bundle` is given and the app is not running, it is launched in the BACKGROUND \u2014 the user's frontmost app stays put. Pass `auto_launch: false` to disable.",
36033      inputSchema: {
36034        ...targetShape,
36035        depth: external_exports3.number().int().max(20).optional().describe("AX tree depth. Default 6."),
36036        interactive_only: external_exports3.boolean().optional().describe("Limit to interactive elements. Default true."),
36037        screenshot_max_width: external_exports3.number().int().optional().describe("Downsample width for the screenshot (default 1280)."),
36038        auto_launch: external_exports3.boolean().optional().describe("Auto-launch the app in the background if not running. Default true.")
36039      }
36040    },
36041    async (args, _extra) => {
36042      const res = await daemon.call(
36043        "get_app_state",
36044        {
36045          bundle: args.bundle,
36046          pid: posIntOr(args.pid, void 0),
36047          window_id: typeof args.window_id === "number" && args.window_id > 0 ? args.window_id : void 0,
36048          depth: typeof args.depth === "number" && args.depth >= 0 ? Math.floor(args.depth) : 6,
36049          interactive_only: args.interactive_only ?? true,
36050          include_screenshot: true,
36051          screenshot_max_width: posIntOr(args.screenshot_max_width, 1280),
36052          auto_launch: args.auto_launch ?? true
36053        },
36054        3e4
36055      );
36056      const content = [];
36057      const playbook = playbookFor(args.bundle ?? res.app?.bundle);
36058      if (playbook) {
36059        content.push(textBlock(`## App playbook (auto-injected)
36060  
36061  ${playbook}`));
36062      }
36063      const body = { ...res };
36064      delete body.screenshot;
36065      content.push(textBlock(JSON.stringify(body, null, 2)));
36066      if (res.screenshot?.path) {
36067        try {
36068          const buf = await (await import("node:fs/promises")).readFile(res.screenshot.path);
36069          content.push({ type: "image", data: buf.toString("base64"), mimeType: "image/jpeg" });
36070        } catch (e) {
36071          content.push(textBlock(`screenshot read failed: ${e instanceof Error ? e.message : String(e)}`));
36072        }
36073      } else if (res.screenshot_error) {
36074        content.push(textBlock(`screenshot error: ${res.screenshot_error}`));
36075      }
36076      return { content };
36077    }
36078  );
36079  var clickInput = {
36080    ref: external_exports3.string().optional().describe('Element ref from get_app_state (e.g. "e7"). Either ref or {x, y} is required.'),
36081    x: external_exports3.number().optional().describe("X coordinate (screenshot pixel by default; see coord_space)."),
36082    y: external_exports3.number().optional().describe("Y coordinate (screenshot pixel by default; see coord_space)."),
36083    coord_space: external_exports3.enum(["screenshot", "screen"]).optional().describe('"screenshot" (default) \u2014 coords are pixels in the last get_app_state screenshot. "screen" \u2014 raw screen points.'),
36084    button: external_exports3.enum(["left", "right", "middle"]).optional().describe("Mouse button. Default left."),
36085    click_count: external_exports3.number().int().max(3).optional().describe("1=single, 2=double, 3=triple. Default 1."),
36086    strategy: external_exports3.enum(["auto", "physical", "ax"]).optional().describe("auto (default) prefers CGEvent if bounds known."),
36087    ...targetShape
36088    // used to pick the app for the post-action screenshot
36089  };

```
