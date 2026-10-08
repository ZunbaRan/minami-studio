# 原始 stdio MCP 局部 tool.sky_press_key

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36369–36387`（inclusive），原字节半开区间 `[1361471, 1362433]`；区间SHA256 `892ab911ac6fff29c6db2f73185c42d2ce81192139ebd6151be76b49d1d16c34`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36369

```javascript
36369  server.registerTool(
36370    "sky_press_key",
36371    {
36372      description: "Codex-compatible: press a `+`-separated keysym chord (Return, Tab, Control_L+a, Super_L+d) in an app window.",
36373      inputSchema: { app: external_exports3.string(), key: external_exports3.string() }
36374    },
36375    async (args) => gated("sky_press_key", { bundle: args.app }, async () => {
36376      const res = await daemon.call("press_key", { key: normalizeKeyChord(args.key), bundle: args.app });
36377      const target = normalizeTarget({ bundle: args.app });
36378      if (res?.delivered === false) {
36379        const note = res.delivery_note ?? "the target app did not accept the key event";
36380        return respond(`NOT delivered: pressed ${args.key} was suppressed \u2014 ${note}`, target);
36381      }
36382      if (res?.via === "menu_ax_press") {
36383        return respond(`pressed ${args.key} (invoked its menu item in the background; the user's focus was untouched)`, target);
36384      }
36385      return respond(`pressed ${args.key}`, target);
36386    })
36387  );

```
