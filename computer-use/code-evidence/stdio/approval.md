# 原始 stdio MCP 局部 approval

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `35666–35759`（inclusive），原字节半开区间 `[1331325, 1334650]`；区间SHA256 `e574f9e1d1cd668e96df2077b7e60ec647d5549a4228b3b98803a3d600dda26e`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L35666

```javascript
35666  async function checkApproval(bundle, appName) {
35667    if (!bundle) return { approved: true, strictMode: false };
35668    try {
35669      const url2 = new URL(`${ALMA_API}/api/computer-use/check_approval`);
35670      url2.searchParams.set("bundle", bundle);
35671      if (appName) url2.searchParams.set("app_name", appName);
35672      const res = await fetch(url2.toString());
35673      if (!res.ok) return { approved: true, strictMode: false };
35674      const body = await res.json();
35675      return {
35676        approved: body.approved === true,
35677        strictMode: body.strict_mode === true,
35678        autoApproved: body.auto_approved === true
35679      };
35680    } catch {
35681      return { approved: true, strictMode: false };
35682    }
35683  }
35684  async function notePipActivity(entry) {
35685    try {
35686      await fetch(`${ALMA_API}/api/pip/computer-use-activity`, {
35687        method: "POST",
35688        headers: { "content-type": "application/json" },
35689        body: JSON.stringify({ tool_name: entry.toolName, bundle: entry.bundle, pid: entry.pid })
35690      });
35691    } catch {
35692    }
35693  }
35694  var focusGuardChecked = 0;
35695  var focusGuardWarned = false;
35696  async function focusGuardWarning() {
35697    const now = Date.now();
35698    if (now - focusGuardChecked < 3e4) {
35699      return focusGuardWarned ? FOCUS_GUARD_WARNING : null;
35700    }
35701    focusGuardChecked = now;
35702    try {
35703      const res = await fetch(`${ALMA_API}/api/computer-use/permissions`);
35704      const body = await res.json();
35705      focusGuardWarned = (body.focus_guard?.arm_failures ?? 0) > 0;
35706    } catch {
35707      focusGuardWarned = false;
35708    }
35709    return focusGuardWarned ? FOCUS_GUARD_WARNING : null;
35710  }
35711  var FOCUS_GUARD_WARNING = "WARNING: focus-steal protection is not active on this Mac, so this action may have pulled the user's frontmost window or keyboard focus away from what they were doing. Tell the user, and ask them to re-grant Accessibility for the Alma Computer Use helper in Settings \u2192 Computer Use (macOS resets that grant for each new build).";
35712  async function logAction(entry) {
35713    try {
35714      await fetch(`${ALMA_API}/api/computer-use/action_log`, {
35715        method: "POST",
35716        headers: { "content-type": "application/json" },
35717        body: JSON.stringify({
35718          tool_name: entry.toolName,
35719          bundle_id: entry.bundleId,
35720          pid: entry.pid,
35721          args: entry.args,
35722          duration_ms: entry.durationMs,
35723          error_code: entry.errorCode
35724        })
35725      });
35726    } catch {
35727    }
35728  }
35729  async function gated(toolName, args, inner) {
35730    const approval = await checkApproval(args.bundle);
35731    if (!approval.approved) {
35732      return {
35733        content: [
35734          textBlock(
35735            `Alma has not yet been approved to drive ${args.bundle}. Ask the user to open Settings \u2192 Computer Use and approve "${args.bundle}", then retry. (Strict-approval mode is currently on.)`
35736          )
35737        ]
35738      };
35739    }
35740    void notePipActivity({ toolName, bundle: args.bundle, pid: args.pid });
35741    const t0 = Date.now();
35742    try {
35743      const r = await inner();
35744      void logAction({ toolName, bundleId: args.bundle, pid: args.pid, args, durationMs: Date.now() - t0 });
35745      const warning = await focusGuardWarning();
35746      if (warning) return { content: [...r.content, textBlock(warning)] };
35747      return r;
35748    } catch (e) {
35749      void logAction({
35750        toolName,
35751        bundleId: args.bundle,
35752        pid: args.pid,
35753        args,
35754        durationMs: Date.now() - t0,
35755        errorCode: e instanceof Error ? e.message : String(e)
35756      });
35757      throw e;
35758    }
35759  }

```
