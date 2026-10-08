# validate_bundle.py 的 Markdown 数据页

> 来源：用户提供的 .164 研究资料 `validate_bundle.py`；原文件 SHA256 `71d1dafb1d43ce4751655f92c07bc1d7ed49e578429e874855e467348731bc55`；全文件 1–30 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

此代码/数据仅供阅读与后续实现提取；本次未执行其所描述的产品行为。

```python
"""Read-only, standard-library validation of this original research bundle.
This never executes an application, target sample, implementation or fixture.
"""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parent
manifest=json.loads((root/'bundle-manifest.json').read_text())
errors=[]
for item in manifest['files']:
    p=root/item['path']
    if not p.is_file():errors.append('missing '+item['path']);continue
    if p.stat().st_size!=item['bytes']:errors.append('size '+item['path'])
    if hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:errors.append('hash '+item['path'])
    if p.suffix=='.json':
        try:json.loads(p.read_text())
        except Exception as ex:errors.append('JSON '+item['path']+' '+str(ex))
for p in root.rglob('*'):
    if p.is_file() and p.suffix.lower() in ['.macho','.asm','.js','.mjs','.jpg','.jpeg','.png','.dmg','.dylib','.asar']:
        errors.append('forbidden artifact '+str(p.relative_to(root)))
checks={}
for rel,key,count in [('analysis/mcp/protocol-catalog.json','tools',23),('analysis/mcp/cli-command-catalog.json','commands',23)]:
    d=json.loads((root/rel).read_text());checks[key]=len(d[key])
    if len(d[key])!=count:errors.append('unexpected count '+rel)
native=json.loads((root/'analysis/native-snapshot/dispatch-inventory.json').read_text());checks['native_commands']=len(native)
if len(native)!=45:errors.append('native count')
if len({x['command'] for x in native})!=45:errors.append('duplicate native command')
if 'snapshot' in {x['command'] for x in native}:errors.append('nonexistent snapshot command')
if manifest['product_tests_run']!=0:errors.append('unexpected product runtime claim')
print(json.dumps({'status':'PASS_BUNDLE_DOCUMENT_INTEGRITY_ONLY' if not errors else 'FAIL','files_checked':len(manifest['files']),'surface_counts':checks,'product_tests_run':0,'errors':errors},ensure_ascii=False,indent=2))
sys.exit(1 if errors else 0)
```
