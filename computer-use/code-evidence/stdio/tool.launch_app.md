# 原始 stdio MCP 局部 tool.launch_app

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `35990–36010`（inclusive），原字节半开区间 `[1342850, 1344295]`；区间SHA256 `6c1237759a85c4a3a76717171eb76910b95cb24487efde980e20f173cf8f5190`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L35990

```javascript
35990  server.registerTool(
35991    "launch_app",
35992    {
35993      description: "Launch an app by bundle id WITHOUT bringing it to the foreground. The user's frontmost app stays put; the launched app opens in the background so Alma can drive it. A running app is NEVER touched: there is no way to make this tool bring an app to the foreground, because Alma must never take the foreground away from the user. `activates` only reaches macOS's own cold-launch flag, exactly as double-clicking an app would, and does nothing for an app already running. `get_app_state` auto-launches too, so you usually do not need to call this explicitly.",
35994      inputSchema: {
35995        bundle: external_exports3.string().describe("Bundle id, e.g. com.netease.163music."),
35996        activates: external_exports3.boolean().optional().describe(
35997          "macOS's own cold-launch activation flag, and only that. Default false. It has no effect on a running app, and nothing here can move the foreground away from the user \u2014 do not reach for it to make an action work."
35998        )
35999      }
36000    },
36001    async (args, _extra) => {
36002      return gated("launch_app", args, async () => {
36003        const res = await daemon.call("launch_app", { bundle: args.bundle, activates: args.activates ?? false });
36004        return { content: [textBlock(JSON.stringify(res, null, 2))] };
36005      });
36006    }
36007  );
36008  var posIntOr = (v, defaultVal) => {
36009    return typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.floor(v) : defaultVal;
36010  };

```
