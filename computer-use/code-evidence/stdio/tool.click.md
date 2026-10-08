# 原始 stdio MCP 局部 tool.click

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36090–36117`（inclusive），原字节半开区间 `[1348699, 1349795]`；区间SHA256 `81458150229a2d7540bef1bcdd6f160d6d93ace1e53d1c4270023f45875921bf`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36090

```javascript
36090  server.registerTool(
36091    "click",
36092    {
36093      description: "Click an element by ref (from get_app_state) or at absolute pixel (x, y) coordinates. Returns a post-action screenshot of the target app so you can see the result.",
36094      inputSchema: clickInput
36095    },
36096    async (args, _extra) => gated("click", args, async () => {
36097      const target = normalizeTarget(args);
36098      const payload = {
36099        button: args.button ?? "left",
36100        click_count: posIntOr(args.click_count, 1),
36101        strategy: args.strategy ?? "auto",
36102        show_cursor: true
36103      };
36104      if (args.ref) payload.ref = args.ref;
36105      else if (args.x !== void 0 && args.y !== void 0) {
36106        payload.x = args.x;
36107        payload.y = args.y;
36108        payload.coord_space = args.coord_space ?? "screenshot";
36109        if (target.pid !== void 0) payload.pid = target.pid;
36110        if (target.bundle !== void 0) payload.bundle = target.bundle;
36111      } else {
36112        throw new Error("click requires either `ref` or both `x` and `y`");
36113      }
36114      await daemon.call("click", payload);
36115      return respond(`click ok (${args.ref ?? `${args.x},${args.y}`})`, target);
36116    })
36117  );

```
