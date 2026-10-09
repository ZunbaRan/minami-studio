// Command handlers + shared resolution — rebuilt against the .153/.164
// disassembly contracts. All wire shapes and error literals are verbatim
// where the binary's string table pins them.
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Shared resolvers [DISASM]

extension Daemon {

    /// resolveApp [DISASM]: pid → live NSRunningApplication; bundle →
    /// bundleID match first, then localizedName == bundle. There is no
    /// `name` argument. Failure → app_not_found `pid=<n>` / `bundle <b>`
    /// / `pid=0` when nothing was supplied.
    func resolveApp(_ a: JSONDict) throws -> NSRunningApplication {
        let pid = a.int("pid")
        if let pid = pid, pid > 0,
           let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            return app
        }
        if let bundle = a.str("bundle") {
            if let app = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundle).first {
                return app
            }
            if let app = NSWorkspace.shared.runningApplications
                .first(where: { $0.localizedName == bundle }) {
                return app
            }
        }
        // [live probe .164] label is the bare bundle string when bundle
        // was supplied (even alongside a dead pid); otherwise pid=N.
        let label: String
        if let bundle = a.str("bundle") { label = bundle }
        else if let pid = pid, pid > 0 { label = "pid=\(pid)" }
        else { label = "pid=0" }
        throw DaemonError("app_not_found",
                          "No running app matched \(label).")
    }

    /// get_app_state's auto-launch predicate [DISASM]: only when
    /// `auto_launch` is enabled (default), `bundle` is present, `pid` is
    /// absent, and the bundle is not already running. Ordinary resolution
    /// proceeds first; a missing bundle target launches in the background.
    func resolveAppForState(_ a: JSONDict) throws -> NSRunningApplication {
        do { return try resolveApp(a) }
        catch let e as DaemonError where e.code == "app_not_found" {
            let autoLaunch = a.bool("auto_launch") ?? true
            guard autoLaunch,
                  a.int("pid") == nil,
                  let bundle = a.str("bundle") else { throw e }
            let launched = try launchWithFrontmostPreserved(bundle: bundle)
            EventDispatch.waitUntilReady(pid: launched.processIdentifier)
            return launched
        }
    }

    /// resolveActionPid — positive `pid` passes through without a liveness
    /// check; nonpositive/missing pid falls back to bundle resolve, then a
    /// cold launch. nil means "no target supplied" — the caller decides.
    func resolveActionPid(_ a: JSONDict) -> pid_t? {
        if let pid = a.int("pid"), pid > 0 { return pid_t(clamping: pid) }
        guard let bundle = a.str("bundle") else { return nil }
        if let app = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundle).first {
            return app.processIdentifier
        }
        return try? launchWithFrontmostPreserved(bundle: bundle)
            .processIdentifier
    }

    /// actionPreflight — resolveActionPid, then the forbidden-target gate.
    /// A nil target passes the gate (ref-only actions carry no args target).
    func actionPreflight(_ a: JSONDict) throws -> pid_t? {
        let pid = resolveActionPid(a)
        try ForbiddenTargets.check(pid: pid,
            allowOverride: a.bool("force_forbidden") ?? false)
        return pid
    }

    /// Require a positive-integer numeric arg: `missing "<key>"`.
    func requireNum(_ a: JSONDict, _ key: String) throws -> Int {
        guard let v = a[key] as? Int else {
            throw DaemonError("invalid_arg", "missing \"\(key)\"")
        }
        return v
    }
    func requireNumD(_ a: JSONDict, _ key: String) throws -> Double {
        guard let v = a[key] as? Double ?? (a[key] as? Int).map(Double.init)
        else {
            throw DaemonError("invalid_arg", "missing \"\(key)\"")
        }
        return v
    }

    /// Resolve an element ref through the store (descriptor recovery on dead
    /// elements). nil → element_not_found.
    func resolveEntry(_ ref: String, store: ElementStore) throws
        -> ElementStore.Entry {
        try store.resolve(ref: ref)
    }

    /// Live action names for an entry's element.
    func actions(of el: AXUIElement) -> [String] {
        var names: CFArray?
        return (AXUIElementCopyActionNames(el, &names) == .success
                ? (names as? [String]) : nil) ?? []
    }
    /// Action points use CURRENT AXPosition/AXSize only — a stale
    /// descriptor bound is never consulted [DISASM: live-only].
    func bounds(of e: ElementStore.Entry) -> CGRect? {
        AXBridge.axBounds(e.element)
    }
    /// Live window id for pointer-event window-local metadata.
    func windowID(of e: ElementStore.Entry) -> CGWindowID? {
        AXBridge.windowIDNumber(of: e.element)
    }

    /// Common settle prelude/postlude driver. settle_ms arg, default 600ms;
    /// parsed with the native int() accessor (Int/trunc-Double/String).
    func settlePrelude(pid: pid_t) -> UInt32 {
        Settle.hash(pid: pid)
    }
    func settlePostlude(pid: pid_t, baseline: UInt32, a: JSONDict) {
        // 0x10008616c: baseline == 0 exits before the loop is entered.
        guard baseline != 0 else { return }
        Settle.wait(pid: pid, baseline: baseline,
                    budgetMs: a.int("settle_ms") ?? 600)
    }
}

// MARK: - Settle — window-content hash settle [DISASM]

/// UInt32 sampled-byte hash over the cached mapping's window image:
/// seed 0xdeadbeef, per byte h = (h &* 0x01000193) ^ b, stride
/// max(1, byteCount/64). Postlude polls every 40ms until the window
/// pixels DIFFER from baseline (the action visibly settled) or the
/// per-command budget (default 600ms) expires.
enum Settle {
    static func hash(pid: pid_t) -> UInt32 {
        guard let wid = Capture.mapping(for: pid)?.wid
                    ?? WindowList.frontWindowID(pid: pid),
              let data = Capture.rgbaBytes(of: wid)
        else { return 0 }
        var h: UInt32 = 0xdeadbeef
        let stride = max(1, data.count / 64)
        var i = 0
        while i < data.count {
            h = (h &* 0x01000193) ^ UInt32(data[i])
            i += stride
        }
        return h
    }

    static func wait(pid: pid_t, baseline: UInt32, budgetMs: Int) {
        let deadline = Date().addingTimeInterval(Double(budgetMs) / 1000.0)
        while Date() < deadline {
            usleep(40_000)
            // 0x100086568: exit iff hash != 0 && hash != baseline.
            let h = hash(pid: pid)
            if h != 0 && h != baseline { return }
        }
    }
}

// MARK: - Utility commands

extension Daemon {

    func cmdPing(_ a: JSONDict) throws -> JSONDict {
        ["pong": true, "version": "0.1.0",
         "uptime_s": Int(ProcessInfo.processInfo.systemUptime)]
    }

    func cmdPermissions(_ a: JSONDict) throws -> JSONDict {
        // screen_recording comes from the cached SCShareableContent probe,
        // not CGPreflight (Alma caches the probe result).
        [
            "accessibility": AXIsProcessTrusted(),
            "screen_recording": Capture.screenRecordingCached(),
            // [live probe] focus_guard carries exactly two keys.
            "focus_guard": [
                "armed": FocusStealPreventer.shared.armed,
                "arm_failures": FocusStealPreventer.shared.armFailures,
            ],
        ]
    }

    /// grant — AX trust prompt only. {accessibility, prompted:true}.
    func cmdGrant(_ a: JSONDict) throws -> JSONDict {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue()
            as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        return ["accessibility": trusted, "prompted": true]
    }

    /// apps — activationPolicy .regular apps; always four fields.
    func cmdApps(_ a: JSONDict) throws -> JSONDict {
        let frontPID = NSWorkspace.shared.frontmostApplication?
            .processIdentifier ?? 0
        let rows: [JSONDict] = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "").lowercased()
                    < ($1.localizedName ?? "").lowercased() }
            .map { app in
                [
                    "bundle": app.bundleIdentifier as Any? ?? NSNull(),
                    "name": app.localizedName ?? "(unknown)",
                    "pid": Int(app.processIdentifier),
                    "active": app.processIdentifier == frontPID,
                ]
            }
        return ["apps": rows]
    }

    /// windows — app{bundle,pid} + complete records (id=0 / title="" / zero
    /// geometry preserved). focused = CFEqual vs AXFocusedWindow.
    func cmdWindows(_ a: JSONDict) throws -> JSONDict {
        let app = try resolveApp(a)
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var axWins: [AXUIElement] = []
        var wv: CFTypeRef?
        let werr = AXUIElementCopyAttributeValue(appEl,
            kAXWindowsAttribute as CFString, &wv)
        if werr == .success, let arr = wv as? [AXUIElement] {
            axWins = arr
        } else if werr != .success {
            try mapAXError(werr, context: "reading AXWindows")
        }
        var focused: AXUIElement?
        var fv: CFTypeRef?
        if AXUIElementCopyAttributeValue(appEl,
                "AXFocusedWindow" as CFString, &fv) == .success,
           let f = fv, CFGetTypeID(f) == AXUIElementGetTypeID() {
            focused = unsafeDowncast(f, to: AXUIElement.self)
        }
        let wins: [JSONDict] = axWins.map { w in
            var wid = CGWindowID(0)
            _AXUIElementGetWindow(w, &wid)
            var pos = CGPoint.zero, size = CGSize.zero
            var pv: CFTypeRef?, sv: CFTypeRef?
            if AXUIElementCopyAttributeValue(w,
                    kAXPositionAttribute as CFString, &pv) == .success,
               let p = pv {
                AXValueGetValue(p as! AXValue,
                                .cgPoint, &pos)
            }
            if AXUIElementCopyAttributeValue(w,
                    kAXSizeAttribute as CFString, &sv) == .success,
               let s = sv {
                AXValueGetValue(s as! AXValue,
                                .cgSize, &size)
            }
            return [
                "id": Int(wid),
                "title": AXBridge.copyString(w, kAXTitleAttribute) ?? "",
                "bounds": [
                    "x": Double(pos.x), "y": Double(pos.y),
                    "w": Double(size.width), "h": Double(size.height),
                ],
                "minimized": AXBridge.copyBool(w, "AXMinimized") ?? false,
                "focused": focused.map { CFEqual($0, w) } ?? false,
            ]
        }
        return [
            "app": [
                "bundle": app.bundleIdentifier as Any? ?? NSNull(),
                "pid": Int(app.processIdentifier),
            ],
            "windows": wins,
        ]
    }

    /// launch_app [DISASM]: an already-running bundle match returns
    /// immediately — no openApplication, no waitUntilReady. A cold launch
    /// is followed by the native ~0.2s delay before the response.
    func cmdLaunchApp(_ a: JSONDict) throws -> JSONDict {
        let bundle = try requireStr(a, "bundle")
        let activates = a.bool("activates") ?? false
        let app: NSRunningApplication
        if let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundle).first {
            app = running
        } else {
            app = try launchWithFrontmostPreserved(
                bundle: bundle, activates: activates)
            EventDispatch.waitUntilReady(pid: app.processIdentifier)
            usleep(200_000) // native 0.2s launch delay
        }
        return [
            "launched": true,
            "activates": activates,
            "app": [
                "bundle": app.bundleIdentifier as Any? ?? NSNull(),
                "name": app.localizedName as Any? ?? NSNull(),
                "pid": Int(app.processIdentifier),
            ],
        ]
    }

    /// Shared launcher — openApplication without activating; throws plain
    /// `internal` on failure (no launch_error code).
    @discardableResult
    func launchWithFrontmostPreserved(bundle: String,
                                      activates: Bool = false) throws
        -> NSRunningApplication {
        guard let url = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: bundle) else {
            // [live probe] same unified label as resolveApp.
            throw DaemonError("app_not_found",
                "No running app matched \(bundle).")
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = activates
        var result: NSRunningApplication?
        var err: Error?
        let sem = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url,
            configuration: cfg) { app, e in
            result = app; err = e; sem.signal()
        }
        sem.wait()
        if let e = err { throw DaemonError.wrap(e) }
        guard let app = result else {
            throw DaemonError("internal",
                "launch \(bundle) returned no application")
        }
        return app
    }
}

// MARK: - list_apps (AppUsage — Spotlight merge)

extension Daemon {

    func cmdListApps(_ a: JSONDict) throws -> JSONDict {
        let days = a.int("days") ?? 14
        return ["apps": AppUsage.list(days: days)]
    }
}

/// AppUsage [APP_USAGE_CONTRACT]: running seed dict + unbundled array →
/// NSMetadataQuery (main-queue lifecycle, observers signal only, 2s → [])
/// → bundle-keyed merge (running fields preserved; path keeps non-nil —
/// "" counts; count/date overwritten unconditionally incl. nil) →
/// dict.values + unbundled → stable 4-stage sort → nine-key rows.
enum AppUsage {

    struct AppInfo {
        var bundle: String?; var name: String; var pid: Int?
        var active = false; var running = false
        var path: String?; var useCount: Int?; var lastUsedAt: Date?
    }
    private struct MDEntry {
        var bundle: String?; var name: String; var path: String
        var useCount: Int?; var lastUsedAt: Date?
    }

    static func list(days: Int) -> [JSONDict] {
        // §3 running seed — activationPolicy==.regular only; later
        // instances of a bundle replace earlier ones; nil bundles append
        // to the separate unbundled array.
        var dict: [String: AppInfo] = [:]
        var unbundled: [AppInfo] = []
        let front = NSWorkspace.shared.frontmostApplication
        let frontPID = front?.processIdentifier
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            let info = AppInfo(
                bundle: app.bundleIdentifier,
                name: app.localizedName ?? "(unknown)",
                pid: Int(app.processIdentifier),
                active: frontPID != nil
                    && app.processIdentifier == frontPID,
                running: true,
                path: app.bundleURL?.path)
            if let b = info.bundle { dict[b] = info }
            else { unbundled.append(info) }
        }
        // §5 merge — metadata rows in returned query order; a duplicate
        // bundle row OVERWRITES count/date unconditionally.
        for m in recentMetadata(days: days) {
            if let b = m.bundle {
                if var row = dict[b] {
                    if row.path == nil { row.path = m.path }
                    row.useCount = m.useCount
                    row.lastUsedAt = m.lastUsedAt
                    dict[b] = row
                } else {
                    dict[b] = AppInfo(
                        bundle: b, name: m.name, pid: nil,
                        path: m.path, useCount: m.useCount,
                        lastUsedAt: m.lastUsedAt)
                }
            } else {
                unbundled.append(AppInfo(
                    bundle: nil, name: m.name, pid: nil,
                    path: m.path, useCount: m.useCount,
                    lastUsedAt: m.lastUsedAt))
            }
        }
        var rows = Array(dict.values)
        rows.append(contentsOf: unbundled)
        // §6 stable 4-stage comparator (decorate-sort to keep ties stable)
        let decorated = rows.enumerated().sorted { a, b in
            let (l, r) = (a.element, b.element)
            if l.active != r.active { return l.active }
            if l.running != r.running { return l.running }
            if (l.useCount ?? -1) != (r.useCount ?? -1) {
                return (l.useCount ?? -1) > (r.useCount ?? -1)
            }
            if l.name.lowercased() != r.name.lowercased() {
                return l.name.lowercased() < r.name.lowercased()
            }
            return a.offset < b.offset
        }.map { $0.element }
        let fmt = ISO8601DateFormatter() // NSISO8601 default, no options
        return decorated.map { r in
            [
                "bundle": r.bundle as Any? ?? NSNull(),
                "name": r.name,
                "pid": r.pid as Any? ?? NSNull(),
                "active": r.active,
                "running": r.running,
                "path": r.path as Any? ?? NSNull(),
                "use_count": r.useCount as Any? ?? NSNull(),
                "last_used_at": r.lastUsedAt
                    .map { fmt.string(from: $0) } as Any? ?? NSNull(),
                "intents": IntentRegistry.intents(for: r.bundle),
            ]
        }
    }

    /// §4 NSMetadataQuery — start/stop on the MAIN queue; the gathering
    /// observer only collects+signals; 2s timeout discards partial rows.
    private static func recentMetadata(days: Int) -> [MDEntry] {
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryLocalComputerScope]
        q.predicate = NSPredicate(format:
            "kMDItemContentType == 'com.apple.application-bundle' "
            + "AND kMDItemLastUsedDate >= %@",
            Date().addingTimeInterval(-86400.0 * Double(days)) as NSDate)
        q.valueListAttributes = [
            "kMDItemDisplayName", "kMDItemCFBundleIdentifier",
            "kMDItemLastUsedDate", "kMDItemUseCount", "kMDItemPath",
            "kMDItemFSName",
        ]
        let sem = DispatchSemaphore(value: 0)
        var rows: [MDEntry] = []
        var obs: NSObjectProtocol?
        DispatchQueue.main.sync {
            obs = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: q, queue: nil) { _ in
                q.disableUpdates()
                for i in 0..<q.resultCount {
                    guard let it = q.result(at: i) as? NSMetadataItem
                    else { continue }
                    rows.append(MDEntry(
                        bundle: it.value(
                            forAttribute: "kMDItemCFBundleIdentifier")
                            as? String,
                        name: (it.value(
                                forAttribute: "kMDItemDisplayName")
                               as? String)
                            ?? (it.value(forAttribute: "kMDItemFSName")
                                as? String)
                            ?? "(unknown)",
                        path: (it.value(forAttribute: "kMDItemPath")
                               as? String) ?? "",
                        useCount: it.value(
                            forAttribute: "kMDItemUseCount") as? Int,
                        lastUsedAt: it.value(
                            forAttribute: "kMDItemLastUsedDate") as? Date))
                }
                sem.signal()
            }
            q.start()
        }
        let timedOut = sem.wait(timeout: .now() + 2.0) == .timedOut
        DispatchQueue.main.sync {
            q.stop()
            if let o = obs {
                NotificationCenter.default.removeObserver(o)
            }
        }
        return timedOut ? [] : rows // timeout discards partial results
    }
}

/// IntentRegistry [APP_INTENTS_METADATA]: lazy dictionary keyed by exact
/// bundle id — 7 keys, 15 intents; per-app order preserved. Emitted as
/// {name, description, required_params, optional_params} objects; nil
/// bundle or unregistered → [].
enum IntentRegistry {
    struct Intent {
        let name: String; let desc: String
        let required: [String]; let optional: [String]
        func wire() -> JSONDict {
            ["name": name, "description": desc,
             "required_params": required, "optional_params": optional]
        }
    }
    private static let table: [String: [Intent]] = [
        "com.netease.163music": [
            Intent(name: "launch",
                desc: "Open NetEase Music without changing frontmost app.",
                required: [], optional: []),
            Intent(name: "play_song",
                desc: "Play a specific NetEase song by its numeric "
                    + "song_id.",
                required: ["song_id"], optional: []),
            Intent(name: "open_playlist",
                desc: "Open a NetEase playlist by its numeric "
                    + "playlist_id.",
                required: ["playlist_id"], optional: []),
            Intent(name: "play_daily_recommendation",
                desc: "Open NetEase's '每日推荐' (daily recommendation) "
                    + "page. Discovered via webfiles/hybrid route "
                    + "'/dailyRecommend'.",
                required: [], optional: []),
            Intent(name: "open_history_recommend",
                desc: "Open the historical recommendations page. "
                    + "Route '/historyRecommend'.",
                required: [], optional: []),
            Intent(name: "open_route",
                desc: "Generic NetEase route dispatcher. `route` param "
                    + "is one of: dailyRecommend, historyRecommend, "
                    + "historyPlaylist, styleRecommend, similarArtist, "
                    + "ranking, playlist, album, artist, albumlist, "
                    + "musicDesktop, localMusic, login. Other values "
                    + "may also work — this is the raw "
                    + "`orpheus://route/<name>` bridge.",
                required: ["route"], optional: []),
        ],
        "com.apple.Music": [
            Intent(name: "launch",
                desc: "Open Music.app in the background.",
                required: [], optional: []),
            Intent(name: "open_url",
                desc: "Open an Apple Music URL (music.apple.com/… "
                    + "or music://…).",
                required: ["url"], optional: []),
        ],
        "com.spotify.client": [
            Intent(name: "launch",
                desc: "Open Spotify in the background.",
                required: [], optional: []),
            Intent(name: "play_uri",
                desc: "Play a Spotify URI, e.g. "
                    + "spotify:track:4iV5W9uYEdYUVa79Axb7Rh or "
                    + "spotify:playlist:37i9dQZF1DXcBWIGoYBM5M.",
                required: ["uri"], optional: []),
        ],
        "com.apple.mail": [
            Intent(name: "compose",
                desc: "Open a new message. All params optional: to, "
                    + "subject, body, cc, bcc.",
                required: [],
                optional: ["to", "subject", "body", "cc", "bcc"]),
        ],
        "com.apple.Safari": [
            Intent(name: "open_url",
                desc: "Open a URL in Safari. Pass a full http/https URL.",
                required: ["url"], optional: []),
        ],
        // [live] WeChat launch description is verbatim "Open WeChat."
        "com.tencent.xinWeChat": [
            Intent(name: "launch", desc: "Open WeChat.",
                required: [], optional: []),
        ],
        // Slack launch description: inline small-string, unverifiable —
        // pattern "Open Slack." follows the WeChat sibling.
        "com.tinyspeck.slackmacgap": [
            Intent(name: "launch", desc: "Open Slack.",
                required: [], optional: []),
            Intent(name: "open_channel",
                desc: "Open a Slack channel or DM. team_id like "
                    + "T02ABCDEF, channel_id like C02ABCDEF.",
                required: ["team_id", "channel_id"], optional: []),
        ],
    ]
    static func intents(for bundle: String?) -> [JSONDict] {
        guard let bundle = bundle else { return [] }
        return (table[bundle] ?? []).map { $0.wire() }
    }
}

// MARK: - Snapshot commands (snap / get_app_state)

extension Daemon {

    /// snap — plain AX projection: ordinary app resolution (NO auto
    /// launch), no diff, no capture, no menu_shortcuts, wakeup default 0.
    func cmdSnap(_ a: JSONDict) throws -> JSONDict {
        let app = try resolveApp(a)
        let store = elementStore
        let snap = try AXBridge.snapshot(
            pid: app.processIdentifier,
            windowId: a.int("window_id").map(CGWindowID.init),
            depth: a.int("depth") ?? 6,
            interactiveOnly: a.bool("interactive_only") ?? true,
            wakeupSeconds: a.double("wakeup_seconds") ?? 0,
            snapshotId: appState.nextSnapshotId(), store: store)
        return snapToDict(snap, app: app, includeMenu: false)
    }

    /// get_app_state — snapshot(1.5s wakeup) → unminimize+re-snapshot ONLY
    /// when include_screenshot is requested → AppStateDiff → optional
    /// capture (skipped without snapshot.windowId) → OCR fallback when the
    /// AX tree was empty.
    func cmdGetAppState(_ a: JSONDict) throws -> JSONDict {
        let app = try resolveAppForState(a)
        let includeShot = a.bool("include_screenshot") ?? true
        let store = elementStore
        var snap = try AXBridge.snapshot(
            pid: app.processIdentifier,
            windowId: a.int("window_id").map(CGWindowID.init),
            depth: a.int("depth") ?? 6,
            interactiveOnly: a.bool("interactive_only") ?? true,
            wakeupSeconds: a.double("wakeup_seconds") ?? 1.5,
            snapshotId: appState.nextSnapshotId(), store: store)
        if includeShot, let el = snap.windowElement,
           AXBridge.unminimizeIfNeeded(el) {
            snap = try AXBridge.snapshot(
                pid: app.processIdentifier,
                windowId: a.int("window_id").map(CGWindowID.init),
                depth: a.int("depth") ?? 6,
                interactiveOnly: a.bool("interactive_only") ?? true,
                wakeupSeconds: 0,
                snapshotId: appState.nextSnapshotId(), store: store)
        }
        let disableDiff = a.bool("disable_diff") ?? false
        let (diffComputed, emitted, removed, unchanged) =
            appState.diff(
                pid: snap.pid, wid: snap.windowId,
                elements: snap.elements, disableDiff: disableDiff)
        var resp = snapToDict(snap, app: app, elements: emitted,
                              includeMenu: true)
        if diffComputed {
            resp["elements_are_diff"] = true
            resp["unchanged_element_count"] = unchanged
            if !removed.isEmpty { resp["removed_refs"] = removed }
        }
        // screenshot — only when the snapshot produced a window id.
        if includeShot,
           let wid = snap.windowId, wid != 0 {
            do {
                let maxW = a.int("screenshot_max_width") ?? 1600
                let out = a.str("screenshot_path")
                    ?? Capture.defaultOutPath()
                let (w, h) = try Capture.windowShotToFile(
                    wid: wid, out: out, maxWidth: maxW, quality: 0.85)
                resp["screenshot"] = [
                    "path": out, "width": w, "height": h,
                ]
                // publish mapping ONLY on successful gas capture
                if let b = snap.windowBounds {
                    Capture.registerMapping(pid: snap.pid, wid: wid,
                        windowRect: b, imageW: w, imageH: h, path: out)
                }
                // OCR fallback: empty AX tree → Vision visual refs
                if snap.elements.count <= 1,
                   let regions = Capture.ocrRegions(
                       imagePath: out, pid: snap.pid),
                   !regions.isEmpty {
                    resp["visual_refs"] = regions
                }
            } catch let e as DaemonError {
                resp["screenshot_error"] = e.message
            } catch {
                resp["screenshot_error"] = error.localizedDescription
            }
        }
        return resp
    }

    private func snapToDict(_ snap: SnapshotResult,
                            app: NSRunningApplication,
                            elements: [SerializedElement]? = nil,
                            includeMenu: Bool) -> JSONDict {
        var d: JSONDict = [
            "snapshot_id": snap.snapshotId,
            "ax_status": snap.axStatus,
            "wakeup_attempts": snap.wakeupAttempts,
            "wakeup_duration_ms": snap.wakeupDurationMs,
            "app": [
                "bundle": app.bundleIdentifier as Any? ?? NSNull(),
                "name": app.localizedName as Any? ?? NSNull(),
                "pid": Int(app.processIdentifier),
            ],
            "elements": (elements ?? snap.elements).map { $0.toDict() },
        ]
        if includeMenu {
            d["menu_shortcuts"] = MenuShortcuts.wireEntries(
                pid: app.processIdentifier)
        }
        // [live probe R5] the window envelope is ALWAYS emitted — a
        // windowless app yields the three-key null triple.
        if let wid = snap.windowId {
            d["window"] = [
                "id": Int(wid),
                "title": snap.windowTitle ?? "",
                "bounds": [
                    "x": Double(snap.windowBounds?.origin.x ?? 0),
                    "y": Double(snap.windowBounds?.origin.y ?? 0),
                    "w": Double(snap.windowBounds?.width ?? 0),
                    "h": Double(snap.windowBounds?.height ?? 0),
                ],
            ]
        } else {
            d["window"] = ["id": NSNull(), "title": NSNull(),
                           "bounds": NSNull()]
        }
        return d
    }
}

// MARK: - Action commands

extension Daemon {

    // MARK: click

    func cmdClick(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        // Pixel routing keys on successful double() parsing, not key
        // presence [DISASM numeric routing].
        if a.double("x") != nil { return try clickPixel(a) }
        return try clickRef(a)
    }

    /// coord_space is echoed verbatim; only the exact lowercase "screen"
    /// bypasses screenshot→desktop mapping. Everything else (including a
    /// missing arg and odd casing) translates when a mapping exists.
    private func mapPoint(_ a: JSONDict, pid: pid_t,
                          _ x: Double, _ y: Double)
        -> (pt: CGPoint, space: String) {
        let space = a.str("coord_space") ?? "screenshot"
        if space != "screen",
           let m = Capture.mapping(for: pid) {
            return (m.point(forX: x, y: y), space)
        }
        return (CGPoint(x: x, y: y), space)
    }

    private func clickPixel(_ a: JSONDict) throws -> JSONDict {
        guard let pid = resolveActionPid(a) else {
            throw DaemonError("invalid_arg",
                "click by pixel requires either `pid` or `bundle` of a "
                + "running app — without a target we'd have to post "
                + "globally and move the real cursor.")
        }
        let x = a.double("x")!
        guard let y = a.double("y") else {
            throw DaemonError("invalid_arg",
                "click --pixel requires both x and y")
        }
        let button = MouseButtonTag.parse(a.str("button"))
        let clicks = a.int("click_count") ?? 1
        let (pt, space) = mapPoint(a, pid: pid, x, y)
        // wait→snapshot→select window→unminimize→re-snapshot→settle→click
        EventDispatch.waitUntilReady(pid: pid)
        let store = elementStore
        var snap = try AXBridge.snapshot(pid: pid, depth: 1,
            interactiveOnly: false, wakeupSeconds: 0,
            snapshotId: appState.nextSnapshotId(), store: store)
        if let el = snap.windowElement,
           AXBridge.unminimizeIfNeeded(el) {
            snap = try AXBridge.snapshot(pid: pid, depth: 1,
                interactiveOnly: false, wakeupSeconds: 0,
                snapshotId: appState.nextSnapshotId(), store: store)
        }
        let baseline = settlePrelude(pid: pid)
        try EventDispatch.click(at: pt, button: button,
            clickCount: clicks, pid: pid,
            showCursor: a.bool("show_cursor") ?? true)

        settlePostlude(pid: pid, baseline: baseline, a: a)
        return [
            "clicked_at": ["x": Double(pt.x), "y": Double(pt.y)],
            "button": button.name,
            "clicks": clicks,
            "coord_space": space,
        ]
    }

    private func clickRef(_ a: JSONDict) throws -> JSONDict {
        let ref = try requireStr(a, "ref")
        // visual refs (v*) — screenshot-pixel CENTER through the target's
        // current mapping; missing mapping → internal, missing ref →
        // element_not_found. Response echoes clicked_at, no strategy.
        if ref.hasPrefix("v") {
            guard let pid = resolveActionPid(a) else {
                throw DaemonError("invalid_arg",
                    "visual refs (v*) require `pid` or `bundle`")
            }
            guard let pt = Capture.visualRefPoint(pid: pid, ref: ref) else {
                if Capture.mapping(for: pid) == nil {
                    throw DaemonError("internal",
                        "no screenshot mapping for pid \(pid)"
                        + "; run get_app_state first")
                }
                throw DaemonError("element_not_found",
                    "No element known for ref \(ref). Run `snap` first.")
            }
            let button = MouseButtonTag.parse(a.str("button"))
            let clicks = a.int("click_count") ?? 1
            let baseline = settlePrelude(pid: pid)
            try EventDispatch.click(at: pt, button: button,
                clickCount: clicks, pid: pid,
                showCursor: a.bool("show_cursor") ?? true)
            settlePostlude(pid: pid, baseline: baseline, a: a)
            return [
                "clicked_at": ["x": Double(pt.x), "y": Double(pt.y)],
                "button": button.name, "clicks": clicks,
            ]
        }
        let store = elementStore
        let entry = try resolveEntry(ref, store: store)
        let strategy = ClickStrategy(
            rawValue: a.str("strategy") ?? "auto") ?? .auto
        let button = MouseButtonTag.parse(a.str("button"))
        let clicks = a.int("click_count") ?? 1
        // ALMA_CU_FORCE_SYNTH true values: 1/true/yes/on (anything else off)
        let forceSynth = ["1", "true", "yes", "on"].contains(
            (ProcessInfo.processInfo.environment["ALMA_CU_FORCE_SYNTH"] ?? "")
                .lowercased())
        // [DISASM] eligibility = !forceSynth && strategy!=physical
        //          && button==left && clicks<=1
        let axEligible = !forceSynth && strategy != .physical
            && button == .left && clicks <= 1
        if axEligible {
            let action = ["AXPress", "AXPick", "AXConfirm"]
                .first { actions(of: entry.element).contains($0) }
            if let action = action {
                let baseline = settlePrelude(pid: entry.pid)
                let err = AXUIElementPerformAction(entry.element,
                    action as CFString)
                try mapAXError(err, context: "performing \(action)")
                if a.bool("show_cursor") ?? true,
                   let b = bounds(of: entry) {
                    let c = CGPoint(x: b.midX, y: b.midY)
                    ActionCursor.record(c)
                    LensBus.postMove(c); LensBus.postClick()
                }
                settlePostlude(pid: entry.pid, baseline: baseline, a: a)
                return [
                    "clicked": ref,
                    "strategy": strategy.rawValue,
                    "button": button.name,
                    "clicks": clicks,
                ]
            }
            if strategy == .ax {
                throw DaemonError("action_unsupported",
                    "Element does not support action click with "
                    + "strategy=ax: no AXPress/AXPick/AXConfirm "
                    + "on element.")
            }
        }
        // physical synthesis — requires bounds
        guard let b = bounds(of: entry) else {
            throw DaemonError("action_unsupported",
                "Element does not support action click: element has no "
                + "AX action and no screen bounds for a physical click.")
        }
        let pt = CGPoint(x: b.midX, y: b.midY)
        let baseline = settlePrelude(pid: entry.pid)
        try EventDispatch.click(at: pt, button: button,
            clickCount: clicks, pid: entry.pid,
            showCursor: a.bool("show_cursor") ?? true)
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return [
            "clicked": ref,
            "strategy": "physical",
            "button": button.name,
            "clicks": clicks,
        ]
    }

    // MARK: perform_secondary_action

    func cmdSecondaryAction(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        if a["x"] != nil {
            guard let pid = resolveActionPid(a) else {
                throw DaemonError("invalid_arg",
                    "perform_secondary_action by pixel requires "
                    + "`pid` or `bundle`.")
            }
            _ = try requireNumD(a, "x")
            guard let y = a.double("y") else {
                throw DaemonError("invalid_arg",
                    "perform_secondary_action --pixel requires "
                    + "both x and y")
            }
            let x = a.double("x")!
            let (pt, _) = mapPoint(a, pid: pid, x, y)
            let baseline = settlePrelude(pid: pid)
            try EventDispatch.click(at: pt, button: .right,
                clickCount: 1, pid: pid,
                showCursor: a.bool("show_cursor") ?? true)
            settlePostlude(pid: pid, baseline: baseline, a: a)
            return [
                "opened_menu_at": ["x": Double(pt.x), "y": Double(pt.y)]
            ]
        }
        let ref = try requireStr(a, "ref")
        let store = elementStore
        let entry = try resolveEntry(ref, store: store)
        if actions(of: entry.element).contains("AXShowMenu") {
            let baseline = settlePrelude(pid: entry.pid)
            let err = AXUIElementPerformAction(entry.element,
                "AXShowMenu" as CFString)
            try mapAXError(err, context: "performing AXShowMenu")
            settlePostlude(pid: entry.pid, baseline: baseline, a: a)
            return ["opened_menu": ref]
        }
        // bounds-based right-click fallback
        guard let b = bounds(of: entry) else {
            throw DaemonError("action_unsupported",
                "Element does not support action "
                + "perform_secondary_action (no AXShowMenu "
                + "and no bounds).")
        }
        let pt = CGPoint(x: b.midX, y: b.midY)
        let baseline = settlePrelude(pid: entry.pid)
        try EventDispatch.click(at: pt, button: .right,
            clickCount: 1, pid: entry.pid)
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return ["opened_menu": ref]
    }

    // MARK: drag

    func cmdDrag(_ a: JSONDict) throws -> JSONDict {
        guard let pid = resolveActionPid(a) else {
            throw DaemonError("invalid_arg",
                "drag requires `pid` or `bundle` of a running app.")
        }
        try ForbiddenTargets.check(pid: pid,
            allowOverride: a.bool("force_forbidden") ?? false)
        let sx = try requireNumD(a, "start_x")
        let sy = try requireNumD(a, "start_y")
        let ex = try requireNumD(a, "end_x")
        let ey = try requireNumD(a, "end_y")
        let button = MouseButtonTag.parse(a.str("button"))
        let (from, space) = mapPoint(a, pid: pid, sx, sy)
        let (to, _) = mapPoint(a, pid: pid, ex, ey)
        let baseline = settlePrelude(pid: pid)
        try EventDispatch.drag(from: from, to: to,
            button: button, pid: pid)

        settlePostlude(pid: pid, baseline: baseline, a: a)
        // [live probe .164] from/to echo the TRANSLATED desktop points,
        // not the request values.
        return [
            "dragged": [
                "from": ["x": from.x, "y": from.y],
                "to": ["x": to.x, "y": to.y],
                "button": button.name,
                "coord_space": space,
            ]
        ]
    }

    // MARK: type (ref text insertion)

    /// Shared ref-insert: focused write → AXSelectedText (throw on failed
    /// writable insert) → append to String-or-empty AXValue.
    private func axInsert(element: AXUIElement, ref: String,
                          text: String, replace: Bool) throws {
        _ = try? AXUIElementSetAttributeValue(element,
            kAXFocusedAttribute as CFString, true as CFTypeRef)
        if replace {
            let err = AXUIElementSetAttributeValue(element,
                kAXValueAttribute as CFString, text as CFTypeRef)
            try mapAXError(err, context: "setting AXValue")
            return
        }
        var settable = DarwinBoolean(false)
        _ = AXUIElementIsAttributeSettable(element,
            "AXSelectedText" as CFString, &settable)
        if settable.boolValue {
            let err = AXUIElementSetAttributeValue(element,
                "AXSelectedText" as CFString, text as CFTypeRef)
            try mapAXError(err, context: "inserting at selection")
            return
        }
        _ = AXUIElementIsAttributeSettable(element,
            kAXValueAttribute as CFString, &settable)
        guard settable.boolValue else {
            throw DaemonError("action_unsupported",
                "Element does not support action type (AXValue not "
                + "settable on this element).")
        }
        var cur: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element,
            kAXValueAttribute as CFString, &cur)
        let err = AXUIElementSetAttributeValue(element,
            kAXValueAttribute as CFString,
            ((cur as? String ?? "") + text) as CFTypeRef)
        try mapAXError(err, context: "appending to AXValue")
    }

    /// typeTextViaFocusedAXElement [0x100023b90]: app AXFocusedUIElement →
    /// AXSelectedText:=text when settable, else AXValue:=(old ?? "")+text
    /// when settable. Returns delivery success; failure falls through to
    /// the key-event chain in typeText.
    private func typeViaFocusedAX(_ text: String, pid: pid_t) -> Bool {
        let appEl = AXUIElementCreateApplication(pid)
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl,
                "AXFocusedUIElement" as CFString, &v) == .success,
              let el = v as! AXUIElement? else { return false }
        var settable = DarwinBoolean(false)
        _ = AXUIElementIsAttributeSettable(el,
            "AXSelectedText" as CFString, &settable)
        if settable.boolValue,
           AXUIElementSetAttributeValue(el, "AXSelectedText" as CFString,
                                      text as CFTypeRef) == .success {
            return true
        }
        settable = false
        _ = AXUIElementIsAttributeSettable(el,
            kAXValueAttribute as CFString, &settable)
        guard settable.boolValue else { return false }
        var cur: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(el,
            kAXValueAttribute as CFString, &cur)
        let merged = (cur as? String ?? "") + text
        return AXUIElementSetAttributeValue(el,
            kAXValueAttribute as CFString,
            merged as CFTypeRef) == .success
    }

    func cmdType(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let ref = try requireStr(a, "ref")
        let text = try requireStr(a, "text")
        let store = elementStore
        let entry = try resolveEntry(ref, store: store)
        let baseline = settlePrelude(pid: entry.pid)
        // text-route AX write runs under the enablement assertion
        try AXBridge.withEnablement(pid: entry.pid) {
            try axInsert(element: entry.element, ref: ref, text: text,
                         replace: a.bool("replace") ?? false)
        }
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return ["typed": ref, "length": text.count]
    }

    // MARK: type_text

    func cmdTypeText(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let text = try requireStr(a, "text")
        let method = a.str("input_method") ?? "auto"
        guard ["auto", "physical", "unicode", "ax"].contains(method) else {
            throw DaemonError("invalid_arg",
                "input_method must be auto|physical|unicode|ax")
        }
        // [live probe R3] the target check precedes the ax-ref check:
        // {input_method:ax} with no target → "requires pid/bundle/ref".
        let ref = a.str("ref")
        var pid: pid_t
        var refEntry: ElementStore.Entry?
        if let ref {
            let store = elementStore
            let e = try resolveEntry(ref, store: store)
            pid = e.pid; refEntry = e
        } else {
            guard let p = resolveActionPid(a) else {
                throw DaemonError("invalid_arg",
                    "type_text requires `pid`, `bundle`, or `ref`.")
            }
            pid = p
        }
        if method == "ax", refEntry == nil {
            throw DaemonError("invalid_arg",
                "input_method=ax requires `ref`.")
        }
        let baseline = settlePrelude(pid: pid)
        switch method {
        case "ax":
            try AXBridge.withEnablement(pid: pid) {
                try axInsert(element: refEntry!.element, ref: ref!,
                             text: text, replace: false)
            }
            settlePostlude(pid: pid, baseline: baseline, a: a)
            return ["typed": true, "method": "ax_ref",
                    "length": text.count]
        case "auto":
            // auto+ref → ax_ref label; auto without ref always reports
            // auto_key_events regardless of the internal physical/unicode
            // fallback [live probe: AUTO+ref → ax_ref, AUTO →
            // auto_key_events].
            if let e = refEntry,
               ((try? AXBridge.withEnablement(pid: pid) {
                   try axInsert(element: e.element, ref: ref!,
                                text: text, replace: false)
               }) != nil) {
                settlePostlude(pid: pid, baseline: baseline, a: a)
                return ["typed": true, "method": "ax_ref",
                        "length": text.count]
            }
            // [0x10002102c] auto without ref runs inside deliver:
            // focused-AX insertion (AXSelectedText, else AXValue append)
            // → physical (try?) → unicode. The TypeVerification baseline
            // must be captured BEFORE the AX write; the method label
            // stays auto_key_events on every branch.
            return try finishTypeEvents(a: a, pid: pid,
                baseline: baseline, text: text,
                method: "auto_key_events") {
                if !self.typeViaFocusedAX(text, pid: pid) {
                    try EventDispatch.withFocusPreserved(pid: pid) {
                        if let presses = try? KeyboardLayoutTranslator
                                .keyPresses(for: text) {
                            try EventDispatch.typeKeyPresses(presses,
                                                           pid: pid)
                        } else {
                            try EventDispatch.typeUnicodeText(text,
                                                           pid: pid)
                        }
                    }
                }
            }
        case "physical":
            let presses = try KeyboardLayoutTranslator.keyPresses(for: text)
            return try finishTypeEvents(a: a, pid: pid,
                baseline: baseline, text: text,
                method: "physical_key_events") {
                try EventDispatch.withFocusPreserved(pid: pid) {
                    try EventDispatch.typeKeyPresses(presses, pid: pid)
                }
            }
        default: // unicode
            return try finishTypeEvents(a: a, pid: pid,
                baseline: baseline, text: text,
                method: "unicode_events") {
                try EventDispatch.withFocusPreserved(pid: pid) {
                    try EventDispatch.typeUnicodeText(text, pid: pid)
                }
            }
        }
    }

    /// Event-route type: deliver → settle → verify [DISASM order]. The
    /// verification note and the no-text error are verbatim string-table
    /// literals (em dashes).
    private func finishTypeEvents(a: JSONDict, pid: pid_t,
                                  baseline: UInt32, text: String,
                                  method: String,
                                  _ deliver: () throws -> Void) throws
        -> JSONDict {
        let tb = TypeVerification.baseline(pid: pid)
        try deliver()
        settlePostlude(pid: pid, baseline: baseline, a: a)
        let outcome = TypeVerification.check(baseline: tb, typed: text,
                                             pid: pid)
        var resp: JSONDict = [
            "typed": true, "method": method, "length": text.count,
        ]
        switch outcome {
        case .verified:
            resp["verified"] = true
        case .unchanged:
            throw DaemonError("internal",
                "type_text delivered no text: the target app has no "
                + "key window, so the keystrokes were discarded (its "
                + "AX element still reports focused=true — that only "
                + "means it is the app's first responder). Use "
                + "set_value with the element's ref to write the field "
                + "directly. Do NOT bring the app forward to make "
                + "typing land — Alma never takes the user's "
                + "foreground.")
        case .unverifiable(let reason):
            resp["verified"] = false
            resp["verification_note"] =
                "sent, but could not confirm it landed — \(reason)"
        }
        return resp
    }

    // MARK: press (ref-based AX action press)

    func cmdPress(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let ref = try requireStr(a, "ref")
        let key = try requireStr(a, "key")
        let store = elementStore
        let entry = try resolveEntry(ref, store: store)
        let lower = key.lowercased()
        let action: String
        switch lower {
        case "enter", "return": action = "AXConfirm"
        case "escape", "esc": action = "AXCancel"
        case "space": action = "AXPress"
        case "increment", "up": action = "AXIncrement"
        case "decrement", "down": action = "AXDecrement"
        case "showmenu", "menu": action = "AXShowMenu"
        default:
            throw DaemonError("action_unsupported",
                "Element does not support action press \(key) "
                + "(only Enter/Escape/Space/Increment/Decrement/"
                + "ShowMenu are supported over AX in v1).")
        }
        guard actions(of: entry.element).contains(action) else {
            throw DaemonError("action_unsupported",
                "Element does not support action press \(key) → "
                + "\(action) not on element.")
        }
        let baseline = settlePrelude(pid: entry.pid)
        let err = AXUIElementPerformAction(entry.element,
            action as CFString)
        try mapAXError(err, context: "performing \(action)")
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return ["pressed": key]
    }

    // MARK: press_key (chord delivery)

    func cmdPressKey(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let key = try requireStr(a, "key")
        guard let pid = resolveActionPid(a) else {
            throw DaemonError("invalid_arg",
                "press_key requires `pid` or `bundle` of a running app.")
        }
        let baseline = settlePrelude(pid: pid)
        let delivery = try EventDispatch.pressKey(key, pid: pid)
        var resp: JSONDict = [
            "pressed": key,
            "delivered": delivery != .suppressed,
        ]
        // [live probe .164] `via` is emitted only on delivered routes
        // (e.g. menu_ax_press); the suppressed response omits it.
        if delivery != .suppressed { resp["via"] = delivery.rawValue }
        if delivery == .suppressed {
            // verbatim string-table literal (em dashes included)
            resp["delivery_note"] =
                "the target app is in the background and no ENABLED "
                + "menu item owns this chord, so nothing was posted "
                + "— a background app is not listening to the keyboard "
                + "and macOS would have answered with the system alert "
                + "beep. Often the command is simply unavailable right "
                + "now (macOS greys out window-scoped commands when the "
                + "app has no usable window). Act on the element "
                + "directly (click or set_value with a ref) or report "
                + "this to the user. NEVER bring the app to the "
                + "foreground to force a keypress through — Alma "
                + "absolutely must not steal the user's focus."
        }
        settlePostlude(pid: pid, baseline: baseline, a: a)
        return resp
    }

    // MARK: set_value

    func cmdSetValue(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let ref = try requireStr(a, "ref")
        guard let raw = a["value"], !(raw is NSNull) else {
            throw DaemonError("invalid_arg", "missing \"value\"")
        }
        let store = elementStore
        let entry = try resolveEntry(ref, store: store)
        var settable = DarwinBoolean(false)
        let serr = AXUIElementIsAttributeSettable(entry.element,
            kAXValueAttribute as CFString, &settable)
        guard serr == .success, settable.boolValue else {
            throw DaemonError("action_unsupported",
                "Element does not support action set_value (AXValue "
                + "not settable on this element).")
        }
        // [DISASM] conversion order: String → NSNumber → Bool → describe.
        // NSNumber must be tried before Bool so numeric JSON values land
        // as numbers, not 0/1 booleans.
        let cf: CFTypeRef
        if let s = raw as? String { cf = s as NSString }
        else if let n = raw as? NSNumber { cf = n }
        else if let b = raw as? Bool { cf = b as NSNumber }
        else { cf = String(describing: raw) as NSString }
        let baseline = settlePrelude(pid: entry.pid)
        let err = try AXBridge.withEnablement(pid: entry.pid) {
            AXUIElementSetAttributeValue(entry.element,
                kAXValueAttribute as CFString, cf)
        }
        try mapAXError(err, context: "setting AXValue")
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return ["set": ref]
    }

    // MARK: select_text (no forbidden gate — dispatcher excludes it)

    func cmdSelectText(_ a: JSONDict) throws -> JSONDict {
        let ref = try requireStr(a, "ref")
        let text = try requireStr(a, "text")
        let selType = a.str("selection_type") ?? "text"
        let store = elementStore
        let entry = try resolveEntry(ref, store: store)
        var v: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(entry.element,
            kAXValueAttribute as CFString, &v)
        let content: String
        if let s = v as? String { content = s }
        else if let at = v as? NSAttributedString {
            content = at.string
        } else {
            throw DaemonError("action_unsupported",
                "Element does not support action select_text "
                + "(element has no readable AXValue text).")
        }
        let prefix = a.str("prefix") ?? ""
        let suffix = a.str("suffix") ?? ""
        guard let match = content.range(of: prefix + text + suffix)
        else {
            throw DaemonError("internal",
                "select_text: text not found in this element")
        }
        var start = content.utf16.distance(
            from: content.utf16.startIndex,
            to: match.lowerBound.samePosition(in: content.utf16)!)
            + prefix.utf16.count
        var length = text.utf16.count
        if selType == "cursor_before" { length = 0 }
        else if selType == "cursor_after" {
            start += length; length = 0
        }
        var focusedV: CFTypeRef?
        let focused = AXUIElementCopyAttributeValue(entry.element,
            kAXFocusedAttribute as CFString, &focusedV) == .success
            && (focusedV as? Bool == true)
        if !focused {
            _ = AXUIElementSetAttributeValue(entry.element,
                kAXFocusedAttribute as CFString, true as CFTypeRef)
        }
        var range = CFRange(location: start, length: length)
        guard let axv = AXValueCreate(.cfRange, &range) else {
            throw DaemonError("internal",
                "select_text: could not build an AX range")
        }
        let baseline = settlePrelude(pid: entry.pid)
        let err = try AXBridge.withEnablement(pid: entry.pid) {
            AXUIElementSetAttributeValue(entry.element,
                "AXSelectedTextRange" as CFString, axv)
        }
        try mapAXError(err, context: "setting AXSelectedTextRange")
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return ["selected": text, "selection_type": selType]
    }

    // MARK: scroll

    func cmdScroll(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let ref = try requireStr(a, "ref")
        let dir = try requireStr(a, "direction")
        let pages = a.int("pages") ?? 1
        let store = elementStore
        // [live probe] ref resolution precedes the direction enum check:
        // {bad ref, bad dir} → element_not_found; {good ref, missing
        // dir} → missing "direction"; {good ref, bad dir} → the enum
        // error.
        let entry = try resolveEntry(ref, store: store)
        let action: String
        switch dir {
        case "up": action = "AXScrollUpByPage"
        case "down": action = "AXScrollDownByPage"
        case "left": action = "AXScrollLeftByPage"
        case "right": action = "AXScrollRightByPage"
        default:
            throw DaemonError("invalid_arg",
                "direction must be up|down|left|right")
        }
        guard actions(of: entry.element).contains(action) else {
            // verbatim: "Element does not support action \(action) not
            // available on element (ref points at an unscrollable
            // element — snap the parent ScrollArea)" — no direction in
            // the message.
            throw DaemonError("action_unsupported",
                "Element does not support action \(action) not "
                + "available on element (ref points at an unscrollable "
                + "element — snap the parent ScrollArea)")
        }
        let baseline = settlePrelude(pid: entry.pid)
        // scroll-route AX performs carry the enablement assertion
        try AXBridge.withEnablement(pid: entry.pid) {
            // [0x100016258] csinc clamps the trip count: max(1, pages) —
            // pages 0/-1 still perform the action once (and can fail with
            // action_unsupported). Response echoes the raw `pages`.
            for _ in 0..<max(1, pages) {
                let err = AXUIElementPerformAction(entry.element,
                    action as CFString)
                try mapAXError(err, context: "performing \(action)")
            }
        }
        LensBus.postScroll(direction: dir)
        settlePostlude(pid: entry.pid, baseline: baseline, a: a)
        return ["scrolled": ref, "pages": pages]
    }
}

// MARK: - Small enums

enum ClickStrategy: String {
    case auto, physical, ax
}


// MARK: - shot / shot_display / shutdown

extension Daemon {

    /// shot — requires `out`; optional `window_id` bypasses app resolution
    /// entirely; otherwise the app's FIRST AX window (focused-first order
    /// is a snapshot concern — shot picks windows.first).
    func cmdShot(_ a: JSONDict) throws -> JSONDict {
        let out = try requireStr(a, "out")
        let maxW = a.int("max_width")
        var wid: CGWindowID
        if let w = a.int("window_id") {
            wid = CGWindowID(w)
        } else {
            let app = try resolveApp(a)
            let wins = try AXBridge.windows(of: app.processIdentifier)
            guard let first = wins.first,
                  let w = AXBridge.windowIDNumber(of: first)
            else {
                throw DaemonError("internal",
                    "App has no windows to capture.")
            }
            wid = w
        }
        let (w, h) = try Capture.windowShotToFile(
            wid: wid, out: out, maxWidth: maxW ?? 0, quality: 0.85)
        var resp: JSONDict = ["path": out, "width": w, "height": h]
        if let c = Capture.cursorForShot(wid: wid) {
            resp["cursor"] = c
        }
        return resp
    }

    /// shot_display [DISASM]: `out` is REQUIRED (missing "<out>"-style
    /// requireStr error); quality arg parsed with default 0.6; cursor
    /// metadata is read from the MAIN display independently of which
    /// display was captured.
    func cmdShotDisplay(_ a: JSONDict) throws -> JSONDict {
        let out = try requireStr(a, "out")
        let maxW = a.int("max_width") ?? 0
        let quality = a.double("quality") ?? 0.6
        let (w, h, _) = try Capture.displayShotToFile(
            displayID: a.int("display_id").map(CGDirectDisplayID.init),
            out: out, maxWidth: maxW, quality: quality)
        var resp: JSONDict = ["path": out, "width": w, "height": h]
        // [UTILITY_COMMANDS] cursor uses the supplied display id when
        // present, else CGMainDisplayID.
        let cursorDisplay = a.int("display_id")
            .map(CGDirectDisplayID.init) ?? CGMainDisplayID()
        if let c = Capture.cursorForDisplay(cursorDisplay) {
            resp["cursor"] = c
        }
        return resp
    }

    /// shutdown — flag on main, restore EnhancedUI, close listen fd, exit.
    func cmdShutdown(_ a: JSONDict) throws -> JSONDict {
        DispatchQueue.main.async { self.initiateShutdown() }
        return ["shutdown": true]
    }
}
