# 原始 .164 CLI 局部 cli-http

源：官方ZIP中的 `Alma.app/Contents/Resources/cli/alma`；全SHA256 `2f156839ea5aec2eb4bc8bc117ff2bbd0ed73cae00d090ad04ea19266e506eeb`；原行13–80 inclusive；区间SHA256 `1351033e7f6e16eb2000afab7114f68557062f3cead11cebde7e37d2ab8d0c2f`；原文静态读取、未运行。只摘CU相关段，不含其它产品CLI/SDK主体。

## L13

```javascript
00013  const BASE_URL = process.env.ALMA_API_URL || 'http://localhost:23001';
00014  
00015  const __alma_filename = _fileURLToPath(import.meta.url);
00016  const __alma_dirname = _path.dirname(__alma_filename);
00017  
00018  /** Get the best package runner: npx, bunx, or bundled bun */
00019  let _cachedRunner;
00020  function getPackageRunner() {
00021      if (_cachedRunner !== undefined) return _cachedRunner;
00022      function tryCmd(cmd) {
00023          try {
00024              _execSync(`${cmd} --version`, { stdio: 'ignore' });
00025              return true;
00026          } catch {
00027              return false;
00028          }
00029      }
00030      if (tryCmd('npx')) {
00031          _cachedRunner = 'npx';
00032          return _cachedRunner;
00033      }
00034      if (tryCmd('bunx')) {
00035          _cachedRunner = 'bunx';
00036          return _cachedRunner;
00037      }
00038      // Try Alma's bundled bun, then a user-installed one.
00039      const bunExe = process.platform === 'win32' ? 'bun.exe' : 'bun';
00040      const bundledPaths = [
00041          // Packaged app on every platform: this file is <resources>/cli/alma and
00042          // electron-builder puts bun at <resources>/bun/ (see extraResources).
00043          _path.join(__alma_dirname, '..', 'bun', bunExe),
00044          // Source checkout: bin/alma next to vendor/bun/<platform>-<arch>/.
00045          _path.join(__alma_dirname, '..', 'vendor', 'bun', `${process.platform}-${process.arch}`, bunExe),
00046          _path.join(_os.homedir(), '.bun', 'bin', bunExe),
00047      ];
00048      for (const p of bundledPaths) {
00049          if (_fs.existsSync(p)) {
00050              _cachedRunner = `"${p}" x`;
00051              return _cachedRunner;
00052          }
00053      }
00054      _cachedRunner = null;
00055      return _cachedRunner;
00056  }
00057  
00058  async function api(method, path, body) {
00059      const opts = {
00060          method,
00061          headers: { 'Content-Type': 'application/json' },
00062      };
00063      if (body !== undefined) opts.body = JSON.stringify(body);
00064  
00065      try {
00066          const resp = await fetch(`${BASE_URL}${path}`, opts);
00067          if (!resp.ok) {
00068              const text = await resp.text().catch(() => '');
00069              console.error(`Error: HTTP ${resp.status} ${resp.statusText}${text ? ' — ' + text : ''}`);
00070              process.exit(1);
00071          }
00072          const ct = resp.headers.get('content-type') || '';
00073          if (ct.includes('application/json')) return await resp.json();
00074          return await resp.text();
00075      } catch (err) {
00076          console.error(`Error: Cannot connect to Alma at ${BASE_URL}`);
00077          console.error('Is Alma running? Start it with: npm run dev (in the alma directory)');
00078          process.exit(1);
00079      }
00080  }

```
