#!/usr/bin/env python3
"""Read-only validation of this technical package, never vendor/product execution.
Run: python3 validate_package.py
Optional: --verify-manifest (after package manifest is frozen).
"""
from pathlib import Path
import json,re,hashlib,collections,argparse,urllib.parse
p=argparse.ArgumentParser();p.add_argument('--verify-manifest',action='store_true');args=p.parse_args()
R=Path(__file__).resolve().parent;errors=[];files=sorted(q for q in R.rglob('*') if q.is_file())
for q in files:
 if q.is_symlink():errors.append('symlink: '+str(q.relative_to(R)))
 if q.suffix not in {'.md','.json','.py','.txt'}:errors.append('unexpected file type: '+str(q.relative_to(R)))
for q in R.rglob('*.json'):
 try:json.loads(q.read_text())
 except Exception as e:errors.append(f'JSON {q}: {e}')
links=0
for q in R.rglob('*.md'):
 t=re.sub(r'```.*?```','',q.read_text(),flags=re.S)
 for m in re.finditer(r'(?<!!)\[[^\]]*\]\(([^)]+)\)',t):
  d=m.group(1).split()[0]
  if re.match(r'^[a-zA-Z][a-zA-Z0-9+.-]*:',d):continue
  base=urllib.parse.unquote(d.split('#',1)[0]);target=(q.parent/base).resolve() if base else q
  links+=1
  if not target.is_relative_to(R):errors.append(f'nonportable link: {q.relative_to(R)} -> {d}')
  elif not target.exists():errors.append(f'missing link: {q.relative_to(R)} -> {d}')
  elif '#' in d and target.suffix=='.md':
   anchor=urllib.parse.unquote(d.split('#',1)[1]).lower();body=target.read_text()
   def slug(s):
    s=re.sub(r'[`*_~]','',s.strip().lower());s=''.join(c for c in s if c.isalnum() or c in ' -_');return s.replace(' ','-')
   anchors={slug(x) for x in re.findall(r'^#{1,6}\s+(.+)$',body,re.M)}|set(re.findall(r'id=["\']([^"\']+)',body))
   if anchor not in anchors:errors.append(f'missing anchor: {q.relative_to(R)} -> {d}')
C=R/'analysis/conformance';x=json.loads((C/'contract-vectors.json').read_text());cs=x['cases'];ids=[c['id'] for c in cs]
if len(cs)!=734 or len(ids)!=len(set(ids)):errors.append('main case count/uniqueness')
if any(c['execution_status']!='NOT_RUN' for c in cs):errors.append('product result status is not NOT_RUN')
byid={c['id']:c for c in cs};cool=byid['UI.cooldown']
if cool['input']!={'last_agent_activity_ms':10000,'ticks_ms':[10333,10666,10999,11332]} or cool['oracle']['expected']!={'capture_start_ticks_ms':[11332]}:errors.append('cooldown oracle regression')
if byid['UI.cooldown.zero_sentinel']['input']['last_agent_activity_ms']!=0:errors.append('missing zero sentinel')
p0=json.loads((C/'p0-critical-subset.json').read_text())['cases']
if len(p0)!=39 or any(c['expected_observation']!=byid[c['id']]['oracle']['expected'] for c in p0):errors.append('P0 mismatch')
adv='\n'.join(q.read_text() for q in (R/'modules/native-http-mcp').glob('*.md'))
adv_ids=set(re.findall(r'^(?:\|\s*|- )((?:AU|RP|LC|IT)-\d+)(?:\s*\||：)',adv,re.M))
if len(adv_ids)!=79:errors.append(f'advanced case count {len(adv_ids)} !=79')
policy=json.loads((R/'contracts/safe-policy.json').read_text())
if policy['behaviorProfile']!='UNSELECTED' or policy['liveInputEnabled'] is not False:errors.append('default profile/input is not unselected/off')
try:
 import jsonschema
 jsonschema.validate(x,json.loads((C/'contract-vectors.schema.json').read_text()))
 for q in R.rglob('*.schema.json'):jsonschema.Draft202012Validator.check_schema(json.loads(q.read_text()))
except ImportError:errors.append('jsonschema dependency missing; see analysis/conformance/requirements.txt')
except Exception as e:errors.append('schema validation: '+str(e))
if args.verify_manifest:
 manifest=(R/'provenance/FILE_MANIFEST.md').read_text();entries=re.findall(r'^\| `([^`]+)` \| (\d+) \| `([0-9a-f]{64})` \|',manifest,re.M)
 expected={str(q.relative_to(R)) for q in files if q!=R/'provenance/FILE_MANIFEST.md'}
 if {name for name,_,_ in entries}!=expected:errors.append('manifest file set mismatch')
 for name,size,h in entries:
  q=R/name
  if not q.exists() or len(q.read_bytes())!=int(size) or hashlib.sha256(q.read_bytes()).hexdigest()!=h:errors.append('manifest mismatch: '+name)
print(json.dumps({'status':'FAIL' if errors else 'PASS_DOCUMENT_PACKAGE_ONLY','files':len(files),'markdown_documents':sum(q.suffix=='.md' for q in files),'json_files':sum(q.suffix=='.json' for q in files),'relative_links_checked':links,'main_design_cases':len(cs),'advanced_design_cases':len(adv_ids),'combined_design_entries':len(cs)+len(adv_ids),'main_P0_design_cases':len(p0),'product_tests_run':0,'vendor_code_executed':False,'errors':errors},ensure_ascii=False,indent=2))
raise SystemExit(bool(errors))
