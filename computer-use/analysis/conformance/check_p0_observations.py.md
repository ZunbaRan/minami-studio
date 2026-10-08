# check_p0_observations.py 的 Markdown 数据页

> 来源：用户提供的 .164 研究资料 `analysis/conformance/check_p0_observations.py`；原文件 SHA256 `30ed070941ca5247c8a87af153d1d6bf4ab7b2863bcd68faa8e3fd9ba9aceb75`；全文件 1–25 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

此代码/数据仅供阅读与后续实现提取；本次未执行其所描述的产品行为。

```python
#!/usr/bin/env python3
"""Usage: python check_p0_observations.py ACTUAL.json
Actual shape: {caseID:{...independently instrumented observation...}, ...}.
Never invokes original or replacement code. A missing case cannot pass.
"""
import sys,json
from pathlib import Path
p=Path(__file__).with_name('p0-critical-subset.json');cases=json.loads(p.read_text())['cases']
def compare(e,a,path=''):
 if isinstance(e,dict):
  if not isinstance(a,dict):return [f'{path}: expected object']
  return [err for k,v in e.items() for err in ([f'{path}/{k}: missing'] if k not in a else compare(v,a[k],path+'/'+k))]
 if isinstance(e,list):
  if not isinstance(a,list) or len(a)!=len(e):return [f'{path}: array shape mismatch']
  return [err for i,(v,w) in enumerate(zip(e,a)) for err in compare(v,w,path+'/'+str(i))]
 if isinstance(e,bool) or e is None:
  return [] if type(e) is type(a) and e==a else [f'{path}: expected {e!r}, got {a!r}']
 return [] if e==a and not isinstance(a,bool) else [f'{path}: expected {e!r}, got {a!r}']
if len(sys.argv)!=2:raise SystemExit(__doc__)
actual=json.loads(Path(sys.argv[1]).read_text());results=[]
for c in cases:
 errors=['case missing'] if c['id'] not in actual else compare(c['expected_observation'],actual[c['id']])
 results.append({'id':c['id'],'result':'FAIL' if errors else 'PASS','errors':errors})
print(json.dumps({'scope':'P0 normalized observation projection only; not OS certification','results':results},ensure_ascii=False,indent=2))
raise SystemExit(1 if any(r['result']=='FAIL' for r in results) else 0)
```
