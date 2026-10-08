import ApplicationServices
import AppKit
import Foundation

// AX subsystem: SerializedElement, ElementStore (refs + descriptors +
// invalidation observers), snapshot walk, diff store, launch/ready/window
// helpers, ForbiddenTargets.
// Wire schema per computer-use/contracts/serialized-element.schema.json:
// required {ref, role, enabled, focused, actions, children_count}; optional
// keys are OMITTED when nil (never emitted as null).
//
// Field-read rules [SNAP §11, verbatim]:
//   role: default "" (empty string, NOT "AXUnknown")
//   title: first non-empty String of AXTitle → AXTitleUIElement.AXValue →
//          AXLabelValue (Alma force-casts the TitleUIElement value; we guard
//          instead — documented deviation, .164 may trap there)
//   value: AXValue as String, else NSNumber.stringValue; empty valid
//   description: AXDescription as String even when empty; AXHelp only when
//          AXDescription is not a String at all
//   enabled: default true; focused: default false; selected: optional
//   bounds: only when BOTH AXPosition and AXSize read succeed
//   descriptor retains last 8 ancestor roles; recovery compares last 3

// MARK: - ElementDescriptor (internal ref-recovery signature; NOT emitted)

struct ElementDescriptor {
    var role: String?
    var subrole: String?
    var title: String?
    var identifier: String?
    var roleDescription: String?
    var parentRoles: [String] = [] // last ≤8 ancestor roles
    var bounds: CGRect?
}

// MARK: - SerializedElement

struct SerializedElement {
    var ref: String
    var role: String = ""            // Alma default is empty string
    var subrole: String?
    var roleDescription: String?
    var title: String?
    var value: String?
    var description: String?
    var bounds: CGRect?
    var actions: [String] = []
    var enabled: Bool = true         // Alma default is TRUE when attr missing
    var focused: Bool = false
    var selected: Bool?
    var childrenCount: Int = 0

    var axElement: AXUIElement?
    var descriptor = ElementDescriptor()

    func toDict() -> JSONDict {
        var d: JSONDict = [
            "ref": ref,
            "role": role,
            "enabled": enabled,
            "focused": focused,
            "actions": actions,
            "children_count": childrenCount,
        ]
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

    /// Diff fingerprint — verbatim field list [04 §12]:
    ///   fixed = role,subrole,title,value,description,role_description,
    ///           enabled,focused,children_count,actions
    ///   each: `key=String(describing:value)` when the optional slot is non-nil
    ///   bounds: "x,y,w,h" each Int(v.rounded()), missing subfield → 0
    /// NOT included: ref, selected.
    func fingerprint() -> String {
        var parts: [String] = []
        parts.append("role=\(role)")
        if let v = subrole { parts.append("subrole=\(v)") }
        if let v = title { parts.append("title=\(v)") }
        if let v = value { parts.append("value=\(v)") }
        if let v = description { parts.append("description=\(v)") }
        if let v = roleDescription { parts.append("role_description=\(v)") }
        parts.append("enabled=\(enabled)")
        parts.append("focused=\(focused)")
        parts.append("children_count=\(childrenCount)")
        parts.append("actions=\(String(describing: actions))")
        if let b = bounds {
            let nums = [b.origin.x, b.origin.y, b.size.width, b.size.height]
                .map { String(Int($0.rounded())) }
            parts.append("bounds=" + nums.joined(separator: ","))
        }
        return parts.joined(separator: "|")
    }
}

// MARK: - SnapshotResult / AppStateDiff

struct SnapshotResult {
    var snapshotId: String
    var elements: [SerializedElement]
    var windowId: CGWindowID?
    var windowElement: AXUIElement?
    var windowBounds: CGRect?
    var windowTitle: String?
    var bundle: String?
    var appName: String?
    var pid: pid_t
    var axStatus: String
    var wakeupAttempts: Int
    var wakeupDurationMs: Int

    /// Diff state per (pid, windowId) key — fingerprint cache by ref.
    struct WindowState {
        var fingerprints: [String: String] = [:]
    }
}

final class AppStateStore {
    private var states: [String: SnapshotResult.WindowState] = [:]
    private var snapshotCounter: Int = 0
    private let lock = NSLock()

    func key(pid: pid_t, wid: CGWindowID?) -> String {
        "\(pid):\(wid ?? 0)"
    }

    /// Verbatim id format from live probes: s_<yyyy-MM-dd'T'HHmmss>Z (UTC).
    func nextSnapshotId() -> String {
        lock.lock(); defer { lock.unlock() }
        snapshotCounter += 1
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HHmmss'Z'"
        return "s_\(f.string(from: Date()))"
    }

    /// Returns (diffComputed, elementsToEmit, removedRefs, unchangedCount).
    /// disable_diff stores the full fingerprint cache and returns the
    /// complete element list WITHOUT diff keys — it is a reset, not a skip.
    func diff(pid: pid_t, wid: CGWindowID?, elements: [SerializedElement],
              disableDiff: Bool)
        -> (computed: Bool, [SerializedElement], [String], Int)
    {
        let k = key(pid: pid, wid: wid)
        lock.lock(); defer { lock.unlock() }
        let newFP = Dictionary(uniqueKeysWithValues:
            elements.map { ($0.ref, $0.fingerprint()) })
        if disableDiff {
            states[k] = SnapshotResult.WindowState(fingerprints: newFP)
            return (false, elements, [], 0)
        }
        guard let prev = states[k] else {
            states[k] = SnapshotResult.WindowState(fingerprints: newFP)
            return (false, elements, [], 0)
        }
        var changed: [SerializedElement] = []
        var unchanged = 0
        for el in elements {
            if prev.fingerprints[el.ref] == el.fingerprint() { unchanged += 1 }
            else { changed.append(el) }
        }
        // removed refs are emitted in lexical order
        let removed = prev.fingerprints.keys.filter { newFP[$0] == nil }.sorted()
        states[k] = SnapshotResult.WindowState(fingerprints: newFP)
        return (true, changed, removed, unchanged)
    }
}

// MARK: - ElementStore
// One table of ref → Entry. Entry carries element + snapshotId + pid +
// descriptor + invalidated flag. CFEqual-matched elements REUSE the existing
// ref across snapshots — this is what makes refs stable; Alma never re-allocs
// a ref for the same AXUIElement in a follow-up snapshot.

final class ElementStore {
    struct Entry {
        var element: AXUIElement
        var snapshotId: String
        var pid: pid_t
        var descriptor: ElementDescriptor
        var invalidated: Bool
    }

    private var table: [String: Entry] = [:]
    private var counter: Int = 0
    private var currentSnapshotRefs: Set<String> = []
    private var observers: [pid_t: AXObserver] = [:]
    private let lock = NSLock()

    /// beginSnapshot: clear the current-generation set and evict entries
    /// whose element is provably dead (AXRole copy → invalidUIElement).
    /// Other transient read failures are NOT evicted.
    func beginSnapshot(_ snapshotId: String) {
        lock.lock(); defer { lock.unlock() }
        currentSnapshotRefs.removeAll()
        var dead: [String] = []
        for (ref, e) in table {
            var v: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(
                e.element, kAXRoleAttribute as CFString, &v)
            if err == .invalidUIElement { dead.append(ref) }
        }
        for ref in dead { table.removeValue(forKey: ref) }
    }

    /// CFEqual dedupe: same AXUIElement re-registered under its existing ref.
    func register(_ el: AXUIElement, snapshotId: String, pid: pid_t,
                  descriptor: ElementDescriptor) -> String {
        lock.lock(); defer { lock.unlock() }
        for (ref, e) in table where e.pid == pid {
            if CFEqual(e.element, el) {
                var updated = e
                updated.snapshotId = snapshotId
                updated.descriptor = descriptor
                updated.invalidated = false
                updated.element = el
                table[ref] = updated
                currentSnapshotRefs.insert(ref)
                return ref
            }
        }
        counter += 1
        let ref = "e\(counter)"
        table[ref] = Entry(element: el, snapshotId: snapshotId, pid: pid,
                           descriptor: descriptor, invalidated: false)
        currentSnapshotRefs.insert(ref)
        ensureDestroyedObserver(pid: pid)
        return ref
    }

    /// Per-pid app-level observer for AXUIElementDestroyed; the destroyed
    /// element arrives in the callback and its entry is flagged invalidated.
    private func ensureDestroyedObserver(pid: pid_t) {
        if observers[pid] != nil { return }
        let app = AXUIElementCreateApplication(pid)
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, el, _, ctx in
            guard let ctx else { return }
            let me = Unmanaged<ElementStore>.fromOpaque(ctx).takeUnretainedValue()
            me.markInvalidated(element: el)
        }, &obs) == .success, let obs else { return }
        AXObserverAddNotification(obs, app,
            kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           AXObserverGetRunLoopSource(obs), .defaultMode)
        observers[pid] = obs
    }

    private func markInvalidated(element: AXUIElement) {
        lock.lock(); defer { lock.unlock() }
        for (ref, e) in table where CFEqual(e.element, element) {
            var u = e; u.invalidated = true; table[ref] = u
        }
    }

    func entry(forRef ref: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        return table[ref]
    }

    /// resolveRef: absent → element_not_found (verbatim message).
    /// invalidated or dead element → refetchByDescriptor once; unique repair
    /// reuses the ref in place; failure → ref_stale.
    func resolve(ref: String) throws -> Entry {
        guard let entry = entry(forRef: ref) else {
            throw DaemonError("element_not_found",
                "No element known for ref \(ref). Run `snap` first.")
        }
        var stale = entry.invalidated
        if !stale {
            var v: CFTypeRef?
            if AXUIElementCopyAttributeValue(entry.element,
                    kAXRoleAttribute as CFString, &v) == .invalidUIElement {
                stale = true
            }
        }
        if !stale { return entry }
        if let repaired = refetchByDescriptor(entry.descriptor, pid: entry.pid) {
            lock.lock()
            var u = entry
            u.element = repaired; u.invalidated = false
            table[ref] = u
            lock.unlock()
            return u
        }
        throw DaemonError("ref_stale",
            "ref \(ref) is stale — element no longer exists")
    }

    /// Descriptor-based re-acquisition: bounded DFS from the app root
    /// (≤200 nodes, ≤12 deep — the 200 cap belongs HERE, not in snapshots).
    /// Match on role+subrole+title+identifier+roleDescription + last-3
    /// parentRoles; exactly one match required.
    private func refetchByDescriptor(_ d: ElementDescriptor,
                                     pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var visited = 0
        var found: [AXUIElement] = []
        func matches(_ el: AXUIElement, parents: [String]) -> Bool {
            if AXBridge.copyString(el, kAXRoleAttribute) != d.role { return false }
            if AXBridge.copyString(el, kAXSubroleAttribute) != d.subrole { return false }
            if AXBridge.copyString(el, kAXTitleAttribute) != d.title { return false }
            if AXBridge.copyString(el, kAXIdentifierAttribute) != d.identifier { return false }
            if AXBridge.copyString(el, kAXRoleDescriptionAttribute) != d.roleDescription { return false }
            let tail = Array(parents.suffix(3))
            let want = Array(d.parentRoles.suffix(3))
            if tail != want { return false }
            return true
        }
        func dfs(_ el: AXUIElement, parents: [String], depth: Int) {
            if visited >= 200 || found.count > 1 { return }
            visited += 1
            let role = AXBridge.copyString(el, kAXRoleAttribute)
            if matches(el, parents: parents) { found.append(el) }
            guard depth < 12 else { return }
            for c in AXBridge.copyElements(el, kAXChildrenAttribute) {
                dfs(c, parents: parents + (role.map { [$0] } ?? []),
                    depth: depth + 1)
            }
        }
        dfs(app, parents: [], depth: 0)
        return found.count == 1 ? found[0] : nil
    }
}

// MARK: - AX error mapping [WIRE_SCHEMA]
// invalidUIElement → ref_stale; attributeUnsupported + actionUnsupported →
// action_unsupported ("Element does not support action <context>.");
// apiDisabled → ax_not_granted; anything else → ax_failure.

func mapAXError(_ err: AXError, context: String) throws {
    switch err {
    case .success: return
    case .invalidUIElement:
        throw DaemonError("ref_stale", "element went stale during \(context)")
    case .attributeUnsupported, .actionUnsupported:
        throw DaemonError("action_unsupported",
            "Element does not support action \(context).")
    case .apiDisabled:
        throw DaemonError("ax_not_granted",
            "Accessibility permission not granted")
    default:
        throw DaemonError("ax_failure",
            "AX error \(err.rawValue) during \(context)")
    }
}

// MARK: - AXBridge

enum AXBridge {

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
    /// bounds exist only when BOTH position and size read successfully.
    static func axBounds(_ el: AXUIElement) -> CGRect? {
        guard let p = axPoint(el), let s = axSize(el) else { return nil }
        return CGRect(origin: p, size: s)
    }

    /// Serialize one AX node — field reads follow [SNAP §11] exactly.
    static func serialize(_ ax: AXUIElement, ref: String,
                          parentRoles: [String]) -> SerializedElement {
        var el = SerializedElement(ref: ref)
        el.role = copyString(ax, kAXRoleAttribute) ?? ""
        el.subrole = copyString(ax, kAXSubroleAttribute)
        el.roleDescription = copyString(ax, kAXRoleDescriptionAttribute)
        // title: first non-empty of AXTitle → AXTitleUIElement.AXValue → AXLabelValue
        var title = copyString(ax, kAXTitleAttribute)
        if title == nil || title!.isEmpty {
            if let tv = copyAttr(ax, kAXTitleUIElementAttribute),
               CFGetTypeID(tv) == AXUIElementGetTypeID() {
                let t = copyString(unsafeDowncast(tv, to: AXUIElement.self),
                                   kAXValueAttribute)
                if let t, !t.isEmpty { title = t }
            }
        }
        if title == nil || title!.isEmpty {
            if let t = copyString(ax, kAXLabelValueAttribute), !t.isEmpty {
                title = t
            }
        }
        el.title = title
        el.value = copyString(ax, kAXValueAttribute)
        // description: AXDescription String (even empty); AXHelp only when
        // AXDescription is not a String at all.
        if let d = copyAttr(ax, kAXDescriptionAttribute) as? String {
            el.description = d
        } else {
            el.description = copyString(ax, kAXHelpAttribute)
        }
        el.bounds = axBounds(ax)
        var actionNames: CFArray?
        el.actions = (AXUIElementCopyActionNames(ax, &actionNames) == .success
                      ? (actionNames as? [String]) : nil) ?? []
        el.enabled = copyBool(ax, kAXEnabledAttribute) ?? true
        el.focused = copyBool(ax, kAXFocusedAttribute) ?? false
        el.selected = copyBool(ax, "AXSelected")
        el.childrenCount = copyElements(ax, kAXChildrenAttribute).count
        el.axElement = ax
        el.descriptor = ElementDescriptor(
            role: el.role.isEmpty ? nil : el.role,
            subrole: el.subrole, title: el.title,
            identifier: copyString(ax, kAXIdentifierAttribute),
            roleDescription: el.roleDescription,
            parentRoles: Array(parentRoles.suffix(8)),
            bounds: el.bounds
        )
        return el
    }

    /// Interactive filter [SNAP §8]: `!actions.isEmpty || role ∈ set16`.
    /// Disabled controls still emit; there is no enabled gate.
    static let interactiveRoles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXMenuButton", "AXMenuItem", "AXTab", "AXLink",
        "AXTextField", "AXTextArea", "AXComboBox", "AXSlider",
        "AXIncrementor", "AXDisclosureTriangle", "AXCell", "AXRow",
    ]
    static func isInteractive(_ el: SerializedElement) -> Bool {
        !el.actions.isEmpty || interactiveRoles.contains(el.role)
    }

    // MARK: app resolution

    static func runningApp(bundle: String? = nil, pid: pid_t? = nil) -> NSRunningApplication? {
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

    static func allRunningRegular() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
    }

    /// launch_app: NSWorkspace.openApplication with `activates` flag.
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
        while !done && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        if let e = err {
            throw DaemonError("internal",
                "launch \(bundle) failed: \(e.localizedDescription)")
        }
        guard let app = result else {
            throw DaemonError("internal", "launch \(bundle) timed out")
        }
        return app
    }

    /// Background launch preserving the user's frontmost app.
    static func launchWithFrontmostPreserved(bundle: String) throws -> NSRunningApplication {
        try EventDispatch.withFocusPreserved(style: .preserved) {
            try launchApp(bundle: bundle, activates: false)
        }
    }

    /// Poll until the app exposes an AX window tree (or budget spent).
    @discardableResult
    static func waitUntilReady(pid: pid_t, maxAttempts: Int = 40,
                               interval: TimeInterval = 0.1)
        -> (Int, Double, Bool)
    {
        let app = AXUIElementCreateApplication(pid)
        let t0 = Date()
        var attempts = 0
        while attempts < maxAttempts {
            attempts += 1
            if !copyElements(app, kAXWindowsAttribute).isEmpty
                || !copyElements(app, "AXChildren").isEmpty {
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
    /// un-minimize animation; true only when an unminimize occurred.
    @discardableResult
    static func unminimizeIfNeeded(_ window: AXUIElement) -> Bool {
        guard copyBool(window, "AXMinimized") == true else { return false }
        AXUIElementSetAttributeValue(window, "AXMinimized" as CFString,
                                   false as CFTypeRef)
        usleep(200_000)
        return true
    }

    // MARK: snapshot

    /// Enhanced-UI assertion [SNAP §12.1]: save AXEnhancedUserInterface +
    /// AXManualAccessibility, set both true, restore on exit. Write failures
    /// are not errors.
    private final class EnhancedUIAssertion {
        let app: AXUIElement
        var savedEnhanced: Bool?
        var savedManual: Bool?
        init(pid: pid_t) {
            app = AXUIElementCreateApplication(pid)
            savedEnhanced = AXBridge.copyBool(app, "AXEnhancedUserInterface")
            savedManual = AXBridge.copyBool(app, "AXManualAccessibility")
            AXUIElementSetAttributeValue(app,
                "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
            AXUIElementSetAttributeValue(app,
                "AXManualAccessibility" as CFString, true as CFTypeRef)
        }
        func restore() {
            if let v = savedEnhanced {
                AXUIElementSetAttributeValue(app,
                    "AXEnhancedUserInterface" as CFString, v as CFTypeRef)
            }
            if let v = savedManual {
                AXUIElementSetAttributeValue(app,
                    "AXManualAccessibility" as CFString, v as CFTypeRef)
            }
        }
    }

    /// Snapshot window selection [SNAP §3]: explicit window_id match → first
    /// focused (AXFocusedWindow / AXMain) → windows[0]. No match is NOT an
    /// error — falls through to focused/first.
    private static func chooseWindow(_ wins: [AXUIElement],
                                     requested: CGWindowID?) -> AXUIElement? {
        if let requested {
            for w in wins where windowIDNumber(of: w) == requested { return w }
        }
        let app = wins.first
        for w in wins {
            if copyBool(w, kAXFocusedAttribute) == true
                || copyBool(w, kAXMainAttribute) == true { return w }
        }
        _ = app
        return wins.first
    }

    /// Wakeup sleep schedule — raw doubles at 0x10008f088.
    private static let wakeupSchedule: [TimeInterval] = [0.15, 0.25, 0.4]

    /// Depth-limited preorder DFS serialization.
    /// - depth counts AXChildren levels below the window; depth=0 still
    ///   emits the root; negative also processes current node.
    /// - Filtered parents do NOT stop child traversal.
    /// - interactiveOnly keeps elements with actions ∪ 16-role set.
    /// - No 200-node cap here — that cap is only in descriptor recovery.
    /// - ancestors CFEqual guard + hard cap stop mirror-tree self-cycles.
    static func snapshot(
        pid: pid_t,
        windowId: CGWindowID? = nil,
        depth: Int = 6,
        interactiveOnly: Bool = true,
        wakeupSeconds: TimeInterval,
        snapshotId: String,
        store: ElementStore
    ) -> SnapshotResult {
        store.beginSnapshot(snapshotId)
        let assertion = EnhancedUIAssertion(pid: pid)
        defer { assertion.restore() }

        let deadline = Date().addingTimeInterval(wakeupSeconds)
        var attempts = 0
        var wakeupMs = 0
        var elements: [SerializedElement] = []
        var wins: [AXUIElement] = []
        var windowEl: AXUIElement?

        while true {
            attempts += 1
            wins = windows(of: pid)
            windowEl = chooseWindow(wins, requested: windowId)
            elements.removeAll()
            if let root = windowEl {
                walk(el: root, depthLeft: depth, parentRoles: [],
                     ancestors: [root], pid: pid, snapshotId: snapshotId,
                     out: &elements, store: store,
                     interactiveOnly: interactiveOnly)
            }
            if elements.count > 1 { break }
            // retry: budget = supplied wakeup_seconds, sleeps from schedule
            if attempts - 1 >= wakeupSchedule.count { break }
            let remain = deadline.timeIntervalSinceNow
            guard remain > 0 else { break }
            let sleep = min(wakeupSchedule[attempts - 1], max(0, remain))
            if sleep > 0 {
                let t0 = DispatchTime.now().uptimeNanoseconds
                usleep(UInt32(sleep * 1_000_000))
                wakeupMs += Int((DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000)
            }
            // re-enable enhanced UI on each retry (per disasm)
            AXUIElementSetAttributeValue(assertion.app,
                "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
            AXUIElementSetAttributeValue(assertion.app,
                "AXManualAccessibility" as CFString, true as CFTypeRef)
        }

        let axStatus: String
        if elements.count > 1 {
            axStatus = attempts == 1 ? "populated" : "woke_up"
        } else {
            axStatus = wakeupSeconds <= 0 ? "no_wakeup_budget" : "empty_after_wakeup"
        }

        var resolvedWid: CGWindowID?
        var windowTitle: String?
        var windowBounds: CGRect?
        if let w = windowEl {
            resolvedWid = windowIDNumber(of: w)
            windowTitle = copyString(w, kAXTitleAttribute)
            windowBounds = axBounds(w)
        } else if let meta = WindowList.topWindow(pid: pid) {
            // CG metadata fallback: fills window identity only; AX output
            // stays empty.
            resolvedWid = meta.wid
            windowTitle = meta.title
            windowBounds = meta.bounds
        }

        let app = runningApp(pid: pid)
        return SnapshotResult(
            snapshotId: snapshotId, elements: elements,
            windowId: resolvedWid, windowElement: windowEl,
            windowBounds: windowBounds,
            windowTitle: windowTitle,
            bundle: app?.bundleIdentifier,
            appName: app?.localizedName,
            pid: pid, axStatus: axStatus,
            wakeupAttempts: attempts, wakeupDurationMs: wakeupMs
        )
    }

    /// Hard cap against combinatorial mirror trees (Calculator's AXWindows
    /// self-loop family); not Alma's snapshot cap — a safety bound only.
    static let maxSerializedElements = 4000

    private static func walk(
        el ax: AXUIElement, depthLeft: Int,
        parentRoles: [String], ancestors: [AXUIElement],
        pid: pid_t, snapshotId: String,
        out: inout [SerializedElement],
        store: ElementStore, interactiveOnly: Bool
    ) {
        if out.count >= maxSerializedElements { return }
        var el = serialize(ax, ref: "", parentRoles: parentRoles)
        let roles = parentRoles + [el.role]
        if !interactiveOnly || isInteractive(el) {
            el.ref = store.register(ax, snapshotId: snapshotId, pid: pid,
                                    descriptor: el.descriptor)
            out.append(el)
        }
        guard depthLeft > 0 else { return }
        for child in copyElements(ax, kAXChildrenAttribute) {
            if ancestors.contains(where: { CFEqual($0, child) }) { continue }
            walk(el: child, depthLeft: depthLeft - 1, parentRoles: roles,
                 ancestors: ancestors + [child], pid: pid,
                 snapshotId: snapshotId, out: &out,
                 store: store, interactiveOnly: interactiveOnly)
            if out.count >= maxSerializedElements { return }
        }
    }

    static func windowIDNumber(of window: AXUIElement) -> CGWindowID? {
        var wid = CGWindowID(0)
        if _AXUIElementGetWindow(window, &wid) == .success && wid != 0 {
            return wid
        }
        return nil
    }
}

// _AXUIElementGetWindow — private-but-stable AX SPI Alma uses for
// AXUIElement → CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement,
                           _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

// MARK: - WindowList (CG metadata fallback / top window)

extension WindowList {
    struct TopWindow { var wid: CGWindowID; var title: String?; var bounds: CGRect? }
    /// First on-screen CG window for pid (front-to-back order).
    static func topWindow(pid: pid_t) -> TopWindow? {
        for entry in windows(pid: pid) {
            if let wid = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value {
                var bounds: CGRect?
                if let b = entry[kCGWindowBounds as String] as? [String: Any] {
                    bounds = CGRect(
                        x: b["X"] as? Double ?? 0, y: b["Y"] as? Double ?? 0,
                        width: b["Width"] as? Double ?? 0,
                        height: b["Height"] as? Double ?? 0)
                }
                return TopWindow(wid: wid,
                    title: entry[kCGWindowName as String] as? String,
                    bounds: bounds)
            }
        }
        return nil
    }
}

// MARK: - ForbiddenTargets (verbatim .164 contract)
// isForbidden: exact Set<String>.contains, 18 entries, no case folding.
// PID variant message: "target app <bundle> is on the CUA blocklist for
//   user-safety reasons" + long hint.
// Bundle variant: "target bundle <bundle> is on the CUA blocklist for
//   user-safety reasons" + "Pass `force_forbidden: true` to override."

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
        "com.apple.tccd",
        "com.apple.universalaccessAuthWarn",
        "com.apple.WindowServer",
        "com.apple.dock",
        "com.apple.launchpad",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.apple.spotlight",
        "com.apple.ScreenSaver.Engine",
        "com.apple.ScreenSaverEngine",
    ]

    static func isForbidden(_ bundleId: String?) -> Bool {
        guard let b = bundleId else { return false }
        return blocklist.contains(b)
    }

    private static let pidHint =
        "Pass `force_forbidden: true` to override. Only do this for flows " +
        "that genuinely require interacting with the system-privacy UI " +
        "(e.g. guiding the user through an Accessibility permission grant)."

    /// PID gate [0x1000322bc]: no pid → pass; unresolvable app → pass;
    /// unbundled app → pass.
    static func check(pid: pid_t?, allowOverride: Bool) throws {
        if allowOverride { return }
        guard let pid else { return }
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        guard let bundle = app.bundleIdentifier else { return }
        guard blocklist.contains(bundle) else { return }
        throw DaemonError("forbidden_target",
            "target app \(bundle) is on the CUA blocklist for user-safety reasons",
            hint: pidHint)
    }

    /// Bundle gate [0x10003249c]: used by intent/open_url only.
    static func check(bundleId: String?, allowOverride: Bool) throws {
        if allowOverride { return }
        guard let b = bundleId, blocklist.contains(b) else { return }
        throw DaemonError("forbidden_target",
            "target bundle \(b) is on the CUA blocklist for user-safety reasons",
            hint: "Pass `force_forbidden: true` to override.")
    }
}
