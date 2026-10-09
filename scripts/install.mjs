#!/usr/bin/env node
// postinstall: fetch the prebuilt native daemon for this version from the
// GitHub release. The MCP wrapper (mcp/*.mjs) resolves it at ../bin/.
// Non-darwin / no-auth environments skip with instructions — install never
// hard-fails on a missing binary.
import { createRequire } from "node:module";
import { execFileSync, execSync } from "node:child_process";
import { existsSync, chmodSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import * as path from "node:path";
import * as os from "node:os";
import { fileURLToPath } from "node:url";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const require = createRequire(import.meta.url);
const pkg = require("../package.json");
const repo = process.env.MINAMI_CU_REPO || "ZunbaRan/minami-computer-use";
const tag = `v${pkg.version}`;
const asset = `minami-computer-use-${tag}-macos-universal.tar.gz`;
const dest = path.join(root, "bin", "minami-computer-use");

function log(m) { process.stderr.write(`[minami-cu install] ${m}\n`); }

if (process.platform !== "darwin") {
  log("non-macOS platform — minami-computer-use is macOS-only, skipping daemon download.");
  process.exit(0);
}
if (existsSync(dest)) { log(`daemon already present: ${dest}`); process.exit(0); }

let token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || "";
if (!token) {
  try { token = execSync("gh auth token", { stdio: ["ignore", "pipe", "ignore"] }).toString().trim(); } catch {}
}
if (!token) {
  log(`no GitHub auth found (set GITHUB_TOKEN or install gh).`);
  log(`after cloning, run manually: ./scripts/build.sh release  (needs Xcode CLT)`);
  process.exit(0);
}

try {
  const rel = JSON.parse(execFileSync("curl", [
    "-sfL", "-H", `Authorization: Bearer ${token}`,
    "-H", "Accept: application/vnd.github+json",
    `https://api.github.com/repos/${repo}/releases/tags/${tag}`,
  ], { maxBuffer: 1 << 24 }).toString());
  const a = (rel.assets || []).find((x) => x.name === asset);
  if (!a) throw new Error(`asset ${asset} not found on ${tag}`);
  const tgz = path.join(os.tmpdir(), `mcu-${process.pid}.tar.gz`);
  writeFileSync(tgz, execFileSync("curl", [
    "-sfL", "-H", `Authorization: Bearer ${token}`,
    "-H", "Accept: application/octet-stream", a.url,
  ], { maxBuffer: 64 << 20 }));
  mkdirSync(path.dirname(dest), { recursive: true });
  execFileSync("tar", ["-xzf", tgz, "-C", path.dirname(tgz),
    `minami-computer-use/bin/minami-computer-use`]);
  const unpacked = path.join(path.dirname(tgz), "minami-computer-use/bin/minami-computer-use");
  execFileSync("cp", [unpacked, dest]);
  chmodSync(dest, 0o755);
  rmSync(tgz, { force: true });
  rmSync(path.join(path.dirname(tgz), "minami-computer-use"), { recursive: true, force: true });
  log(`daemon installed → ${dest} (${tag})`);
} catch (e) {
  log(`daemon download failed: ${String(e).slice(0, 300)}`);
  log(`fallback: ./scripts/build.sh release (needs Xcode CLT)`);
}
