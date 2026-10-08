# 原始 stdio MCP 局部 tool.sky_list_apps

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `36294–36311`（inclusive），原字节半开区间 `[1357682, 1358295]`；区间SHA256 `a4592ab54b5ad907c7782cba2cfeeb35644570604637904c08fb99f634528877`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L36294

```javascript
36294  server.registerTool(
36295    "sky_list_apps",
36296    {
36297      description: "Codex-compatible: list apps that can be targeted by the window API. Returns {id, displayName, isRunning, lastUsedDate, useCount}.",
36298      inputSchema: {}
36299    },
36300    async () => {
36301      const res = await daemon.call("list_apps", {});
36302      const apps = (res.apps ?? []).map((a) => ({
36303        id: a.bundle || a.name || "unknown",
36304        displayName: a.name,
36305        isRunning: a.running ?? a.active,
36306        lastUsedDate: a.last_used_at ?? void 0,
36307        useCount: a.use_count ?? void 0
36308      }));
36309      return { content: [textBlock(JSON.stringify(apps, null, 2))] };
36310    }
36311  );

```
