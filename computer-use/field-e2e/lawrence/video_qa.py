#!/usr/bin/env python3
import pathlib, subprocess, json

root=pathlib.Path(__file__).resolve().parent
dst=root/'evidence'/'video-qa'
dst.mkdir(exist_ok=True)
records=[json.loads(p.read_text()) for p in sorted((root/'evidence').glob('*_record.json'))]
records=[r for r in records if r.get('status')=='success']
for r in records:
    for tag,sec in [('a-start',0.1),('b-end',7.5)]:
        img=dst/f"{r['number']:03}-{tag}.jpg"
        vf=f"scale=400:-1,pad=400:300:0:24:white,drawtext=fontfile=/System/Library/Fonts/Helvetica.ttc:text='{r['number']:03} {tag}':x=8:y=5:fontsize=16:fontcolor=black"
        subprocess.run(['ffmpeg','-v','error','-y','-ss',str(sec),'-i',r['clip'],'-frames:v','1','-vf',vf,str(img)],check=True,capture_output=True)
subprocess.run(['ffmpeg','-v','error','-y','-pattern_type','glob','-i',str(dst/'[0-9][0-9][0-9]-*.jpg'),'-vf','tile=4x3:padding=2:margin=2','-fps_mode','vfr',str(dst/'contact-%02d.jpg')],check=True)
print(f'{len(records)} clips / {(len(records)+5)//6} sheets')
