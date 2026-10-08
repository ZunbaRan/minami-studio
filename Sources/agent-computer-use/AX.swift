import ApplicationServices
import AppKit
import Foundation

// AX subsystem: SerializedElement, ElementStore (refs + descriptors), snapshot
// walk, diff store, launch/ready/window helpers, ForbiddenTargets.
// Wire schema per computer-use/contracts/serialized-element.schema.json:
// required {ref, role, enabled, focused, actions, children_count}; optional
// keys are OMITTED when nil (never emitted as null).

// MARK: - ElementDescriptor (internal ref-recovery signature; NOT emitted)

struct ElementDescriptor {
    var role: String?
    var subrole: String?
    var title: String?
    var identifier: String?
    var roleDescription: String?
    var parentRoles: [String] = []
    var bounds: CGRect?
}

// MARK: - SerializedElement

struct SerializedElement {
    var ref: String
    var role: String?
    var subrole: String?
    var roleDescription: String?
    var title: String?
    var value: String?
    var description: String?
    var bounds: CGRect?
    var actions: [String] = []
    var enabled: Bool = false
    var focused: Bool = false
    var selected: Bool?
    var childrenCount: Int = 0

    var axElement: AXUIElement?
    var descriptor = ElementDescriptor()

    func toDict() -> JSONDict {
        var d: JSONDict = [
            "ref": ref,
            "enabled": enabled,
            "focused": focused,
            "actions": actions,
            "children_count": childrenCount,
        ]
        // role is emitted unconditionally as a string (AXUnknown fallback)
        d["role"] = role ?? "AXUnknown"
        if let subrole { d["subrole"] = subrole }
        if let roleDescription { d["role_description"] = roleDescription }
        if let title { d["title"] = title }
        if let value { d["value"] = value }
        if let description { d["description"] = description }
        if let selected { d["selected"] = selected }
        if let b = bounds {
            d["bounds"] = [
                "x": Double(b.origin.x), "y": Double(b.origin.y),
                "w": Double(b.size.width), "h": Double(b.size.height),
            ]
        }
        return d
    }

    /// Fingerprint input for snapshot diffing — k=v fields joined by '|'.
    func fingerprint() -> String {
        var parts: [String] = ["ref=\(ref)"]
        if let role { parts.append("role=\(role)") }
        if let title { parts.append("title=\(title)") }
        if let value { parts.append("value=\(value)") }
        if let b = bounds {
            parts.append("bounds=\(b.origin.x),\(b.origin.y),\(b.size.width),\(b.size.height)")
        }
        parts.append("enabled=\(enabled)")
        parts.append("focused=\(focused)")
        if let selected { parts.append("selected=\(selected)") }
        parts.append("children=\(childrenCount)")
        return parts.joined(separator: "|")
    }
}

// MARK: - SnapshotResult / AppStateDiff

struct SnapshotResult {
    var snapshotId: String
    var elements: [SerializedElement]
    var windowId: CGWindowID?
    var windowBounds: CGRect?
    var windowTitle: String?
    var bundle: String?
    var appName: String?
    var pid: pid_t
    var axStatus: String
    var wakeupAttempts: Int
    var wakeupDurationMs: Double

    /// Diff state per window key. fingerprint equality compares element
    /// fingerprints; refs removed since last snapshot are reported.
    struct WindowState {
        var fingerprints: [String: String] = [:] // ref -> fingerprint
    }
}

final class AppStateStore {
    private var states: [String: SnapshotResult.WindowState] = [:]
    private var snapshotCounter: Int = 0
    private let lock = NSLock()

    func key(pid: pid_t, wid: CGWindowID?) -> String {
        "\(pid):\(wid ?? 0)" // "pid:wid", 0 = nil placeholder
    }

    /// Verbatim id format from live probes: s_<yyyyMMdd'T'HHmmss>Z (UTC).
    func nextSnapshotId() -> String {
        lock.lock(); defer { lock.unlock() }
        snapshotCounter += 1
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        return "s_\(f.string(from: Date()))"
    }

    /// Returns (diffComputed, isDiff, elementsToEmit, removedRefs, unchangedCount).
    /// No previous snapshot or diff disabled → diffComputed=false and the
    /// caller OMITS the diff keys entirely (verified wire shape).
    func diff(pid: pid_t, wid: CGWindowID?, elements: [SerializedElement], disableDiff: Bool) -> (computed: Bool, isDiff: Bool, [SerializedElement], [String], Int) {
        let k = key(pid: pid, wid: wid)
        lock.lock(); defer { lock.unlock() }
        let newFP = Dictionary(uniqueKeysWithValues: elements.map { ($0.ref, $0.fingerprint()) })
        guard !disableDiff, let prev = states[k] else {
            states[k] = SnapshotResult.WindowState(fingerprints: newFP)
            return (false, false, elements, [], 0)
        }
        var changed: [SerializedElement] = []
        var unchanged = 0
        for el in elements {
            if prev.fingerprints[el.ref] == el.fingerprint() { unchanged += 1 }
            else { changed.append(el) }
        }
        let removed = prev.fingerprints.keys.filter { newFP[$0] == nil }
        states[k] = SnapshotResult.WindowState(fingerprints: newFP)
        return (true, true, changed, removed, unchanged)
    }
}

// MARK: - ElementStore (ref -> element + descriptor; counter is monotonic, never reset per snapshot)

final class ElementStore {
    private var refs: [String: (AXUIElement, ElementDescriptor)] = [:]
    private var counter: Int = 0
    private let lock = NSLock()

    func alloc() -> String {
        lock.lock(); defer { lock.unlock() }
        counter += 1
        return "e\(counter)"
    }

    func register(_ el: AXUIElement, descriptor: ElementDescriptor) -> String {
        let ref = alloc()
        lock.lock(); refs[ref] = (el, descriptor); lock.unlock()
        return ref
    }

    func element(forRef ref: String) -> (AXUIElement, ElementDescriptor)? {
        lock.lock(); defer { lock.unlock() }
        return refs[ref]
    }
}

// MARK: - AXBridge

enum AXBridge {

    // attribute helpers
    static func copyAttr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
        return v
    }
    static func copyString(_ el: AXUIElement, _ name: String) -> String? {
        let v = copyAttr(el, name)
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        if let a = v as? NSAttributedString { return a.string }
        return nil
    }
    static func copyBool(_ el: AXUIElement, _ name: String) -> Bool? {
        (copyAttr(el, name) as? NSNumber)?.boolValue
    }
    static func copyStrings(_ el: AXUIElement, _ name: String) -> [String] {
        (copyAttr(el, name) as? [String]) ?? []
    }
    static func copyElements(_ el: AXUIElement, _ name: String) -> [AXUIElement] {
        (copyAttr(el, name) as? [AXUIElement]) ?? []
    }
    static func axPoint(_ el: AXUIElement) -> CGPoint? {
        guard let v = copyAttr(el, kAXPositionAttribute),
              CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(unsafeDowncast(v, to: AXValue.self), .cgPoint, &p) ? p : nil
    }
    static func axSize(_ el: AXUIElement) -> CGSize? {
        guard let v = copyAttr(el, kAXSizeAttribute),
              CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
        var s = CGSize.zero
        return AXValueGetValue(unsafeDowncast(v, to: AXValue.self), .cgSize, &s) ? s : nil
    }
    static func axBounds(_ el: AXUIElement) -> CGRect? {
        guard let p = axPoint(el), let s = axSize(el) else { return nil }
        return CGRect(origin: p, size: s)
    }

    // Serialize one AX node into a SerializedElement (ref assigned by caller).
    static func serialize(_ ax: AXUIElement, ref: String, parentRoles: [String]) -> SerializedElement {
        var el = SerializedElement(ref: ref)
        el.role = copyString(ax, kAXRoleAttribute)
        el.subrole = copyString(ax, kAXSubroleAttribute)
        el.roleDescription = copyString(ax, kAXRoleDescriptionAttribute)
        el.title = copyString(ax, kAXTitleAttribute)
        el.value = copyString(ax, kAXValueAttribute)
        el.description = copyString(ax, kAXDescriptionAttribute)
        el.bounds = axBounds(ax)
        var actionNames: CFArray?
        el.actions = (AXUIElementCopyActionNames(ax, &actionNames) == .success ? (actionNames as? [String]) : nil) ?? []
        el.enabled = copyBool(ax, kAXEnabledAttribute) ?? false
        el.focused = copyBool(ax, kAXFocusedAttribute) ?? false
        el.selected = copyBool(ax, "AXSelected")
        el.childrenCount = copyElements(ax, kAXChildrenAttribute).count
        el.axElement = ax
        el.descriptor = ElementDescriptor(
            role: el.role, subrole: el.subrole, title: el.title,
            identifier: copyString(ax, kAXIdentifierAttribute),
            roleDescription: el.roleDescription,
            parentRoles: parentRoles, bounds: el.bounds
        )
        return el
    }

    /// Interactive filter — "有 actions 或可写 value" (04-ax-subsystem).
    static func isInteractive(_ el: SerializedElement) -> Bool {
        if !el.actions.isEmpty { return true }
        if el.value != nil { return true } // value-bearing (potentially writable)
        return false
    }

    // MARK: app resolution

    static func runningApp(bundle: String? = nil, pid: pid_t? = nil) -> NSRunningApplication? {
        // NSWorkspace.shared.runningApplications is notification-fed and
        // goes stale in a bare-executable daemon (no NSApplication event
        // loop). NSRunningApplication queries hit launch services directly.
        if let pid {
            let app = NSRunningApplication(processIdentifier: pid)
            return (app?.isTerminated == false) ? app : nil
        }
        if let bundle {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundle)
                .first { !$0.isTerminated }
        }
        return nil
    }

    /// launch_app path: direct NSWorkspace launch. `activates` only reaches the
    static func allRunningRegular() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
    }

    /// macOS cold-launch flag; running apps are NEVER activated.
    static func launchApp(bundle: String, activates: Bool) throws -> NSRunningApplication {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else {
            throw DaemonError("app_not_found", "No app found for bundle \(bundle)")
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activates
        var done = false
        var result: NSRunningApplication?
        var err: Error?
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, e in
            result = app; err = e; done = true
        }
        let deadline = Date().addingTimeInterval(20)
        while !done && Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        if let e = err { throw DaemonError("launch_error", "launch \(bundle) failed: \(e.localizedDescription)") }
        guard let app = result else {
            throw DaemonError("launch_error", "launch \(bundle) timed out")
        }
        return app
    }

    /// Background launch that must not disturb the user's frontmost app —
    /// wraps launchApp(activates:false) in the FocusStealPreventer window.
    static func launchWithFrontmostPreserved(bundle: String) throws -> NSRunningApplication {
        try EventDispatch.withFocusPreserved(style: .preserved) {
            try launchApp(bundle: bundle, activates: false)
        }
    }

    /// Poll until the app has an AX window (or the attempts budget is spent).
    /// Returns (attempts, durationMs, ready).
    @discardableResult
    static func waitUntilReady(pid: pid_t, maxAttempts: Int = 40, interval: TimeInterval = 0.1) -> (Int, Double, Bool) {
        let app = AXUIElementCreateApplication(pid)
        let t0 = Date()
        var attempts = 0
        while attempts < maxAttempts {
            attempts += 1
            if !copyElements(app, kAXWindowsAttribute).isEmpty || !copyElements(app, "AXChildren").isEmpty {
                return (attempts, Date().timeIntervalSince(t0) * 1000, true)
            }
            usleep(UInt32(interval * 1_000_000))
        }
        return (attempts, Date().timeIntervalSince(t0) * 1000, false)
    }

    static func windows(of pid: pid_t) -> [AXUIElement] {
        copyElements(AXUIElementCreateApplication(pid), kAXWindowsAttribute)
    }

    /// Read AXMinimized; if true write false, sleep ~0.2s for the Dock
    /// un-minimize animation, return true only when an unminimize occurred.
    @discardableResult
    static func unminimizeIfNeeded(_ window: AXUIElement) -> Bool {
        guard copyBool(window, "AXMinimized") == true else { return false }
        AXUIElementSetAttributeValue(window, "AXMinimized" as CFString, false as CFTypeRef)
        usleep(200_000)
        return true
    }

    // MARK: snapshot

    /// Depth-limited DFS serialization of an app's window tree.
    /// depth counts AXChildren levels below the window; 0 = window only.
    static func snapshot(
        pid: pid_t,
        windowId: CGWindowID? = nil,
        depth: Int = 6,
        interactiveOnly: Bool = true,
        wakeupSeconds: TimeInterval = 4.0,
        store: ElementStore
    ) -> SnapshotResult {
        _ = AXUIElementCreateApplication(pid) // creates+retains the app handle; walker uses its own
        var attempts = 0
        var wakeupMs = 0.0
        var axStatus = "populated" // verbatim live-probe value

        var wins = windows(of: pid)
        if wins.isEmpty {
            // wakeup path — retry until AX populates or budget spent
            let t0 = Date()
            let maxAttempts = max(1, Int(wakeupSeconds / 0.1))
            while attempts < maxAttempts && wins.isEmpty {
                attempts += 1
                usleep(100_000)
                wins = windows(of: pid)
            }
            wakeupMs = Date().timeIntervalSince(t0) * 1000
            axStatus = wins.isEmpty ? "empty_after_wakeup" : "woke"
        }

        var windowEl: AXUIElement?
        var resolvedWid: CGWindowID?
        var windowTitle: String?
        var windowBounds: CGRect?
        if let windowId {
            for w in wins {
                if let wid = windowIDNumber(of: w), wid == windowId { windowEl = w; break }
            }
        }
        if windowEl == nil { windowEl = wins.first }
        if let w = windowEl {
            resolvedWid = windowIDNumber(of: w)
            windowTitle = copyString(w, kAXTitleAttribute)
            windowBounds = axBounds(w)
        }

        var elements: [SerializedElement] = []
        if let root = windowEl {
            walk(el: root, depthLeft: depth, parentRoles: [], ancestors: [root],
                 out: &elements, store: store, interactiveOnly: interactiveOnly)
        }

        return SnapshotResult(
            snapshotId: "", elements: elements,
            windowId: resolvedWid, windowBounds: windowBounds,
            windowTitle: windowTitle,
            bundle: runningApp(pid: pid)?.bundleIdentifier,
            appName: runningApp(pid: pid)?.localizedName,
            pid: pid, axStatus: axStatus,
            wakeupAttempts: attempts, wakeupDurationMs: wakeupMs
        )
    }

    /// Pathological-tree bound. Calculator's AXWindows returns the app
    /// element itself and its AXChildren re-return self — ancestors are
    /// checked by CFEqual so a self-cycle terminates after one hop, and the
    /// hard cap stops combinatorial mirror trees regardless.
    static let maxSerializedElements = 4000

    private static func walk(
        el ax: AXUIElement, depthLeft: Int,
        parentRoles: [String], ancestors: [AXUIElement],
        out: inout [SerializedElement],
        store: ElementStore, interactiveOnly: Bool
    ) {
        if out.count >= maxSerializedElements { return }
        var el = serialize(ax, ref: "", parentRoles: parentRoles)
        let roles = parentRoles + (el.role.map { [$0] } ?? [])
        if !interactiveOnly || isInteractive(el) {
            // ref is allocated only for emitted elements so agent-visible
            // numbering stays dense (e1,e2,e3...), as observed live.
            el.ref = store.register(ax, descriptor: el.descriptor)
            out.append(el)
        }
        guard depthLeft > 0 else { return }
        for child in copyElements(ax, kAXChildrenAttribute) {
            if ancestors.contains(where: { CFEqual($0, child) }) { continue }
            walk(el: child, depthLeft: depthLeft - 1, parentRoles: roles,
                 ancestors: ancestors + [child], out: &out,
                 store: store, interactiveOnly: interactiveOnly)
            if out.count >= maxSerializedElements { return }
        }
    }

    static func windowIDNumber(of window: AXUIElement) -> CGWindowID? {
        var wid = CGWindowID(0)
        if _AXUIElementGetWindow(window, &wid) == .success && wid != 0 { return wid }
        return nil
    }
}

// _AXUIElementGetWindow is a private-but-stable AX API used by Alma for
// AXUIElement -> CGWindowID. Same SPI, same purpose.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - ForbiddenTargets (verbatim blocklist per strings evidence)

enum ForbiddenTargets {
    static let blocklist: Set<String> = [
        "com.apple.systempreferences",
        "com.apple.security.pluginkit",
        "com.apple.security-notification",
        "com.apple.preference.general",
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.PassphraseAgent",
        "com.apple.PasswordBreachAgent",
        "com.apple.universalaccessAuthWarn",
        "com.apple.WindowServer",
        "com.apple.launchpad",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.spotlight",
        "com.apple.ScreenSaver.Engine",
        "com.apple.ScreenSaverEngine",
        "com.apple.tccd",
        "com.apple.dock",
    ]

    /// Throws unless `allowOverride` (force_forbidden arg) is true.
    /// pid variant resolves the bundle id first.
    static func check(pid: pid_t?, allowOverride: Bool) throws {
        if allowOverride { return }
        guard let pid else { return }
        try check(bundleId: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, allowOverride: allowOverride)
    }

    static func check(bundleId: String?, allowOverride: Bool) throws {
        if allowOverride { return }
        guard let b = bundleId, blocklist.contains(b) else { return }
        throw DaemonError("forbidden_target", "Refusing to drive \(b) — this target is on the computer-use blocklist.")
    }
}
