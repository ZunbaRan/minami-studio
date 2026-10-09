#!/usr/bin/env python3
import json, pathlib, subprocess, collections

root = pathlib.Path(__file__).resolve().parent
records = [json.loads(p.read_text()) for p in sorted((root/'evidence').glob('*_record.json'))]
assert [r['number'] for r in records] == list(range(1,81))
assert all(r.get('status') in ('success','fail') for r in records)
kept = [r for r in records if r['status']=='success']
expected = {pathlib.Path(r['clip']).name for r in kept}
actual = {p.name for p in (root/'clips').glob('*.mov')}
assert actual == expected, (actual-expected, expected-actual)
duration = 0
for r in kept:
    result = subprocess.run(['ffprobe','-v','error','-show_entries','format=duration:stream=width,height,codec_name,pix_fmt','-of','json',r['clip']], check=True, capture_output=True,text=True)
    media = json.loads(result.stdout)
    assert media['streams'][0]['width'] == 2754
    assert media['streams'][0]['height'] == 1884
    assert 6 <= float(media['format']['duration']) <= 12.5
    duration += float(media['format']['duration'])
with (root/'clips.txt').open('w') as out:
    for r in kept:
        out.write("file 'clips/"+pathlib.Path(r['clip']).name+"'\n")
summary = {'operations':len(records),'success':len(kept),'failure':len(records)-len(kept),'clips_duration_sum_seconds':duration,'window_id':234415,'pid':86359,'video':'out/lawrence-tour.mov'}
(root/'out'/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
