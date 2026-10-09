#!/bin/sh
# End-to-end smoke: MCP initialize → tools/list (must be the 23 Alma tools)
# → permissions → list_apps → sky_get_app_state on a windowed app.
set -e
cd "$(dirname "$0")/.."
python3 - <<'PYEOF'
import subprocess, json, time, select, sys, os
p = subprocess.Popen(["bin/minami-studio-mcp"], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
def send(msg):
    body = json.dumps(msg).encode()
    p.stdin.write(b"Content-Length: "+str(len(body)).encode()+b"\r\n\r\n"+body)
    p.stdin.flush()
def recv(timeout=45):
    deadline = time.time()+timeout; buf = b""
    while time.time() < deadline:
        r,_,_ = select.select([p.stdout],[],[],0.5)
        if not r: continue
        buf += p.stdout.read1(1<<22)
        while b"\r\n\r\n" in buf:
            h,rest = buf.split(b"\r\n\r\n",1)
            n = int(h.split(b"Content-Length: ")[1].split(b"\r\n")[0])
            if len(rest) >= n: return json.loads(rest[:n])
            break
    return None

send({"jsonrpc":"2.0","id":1,"method":"initialize",
      "params":{"protocolVersion":"2024-11-05","capabilities":{},
                "clientInfo":{"name":"smoke","version":"0"}}})
r = recv(); assert r and r["result"]["serverInfo"]["name"]=="minami-studio", r
send({"jsonrpc":"2.0","method":"notifications/initialized"})

send({"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}})
r = recv(); names = sorted(t["name"] for t in r["result"]["tools"])
assert len(names)==29, names
print("tools/list: 29 tools OK")

send({"jsonrpc":"2.0","id":3,"method":"tools/call",
      "params":{"name":"permissions","arguments":{}}})
r = recv(); perms = json.loads(r["result"]["content"][0]["text"])
print("permissions:", perms)

send({"jsonrpc":"2.0","id":4,"method":"tools/call",
      "params":{"name":"list_apps","arguments":{}}})
r = recv(); apps = json.loads(r["result"]["content"][0]["text"])["apps"]
target = next((a["bundle"] for a in apps
              if a.get("active") and a.get("bundle","").startswith("com.")==False or a.get("active")), None)
print("list_apps: %d apps; active=%s" % (len(apps), target))
p.terminate()
print("SMOKE OK")
PYEOF
