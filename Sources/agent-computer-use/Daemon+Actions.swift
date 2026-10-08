import AppKit
import ApplicationServices
import Foundation

// Command handlers. Wire shapes and error texts per live-probe evidence and
// the .164 contract chapters; branch behavior per .153 disasm.

extension Daemon {
    private static let startedAt = Date()

    // MARK: - target resolution

    /// Resolve pid from args: explicit pid, else bundle → running app.
    /// Error text verbatim: No running app matched pid=X.
    func resolvePid(_ a: JSONDict, requireRunning: Bool = true) throws -> pid_t {
        if let pid = a.int("pid"), pid > 0 {
            if requireRunning, AXBridge.runningApp(pid: pid_t(pid)) == nil {
                throw DaemonError("app_not_found", "No running app matched pid=\(pid).")
            }
            return pid_t(pid)
        }
        if let bundle = a.string("bundle") {
            guard let app = AXBridge.runningApp(bundle: bundle) else {
                throw DaemonError("app_not_found", "No running app matched bundle \(bundle).")
            }
            return app.processIdentifier
        }
        throw DaemonError("invalid_arg", "missing \"bundle\"")
    }

    /// Shared preflight for the action command set
    /// (click/secondary/drag/type*/press*/scroll/set_value):
    /// ForbiddenTargets.check on the resolved pid/bundle unless force_forbidden.
    func actionPreflight(_ a: JSONDict) throws {
        let allowOverride = a.bool("force_forbidden") == true
        if let pid = a.int("pid") {
            try ForbiddenTargets.check(pid: pid_t(pid), allowOverride: allowOverride)
        } else if let bundle = a.string("bundle") {
            try ForbiddenTargets.check(bundleId: bundle, allowOverride: allowOverride)
        }
    }

    // MARK: - infra

    func cmdPing(_ a: JSONDict) throws -> JSONDict {
        ["version": HELPER_VERSION, "uptime_s": Date().timeIntervalSince(Self.startedAt)]
    }

    func cmdPermissions(_ a: JSONDict) throws -> JSONDict {
        [
            "accessibility": AXIsProcessTrusted(),
            "screen_recording": CGPreflightScreenCaptureAccess(),
            "focus_guard": FocusStealPreventer.shared.status,
        ]
    }

    func cmdGrant(_ a: JSONDict) throws -> JSONDict {
        // The ONLY command that may prompt. Others fail-fast ax_not_granted.
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        let screen = CGRequestScreenCaptureAccess()
        return ["accessibility": trusted, "screen_recording": screen]
    }

    func cmdShutdown(_ a: JSONDict) throws -> JSONDict {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { exit(0) }
        return ["shutting_down": true]
    }

    // MARK: - inventory

    func cmdApps(_ a: JSONDict) throws -> JSONDict {
        // Live-probe wire: {"apps":[{pid,name,bundle,active}]} — no "running".
        let apps = AXBridge.allRunningRegular()
            .map { app -> JSONDict in
                var d: JSONDict = ["pid": app.processIdentifier]
                if let b = app.bundleIdentifier { d["bundle"] = b }
                if let n = app.localizedName { d["name"] = n }
                d["active"] = app.isActive
                return d
            }
        return ["apps": apps]
    }

    func cmdListApps(_ a: JSONDict) throws -> JSONDict {
        // Live-probe wire (distinct from `apps`): adds path/running/use_count/
        // last_used_at/intents. AppUsage not implemented → usage keys omitted
        // per the normalized-state schema (absent key, not null).
        let apps = AXBridge.allRunningRegular()
            .map { app -> JSONDict in
                var d: JSONDict = ["pid": app.processIdentifier]
                if let b = app.bundleIdentifier { d["bundle"] = b }
                if let n = app.localizedName { d["name"] = n }
                if let p = app.bundleURL?.path { d["path"] = p }
                d["running"] = true
                d["active"] = app.isActive
                d["intents"] = [JSONDict]() // AppCommandRegistry surface not implemented
                return d
            }
        return ["apps": apps]
    }

    func cmdWindows(_ a: JSONDict) throws -> JSONDict {
        // Live-probe wire: {"app":{bundle,pid}, "windows":[{focused,id,title,
        // bounds,minimized}]}. focused/minimized come from the AX window
        // elements; bounds from CGWindowList.
        let pid = try resolvePid(a)
        var appD: JSONDict = ["pid": pid]
        if let ra = AXBridge.runningApp(pid: pid) {
            if let b = ra.bundleIdentifier { appD["bundle"] = b }
            if let n = ra.localizedName { appD["name"] = n }
        }
        let cgWindows = WindowList.windows(pid: pid)
        var wins: [JSONDict] = []
        for w in AXBridge.windows(of: pid) {
            var d: JSONDict = [:]
            if let wid = AXBridge.windowIDNumber(of: w) {
                d["id"] = wid
                if let cg = cgWindows.first(where: {
                    ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == wid
                }) {
                    if let b = cg[kCGWindowBounds as String] as? [String: Any] {
                        d["bounds"] = [
                            "x": b["X"] as? Double ?? 0, "y": b["Y"] as? Double ?? 0,
                            "w": b["Width"] as? Double ?? 0, "h": b["Height"] as? Double ?? 0,
                        ]
                    }
                }
            }
            if let t = AXBridge.copyString(w, kAXTitleAttribute), !t.isEmpty { d["title"] = t }
            d["focused"] = AXBridge.copyBool(w, kAXFocusedAttribute) ?? false
            d["minimized"] = AXBridge.copyBool(w, "AXMinimized") ?? false
            wins.append(d)
        }
        return ["app": appD, "windows": wins]
    }

    // MARK: - snapshot (snap == get_app_state path minus screenshot args)

    private func requireTrusted() throws {
        guard AXIsProcessTrusted() else {
            throw DaemonError("ax_not_granted", "accessibility permission not granted — call grant first")
        }
    }

    func snapshotResponse(pid: pid_t, a: JSONDict, includeScreenshot: Bool, screenshotMaxWidth: Int) throws -> JSONDict {
        try requireTrusted()
        let depth = a.int("depth") ?? 6
        let interactiveOnly = a.bool("interactive_only") ?? true
        let disableDiff = a.bool("disable_diff") ?? false
        let windowId = a.int("window_id").map { CGWindowID($0) }

        var snap = AXBridge.snapshot(
            pid: pid, windowId: windowId, depth: depth,
            interactiveOnly: interactiveOnly, store: elementStore
        )
        snap.snapshotId = appState.nextSnapshotId()

        let (diffComputed, _, emitted, removed, unchanged) = appState.diff(
            pid: pid, wid: snap.windowId, elements: snap.elements, disableDiff: disableDiff
        )

        var resp: JSONDict = [
            "snapshot_id": snap.snapshotId,
            "ax_status": snap.axStatus,
            "wakeup_attempts": snap.wakeupAttempts,
            "wakeup_duration_ms": snap.wakeupDurationMs,
            "elements": emitted.map { $0.toDict() },
        ]
        // Diff keys exist only when a diff actually ran (verified wire:
        // absent on first snapshot and with disable_diff).
        if diffComputed {
            resp["elements_are_diff"] = true
            resp["unchanged_element_count"] = unchanged
            resp["removed_refs"] = removed
        }

        var app: JSONDict = ["pid": snap.pid]
        if let b = snap.bundle { app["bundle"] = b }
        if let n = snap.appName { app["name"] = n }
        resp["app"] = app

        // Live-probe wire: window is its own nested dict, not flattened
        // into app: {"id","title","bounds":{x,y,w,h}}.
        if let wid = snap.windowId {
            var w: JSONDict = ["id": wid]
            if let t = snap.windowTitle { w["title"] = t }
            if let wb = snap.windowBounds {
                w["bounds"] = [
                    "x": Double(wb.origin.x), "y": Double(wb.origin.y),
                    "w": Double(wb.size.width), "h": Double(wb.size.height),
                ]
            }
            resp["window"] = w
        }

        // menu_shortcuts key is always present ([] when disabled/none).
        // Elements: [{combo,title,path}] — symbol-confirmed key names.
        if a.bool("menu_shortcuts") ?? true {
            resp["menu_shortcuts"] = MenuShortcuts.wireEntries(pid: pid)
        } else {
            resp["menu_shortcuts"] = [JSONDict]()
        }

        if includeScreenshot {
            do {
                let shot = try Capture.windowShot(
                    pid: pid, wid: snap.windowId,
                    maxWidth: screenshotMaxWidth
                )
                resp["screenshot"] = ["path": shot.path, "width": shot.width, "height": shot.height]
            } catch let e as DaemonError {
                resp["screenshot_error"] = e.message
            }
        }
        return resp
    }

    func cmdSnap(_ a: JSONDict) throws -> JSONDict {
        let pid = try resolvePid(a)
        return try snapshotResponse(pid: pid, a: a, includeScreenshot: a.bool("include_screenshot") ?? false,
                                    screenshotMaxWidth: a.int("screenshot_max_width") ?? 1280)
    }

    func cmdGetAppState(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        // AUTO-LAUNCH: bundle given + not running → background launch then resolve.
        var pid: pid_t
        if let bundle = a.string("bundle"),
           AXBridge.runningApp(bundle: bundle) == nil {
            if a.bool("auto_launch") ?? true {
                _ = try AXBridge.launchWithFrontmostPreserved(bundle: bundle)
            } else {
                throw DaemonError("app_not_found", "No running app matched bundle \(bundle).")
            }
        }
        pid = try resolvePid(a)
        // waitUntilReady lives only on the click auto-launch path (single
        // call site in the binary); get_app_state relies on the snapshot
        // walker's own wakeup loop.
        return try snapshotResponse(
            pid: pid, a: a,
            includeScreenshot: a.bool("include_screenshot") ?? true,
            screenshotMaxWidth: a.int("screenshot_max_width") ?? 1280
        )
    }

    // MARK: - launch

    func cmdLaunchApp(_ a: JSONDict) throws -> JSONDict {
        // Thin command: direct AXBridge.launchApp — NO waitUntilReady,
        // NO unminimize (those live on the click auto-launch path).
        guard let bundle = a.string("bundle") else {
            throw DaemonError("invalid_arg", "missing \"bundle\"")
        }
        let activates = a.bool("activates") ?? false
        let app = try AXBridge.launchApp(bundle: bundle, activates: activates)
        // Live-probe wire: {"launched":true,"activates":false,"bundle":"…","app":{…}}
        var appD: JSONDict = ["pid": app.processIdentifier]
        if let b = app.bundleIdentifier { appD["bundle"] = b }
        if let n = app.localizedName { appD["name"] = n }
        return ["launched": true, "activates": activates, "bundle": bundle, "app": appD]
    }

    // MARK: - element resolution

    func resolveElement(_ a: JSONDict) throws -> (AXUIElement, pid_t) {
        guard let ref = a.string("ref") else {
            throw DaemonError("invalid_arg", "missing \"ref\"")
        }
        guard let (el, _) = elementStore.element(forRef: ref) else {
            throw DaemonError("element_not_found", "No element known for ref \(ref). Run `snap` first.")
        }
        var pid = pid_t(0)
        AXUIElementGetPid(el, &pid)
        return (el, pid)
    }

    // MARK: - click

    func cmdClick(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        let button = a.string("button") ?? "left"
        let clickCount = max(1, a.int("click_count") ?? 1)
        let strategy = a.string("strategy") ?? "auto"

        var point: CGPoint
        var pid: pid_t

        if let _ = a.string("ref") {
            let (el, ep) = try resolveElement(a)
            pid = ep
            if strategy == "ax" {
                // AX press path — no pixel dispatch at all.
                if AXUIElementPerformAction(el, kAXPressAction as CFString) == .success {
                    return ["clicked": true, "clicks": clickCount, "button": button, "via": "ax_press"]
                }
                throw DaemonError("action_unsupported", "Element does not support AXPress")
            }
            guard let b = AXBridge.axBounds(el) else {
                throw DaemonError("element_not_found", "Element has no on-screen bounds")
            }
            point = CGPoint(x: b.midX, y: b.midY)
        } else {
            // pixel path — verified chain: requires pid|bundle; if app not
            // running and bundle given → launchWithFrontmostPreserved →
            // waitUntilReady → snapshot → window match → unminimize →
            // re-snapshot(wakeup=0) if it moved → settle → clickAtPoint.
            guard let x = a.double("x"), let y = a.double("y") else {
                throw DaemonError("invalid_arg", "click requires either `ref` or both `x` and `y`")
            }
            if a.int("pid") == nil && a.string("bundle") == nil {
                throw DaemonError("invalid_arg",
                    "click by pixel requires either `pid` or `bundle` of a running app — without a target we'd have to post globally and move the real cursor.")
            }
            if let bundle = a.string("bundle"), AXBridge.runningApp(bundle: bundle) == nil {
                _ = try AXBridge.launchWithFrontmostPreserved(bundle: bundle)
            }
            pid = try resolvePid(a)
            AXBridge.waitUntilReady(pid: pid)

            let wins = AXBridge.windows(of: pid)
            if let w = wins.first {
                if AXBridge.unminimizeIfNeeded(w) {
                    // window moved on un-minimize — re-read geometry
                    _ = AXBridge.axBounds(w)
                }
            }

            let coordSpace = a.string("coord_space") ?? "screenshot"
            point = coordSpace == "screen"
                ? CGPoint(x: x, y: y)
                : try Capture.translateScreenshotCoord(pid: pid, x: x, y: y)
        }

        let token = EventDispatch.settlePrelude(pid: pid, point: point)
        try EventDispatch.withFocusPreserved(pid: pid) {
            try EventDispatch.clickAtPoint(point, pid: pid, button: button, clickCount: clickCount)
        }
        EventDispatch.settlePostlude(token, pid: pid)

        return [
            "clicked": true, "clicks": clickCount, "button": button,
            "coord_space": a.string("coord_space") ?? "screenshot",
        ]
    }

    func cmdSecondaryAction(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        if let _ = a.string("ref") {
            let (el, _) = try resolveElement(a)
            if let action = a.string("action") {
                if AXUIElementPerformAction(el, action as CFString) == .success {
                    return ["performed": true, "action": action]
                }
                throw DaemonError("action_unsupported",
                    "Element does not support action \(action) → AX action not available.")
            }
            if AXUIElementPerformAction(el, kAXShowMenuAction as CFString) == .success {
                return ["performed": true, "action": "AXShowMenu"]
            }
            throw DaemonError("action_unsupported", "Element does not support AXShowMenu")
        }
        // pixel variant = right click
        guard let x = a.double("x"), let y = a.double("y") else {
            throw DaemonError("invalid_arg", "perform_secondary_action requires either `ref` or both `x` and `y`")
        }
        let pid = try resolvePid(a)
        let coordSpace = a.string("coord_space") ?? "screenshot"
        let point = coordSpace == "screen" ? CGPoint(x: x, y: y)
            : try Capture.translateScreenshotCoord(pid: pid, x: x, y: y)
        try EventDispatch.withFocusPreserved(pid: pid) {
            try EventDispatch.clickAtPoint(point, pid: pid, button: "right", clickCount: 1)
        }
        return ["performed": true]
    }

    // MARK: - drag

    func cmdDrag(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        for k in ["start_x", "start_y", "end_x", "end_y"] where a.double(k) == nil {
            throw DaemonError("invalid_arg", "missing \"\(k)\"")
        }
        let pid = try resolvePid(a)
        let coordSpace = a.string("coord_space") ?? "screenshot"
        func pt(_ x: Double, _ y: Double) throws -> CGPoint {
            coordSpace == "screen" ? CGPoint(x: x, y: y)
                : try Capture.translateScreenshotCoord(pid: pid, x: x, y: y)
        }
        let from = try pt(a.double("start_x")!, a.double("start_y")!)
        let to = try pt(a.double("end_x")!, a.double("end_y")!)
        let token = EventDispatch.settlePrelude(pid: pid, point: to)
        try EventDispatch.withFocusPreserved(pid: pid) {
            EventDispatch.dragToPid(from: from, to: to, pid: pid)
        }
        EventDispatch.settlePostlude(token, pid: pid)
        return ["dragged": true]
    }

    // MARK: - text

    func cmdTypeText(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        guard let text = a.string("text") else {
            throw DaemonError("invalid_arg", "missing \"text\"")
        }
        // ref + (auto|ax) → AX insertion on the referenced element:
        // AXSelectedText insert first, else AXValue append. physical/unicode
        // bypass AX entirely even with a ref (event path by pid).
        let method = a.string("input_method") ?? "auto"
        if let _ = a.string("ref"), method == "ax" || method == "auto" {
            let (el, _) = try resolveElement(a)
            if AXUIElementSetAttributeValue(el, "AXSelectedText" as CFString, text as CFTypeRef) == .success {
                return ["typed": true, "via": "ax"]
            }
            if let cur = AXBridge.copyString(el, kAXValueAttribute),
               AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, (cur + text) as CFTypeRef) == .success {
                return ["typed": true, "via": "ax"]
            }
            if method == "ax" {
                throw DaemonError("action_unsupported", "Element does not support action setting AXValue.")
            }
        }
        let pid = try resolvePid(a)
        try EventDispatch.typeText(text, pid: pid, method: method)
        return ["typed": true, "chars": text.count]
    }

    // MARK: - press / press_key

    /// `press` — AX action on a ref. Only Enter/Escape/Space/Increment/
    /// Decrement/ShowMenu are supported over AX (verbatim error text).
    func cmdPress(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        guard let key = a.string("key") else {
            throw DaemonError("invalid_arg", "missing \"key\"")
        }
        let supported = ["Enter": "AXConfirm", "Escape": "AXCancel",
                         "Space": "AXPress", "Increment": "AXIncrement",
                         "Decrement": "AXDecrement", "ShowMenu": "AXShowMenu"]
        guard let axAction = supported[key] else {
            throw DaemonError("action_unsupported",
                "Element does not support action press \(key) (only Enter/Escape/Space/Increment/Decrement/ShowMenu are supported over AX in v1).")
        }
        let (el, _) = try resolveElement(a)
        guard AXUIElementPerformAction(el, axAction as CFString) == .success else {
            throw DaemonError("action_unsupported",
                "Element does not support action press \(key) → \(axAction) not on element.")
        }
        return ["pressed": true, "via": "ax"]
    }

    /// `press_key` — chord → menu fallback (menu_ax_press) else CGEvent to pid.
    func cmdPressKey(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        guard let key = a.string("key") else {
            throw DaemonError("invalid_arg", "missing \"key\"")
        }
        let pid = try resolvePid(a)
        let result = try EventDispatch.withFocusPreserved(pid: pid) {
            try EventDispatch.pressKey(key, pid: pid)
        }
        var resp: JSONDict = ["delivered": result.delivered]
        if let via = result.via { resp["via"] = via }
        if let note = result.note { resp["delivery_note"] = note }
        return resp
    }

    // MARK: - set_value / select_text

    func cmdSetValue(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        guard let value = a.string("value") ?? a.string("text") else {
            throw DaemonError("invalid_arg", "missing \"value\"")
        }
        let (el, _) = try resolveElement(a)
        guard AXUIElementSetAttributeValue(el, kAXValueAttribute as CFString, value as CFTypeRef) == .success else {
            throw DaemonError("action_unsupported", "Element does not support action setting AXValue.")
        }
        return ["set": true]
    }

    func cmdSelectText(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        guard let text = a.string("text") else {
            throw DaemonError("invalid_arg", "missing \"text\"")
        }
        let (el, _) = try resolveElement(a)
        // Verified: AXFocused=true is written BEFORE the selection.
        AXUIElementSetAttributeValue(el, kAXFocusedAttribute as CFString, true as CFTypeRef)

        let haystack = AXBridge.copyString(el, kAXValueAttribute)
            ?? AXBridge.copyString(el, kAXTitleAttribute) ?? ""
        let prefix = a.string("prefix")
        let suffix = a.string("suffix")
        let selectionType = a.string("selection_type") ?? "" // non-optional; "" → whole match

        var range: NSRange?
        var searchFrom = haystack.startIndex
        while let found = haystack.range(of: text, options: [.caseInsensitive], range: searchFrom..<haystack.endIndex) {
            let beforeOK = prefix.map { haystack[..<found.lowerBound].hasSuffix($0) } ?? true
            let afterOK = suffix.map { haystack[found.upperBound...].hasPrefix($0) } ?? true
            if beforeOK && afterOK {
                range = NSRange(found, in: haystack)
                break
            }
            searchFrom = found.upperBound
        }
        guard let match = range else {
            throw DaemonError("element_not_found", "text not found in element")
        }

        var sel = match
        switch selectionType {
        case "cursor_before": sel = NSRange(location: match.location, length: 0)
        case "cursor_after": sel = NSRange(location: match.location + match.length, length: 0)
        default: break // "text" / "" → select the whole match
        }

        var cfRange = CFRange(location: sel.location, length: sel.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            throw DaemonError("action_unsupported", "could not build selection range")
        }
        guard AXUIElementSetAttributeValue(el, "AXSelectedTextRange" as CFString, rangeValue) == .success else {
            throw DaemonError("action_unsupported", "Element does not support action selecting text.")
        }
        return ["selected": true]
    }

    // MARK: - scroll

    func cmdScroll(_ a: JSONDict) throws -> JSONDict {
        try actionPreflight(a)
        guard let direction = a.string("direction") else {
            throw DaemonError("invalid_arg", "missing \"direction\"")
        }
        let pages = max(1, a.int("pages") ?? 1)
        let actionName: String
        switch direction {
        case "up": actionName = "AXScrollUpByPage"
        case "down": actionName = "AXScrollDownByPage"
        case "left": actionName = "AXScrollLeftByPage"
        case "right": actionName = "AXScrollRightByPage"
        default:
            throw DaemonError("invalid_arg", "unknown direction \"\(direction)\"")
        }
        LensBus.postScroll(direction: direction)
        let (el, _) = try resolveElement(a)
        for _ in 0..<pages {
            guard AXUIElementPerformAction(el, actionName as CFString) == .success else {
                throw DaemonError("action_unsupported",
                    "\(actionName) not available on element (ref points at an unscrollable element — snap the parent ScrollArea).")
            }
            usleep(50_000)
        }
        return ["scrolled": true, "direction": direction, "pages": pages]
    }

    // MARK: - shot

    func cmdShot(_ a: JSONDict) throws -> JSONDict {
        // Live-probe: shot {"bundle":…} without out → invalid_arg missing "out".
        guard let out = a.string("out") else {
            throw DaemonError("invalid_arg", "missing \"out\"")
        }
        let pid = try resolvePid(a)
        let wid = a.int("window_id").map { CGWindowID($0) }
        let shot = try Capture.windowShot(pid: pid, wid: wid,
                                          maxWidth: a.int("max_width") ?? 2000,
                                          outPath: out)
        return ["path": shot.path, "width": shot.width, "height": shot.height]
    }

    func cmdShotDisplay(_ a: JSONDict) throws -> JSONDict {
        guard let out = a.string("out") else {
            throw DaemonError("invalid_arg", "missing \"out\"")
        }
        let shot = try Capture.displayShot(maxWidth: a.int("max_width") ?? 2000,
                                           outPath: out)
        return ["path": shot.path, "width": shot.width, "height": shot.height]
    }

    // MARK: - picture-in-picture
    // [LIVE] pip_open{window_id,title?,width?,height?} →
    //   {"opened":true,"session":{window_id,pid,title,floater_frame:{x,y,w,h},
    //    has_first_frame,last_frame_age_ms}}
    // pip_status{} → {"sessions":[…],"armed":[…]}
    // pip_arm{window_id,pid,title} → {"armed":[…]}
    // pip_close/pip_disarm {window_id} | {"all":true}

    func cmdPipOpen(_ a: JSONDict) throws -> JSONDict {
        guard let wid = a.int("window_id").map({ CGWindowID($0) }) else {
            throw DaemonError("invalid_arg", "missing \"window_id\"")
        }
        // Verbatim: partial preferred size is rejected.
        let w = a.int("width"), h = a.int("height")
        if (w == nil) != (h == nil) {
            throw DaemonError("invalid_arg",
                "\"width\" and \"height\" are required when pip_open " +
                "carries a preferred size")
        }
        let size = w.flatMap { wv in h.map { CGSize(width: wv, height: $0) } }
        return try PIPManager.shared.open(windowId: wid,
            pid: a.int("pid").map { pid_t($0) }, title: a.string("title"),
            preferredSize: size)
    }

    func cmdPipClose(_ a: JSONDict) throws -> JSONDict {
        try PIPManager.shared.close(
            windowId: a.int("window_id").map { CGWindowID($0) },
            all: a.bool("all") ?? false)
    }

    func cmdPipStatus(_ a: JSONDict) throws -> JSONDict {
        try PIPManager.shared.status()
    }

    func cmdPipArm(_ a: JSONDict) throws -> JSONDict {
        var pid = a.int("pid").map { pid_t($0) }
        if pid == nil, let w = a.string("bundle") {
            pid = NSRunningApplication
                .runningApplications(withBundleIdentifier: w)
                .first?.processIdentifier
        }
        guard let pid else {
            throw DaemonError("invalid_arg", "missing \"pid\"")
        }
        // Resolve the CGWindowID: explicit arg, else the app's first window —
        // miss → "App has no windows to arm."
        var wid = a.int("window_id").map { CGWindowID($0) }
        if wid == nil {
            wid = AXBridge.windows(of: pid).compactMap {
                AXBridge.windowIDNumber(of: $0)
            }.first
            if wid == nil {
                throw DaemonError("invalid_arg",
                    "App has no windows to arm.")
            }
        }
        try PIPMinimizeArmer.shared.arm(windowId: wid!, pid: pid,
                                        title: a.string("title"))
        return ["armed": PIPMinimizeArmer.shared.statusList()]
    }

    func cmdPipDisarm(_ a: JSONDict) throws -> JSONDict {
        if a.bool("all") == true {
            PIPMinimizeArmer.shared.disarmAll()
        } else if let wid = a.int("window_id") {
            _ = PIPMinimizeArmer.shared.disarm(windowId: CGWindowID(wid))
        }
        return ["armed": PIPMinimizeArmer.shared.statusList()]
    }
}
