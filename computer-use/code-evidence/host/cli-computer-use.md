# 原始 .164 CLI 局部 cli-computer-use

源：官方ZIP中的 `Alma.app/Contents/Resources/cli/alma`；全SHA256 `2f156839ea5aec2eb4bc8bc117ff2bbd0ed73cae00d090ad04ea19266e506eeb`；原行8297–8773 inclusive；区间SHA256 `3b6ae7dccc3f30e59dfcaa906d8245b0baa66ee434bff1674a85a38c0a355c12`；原文静态读取、未运行。只摘CU相关段，不含其它产品CLI/SDK主体。

## L8297

```javascript
08297          process.exit(1);
08298      }
08299  
08300      // ── Computer Use (macOS desktop automation via AX) ──────
08301      if (cmd === 'cu') {
08302          const subcmd = args[1];
08303  
08304          // Parse "<bundle-or-pid>" — a bundle id if it looks like one, else a PID.
08305          const parseTarget = raw => {
08306              if (!raw) return {};
08307              if (/^\d+$/.test(raw)) return { pid: parseInt(raw, 10) };
08308              return { bundle: raw };
08309          };
08310  
08311          // Flag lookup: `--foo=bar` or `--foo bar`. Returns undefined if absent.
08312          const flag = name => {
08313              for (let i = 0; i < args.length; i++) {
08314                  const a = args[i];
08315                  if (a === `--${name}`) return args[i + 1];
08316                  if (a && a.startsWith(`--${name}=`)) return a.slice(name.length + 3);
08317              }
08318              return undefined;
08319          };
08320          const hasFlag = name => args.includes(`--${name}`);
08321          const asJson = hasFlag('json');
08322  
08323          if (!subcmd || subcmd === 'help') {
08324              console.log(`alma cu — macOS desktop automation (Codex-compatible verb set)
08325  
08326  DISCOVERY
08327    alma cu status                      Helper bundle + daemon status
08328    alma cu doctor                      Ping daemon + report permissions
08329    alma cu grant                       Trigger AX permission dialog
08330    alma cu list_apps [--days=14]       Running + recently-used apps (w/ freq)
08331    alma cu apps [--json]               Running apps only (legacy)
08332    alma cu windows <bundle|pid>        List AX windows of an app
08333  
08334  STATE (call once per turn)
08335    alma cu get_app_state <bundle|pid> [--window=ID] [--depth=N] [--no-shot]
08336                                        AX tree + window screenshot combined
08337    alma cu snap <bundle|pid> [--window=ID] [--depth=N] [--all]
08338                                        AX tree only (legacy)
08339  
08340  ACTIONS
08341    alma cu click <ref> [--strategy=auto|physical|ax] [--button=left|right|middle]
08342                  [--clicks=N]
08343    alma cu click --pixel <x> <y> [--pid=N] [--button=left|right|middle] [--clicks=N]
08344    alma cu perform_secondary_action <ref>
08345    alma cu perform_secondary_action --pixel <x> <y> [--pid=N]
08346    alma cu drag <x1> <y1> <x2> <y2> [--pid=N] [--button=left|right|middle]
08347    alma cu type <ref> <text> [--append]          AX-scoped text replacement
08348    alma cu type_text <text> [--pid=N]            CGEvent keystroke input
08349    alma cu press <ref> <key>                     Enter|Escape|Space|Increment|Decrement|ShowMenu
08350    alma cu press_key <combo> [--pid=N]           xdotool syntax: cmd+s, ctrl+shift+t, Return…
08351    alma cu set_value <ref> <value>               Direct AXValue set (sliders, inputs)
08352    alma cu scroll <ref> <up|down|left|right> [--pages=N]
08353  
08354  OTHER
08355    alma cu raise <bundle|pid> [--window=ID]
08356    alma cu shot <bundle|pid> [--window=ID] [--out=PATH] [--max-width=N]
08357    alma cu lens <on|off|toggle>
08358    alma cu shutdown
08359  
08360  Action flags: --no-cursor hides the lens for one action.
08361  
08362  Hint: start every turn with \`alma cu get_app_state <bundle>\` — refs become
08363  stale across turns, so the screenshot is your visual anchor.
08364  `);
08365              return;
08366          }
08367  
08368          if (subcmd === 'status') {
08369              const data = await api('GET', '/api/computer-use/status');
08370              prettyPrint(data);
08371              return;
08372          }
08373  
08374          if (subcmd === 'doctor') {
08375              const status = await api('GET', '/api/computer-use/status');
08376              if (!status.available) {
08377                  console.log('helper:    NOT FOUND');
08378                  console.log('platform: ', status.platform);
08379                  console.log('\nBuild the helper with: pnpm build:computer-use');
08380                  process.exit(1);
08381              }
08382              const ping = await api('GET', '/api/computer-use/ping');
08383              const perms = await api('GET', '/api/computer-use/permissions');
08384              console.log(`helper:              ${status.helper_path}`);
08385              console.log(`daemon:              v${ping.version} (uptime ${ping.uptime_s}s)`);
08386              console.log(`accessibility:       ${perms.accessibility ? 'granted' : 'NOT granted'}`);
08387              console.log(`screen recording:    ${perms.screen_recording ? 'granted' : 'NOT granted'}`);
08388              if (!perms.accessibility) {
08389                  console.log('\nRun `alma cu grant`, then grant "Alma Computer Use" in');
08390                  console.log('System Settings → Privacy & Security → Accessibility.');
08391              }
08392              return;
08393          }
08394  
08395          if (subcmd === 'grant') {
08396              const data = await api('POST', '/api/computer-use/grant');
08397              if (data.accessibility) console.log('Accessibility already granted.');
08398              else console.log('Requested Accessibility permission. Approve the dialog, then `alma cu doctor`.');
08399              return;
08400          }
08401  
08402          if (subcmd === 'apps') {
08403              const data = await api('GET', '/api/computer-use/apps');
08404              if (asJson) {
08405                  console.log(JSON.stringify(data, null, 2));
08406                  return;
08407              }
08408              for (const a of data.apps) {
08409                  const mark = a.active ? '*' : ' ';
08410                  console.log(`${mark} [${String(a.pid).padStart(6)}] ${a.bundle || '?'.padEnd(30)}  ${a.name}`);
08411              }
08412              return;
08413          }
08414  
08415          if (subcmd === 'launch_app' || subcmd === 'launch') {
08416              const bundle = args[2];
08417              if (!bundle) {
08418                  console.error('Usage: alma cu launch_app <bundle> [--activates]');
08419                  process.exit(1);
08420              }
08421              const body = { bundle, activates: hasFlag('activates') };
08422              const data = await api('POST', '/api/computer-use/launch_app', body);
08423              console.log(`${data.app.name || bundle} pid=${data.app.pid}${data.activates ? ' (foreground)' : ' (background)'}`);
08424              return;
08425          }
08426  
08427          if (subcmd === 'list_apps') {
08428              const body = {};
08429              const d = flag('days');
08430              if (d) body.days = parseInt(d, 10);
08431              const data = await api('POST', '/api/computer-use/list_apps', body);
08432              if (asJson) {
08433                  console.log(JSON.stringify(data, null, 2));
08434                  return;
08435              }
08436              for (const a of data.apps) {
08437                  const mark = a.active ? '*' : a.running ? 'R' : ' ';
08438                  const pid = a.pid != null ? String(a.pid).padStart(6) : '     -';
08439                  const freq = a.use_count != null ? `(${a.use_count}×)` : '';
08440                  console.log(`${mark} [${pid}] ${(a.bundle || '?').padEnd(32)}  ${a.name}  ${freq}`);
08441              }
08442              return;
08443          }
08444  
08445          if (subcmd === 'windows') {
08446              const target = parseTarget(args[2]);
08447              if (!target.bundle && !target.pid) {
08448                  console.error('Usage: alma cu windows <bundle|pid>');
08449                  process.exit(1);
08450              }
08451              const data = await api('POST', '/api/computer-use/windows', target);
08452              if (asJson) {
08453                  console.log(JSON.stringify(data, null, 2));
08454                  return;
08455              }
08456              for (const w of data.windows) {
08457                  const f = w.focused ? '*' : ' ';
08458                  const m = w.minimized ? ' (minimized)' : '';
08459                  console.log(`${f} [${w.id}] ${w.title || '(untitled)'} ${Math.round(w.bounds.w)}×${Math.round(w.bounds.h)}${m}`);
08460              }
08461              return;
08462          }
08463  
08464          if (subcmd === 'get_app_state') {
08465              const target = parseTarget(args[2]);
08466              if (!target.bundle && !target.pid) {
08467                  console.error('Usage: alma cu get_app_state <bundle|pid> [--window=ID] [--depth=N] [--no-shot] [--shot-out=PATH] [--shot-max-width=N]');
08468                  process.exit(1);
08469              }
08470              const body = { ...target };
08471              const w = flag('window');
08472              if (w) body.window_id = parseInt(w, 10);
08473              const d = flag('depth');
08474              if (d) body.depth = parseInt(d, 10);
08475              if (hasFlag('all')) body.interactive_only = false;
08476              if (hasFlag('no-shot')) body.include_screenshot = false;
08477              const sp = flag('shot-out');
08478              if (sp) body.screenshot_path = sp;
08479              const smw = flag('shot-max-width');
08480              if (smw) body.screenshot_max_width = parseInt(smw, 10);
08481              const data = await api('POST', '/api/computer-use/get_app_state', body);
08482              if (asJson) {
08483                  console.log(JSON.stringify(data, null, 2));
08484                  return;
08485              }
08486              console.log(`${data.app.name} (${data.app.bundle || 'pid=' + data.app.pid})`);
08487              console.log(`window: ${data.window.title || ''} [${data.window.id ?? '?'}]`);
08488              if (data.screenshot) {
08489                  console.log(`screenshot: ${data.screenshot.path} ${data.screenshot.width}×${data.screenshot.height}`);
08490              } else if (data.screenshot_error) {
08491                  console.log(`screenshot: FAILED (${data.screenshot_error})`);
08492              }
08493              console.log(`snapshot: ${data.snapshot_id}  elements: ${data.elements.length}`);
08494              console.log('');
08495              for (const el of data.elements) {
08496                  const parts = [`${el.ref.padEnd(5)}`, el.role];
08497                  if (el.subrole) parts.push(`(${el.subrole})`);
08498                  if (el.title) parts.push(`"${el.title}"`);
08499                  else if (el.value) parts.push(`= ${JSON.stringify(String(el.value).slice(0, 60))}`);
08500                  else if (el.description) parts.push(`~ ${JSON.stringify(String(el.description).slice(0, 60))}`);
08501                  if (!el.enabled) parts.push('[disabled]');
08502                  if (el.focused) parts.push('[focused]');
08503                  console.log(parts.join(' '));
08504              }
08505              return;
08506          }
08507  
08508          if (subcmd === 'snap') {
08509              const target = parseTarget(args[2]);
08510              if (!target.bundle && !target.pid) {
08511                  console.error('Usage: alma cu snap <bundle|pid> [--window=ID] [--depth=N] [--all]');
08512                  process.exit(1);
08513              }
08514              const body = { ...target };
08515              const w = flag('window');
08516              if (w) body.window_id = parseInt(w, 10);
08517              const d = flag('depth');
08518              if (d) body.depth = parseInt(d, 10);
08519              if (hasFlag('all')) body.interactive_only = false;
08520              const data = await api('POST', '/api/computer-use/snap', body);
08521              if (asJson) {
08522                  console.log(JSON.stringify(data, null, 2));
08523                  return;
08524              }
08525              console.log(`${data.app.name} (${data.app.bundle || 'pid=' + data.app.pid})`);
08526              console.log(`window: ${data.window.title || ''} [${data.window.id}]`);
08527              console.log(`snapshot: ${data.snapshot_id}  elements: ${data.elements.length}`);
08528              console.log('');
08529              for (const el of data.elements) {
08530                  const parts = [`${el.ref.padEnd(5)}`, el.role];
08531                  if (el.subrole) parts.push(`(${el.subrole})`);
08532                  if (el.title) parts.push(`"${el.title}"`);
08533                  else if (el.value) parts.push(`= ${JSON.stringify(String(el.value).slice(0, 60))}`);
08534                  else if (el.description) parts.push(`~ ${JSON.stringify(String(el.description).slice(0, 60))}`);
08535                  if (!el.enabled) parts.push('[disabled]');
08536                  if (el.focused) parts.push('[focused]');
08537                  console.log(parts.join(' '));
08538              }
08539              return;
08540          }
08541  
08542          const showCursor = !hasFlag('no-cursor');
08543          const buttonArg = (() => {
08544              const b = flag('button');
08545              if (!b) return 'left';
08546              if (!['left', 'right', 'middle'].includes(b)) {
08547                  console.error(`--button must be left|right|middle`);
08548                  process.exit(1);
08549              }
08550              return b;
08551          })();
08552          const clickCountArg = parseInt(flag('clicks') || '1', 10);
08553  
08554          if (subcmd === 'click') {
08555              // Two forms:
08556              //   alma cu click <ref> [--strategy=...] [--button=...] [--clicks=N]
08557              //   alma cu click --pixel <x> <y> [--pid=N] [--button=...] [--clicks=N]
08558              if (hasFlag('pixel')) {
08559                  const xi = args.indexOf('--pixel');
08560                  const x = parseFloat(args[xi + 1]);
08561                  const y = parseFloat(args[xi + 2]);
08562                  if (!Number.isFinite(x) || !Number.isFinite(y)) {
08563                      console.error('Usage: alma cu click --pixel <x> <y> [--pid=N] [--button=...] [--clicks=N]');
08564                      process.exit(1);
08565                  }
08566                  const body = { x, y, button: buttonArg, click_count: clickCountArg, show_cursor: showCursor };
08567                  const p = flag('pid');
08568                  if (p) body.pid = parseInt(p, 10);
08569                  const data = await api('POST', '/api/computer-use/click', body);
08570                  console.log(`clicked @${x},${y} (${data.button}×${data.clicks})`);
08571                  return;
08572              }
08573              const ref = args[2];
08574              if (!ref) {
08575                  console.error('Usage: alma cu click <ref> | --pixel <x> <y>');
08576                  process.exit(1);
08577              }
08578              const strategy = flag('strategy') || 'auto';
08579              const body = { ref, strategy, button: buttonArg, click_count: clickCountArg, show_cursor: showCursor };
08580              const data = await api('POST', '/api/computer-use/click', body);
08581              console.log(`clicked ${data.clicked} (${data.strategy}, ${data.button}×${data.clicks})`);
08582              return;
08583          }
08584  
08585          if (subcmd === 'perform_secondary_action') {
08586              if (hasFlag('pixel')) {
08587                  const xi = args.indexOf('--pixel');
08588                  const x = parseFloat(args[xi + 1]);
08589                  const y = parseFloat(args[xi + 2]);
08590                  if (!Number.isFinite(x) || !Number.isFinite(y)) {
08591                      console.error('Usage: alma cu perform_secondary_action --pixel <x> <y> [--pid=N]');
08592                      process.exit(1);
08593                  }
08594                  const body = { x, y, show_cursor: showCursor };
08595                  const p = flag('pid');
08596                  if (p) body.pid = parseInt(p, 10);
08597                  await api('POST', '/api/computer-use/perform_secondary_action', body);
08598                  console.log(`secondary click @${x},${y}`);
08599                  return;
08600              }
08601              const ref = args[2];
08602              if (!ref) {
08603                  console.error('Usage: alma cu perform_secondary_action <ref> | --pixel <x> <y>');
08604                  process.exit(1);
08605              }
08606              await api('POST', '/api/computer-use/perform_secondary_action', { ref, show_cursor: showCursor });
08607              console.log(`secondary click on ${ref}`);
08608              return;
08609          }
08610  
08611          if (subcmd === 'drag') {
08612              const x1 = parseFloat(args[2]);
08613              const y1 = parseFloat(args[3]);
08614              const x2 = parseFloat(args[4]);
08615              const y2 = parseFloat(args[5]);
08616              if (!Number.isFinite(x1) || !Number.isFinite(y1) || !Number.isFinite(x2) || !Number.isFinite(y2)) {
08617                  console.error('Usage: alma cu drag <x1> <y1> <x2> <y2> [--pid=N] [--button=...]');
08618                  process.exit(1);
08619              }
08620              const body = { start_x: x1, start_y: y1, end_x: x2, end_y: y2, button: buttonArg, show_cursor: showCursor };
08621              const p = flag('pid');
08622              if (p) body.pid = parseInt(p, 10);
08623              await api('POST', '/api/computer-use/drag', body);
08624              console.log(`dragged ${x1},${y1} → ${x2},${y2}`);
08625              return;
08626          }
08627  
08628          if (subcmd === 'type_text') {
08629              const text = args[2];
08630              if (text === undefined) {
08631                  console.error('Usage: alma cu type_text <text> [--pid=N] [--bundle=ID] [--ref=eN] [--input-method=auto|physical|unicode|ax]');
08632                  process.exit(1);
08633              }
08634              const body = { text };
08635              const p = flag('pid');
08636              if (p) body.pid = parseInt(p, 10);
08637              const b = flag('bundle');
08638              if (b) body.bundle = b;
08639              const r = flag('ref');
08640              if (r) body.ref = r;
08641              const m = flag('input-method') || flag('input_method');
08642              if (m) body.input_method = m;
08643              await api('POST', '/api/computer-use/type_text', body);
08644              console.log(`typed ${text.length} chars`);
08645              return;
08646          }
08647  
08648          if (subcmd === 'press_key') {
08649              const combo = args[2];
08650              if (!combo) {
08651                  console.error('Usage: alma cu press_key <combo> [--pid=N]  e.g. cmd+s, ctrl+shift+t, Return');
08652                  process.exit(1);
08653              }
08654              const body = { key: combo };
08655              const p = flag('pid');
08656              if (p) body.pid = parseInt(p, 10);
08657              await api('POST', '/api/computer-use/press_key', body);
08658              console.log(`pressed ${combo}`);
08659              return;
08660          }
08661  
08662          if (subcmd === 'set_value') {
08663              const ref = args[2];
08664              const raw = args[3];
08665              if (!ref || raw === undefined) {
08666                  console.error('Usage: alma cu set_value <ref> <value>');
08667                  process.exit(1);
08668              }
08669              // Coerce number / bool / fallback to string.
08670              let value;
08671              if (raw === 'true') value = true;
08672              else if (raw === 'false') value = false;
08673              else if (!Number.isNaN(Number(raw)) && raw.trim() !== '') value = Number(raw);
08674              else value = raw;
08675              await api('POST', '/api/computer-use/set_value', { ref, value });
08676              console.log(`set ${ref} = ${JSON.stringify(value)}`);
08677              return;
08678          }
08679  
08680          if (subcmd === 'type') {
08681              const ref = args[2];
08682              const text = args[3];
08683              if (!ref || text === undefined) {
08684                  console.error('Usage: alma cu type <ref> <text> [--append] [--no-cursor]');
08685                  process.exit(1);
08686              }
08687              const replace = !hasFlag('append');
08688              const data = await api('POST', '/api/computer-use/type', { ref, text, replace, show_cursor: showCursor });
08689              console.log(`typed ${data.length} chars into ${data.typed}`);
08690              return;
08691          }
08692  
08693          if (subcmd === 'press') {
08694              const ref = args[2];
08695              const key = args[3];
08696              if (!ref || !key) {
08697                  console.error('Usage: alma cu press <ref> <key> [--no-cursor]');
08698                  process.exit(1);
08699              }
08700              const data = await api('POST', '/api/computer-use/press', { ref, key, show_cursor: showCursor });
08701              console.log(`pressed ${data.pressed}`);
08702              return;
08703          }
08704  
08705          if (subcmd === 'scroll') {
08706              const ref = args[2];
08707              const direction = args[3];
08708              if (!ref || !direction) {
08709                  console.error('Usage: alma cu scroll <ref> <up|down|left|right> [--pages=N] [--no-cursor]');
08710                  process.exit(1);
08711              }
08712              const pages = parseInt(flag('pages') || '1', 10);
08713              const data = await api('POST', '/api/computer-use/scroll', { ref, direction, pages, show_cursor: showCursor });
08714              console.log(`scrolled ${data.scrolled} x${data.pages}`);
08715              return;
08716          }
08717  
08718          if (subcmd === 'lens') {
08719              const mode = args[2];
08720              let enabled;
08721              if (mode === 'on' || mode === 'true' || mode === '1') enabled = true;
08722              else if (mode === 'off' || mode === 'false' || mode === '0') enabled = false;
08723              else if (mode === 'toggle' || mode === undefined) enabled = undefined;
08724              else {
08725                  console.error('Usage: alma cu lens <on|off|toggle>');
08726                  process.exit(1);
08727              }
08728              // Toggle: read current state, flip.
08729              if (enabled === undefined) {
08730                  const cur = await api('POST', '/api/computer-use/lens', {});
08731                  enabled = !cur.enabled;
08732              }
08733              const data = await api('POST', '/api/computer-use/lens', { enabled });
08734              console.log(`lens: ${data.enabled ? 'on' : 'off'}`);
08735              return;
08736          }
08737  
08738          if (subcmd === 'raise') {
08739              const target = parseTarget(args[2]);
08740              if (!target.bundle && !target.pid) {
08741                  console.error('Usage: alma cu raise <bundle|pid> [--window=ID]');
08742                  process.exit(1);
08743              }
08744              const body = { ...target };
08745              const w = flag('window');
08746              if (w) body.window_id = parseInt(w, 10);
08747              await api('POST', '/api/computer-use/raise', body);
08748              console.log('raised');
08749              return;
08750          }
08751  
08752          if (subcmd === 'shot') {
08753              const target = parseTarget(args[2]);
08754              const out = flag('out') || `/tmp/alma-cu-${Date.now()}.jpg`;
08755              const body = { ...target, out };
08756              const w = flag('window');
08757              if (w) body.window_id = parseInt(w, 10);
08758              const mw = flag('max-width');
08759              if (mw) body.max_width = parseInt(mw, 10);
08760              const data = await api('POST', '/api/computer-use/shot', body);
08761              console.log(`${data.path}  ${data.width}×${data.height}`);
08762              return;
08763          }
08764  
08765          if (subcmd === 'shutdown') {
08766              await api('POST', '/api/computer-use/shutdown');
08767              console.log('daemon stopped.');
08768              return;
08769          }
08770  
08771          console.error(`Unknown cu subcommand: ${subcmd}. Run 'alma cu help' for usage.`);
08772          process.exit(1);
08773      }

```
