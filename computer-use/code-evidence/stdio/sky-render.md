# 原始 stdio MCP 局部 sky-render

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `35580–35626`（inclusive），原字节半开区间 `[1316960, 1318883]`；区间SHA256 `057518195e58dec22df649c4b67410aae1a7bc17d234b02b40c660621e2d8172`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L35580

```javascript
35580  var PlaybookOnce = class {
35581    sent = /* @__PURE__ */ new Set();
35582    /** True the first time an app is seen, false thereafter. */
35583    shouldSend(appKey) {
35584      if (this.sent.has(appKey)) return false;
35585      this.sent.add(appKey);
35586      return true;
35587    }
35588    reset() {
35589      this.sent.clear();
35590    }
35591  };
35592  function renderAppStateText(elements, opts = {}) {
35593    const refByIndex = [...opts.carryOver ?? []];
35594    const indexOfRef = /* @__PURE__ */ new Map();
35595    refByIndex.forEach((r, i) => indexOfRef.set(r, i));
35596    const lines = [];
35597    for (const el of elements) {
35598      const ref = typeof el.ref === "string" ? el.ref : void 0;
35599      if (!ref) continue;
35600      let index = indexOfRef.get(ref);
35601      if (index === void 0) {
35602        index = refByIndex.length;
35603        refByIndex.push(ref);
35604        indexOfRef.set(ref, index);
35605      }
35606      const role = String(el.role ?? "AXUnknown").replace(/^AX/, "");
35607      const label = [el.title, el.description, el.value, el.role_description].map((v) => typeof v === "string" ? v.trim() : "").find((v) => v.length > 0);
35608      const bounds = el.bounds;
35609      const pos = bounds ? ` @${Math.round(bounds.x ?? 0)},${Math.round(bounds.y ?? 0)} ${Math.round(bounds.w ?? 0)}x${Math.round(bounds.h ?? 0)}` : "";
35610      const flags = [el.focused === true ? "focused" : "", el.enabled === false ? "disabled" : ""].filter(Boolean).join(",");
35611      lines.push(`[${index}] ${role}${label ? ` "${label}"` : ""}${pos}${flags ? ` (${flags})` : ""}`);
35612    }
35613    const parts = [];
35614    if (opts.instructions) parts.push(`<app_specific_instructions>
35615  ${opts.instructions}
35616  </app_specific_instructions>`);
35617    if (opts.diffNote) parts.push(opts.diffNote);
35618    parts.push(lines.join("\n"));
35619    return { text: parts.join("\n"), refByIndex };
35620  }
35621  
35622  // electron/mcp-servers/computer-use.ts
35623  import { spawn } from "node:child_process";
35624  import { createConnection } from "node:net";
35625  import { existsSync, mkdirSync } from "node:fs";
35626  import { randomBytes, createHash } from "node:crypto";

```
