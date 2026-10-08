# build_conformance.py 的 Markdown 数据页

> 来源：用户提供的 .164 研究资料 `analysis/conformance/build_conformance.py`；原文件 SHA256 `3b76730f8050f9659f387199a74654ef75f87e5a46302a6a81d8d08c7515fc5d`；全文件 1–165 行。类别：研究契约/设计参考，非厂商原始源码；当前版本经过整合勘误，详见根目录 CHANGELOG.md。原静态结论与未运行验收必须区分。

历史生成器只供阅读；它未更新为本次734条合并语料的完整生成入口，不要用它覆盖当前contract-vectors.json。UI.cooldown原错误已在此参考代码纠正；新增zero_sentinel以当前机器JSON为准。

```python
#!/usr/bin/env python3
"""Build original synthetic documentation data. Never imports or executes target code."""
from pathlib import Path
import json, hashlib, copy
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'analysis/conformance'
def write(name,x): (OUT/name).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
cat=json.loads((ROOT/'analysis/mcp/protocol-catalog.json').read_text())
loc=json.loads((ROOT/'analysis/mcp/source-locators.json').read_text())['locators']
evidence=[{'id':x['id'],'path':'analysis/mcp/source-locators.json','locator':x} for x in loc]
for ident,path,section in [
 ('AUDIT','analysis/audit/edge-contract-audit.md','Verified contracts and corrections'),('NATIVE.VISUAL','analysis/native-snapshot/WIRE_SCHEMA.md','Visual click; 0x100078104/78110/78118 to0x100079324/79330/7934c'),('NATIVE.SNAPSHOT','analysis/native-snapshot/FINDINGS.md','raw snapshot.elements count and visual_regions'),
 ('NATIVE.REF','analysis/native/FINDINGS.md','1. ElementStore'),('NATIVE.DIFF','analysis/native/FINDINGS.md','3. AppStateDiff'),('NATIVE.MAP','analysis/native/FINDINGS.md','6. Screenshot mapping and OCR'),('NATIVE.KEY','analysis/native/FINDINGS.md','4. Keyboard delivery'),
 ('HOST.ERROR','analysis/host/host-contract-report.md','7. Model output adaptation'),('HOST.CANCEL','analysis/host/host-contract-report.md','6. Cancellation'),('HOST.TRANSPORT','analysis/host/host-contract-report.md','4. Helper transport'),
 ('UI.STACK','analysis/mirror-ui/behavioral-contract.md','2. Unified PiP state'),('UI.PUMP','analysis/mirror-ui/behavioral-contract.md','4. Capture versus renderer loop'),('UI.FOCUS','analysis/mirror-ui/behavioral-contract.md','3. Selection'),('UI.APPSHOT','analysis/mirror-ui/behavioral-contract.md','Appshot'),
 ('NATIVE.CURSOR','analysis/mirror-ui/native-cursor-contract.md','2. ActionCursor'),('NATIVE.PIP','analysis/mirror-ui/native-cursor-contract.md','6. Native PiP pointer mapping')]:
 evidence.append({'id':ident,'path':path,'section':section,'sha256_at_generation':hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),'status':'analyst_report; consult embedded original anchors; runtime effect unverified'})
write('evidence-registry.json',evidence)
groups=['transport','schema','target','ref','state','diff','screenshots','cancel','permissions','error_propagation','UI']
reqs=[]; cases=[]
def add(group,id,inp,expected,ev,profile='alma_0_4_164',kind='positive',unknown=False):
 rid='REQ-'+group.upper()
 cases.append({'id':id,'group':group,'profile':profile,'kind':kind,'requirement_ids':[rid],'evidence_ids':ev,'input':inp,'oracle':{'status':'UNKNOWN_REQUIRE_RUNTIME' if unknown else 'STATIC_EXPECTATION','expected':expected},'execution_status':'NOT_RUN'})
for g in groups:
 reqs.append({'id':'REQ-'+g.upper(),'group':g,'meaning':{'transport':'JSONL关联、计时与断线；不得重放变更','schema':'先校验再归一化，普通与sky接口分开','target':'审批/动作/截图/日志身份可分别记录','ref':'引用身份、生命周期、失效与恢复','state':'快照基线与可观察状态','diff':'增改删、重置、PID/window隔离','screenshots':'截图载荷、映射、失败退化','cancel':'取消响应与取消副作用分开证明','permissions':'本地批准与OS权限分层','error_propagation':'传输/工具/语义/呈现错误不可混同','UI':'三种视觉系统的呈现、资源、光标与焦点'}[g],'evidence_ids':[],'case_ids':[]})
# Pure schema contracts. Validity here never promises action delivery.
def value(s,name=''):
 if 'enum' in s:return s['enum'][0]
 if 'anyOf' in s:return value(s['anyOf'][0],name)
 return {'string':{'app':'org.example.cu.fixture','bundle':'org.example.cu.fixture','ref':'e_fixture','text':'合成🧪','key':'Left'}.get(name,'fixture'),'integer':1,'number':1.25,'boolean':True,'object':{}}.get(s.get('type'),'fixture')
for tool in cat['tools']:
 name=tool['name']; s=tool['input_schema']; props=s.get('properties',{}); required=s.get('required',[])
 base={k:value(props[k],k) for k in required}; ev=tool['evidence']
 def sc(suffix,inp,valid,kind):add('schema','schema.'+name+'.'+suffix,{'tool':name,'args':inp},{'schema_valid':valid,'scope':'schema only; handler/native side effects not asserted'},ev,kind=kind)
 sc('minimal',base,True,'positive')
 for k in required:
  d=copy.deepcopy(base);d.pop(k);sc('missing.'+k,d,False,'negative')
 for k,p in props.items():
  d=copy.deepcopy(base);d[k]=None;sc('null.'+k,d,False,'negative')
  d=copy.deepcopy(base);d[k]=value(p,k);sc('valid.'+k,d,True,'positive')
  d=copy.deepcopy(base);d[k]=[];sc('wrongtype.'+k,d,False,'negative')
  if p.get('type')=='integer':
   d=copy.deepcopy(base);d[k]=1.5;sc('fractional.'+k,d,False,'negative')
  if 'maximum' in p:
   for n,valid in [(p['maximum'],True),(p['maximum']+1,False),(0,True),(-1,True)]:
    d=copy.deepcopy(base);d[k]=n;sc('bound.'+k+'.'+str(n),d,valid,'positive' if valid else 'negative')
  if 'enum' in p:
   for n in p['enum']:
    d=copy.deepcopy(base);d[k]=n;sc('enum.'+k+'.'+n,d,True,'positive')
   d=copy.deepcopy(base);d[k]='__invalid__';sc('invalid_enum.'+k,d,False,'negative')
# Original precise seam vectors. Adapter harness supplies mocks and captures calls, not OS effects.
def a(g,i,inp,out,ev,**kw):add(g,g+'.'+i,inp,out,[ev] if isinstance(ev,str) else ev,**kw)
for chunks in [['{"id":"a","ok":true,"data":7}\n'],['{"id":"a",','"ok":true,','"data":7}\n'],['\n','garbage\n','{"id":"unknown","ok":true}\n','{"id":"a","ok":true,"data":7}\n']]:
 a('transport','chunks.'+str(len(cases)),{'pending':['a'],'receive_chunks':chunks},{'resolutions':[{'id':'a','value':7}],'rejections':[],'pending_after':[]},'MCP.transport')
a('transport','out_of_order',{'pending':['a','b'],'receive_lines':[{'id':'b','ok':True,'data':2},{'id':'a','ok':True,'data':1}]},{'resolutions':[{'id':'b','value':2},{'id':'a','value':1}]},'MCP.transport')
for ok,success in [(True,True),(1,True),('yes',True),(False,False),(0,False),('',False),(None,False)]:
 a('transport','truthy.'+str(ok),{'pending':['a'],'response':{'id':'a','ok':ok,'data':7,'error':{'message':'fixture error','code':'fixture_code','hint':'fixture hint'}}},{'resolved':success,'value':7 if success else None,'error':None if success else {'message':'fixture error','code':'fixture_code','hint':'fixture hint'}},'MCP.transport',kind='negative' if not success else 'positive')
a('transport','no_lf',{'pending':['a'],'receive_chunks':['{"id":"a","ok":true,"data":7}'],'advance_ms':10},{'resolution_count':0,'pending_after':['a']},'MCP.transport')
a('transport','disconnect',{'pending':['a','b'],'event':'socket_close'},{'rejection_count':2,'messages':['computer-use daemon disconnected']*2,'socket':None,'retry_sent':False},'MCP.transport',kind='negative')
a('transport','partial_reconnect',{'first_connection_bytes':'{"id":','disconnect':True,'second_connection_bytes':'{"id":"b","ok":true,"data":2}\n'},{'retained_buffer_hazard':True,'actual_first_reply_corruption':'UNKNOWN_REQUIRE_RUNTIME','required_witness':'raw bytes + connection epoch + pending outcomes'},'MCP.transport',kind='negative',unknown=True)
a('transport','safe_reconnect',{'partial_line_before_disconnect':True},{'buffer_reset':True,'old_epoch_response_accepted':False,'mutation_replay_count':0},'AUDIT',profile='safe_profile',kind='negative')
a('transport','id_shape',{'operation':'new request'},{'id_regex':'^[0-9a-f]{16}$','request_keys':['id','cmd','args'],'line_terminator':'LF'},'MCP.transport')
a('target','ref_wins',{'tool':'click','args':{'ref':'e_fixture','x':0,'y':0,'bundle':'org.example.other','pid':222,'window_id':9}},{'native_call':{'cmd':'click','args':{'ref':'e_fixture','button':'left','click_count':1,'strategy':'auto','show_cursor':True}},'approval_bundle':'org.example.other','postshot_target':{'bundle':'org.example.other','pid':222,'window_id':9}},['MCP.tool.click','MCP.screenshot'])
a('target','zero_coordinate',{'tool':'click','args':{'x':0,'y':0}},{'native_call':{'cmd':'click','args':{'x':0,'y':0,'coord_space':'screenshot','button':'left','click_count':1,'strategy':'auto','show_cursor':True}},'postshot_calls':0},'MCP.tool.click')
a('target','window_only',{'tool':'click','args':{'ref':'e_fixture','window_id':9}},{'native_args_forbidden_keys':['window_id'],'postshot_calls':0},['MCP.tool.click','MCP.screenshot'])
a('target','empty_ref_coordinates',{'tool':'click','args':{'ref':'','x':0,'y':0}},{'native_ref_present':False,'native_x':0,'native_y':0},'MCP.tool.click')
a('target','missing_coordinates',{'tool':'click','args':{'x':1}},{'isError':True,'native_calls':0,'message':'click requires either `ref` or both `x` and `y`'},['MCP.tool.click','MCP.sdk-error'],kind='negative')
for tool,field,raw,normalized in [('click','click_count',0,1),('click','click_count',-1,1),('list_apps','days',0,14),('get_app_state','depth',-1,6),('get_app_state','depth',0,0),('get_app_state','screenshot_max_width',0,1280),('scroll','pages',-1,1),('sky_scroll','pages',-1.5,-1.5),('sky_click','click_count',0,0)]:
 a('target',tool+'.'+field+'.'+str(raw),{'tool':tool,'args':dict({'click':{'ref':'e_fixture'},'list_apps':{},'get_app_state':{},'scroll':{'ref':'e_fixture','direction':'down'},'sky_scroll':{'app':'org.example.cu.fixture','element_index':0,'direction':'d'},'sky_click':{'app':'org.example.cu.fixture','element_index':0}}[tool],**{field:raw}),'setup':{'sky_index_map':{'org.example.cu.fixture':['e_fixture']},'approval':{'status':200,'body':{'approved':True}},'daemon_default':{'ok':True,'data':{}},'postshot_default':{'ok':True,'data':{}},'playbooks':{}}},{'forwarded_field':field,'value':normalized},'MCP.tool.'+tool)
a('target','safe_binding',{'resolved_ref_owner':'org.example.A','supplied_bundle':'org.example.B'},{'dispatch_count':0,'error_class':'TARGET_MISMATCH','approval_action_capture_log_identity_equal':True},'AUDIT',profile='safe_profile',kind='negative')
# Ref/store static algorithm invariants; runtime AX object equality needs controlled receiver.
a('ref','retain_next_snapshot',{'existing_entry':'e1','AXRole_read':'success','event':'beginSnapshot'},{'entry_table_contains_e1':True,'current_snapshot_refs':[]},'NATIVE.REF')
a('ref','prune_invalid',{'existing_entry':'e1','AXRole_error':-25202,'event':'beginSnapshot'},{'entry_table_contains_e1':False},'NATIVE.REF',kind='negative')
a('ref','reuse_once',{'existing_entry':{'ref':'e1','pid':111},'new_element':'CFEqual to existing','current_snapshot_refs':[]},{'returned_ref':'e1'},'NATIVE.REF')
for matches,accepted in [(0,False),(1,True),(2,False)]:a('ref','descriptor.'+str(matches),{'matching_candidates':matches},{'recovery_accepted':accepted,'keep_original_ref_if_recovered':True},'NATIVE.REF',kind='positive' if accepted else 'negative')
a('ref','stale_runtime',{'event':'destroy control; recreate duplicate descriptors; use old ref'},{'acceptance':'UNKNOWN_REQUIRE_RUNTIME','measure':['AX error','reference table','receiver event count'],'safe_requirement':'reject ambiguity; never select arbitrary duplicate'},'NATIVE.REF',unknown=True,kind='negative')
a('state','plain_defaults',{'tool':'get_app_state','args':{}},{'native_args':{'depth':6,'interactive_only':True,'include_screenshot':True,'screenshot_max_width':1280,'auto_launch':True},'rpc_timeout_ms':30000,'approval_calls':0},'MCP.tool.get_app_state')
a('state','sky_first_full',{'tool':'sky_get_app_state','args':{'app':'org.example.cu.fixture'},'prior_indices':[]},{'native_args':{'bundle':'org.example.cu.fixture','disable_diff':True},'rpc_timeout_ms':20000},'MCP.tool.sky_get_app_state')
a('state','sky_existing_diff',{'tool':'sky_get_app_state','args':{'app':'org.example.cu.fixture'},'prior_indices':['e1']},{'native_args':{'bundle':'org.example.cu.fixture','disable_diff':False}},'MCP.tool.sky_get_app_state')
a('state','unicode_summary',{'tool':'type_text','args':{'text':'A🧪中'}},{'displayed_length':4,'unit':'UTF-16 code units'},'MCP.tool.type_text')
a('diff','sky_append',{'prior_refs':['e1','e2'],'raw':{'elements_are_diff':True,'elements':[{'ref':'e2'},{'ref':'e3'}],'removed_refs':['e1']}},{'refs':['e1','e2','e3'],'emitted_indices':[1,2],'deleted_ref_still_in_index':True},'MCP.sky-render')
a('diff','sky_full_reset',{'prior_refs':['e1','e2'],'raw':{'elements_are_diff':False,'elements':[{'ref':'e3'},{'ref':'e2'}]}},{'refs':['e3','e2'],'emitted_indices':[0,1]},'MCP.sky-render')
a('diff','labels_and_bounds',{'elements':[{'ref':'e1','role':'AXButton','title':'  ','description':' Save ','value':3,'bounds':{'x':1.4,'y':2.6,'w':10.5,'h':20.1},'enabled':False,'focused':True}]},{'text':'[0] Button "Save" @1,3 11x20 (focused,disabled)','refs':['e1']},'MCP.sky-render')
a('diff','skip_nonref',{'elements':[{'role':'AXButton'},{'ref':7},{'ref':''}]},{'refs':[],'text':''},'MCP.sky-render')
a('diff','native_add_change_remove',{'baseline':[{'ref':'e1','title':'one'},{'ref':'e2','title':'two'},{'ref':'e10','title':'ten'}],'next':[{'ref':'e2','title':'TWO'},{'ref':'e3','title':'three'}]},{'changed_refs':['e2','e3'],'removed_refs':['e1','e10'],'unchanged_count':0,'is_diff':True},'NATIVE.DIFF')
a('diff','disabled_resets',{'baseline':[{'ref':'e1','title':'old'}],'disabled_snapshot':[{'ref':'e1','title':'new'}],'following_snapshot':[{'ref':'e1','title':'new'}]},{'disabled_output':{'full':True,'removed_refs':[],'unchanged_count':0},'following_output':{'changed_refs':[],'unchanged_count':1,'is_diff':True}},'NATIVE.DIFF')
a('diff','key_isolation',{'pid':111,'window_ids':[None,42,43]},{'keys':['111:-','111:42','111:43'],'shared_baseline':False},'NATIVE.DIFF')
a('diff','nonfingerprint_field',{'baseline':{'ref':'e1','title':'one','custom_fixture':1},'next':{'ref':'e1','title':'one','custom_fixture':2}},{'changed_refs':[],'unchanged_count':1},'NATIVE.DIFF')
for shape,shot in [('path',{'path':'fixture://shot.jpg'}),('data_url',{'data_url':'data:image/jpeg;base64,AQID','url':'alternate'}),('url',{'url':'fixture://url.jpg'}),('none',{})]:
 for surface in ['get_app_state','sky_get_app_state']:
  isplain=surface=='get_app_state'; expected={'image_blocks':1 if isplain and shape=='path' else 0,'filesystem_read_count':1 if isplain and shape=='path' else 0}
  if isplain:expected.update({'json_screenshot_key_present':False,'base64':'AQID' if shape=='path' else None,'mimeType':'image/jpeg' if shape=='path' else None})
  else:expected.update({'text_json_screenshot':{'url':shot.get('data_url') or shot.get('url')} if shot.get('data_url') or shot.get('url') else None,'content_blocks':1})
  a('screenshots',surface+'.'+shape,{'tool':surface,'native_data':{'elements':[],'screenshot':shot},'mock_files':{'fixture://shot.jpg':{'bytes_hex':'010203'}}},expected,'MCP.tool.'+surface)
a('screenshots','postshot_no_path',{'mutation_succeeded':True,'target':{'pid':111},'postshot_native_data':{}},{'summary_preserved':True,'extra_text':'Post-action screenshot unavailable.','isError_present':False},'MCP.screenshot',kind='negative')
a('screenshots','postshot_read_fail',{'mutation_succeeded':True,'target':{'pid':111},'file_read_error':'fixture EACCES'},{'summary_preserved':True,'extra_text':'Post-action screenshot failed: fixture EACCES','isError_present':False},'MCP.screenshot',kind='negative')
a('screenshots','mapping',{'mapping':{'origin':[-1920,100],'point_size':[1920,1080],'pixel_size':[960,540]},'screenshot_xy':[240,135]},{'desktop_xy':[-1440,370]},'NATIVE.MAP')
a('screenshots','mapping_outside',{'mapping':{'origin':[10,20],'point_size':[100,100],'pixel_size':[50,50]},'screenshot_xy':[-1,60]},{'desktop_xy':[8,140],'clamped':False},'NATIVE.MAP',kind='negative')
a('screenshots','mapping_pid_collision',{'capture_order':[{'pid':111,'window_id':1},{'pid':111,'window_id':2}],'action':'screenshot-coordinate action intended for window1'},{'last_mapping_key':'pid only','actual_routing':'UNKNOWN_REQUIRE_RUNTIME','safe_requirement':'bind map to capture_id and target window'},'NATIVE.MAP',unknown=True,kind='negative')
a('screenshots','safe_valid_bytes',{'path_bytes_hex':'010203'},{'image_emitted':False,'reason':'INVALID_IMAGE_BYTES','mutation_retried':False},'AUDIT',profile='safe_profile',kind='negative')
for stage in ['approval_pending','native_pending','postshot_pending']:
 a('cancel',stage,{'cancel_notification_at':stage,'native_eventual_result':'success'},{'eventual_mcp_response_count':0,'native_cancel_frame_count':0,'actual_side_effects':'UNKNOWN_REQUIRE_RUNTIME'},['MCP.sdk-cancel','MCP.sdk-handler-abort','MCP.transport'],unknown=True,kind='negative')
a('cancel','rpc_timeout_late',{'rpc_timeout_ms':20000,'response_at_ms':20001},{'local_rejection_count':1,'late_response_ignored':True,'native_cancel_frames':0,'mutation_send_count':1,'actual_effect':'UNKNOWN_REQUIRE_RUNTIME'},'MCP.transport',unknown=True,kind='negative')
a('cancel','safe_uncertain',{'dispatch_ack':True,'connection_lost_before_result':True},{'outcome':'UNKNOWN_OUTCOME','automatic_retry_count':0,'next_step':'read-only reconciliation or explicit user decision'},'AUDIT',profile='safe_profile',kind='negative')
a('cancel','host_watchdog',{'outer_watchdog_fired':True,'mcp_still_pending':True},{'mcp_signal_forwarded':False,'native_termination_claim_valid':False,'actual_effect':'UNKNOWN_REQUIRE_RUNTIME'},'HOST.CANCEL',unknown=True,kind='negative')
for name,response,allow in [('approved',{'status':200,'body':{'approved':True}},True),('denied',{'status':200,'body':{'approved':False}},False),('missing',{'status':200,'body':{}},False),('truthy_not_true',{'status':200,'body':{'approved':1}},False),('http503',{'status':503},True),('parse_error',{'status':200,'parse_error':True},True),('network_error',{'network_error':True},True)]:
 a('permissions',name,{'tool':'click','args':{'bundle':'org.example.cu.fixture','ref':'e1'},'approval_mock':response},{'dispatch_allowed':allow,'denial_isError_present':False if not allow else None,'denial_log_and_pip_calls':0 if not allow else None},'MCP.approval',kind='positive' if allow else 'negative')
for target in [{'pid':111},{'ref':'e1'},{'bundle':''}]:a('permissions','skip.'+str(len(cases)),{'args':target},{'approval_http_calls':0},'MCP.approval')
a('permissions','plain_ungated_state',{'tool':'get_app_state','strict_approval_denied':True},{'approval_http_calls':0,'native_state_dispatch_allowed_by_wrapper':True,'OS_permission_result':'UNKNOWN_REQUIRE_RUNTIME'},'MCP.tool.get_app_state',unknown=True)
a('permissions','safe_strict_service_loss',{'strict':True,'approval_service':'unavailable'},{'mutation_dispatch_count':0,'error_class':'APPROVAL_UNAVAILABLE'},'AUDIT',profile='safe_profile',kind='negative')
a('permissions','os_matrix',{'AX':[False,True],'screen_recording':[False,True],'approval':[False,True]},{'actual_error_codes_prompts_and_capture_outcome':'UNKNOWN_REQUIRE_RUNTIME','independence_required':True,'grant_is_not_permission_proof':True},'AUDIT',unknown=True,kind='negative')
a('error_propagation','key_not_delivered',{'tool':'press_key','native_data':{'delivered':False,'delivery_note':'fixture suppression'}},{'summary_contains':'NOT delivered','isError_present':False,'success_delivery_claim':False},'MCP.tool.press_key',kind='negative')
a('error_propagation','mutation_ignores_body',{'tool':'click','native_envelope':{'ok':True,'data':{'delivered':False}}},{'summary_contains':'click ok','isError_present':False},'MCP.tool.click',kind='negative')
a('error_propagation','sdk_loses_fields',{'native_error':{'code':'fixture_code','message':'fixture failure','hint':'fixture hint'}},{'MCP_isError':True,'structured_code_preserved':False,'structured_hint_preserved':False,'content_text_contains':'fixture failure'},'MCP.sdk-error',kind='negative')
a('error_propagation','host_error_bit',{'mcp_result':{'isError':True,'content':[{'type':'text','text':'fixture failure'}]}},{'host_conversion':'ordinary model text','preserves_error_bit':False},'HOST.ERROR',kind='negative')
a('error_propagation','cli_key',{'native_data':{'delivered':False}},{'cli_success_summary':True,'receiver_delivery_inferred':False},'CLI.key-result',kind='negative')
a('error_propagation','safe_error',{'mcp_result':{'isError':True},'delivery':False},{'outcome_kind':'TOOL_ERROR','delivery_success':False,'UI_success_checkmark':False},'AUDIT',profile='safe_profile',kind='negative')
# UI state tests use an injected monotonic clock; no wall-clock sleeps.
a('UI','dismiss_sliding',{'timeline_ms':[{'t':0,'event':'user_close_last','item':'computer:desktop','thread':'t1'},{'t':599999,'event':'auto_present_same'},{'t':600001,'event':'auto_present_same'}]},{'visible':False,'dismissal_timestamp_ms':600001},'UI.STACK')
a('UI','dismiss_boundary',{'dismissed_at_ms':0,'automatic_present_at_ms':600000},{'suppressed':True,'new_timestamp_ms':600000},'UI.STACK')
a('UI','dismiss_expired',{'dismissed_at_ms':0,'automatic_present_at_ms':600001},{'suppressed':False},'UI.STACK')
a('UI','manual_clear',{'tombstones':[['computer:desktop','t1'],['computer:desktop','t2']],'event':'manual present computer:desktop'},{'remaining_tombstones':[],'visible':True},'UI.STACK')
a('UI','new_thread',{'tombstone':['computer:desktop','t1'],'event':{'automatic_present':'computer:desktop','thread':'t2'}},{'suppressed':False},'UI.STACK')
a('UI','programmatic_hide',{'event':'programmatic hide then automatic present'},{'new_dismissal_tombstones':0,'may_reopen':True},'UI.STACK')
a('UI','retire_race',{'events':['retire item at0','upsert same at100','fire scheduled delete at420']},{'static_scheduled_delete_not_cancelled':True,'actual_final_panel':'UNKNOWN_REQUIRE_RUNTIME'},'UI.STACK',unknown=True,kind='negative')
a('UI','cooldown',{'last_agent_activity_ms':10000,'ticks_ms':[10333,10666,10999,11332]},{'capture_start_ticks_ms':[11332]},'UI.PUMP')
a('UI','hung_capture',{'inflight_started_ms':0,'tick_at_ms':4330},{'may_start_second_capture':True,'previous_capture_cancelled':False,'late_frame_order':'UNKNOWN_REQUIRE_RUNTIME'},'UI.PUMP',unknown=True,kind='negative')
a('UI','stale_frame',{'cached_frame':'F1','next_capture':'fails'},{'cached_frame':'F1','expiry_enforced':False},'UI.PUMP',kind='negative')
a('UI','stop_inflight',{'capture_pending':True,'event':'stop pump','capture_completes_later':True},{'timer_cleared':True,'inflight_cancelled':False,'file_recreation':'UNKNOWN_REQUIRE_RUNTIME'},'UI.PUMP',unknown=True,kind='negative')
a('UI','action_cursor',{'source_rect':[-1920,0,1920,1080],'action_point':[-960,270],'age_seconds':8},{'normalized':[0.5,0.25]},'NATIVE.CURSOR')
a('UI','action_cursor_expired',{'age_seconds':8.001},{'current_cursor':None},'NATIVE.CURSOR',kind='negative')
a('UI','action_cursor_outside',{'source_rect':[0,0,100,100],'action_point':[-1,50]},{'normalized':None},'NATIVE.CURSOR',kind='negative')
a('UI','electron_ring',{'panel_size':[380,250],'source_size':[1920,1080],'normalized':[0.5,0.25]},{'ring_xy_top_down':[190,53.4375],'fit_size':[380,213.75],'top_offset':0},'UI.PUMP')
a('UI','native_ring',{'view_size':[380,250],'source_size':[1920,1080],'normalized':[0.5,0.25]},{'cursor_xy_bottom_up':[190,178.4375],'fit_rect':[0,18.125,380,213.75]},'NATIVE.PIP')
a('UI','lens_disabled',{'lens_enabled':False,'show_cursor':True,'action_point':[100,100]},{'action_cursor_updated':True,'desktop_lens_shown':False},'NATIVE.CURSOR')
a('UI','passive_focus',{'other_fixture_is_frontmost':True,'event':'automatic mirror presentation'},{'requested_window_show':'showInactive','actual_focus_stability':'UNKNOWN_REQUIRE_RUNTIME'},'UI.FOCUS',unknown=True)
a('UI','appshot_focus',{'event':'explicit Appshot capture'},{'intent':'bring Alma forward and focus composer','actual_focus_timing':'UNKNOWN_REQUIRE_RUNTIME'},'UI.APPSHOT',unknown=True)
# Runtime matrix is explicit: observations cannot be marked PASS by static analysis.
for engine in ['AppKit','Electron','Browser']:
 for state in ['visible_default','covered','minimized','locked','different_space','multiscreen_negative_origin','multiscreen_mixed_DPI']:
  for action in ['ref_click','coordinate_click','type_text_unicode','press_key','scroll','drag','capture','cancel_inflight']:
   a('UI',f'runtime.{engine}.{state}.{action}',{'fixture':engine,'window_state':state,'action':action,'spec':'fixture-specifications.json','fresh_run_required':True},{'alma_effect':'UNKNOWN_REQUIRE_RUNTIME','mandatory_witnesses':['receiver_events','final_state','frontmost_history','hardware_cursor_history','raw_rpc','screenshot_files','operation_count'],'safe_acceptance':'run acceptance rules RUNTIME-01 through RUNTIME-12; no mutation replay'},['AUDIT','UI.FOCUS'],unknown=True)
a('target','visual_ref_loses_target',{'tool':'click','args':{'ref':'v1','bundle':'org.example.cu.fixture'},'setup':{'approval':{'status':200,'body':{'approved':True}},'visual_cache':{'111':{'v1':{'x':10,'y':20,'w':30,'h':40}}},'focus_guard_healthy':True}},{'schema_valid':True,'approval_bundle':'org.example.cu.fixture','native_call':{'cmd':'click','args':{'ref':'v1','button':'left','click_count':1,'strategy':'auto','show_cursor':True}},'native_error':{'code':'invalid_arg','message':'visual refs (v*) require `pid` or `bundle`'},'visual_cache_read_count':0,'input_dispatch_count':0,'postshot_call_count':0,'MCP_isError':True,'MCP_structured_native_code_preserved':False},['MCP.tool.click','MCP.sdk-error','NATIVE.VISUAL'],kind='negative')
a('state','sky_ignores_visual_regions',{'tool':'sky_get_app_state','args':{'app':'org.example.cu.fixture'},'setup':{'sky_index_map':{},'playbooks':{},'approval':{'status':200,'body':{'approved':True}}},'native_data':{'app':{'bundle':'org.example.cu.fixture','pid':111},'elements':[],'elements_are_diff':False,'visual_regions':[{'ref':'v1','text':'Synthetic OCR','bounds':{'x':10,'y':20,'w':30,'h':40},'confidence':0.9}],'screenshot':{'data_url':'data:image/jpeg;base64,AQID'}}},{'content_blocks':1,'image_blocks':0,'text_json':{'app':'org.example.cu.fixture','screenshot':{'url':'data:image/jpeg;base64,AQID'},'text':''},'sky_index_map_after':{'org.example.cu.fixture':[]},'visual_ref_index_created':False},['MCP.tool.sky_get_app_state','MCP.sky-render','NATIVE.SNAPSHOT'],kind='negative')
# Deterministic critical transport probes, independent of native outcome.
raw='{"id":"a","ok":true,"data":"中"}\n'.encode('utf-8'); cut=raw.index('中'.encode('utf-8'))+1
a('transport','utf8_split',{'pending':['a'],'receive_chunks_hex':[raw[:cut].hex(),raw[cut:].hex()]},{'resolutions':[{'id':'a','value':'中'}],'replacement_character_seen':False},'MCP.transport')
a('transport','timeout_local_no_replay',{'request':{'id':'a','cmd':'click','args':{'ref':'e_fixture'}},'timeout_ms':20000,'late_response_at_ms':20001,'late_response':{'id':'a','ok':True,'data':{}}},{'local_rejection_count':1,'pending_after':[],'late_resolution_count':0,'mutation_send_count':1,'native_cancel_frames':0},'MCP.transport',kind='negative')
for c in cases:
 if c['id'].startswith('screenshots.get_app_state.') or c['id'].startswith('screenshots.sky_get_app_state.'):
  tool=c['input']['tool']; c['input']['args']={'app':'org.example.cu.fixture'} if tool.startswith('sky_') else {'bundle':'org.example.cu.fixture'}
  c['input']['setup']={'sky_index_map':{},'playbooks':{},'approval':{'status':200,'body':{'approved':True}}}
 if c['id']=='screenshots.postshot_no_path':
  c['input']={'call_seam':'respond(summary,target)','summary':'fixture mutation ok','target':{'pid':111},'daemon_reply_for_get_app_state':{'ok':True,'data':{}},'readFile_should_not_be_called':True}
 if c['id'] in ['UI.dismiss_boundary','UI.dismiss_expired']:
  c['input']['item']={'id':'computer:desktop','threadId':'fixture-thread-A','kind':'computer'}; c['input']['initial_live_items']=[];c['input']['dismissal_key_parts']=['computer:desktop','fixture-thread-A']
for c in cases:
 c['design_origin']='generated_schema_permutation' if c['group']=='schema' else ('generated_runtime_matrix_cell' if c['id'].startswith('UI.runtime.') else 'individually_authored_contract_scenario')
 c['harness_seam']={'schema':'schema_validator','transport':'daemon_client_fake_bytestream','target':'MCP_handler_fake_daemon','ref':'element_store_fake_AX','state':'MCP_handler_fake_daemon','diff':'state_diff_or_sky_renderer_pure','screenshots':'capture_mapping_or_MCP_fake_files','cancel':'SDK_adapter_virtual_scheduler','permissions':'MCP_handler_fake_HTTP','error_propagation':'adapter_output_conversion','UI':'OS_fixture' if c['id'].startswith('UI.runtime.') else 'UI_state_machine_virtual_clock'}[c['group']]
for r in reqs:
 subset=[c for c in cases if r['id'] in c['requirement_ids']];r['case_ids']=[c['id'] for c in subset];r['evidence_ids']=sorted({x for c in subset for x in c['evidence_ids']})
write('requirements-traceability.json',reqs)
write('contract-vectors.json',{'format_version':1,'target_version':'0.4.164','provenance':'Original synthetic fixtures derived from static behavioral findings; no proprietary target code executed','status':'DESIGN_ONLY_NOT_PRODUCT_TEST_RESULTS','profiles':{'alma_0_4_164':'Compatibility expectations, including known weak boundaries; not endorsement','safe_profile':'Explicit replacement requirements; deliberate deviations, not claims about Alma'},'cases':cases})
schema={'$schema':'https://json-schema.org/draft/2020-12/schema','type':'object','required':['format_version','target_version','status','profiles','cases'],'properties':{'cases':{'type':'array','items':{'type':'object','required':['id','group','profile','kind','requirement_ids','evidence_ids','input','oracle','execution_status'],'properties':{'id':{'type':'string','minLength':1},'group':{'enum':groups},'profile':{'enum':['alma_0_4_164','safe_profile']},'kind':{'enum':['positive','negative']},'requirement_ids':{'type':'array','minItems':1,'items':{'type':'string'}},'evidence_ids':{'type':'array','minItems':1,'items':{'type':'string'}},'input':{'type':'object'},'oracle':{'type':'object','required':['status','expected'],'properties':{'status':{'enum':['STATIC_EXPECTATION','UNKNOWN_REQUIRE_RUNTIME']},'expected':{'type':'object'}}},'execution_status':{'const':'NOT_RUN'}}}}}}
write('contract-vectors.schema.json',schema)
print(len(cases),'vectors generated')
```
