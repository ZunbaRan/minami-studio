# 原始 stdio MCP 局部 screenshot

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `35930–35976`（inclusive），原字节半开区间 `[1340184, 1341909]`；区间SHA256 `6ac6c70507c04eaa023b5456b05d187008db4d89fdacba6b697564f62e419a7c`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L35930

```javascript
35930  function normalizeTarget(args) {
35931    return {
35932      bundle: typeof args.bundle === "string" && args.bundle.length > 0 ? args.bundle : void 0,
35933      pid: typeof args.pid === "number" && args.pid > 0 ? Math.floor(args.pid) : void 0,
35934      window_id: typeof args.window_id === "number" && args.window_id > 0 ? Math.floor(args.window_id) : void 0
35935    };
35936  }
35937  async function screenshotTarget(target) {
35938    if (!target || !target.bundle && target.pid === void 0) return null;
35939    try {
35940      const state = await daemon.call(
35941        "get_app_state",
35942        {
35943          bundle: target.bundle,
35944          pid: target.pid,
35945          window_id: target.window_id,
35946          include_screenshot: true,
35947          interactive_only: true,
35948          depth: 0,
35949          // we only need the screenshot, skip the AX walk
35950          screenshot_max_width: 1280
35951        },
35952        3e4
35953      );
35954      const shotPath = state.screenshot?.path;
35955      if (!shotPath) return { type: "text", text: "Post-action screenshot unavailable." };
35956      const buf = await (await import("node:fs/promises")).readFile(shotPath);
35957      return { type: "image", data: buf.toString("base64"), mimeType: "image/jpeg" };
35958    } catch (e) {
35959      return { type: "text", text: `Post-action screenshot failed: ${e instanceof Error ? e.message : String(e)}` };
35960    }
35961  }
35962  function textBlock(text) {
35963    return { type: "text", text };
35964  }
35965  async function respond(summary, target) {
35966    const content = [textBlock(summary)];
35967    const shot = await screenshotTarget(target);
35968    if (shot) {
35969      if (shot.type === "image") content.push({ type: "image", data: shot.data, mimeType: shot.mimeType });
35970      else content.push(textBlock(shot.text));
35971    }
35972    return { content };
35973  }
35974  var server = new McpServer(
35975    { name: "alma-computer-use", version: "1.0.0" },
35976    {

```
