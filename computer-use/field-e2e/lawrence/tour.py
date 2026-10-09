#!/usr/bin/env python3
import argparse, json, pathlib, subprocess, time, shutil

ROOT = pathlib.Path(__file__).resolve().parent

def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest='cmd', required=True)
    a = sub.add_parser('start')
    a.add_argument('number', type=int)
    a.add_argument('slug')
    a.add_argument('--seconds', type=int, default=8)
    a = sub.add_parser('finish')
    a.add_argument('number', type=int)
    a.add_argument('status', choices=['success', 'fail'])
    a.add_argument('element')
    a.add_argument('method')
    a.add_argument('effect')
    a = sub.add_parser('snapshot')
    a.add_argument('label')
    a.add_argument('json_text')
    args = p.parse_args()
    (ROOT / 'evidence').mkdir(exist_ok=True)
    if args.cmd == 'start':
        assert 6 <= args.seconds <= 12
        clip = ROOT / 'clips' / f'{args.number:03}_{args.slug}.mov'
        if clip.exists():
            raise RuntimeError(f'Refusing to overwrite {clip}')
        log_path = ROOT / 'evidence' / f'{args.number:03}_capture.log'
        with log_path.open('wb') as log:
            proc = subprocess.Popen(['/usr/sbin/screencapture', '-l', '234415', '-V', str(args.seconds), str(clip)], stdout=log, stderr=log, start_new_session=True)
        data = dict(number=args.number, clip=str(clip), capture_pid=proc.pid, start=time.time(), seconds=args.seconds)
        (ROOT / 'evidence' / f'{args.number:03}_record.json').write_text(json.dumps(data, indent=2))
        time.sleep(0.7)
        print(json.dumps(data))
    elif args.cmd == 'finish':
        path = ROOT / 'evidence' / f'{args.number:03}_record.json'
        data = json.loads(path.read_text())
        wait = max(0, data['start'] + data['seconds'] + 1 - time.time())
        time.sleep(wait)
        clip = pathlib.Path(data['clip'])
        data.update(status=args.status, element=args.element, method=args.method, effect=args.effect)
        if args.status == 'success':
            result = subprocess.run(['ffprobe','-v','error','-show_entries','format=duration:stream=width,height,codec_name','-of','json',str(clip)], capture_output=True, text=True)
            if result.returncode:
                raise RuntimeError('Invalid recording: ' + result.stderr)
            data['media'] = json.loads(result.stdout)
        else:
            clip.unlink(missing_ok=True)
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False))
        with (ROOT / 'LOG.md').open('a') as f:
            f.write(f"{args.number:03} | {args.element} | {args.method} | {'FAIL:' if args.status == 'fail' else ''}{args.effect}\n")
        print(json.dumps(data, ensure_ascii=False))
    elif args.cmd == 'snapshot':
        (ROOT / 'evidence' / f'{args.label}.json').write_text(args.json_text)

if __name__ == '__main__':
    main()
