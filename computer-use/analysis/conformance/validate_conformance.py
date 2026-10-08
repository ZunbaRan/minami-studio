#!/usr/bin/env python3
"""Validates documentation fixtures only. Does not load or execute Alma code."""
from pathlib import Path
import json, collections, hashlib, argparse
parser=argparse.ArgumentParser(description="Validate distributed documentation only; optional original-sample hash verification")
parser.add_argument("--sample-root",type=Path,help="Original research root containing extracted/; never executed")
args=parser.parse_args()
import jsonschema
O=Path(__file__).parent; R=O.parents[1]
def read(p):return json.loads((O/p).read_text())
x=read('contract-vectors.json'); jsonschema.Draft202012Validator.check_schema(read('contract-vectors.schema.json'));jsonschema.validate(x,read('contract-vectors.schema.json'))
cs=x['cases']; ids=[c['id'] for c in cs];assert len(ids)==len(set(ids)),'duplicate case ID'
es={e['id'] for e in read('evidence-registry.json')};rs=read('requirements-traceability.json');rids={r['id'] for r in rs}; schemas={t['name']:t['input_schema'] for t in json.loads((R/'analysis/mcp/protocol-catalog.json').read_text())['tools']}
for c in cs:
 assert set(c['evidence_ids'])<=es,c['id'];assert set(c['requirement_ids'])<=rids,c['id']
 if c['group']=='schema':
  inp=c['input']; v=jsonschema.Draft202012Validator(schemas[inp['tool']]).is_valid(inp['args']);assert v==c['oracle']['expected']['schema_valid'],c['id']
 assert c['execution_status']=='NOT_RUN'
for r in rs:
 assert set(r['case_ids'])=={c['id'] for c in cs if r['id'] in c['requirement_ids']}
for p in O.glob('*.json'):json.loads(p.read_text())
for e in read('evidence-registry.json'):
 assert (R/e['path']).exists(),e['id']
 if 'locator' in e and args.sample_root:
  loc=e['locator']; raw=(args.sample_root/loc['path']).read_bytes(); lo,hi=loc['byte_range_half_open']; assert hashlib.sha256(raw[lo:hi]).hexdigest()==loc['range_sha256'],e['id']
p0=read('p0-critical-subset.json')['cases']; assert len(p0)==39
assert all(c['id'] in set(ids) for c in p0)
assert all(c['expected_observation']==next(v['oracle']['expected'] for v in cs if v['id']==c['id']) for c in p0)
jsonschema.Draft202012Validator.check_schema(read('runtime-result.schema.json'))
report={'status':'PASS_DOCUMENT_VALIDATION_ONLY','checks':['all generated JSON parses','vector JSON Schema validation','unique case IDs','all case evidence/requirement IDs resolve','bidirectional requirement coverage','schema permutations agree with source-transcribed schemas','runtime result schema is valid','evidence index paths exist in distributed tree','all39 P0 cases match main corpus'],'counts':{'cases':len(cs),'by_origin':dict(collections.Counter(c['design_origin'] for c in cs)),'by_group':dict(collections.Counter(c['group'] for c in cs)),'by_oracle':dict(collections.Counter(c['oracle']['status'] for c in cs))},'sample_hash_verification':'PASS' if args.sample_root else 'SKIPPED_NO_SAMPLE_REQUESTED','product_tests_run':0,'Alma_code_executed':False,'limitations':['Schema oracle tests compare against static transcription, not runtime tools/list','No receiver/OS behavior tested','Generated matrix cells are coverage obligations, not individually established behavior'],'corpus_sha256':hashlib.sha256((O/'contract-vectors.json').read_bytes()).hexdigest()}
(O/'validation-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(report,ensure_ascii=False,indent=2))
