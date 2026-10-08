# 原始 stdio MCP 局部 tool.type_text

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36177–36199`（inclusive），原字节半开区间 `[1352207, 1353376]`；区间SHA256 `238ea4541c2692a359eb76e021f3f1563f6cb77d923d4bbb86f9f08bcd5b688e`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36177

```javascript
36177  server.registerTool(
36178    "type_text",
36179    {
36180      description: "Text entry into the target app. By default this uses AX insertion when ref is provided, physical key events translated from the current keyboard layout, and Unicode CGEvents as fallback. Target must already have keyboard focus \u2014 click it first. Returns a post-action screenshot.",
36181      inputSchema: {
36182        text: external_exports3.string(),
36183        ref: external_exports3.string().optional().describe("Optional text-field ref from get_app_state. When present, auto mode inserts via AX instead of keystrokes."),
36184        input_method: external_exports3.enum(["auto", "physical", "unicode", "ax"]).optional().describe("auto (default), physical key events, unicode CGEvents, or AX insertion when ref is provided."),
36185        ...targetShape
36186      }
36187    },
36188    async (args, _extra) => gated("type_text", args, async () => {
36189      const target = normalizeTarget(args);
36190      await daemon.call("type_text", {
36191        text: args.text,
36192        ref: args.ref,
36193        input_method: args.input_method ?? "auto",
36194        pid: target.pid,
36195        bundle: target.bundle
36196      });
36197      return respond(`typed ${args.text.length} chars`, target);
36198    })
36199  );

```
