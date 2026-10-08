# 原始 stdio MCP 局部 transport

文件：`Resources/cli/alma-computer-use-mcp.mjs`；.153 与 .164 字节同一，SHA256 `d157be25e6f87879df47287a727070fd1d223d6e3bfb1addf187eb14bd9fb976`。原行 `35761–35929`（inclusive），原字节半开区间 `[1334683, 1340184]`；区间SHA256 `df6baea109f599e03bc39a3f0fc6a73ca703570ef7087ab0313523a31bd135c7`。证据强度：原始JS应用层局部原文，STATIC/NOT_EXECUTED；无SDK主体、无playbook全文。此范围边界沿用源定位目录，可能包含相邻声明，具体工具以server.registerTool名称为准。

## L35761

```javascript
35761    const override = process.env.ALMA_CU_HELPER;
35762    if (override && existsSync(override)) return override;
35763    const candidates = [];
35764    const rel = path.join("Alma Computer Use.app", "Contents", "MacOS", "AlmaComputerUse");
35765    const resources = process.env.ALMA_RESOURCES_PATH;
35766    if (resources) {
35767      candidates.push(path.join(resources, rel));
35768    }
35769    try {
35770      const self = process.argv[1] || "";
35771      if (self) {
35772        const dir = path.dirname(path.resolve(self));
35773        candidates.push(path.join(dir, "..", "computer-use", rel));
35774        candidates.push(path.join(dir, "..", "..", "computer-use", rel));
35775        candidates.push(path.join(dir, "..", "..", "..", "computer-use", rel));
35776      }
35777    } catch {
35778    }
35779    for (const p of candidates) {
35780      if (existsSync(p)) return p;
35781    }
35782    return null;
35783  }
35784  function defaultSocketPath() {
35785    const base = path.join(os.homedir(), "Library", "Application Support", "Alma");
35786    mkdirSync(base, { recursive: true });
35787    const helper = resolveHelperBinary();
35788    if (!helper) return path.join(base, "computer-use.sock");
35789    const tag = createHash("sha1").update(helper).digest("hex").slice(0, 8);
35790    return path.join(base, `computer-use-${tag}.sock`);
35791  }
35792  var DaemonClient = class {
35793    sock = null;
35794    child = null;
35795    readBuffer = Buffer.alloc(0);
35796    pending = /* @__PURE__ */ new Map();
35797    connecting = null;
35798    socketPath = defaultSocketPath();
35799    async call(cmd, args = {}, timeoutMs = 2e4) {
35800      await this.ensureConnected();
35801      return new Promise((resolve2, reject) => {
35802        const id = randomBytes(8).toString("hex");
35803        const timer = setTimeout(() => {
35804          this.pending.delete(id);
35805          reject(new Error(`computer-use ${cmd} timed out after ${timeoutMs}ms`));
35806        }, timeoutMs);
35807        this.pending.set(id, { resolve: resolve2, reject, timer });
35808        const payload = JSON.stringify({ id, cmd, args }) + "\n";
35809        try {
35810          this.sock.write(payload);
35811        } catch (err) {
35812          clearTimeout(timer);
35813          this.pending.delete(id);
35814          reject(err);
35815        }
35816      });
35817    }
35818    async ensureConnected() {
35819      if (this.sock && !this.sock.destroyed) return;
35820      if (this.connecting) return this.connecting;
35821      this.connecting = (async () => {
35822        try {
35823          await this.connectOnce();
35824          return;
35825        } catch {
35826        }
35827        const helper = resolveHelperBinary();
35828        if (!helper) {
35829          throw new Error("Alma Computer Use helper not found. Run `pnpm build:computer-use` or reinstall Alma.");
35830        }
35831        this.spawnDaemon(helper);
35832        const deadline = Date.now() + 4e3;
35833        let lastErr = null;
35834        while (Date.now() < deadline) {
35835          try {
35836            await this.connectOnce();
35837            return;
35838          } catch (e) {
35839            lastErr = e;
35840            await new Promise((r) => setTimeout(r, 100));
35841          }
35842        }
35843        throw new Error(`Failed to connect to computer-use daemon at ${this.socketPath}: ${String(lastErr)}`);
35844      })().finally(() => {
35845        this.connecting = null;
35846      });
35847      return this.connecting;
35848    }
35849    connectOnce() {
35850      return new Promise((resolve2, reject) => {
35851        const s = createConnection({ path: this.socketPath });
35852        const onError = (err) => {
35853          s.removeAllListeners();
35854          s.destroy();
35855          reject(err);
35856        };
35857        s.once("error", onError);
35858        s.once("connect", () => {
35859          s.removeListener("error", onError);
35860          this.sock = s;
35861          this.wireSocket(s);
35862          resolve2();
35863        });
35864      });
35865    }
35866    wireSocket(s) {
35867      s.on("data", (chunk) => {
35868        this.readBuffer = Buffer.concat([this.readBuffer, Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)]);
35869        let nl = this.readBuffer.indexOf(10);
35870        while (nl !== -1) {
35871          const line = this.readBuffer.subarray(0, nl);
35872          this.readBuffer = this.readBuffer.subarray(nl + 1);
35873          if (line.length) this.handleLine(line);
35874          nl = this.readBuffer.indexOf(10);
35875        }
35876      });
35877      s.on("close", () => {
35878        this.sock = null;
35879        const err = new Error("computer-use daemon disconnected");
35880        for (const [id, p] of this.pending) {
35881          clearTimeout(p.timer);
35882          p.reject(err);
35883          this.pending.delete(id);
35884        }
35885      });
35886      s.on("error", () => {
35887      });
35888    }
35889    handleLine(line) {
35890      let resp;
35891      try {
35892        resp = JSON.parse(line.toString("utf8"));
35893      } catch {
35894        return;
35895      }
35896      const pending = this.pending.get(resp.id);
35897      if (!pending) return;
35898      clearTimeout(pending.timer);
35899      this.pending.delete(resp.id);
35900      if (resp.ok) pending.resolve(resp.data);
35901      else pending.reject(Object.assign(new Error(resp.error?.message || "daemon error"), { code: resp.error?.code, hint: resp.error?.hint }));
35902    }
35903    spawnDaemon(binary) {
35904      try {
35905        const child = spawn(
35906          binary,
35907          // Must match CU_DAEMON_IDLE_SECONDS in computerUseManager.ts: whichever
35908          // process starts the daemon sets its lifetime for both.
35909          ["daemon", "--socket", this.socketPath, "--idle-seconds", "900"],
35910          {
35911            stdio: ["ignore", "pipe", "pipe"],
35912            detached: false
35913          }
35914        );
35915        child.stderr?.on("data", (buf) => process.stderr.write(buf));
35916        child.on("exit", (code, sig) => {
35917          if (this.child === child) this.child = null;
35918          if (code !== 0 && code !== null) {
35919            process.stderr.write(`[computer-use-mcp] daemon exited code=${code} sig=${sig}
35920  `);
35921          }
35922        });
35923        this.child = child;
35924      } catch (e) {
35925        throw new Error(`Failed to spawn computer-use daemon: ${String(e)}`);
35926      }
35927    }
35928  };
35929  var daemon = new DaemonClient();

```
