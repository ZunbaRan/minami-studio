# build_p0.py 的 Markdown 数据页

> 来源：用户提供的 .164 研究资料 `analysis/conformance/build_p0.py`；原文件 SHA256 `acc5a4fc111fe34bde77c502730f9c24e179d1663b79608186e21f6a668c51a1`；全文件 1–12 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

此代码/数据仅供阅读与后续实现提取；本次未执行其所描述的产品行为。

```python
from pathlib import Path
import json
O=Path(__file__).parent
x=json.loads((O/'contract-vectors.json').read_text());d={c['id']:c for c in x['cases']}
ids=['schema.click.null.ref','schema.click.bound.click_count.4','schema.click.bound.click_count.0','schema.sky_click.fractional.click_count','schema.sky_scroll.valid.pages','schema.set_value.null.value','transport.out_of_order','transport.no_lf','transport.disconnect','transport.truthy.yes','target.ref_wins','target.zero_coordinate','target.window_only','target.click.click_count.0','target.sky_click.click_count.0','state.plain_defaults','state.sky_first_full','diff.sky_append','diff.sky_full_reset','diff.labels_and_bounds','diff.native_add_change_remove','diff.disabled_resets','screenshots.get_app_state.path','screenshots.sky_get_app_state.path','screenshots.sky_get_app_state.data_url','screenshots.postshot_no_path','screenshots.mapping','permissions.denied','permissions.http503','UI.dismiss_boundary','UI.dismiss_expired','UI.electron_ring']
ids.extend(['transport.utf8_split','transport.timeout_local_no_replay','transport.safe_reconnect','cancel.safe_uncertain','target.safe_binding'])
ids.extend(['target.visual_ref_loses_target','state.sky_ignores_visual_regions'])
assert len(ids)==39 and all(i in d for i in ids)
entries=[]
for i in ids:
 c=d[i];entries.append({'id':i,'group':c['group'],'profile':c['profile'],'input':c['input'],'harness_seam':c['harness_seam'],'expected_observation':c['oracle']['expected'],'oracle_operator':'recursive_exact_expected_projection','source_case':i})
(O/'p0-critical-subset.json').write_text(json.dumps({'status':'NOT_RUN; expected-observation checker provided; replacement harness must supply independent actual observations','cases':entries},ensure_ascii=False,indent=2)+'\n')
```
