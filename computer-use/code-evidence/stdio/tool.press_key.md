# 原始 stdio MCP 局部 tool.press_key

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36200–36221`（inclusive），原字节半开区间 `[1353376, 1354431]`；区间SHA256 `813da11640acdaa9532085b5eeb15018ab3fa55a77591452c102dcce802e3d49`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36200

```javascript
36200  server.registerTool(
36201    "press_key",
36202    {
36203      description: "Press a key or combo in xdotool syntax \u2014 cmd+s, ctrl+shift+t, Return, Escape, F1, cmd+opt+esc. Modifiers: cmd|command|meta, ctrl|control, shift, opt|option|alt, fn.",
36204      inputSchema: {
36205        key: external_exports3.string().describe('xdotool-style key combo, e.g. "cmd+s" or "Return"'),
36206        ...targetShape
36207      }
36208    },
36209    async (args, _extra) => gated("press_key", args, async () => {
36210      const target = normalizeTarget(args);
36211      const res = await daemon.call("press_key", { key: args.key, pid: target.pid, bundle: target.bundle });
36212      if (res?.delivered === false) {
36213        const note = res.delivery_note ?? "the target app did not accept the key event";
36214        return respond(`NOT delivered: pressed ${args.key} was suppressed \u2014 ${note}`, target);
36215      }
36216      if (res?.via === "menu_ax_press") {
36217        return respond(`pressed ${args.key} (invoked its menu item in the background; the user's focus was untouched)`, target);
36218      }
36219      return respond(`pressed ${args.key}`, target);
36220    })
36221  );

```
