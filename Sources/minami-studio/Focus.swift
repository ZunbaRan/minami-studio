import AppKit
import ApplicationServices
import Foundation

// Focus-safety subsystem — rebuilt to the verified disassembly contract
// [ALGORITHMS §6]:
//
//   withFocusPreserved:
//     oldFront = NSWorkspace.frontmostApplication?.pid ?? 0
//     preservingOther = (style == .preserved && oldFront > 0
//                        && oldFront != targetPid)
//     preventer.begin()               // CGEventTap arm
//     globalDisallowed.insert(targetPid)
//     victimObserver(targetPid).begin()
//     if preservingOther:
//         globalOnlyAllow = oldFront
//         frontmostWatcher(oldFront).begin()
//     RunLoop.main.run(until: now + 0.001)
//     try body()
//     defer: if !activating && frontmost == oldFront
//            → makeWindowKeyWithoutActivating(oldFront)   // immediate
//     DispatchQueue.main.asyncAfter(+5.0):
//         if frontmost == oldFront
//            → makeWindowKeyWithoutActivating(oldFront)   // +5s repair
//         setOnlyAllow(nil); removeDisallowed(target)
//         preventer.end(); watcher?.end(); victimObserver.end()
//
//   CGEventTap (ALGORITHMS §6.2):
//     tapCreate(location=annotatedSession(2), placement=headInsert(0),
//               options=defaultTap(0), mask=0x6000)  — types 13/14 only
//     callback:
//       - tapDisabledByTimeout/UserInput → re-enable + count + stderr log
//       - field 0x2a == ALMANOFL sentinel → pass
//       - NSEvent(ev): type==13 → target=data1;
//         type==14 && subtype==8 → target=data1; else pass
//       - shouldDrop(target): temporaryAllowance unexpired → false;
//         target∈disallowed → true; onlyAllow set && != → true
//       - drop → nil, else event
//     Arm failure → armFailures += 1 + FATAL stderr (no process exit).
//
//   VictimObserver: running apps whose bundle id = targetBundle + "."
//   suffix, lowercased suffix containing helper/xpc/service markers →
//   those helper pids join `disallowed`; end() removes them.
//
//   makeWindowKeyWithoutActivating: GetProcessForPID +
//   SetFrontProcessWithOptions(option 1) — NOT NSRunningApplication
//   activate.

// MARK: - private Carbon SPI

@_silgen_name("GetProcessForPID")
private func GetProcessForPID(_ pid: Int32,
                              _ psn: UnsafeMutablePointer<ProcessSerialNumber>)
    -> OSStatus

@_silgen_name("SetFrontProcessWithOptions")
private func SetFrontProcessWithOptions(
    _ psn: UnsafePointer<ProcessSerialNumber>,
    _ options: UInt32) -> OSStatus

/// [ALGORITHMS] option1 — re-key the process's front window without the
/// activation semantics of a full front-process switch.
func makeWindowKeyWithoutActivating(pid: pid_t) -> Bool {
    var psn = ProcessSerialNumber()
    guard GetProcessForPID(pid, &psn) == noErr else { return false }
    return SetFrontProcessWithOptions(&psn, 1) == noErr
}

/// Namespace for the input-dispatch surface (extended in Input.swift).
enum EventDispatch {}

enum PreventerStyle {
    case preserved   // keep user's frontmost
    case activating  // allow the target to activate
}

// MARK: - FocusStealPreventer (CGEventTap + NSWorkspace repair)

final class FocusStealPreventer {
    static let shared = FocusStealPreventer()

    private(set) var armed = false
    private(set) var armFailures = 0
    private(set) var tapDisablesRecovered = 0

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var disallowed = Set<pid_t>()
    private var onlyAllow: pid_t?
    /// temporaryAllowance[target] → expiry; an unexpired entry defeats
    /// shouldDrop entirely [ALGORITHMS §6.2].
    private var temporaryAllowance: [pid_t: Date] = [:]
    private var observer: NSObjectProtocol?
    private let lock = NSLock()

    private init() {}

    // MARK: tap callback contract

    /// shouldDrop — locked read of the three gates.
    func shouldDrop(target: pid_t) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let exp = temporaryAllowance[target], exp > Date() {
            return false
        }
        if disallowed.contains(target) { return true }
        if let only = onlyAllow, only != target { return true }
        return false
    }

    func noteTapDisabled() {
        lock.lock(); tapDisablesRecovered += 1; lock.unlock()
    }

    // MARK: arm/disarm

    /// Arm the session-level event tap once. A nil tapCreate result
    /// counts an arm failure and writes the FATAL line — actions still
    /// proceed without protection (Alma does not exit).
    func begin() {
        lock.lock()
        if armed { lock.unlock(); return }
        armed = true
        lock.unlock()

        // NSEvent type 13/14 only — mask bits 13|14.
        let mask = CGEventMask((1 << 13) | (1 << 14))
        guard let tap = CGEvent.tapCreate(
                tap: CGEventTapLocation(
                    rawValue: 2)!, // kCGAnnotatedSessionEventTap
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: focusTapCallback,
                userInfo: nil)
        else {
            lock.lock(); armFailures += 1; armed = false; lock.unlock()
            FileHandle.standardError.write(Data((
                "[alma-cu] FATAL: focus-steal prevention could NOT be "
                + "armed (CGEvent.tapCreate returned nil). Actions will "
                + "steal the user's focus. Check Accessibility permission "
                + "for this helper binary.\n").utf8))
            return
        }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        lock.lock()
        self.tap = tap; self.tapSource = src
        lock.unlock()
        // The tap's runloop source lives on the MAIN runloop (NSApp).
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // NSWorkspace watcher — repairs the allowed app's key window when
        // a disallowed/non-allowed app activates despite the tap.
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[
                      NSWorkspace.applicationUserInfoKey]
                      as? NSRunningApplication
            else { return }
            let pid = app.processIdentifier
            if self.shouldDrop(target: pid),
               let cur = self.onlyAllow {
                _ = makeWindowKeyWithoutActivating(pid: cur)
            }
        }
    }

    /// Drop the tap + source + watcher. Called from the +5s teardown of
    /// every protected action — overlapping actions are NOT refcounted
    /// (contract: refcount isolation unproven).
    func end() {
        lock.lock()
        let t = tap, src = tapSource
        tap = nil; tapSource = nil
        armed = false
        let obs = observer; observer = nil
        lock.unlock()
        if let t { CGEvent.tapEnable(tap: t, enable: false) }
        if let src {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        if let obs { NSWorkspace.shared.notificationCenter
            .removeObserver(obs) }
    }

    // MARK: gates

    func disallow(_ pid: pid_t?) {
        guard let pid else { return }
        lock.lock(); disallowed.insert(pid); lock.unlock()
    }
    func removeDisallowed(_ pid: pid_t) {
        lock.lock(); disallowed.remove(pid); lock.unlock()
    }
    func setOnlyAllow(_ pid: pid_t?) {
        lock.lock(); onlyAllow = pid; lock.unlock()
    }
    var onlyAllowedPid: pid_t? {
        lock.lock(); defer { lock.unlock() }; return onlyAllow
    }
    func allowTemporarily(_ pid: pid_t, for seconds: TimeInterval) {
        lock.lock()
        temporaryAllowance[pid] = Date().addingTimeInterval(seconds)
        lock.unlock()
    }
}

// MARK: - tap callback (C-convention, no captures)

/// [ALGORITHMS §6.2] verbatim flow:
///   disabled → re-enable + log; sentinel → pass; type13 → data1;
///   type14 && subtype8 → data1; else pass; shouldDrop → nil.
private func focusTapCallback(proxy: CGEventTapProxy,
                              type: CGEventType,
                              event: CGEvent,
                              refcon: UnsafeMutableRawPointer?)
    -> Unmanaged<CGEvent>? {
    let p = FocusStealPreventer.shared
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = p.currentTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        p.noteTapDisabled()
        let why = type == .tapDisabledByTimeout ? "timeout" : "user input"
        FileHandle.standardError.write(Data(
            "[alma-cu] CGEventTap disabled (\(why)) — re-enabled\n".utf8))
        return nil
    }
    // sentinel-tagged daemon events pass unconditionally
    if event.getIntegerValueField(CGEventField(rawValue: 0x2a)!)
        == 0x414c4d414e4f464c {
        return Unmanaged.passRetained(event)
    }
    guard let ns = NSEvent(cgEvent: event) else {
        return Unmanaged.passRetained(event)
    }
    let target: pid_t?
    switch ns.type.rawValue {
    case 13:
        target = pid_t(truncatingIfNeeded: ns.data1)
    case 14 where ns.subtype.rawValue == 8:
        target = pid_t(truncatingIfNeeded: ns.data1)
    default:
        target = nil
    }
    if let target, p.shouldDrop(target: target) {
        return nil
    }
    return Unmanaged.passRetained(event)
}

private extension FocusStealPreventer {
    var currentTap: CFMachPort? {
        lock.lock(); defer { lock.unlock() }; return tap
    }
}

// MARK: - VictimObserver (helper-pid disallowed set)

/// Scans runningApplications for the target's helper siblings:
/// bundle == targetBundle || bundle.hasPrefix(targetBundle + ".")
/// where the suffix lowercased contains helper/xpc/service markers.
/// Matching helper pids are added to the preventer's disallowed set and
/// removed on end().
final class VictimObserver {
    private let added: [pid_t]

    init(targetPid: pid_t) {
        guard let targetBundle = NSRunningApplication(
                processIdentifier: targetPid)?.bundleIdentifier
        else { added = []; return }
        var hits: [pid_t] = []
        for app in NSWorkspace.shared.runningApplications {
            guard let b = app.bundleIdentifier,
                  b != targetBundle,
                  b.hasPrefix(targetBundle + ".")
            else { continue }
            let suffix = String(b.dropFirst(targetBundle.count))
            guard suffix.hasPrefix(".") else { continue }
            let s = suffix.lowercased()
            if s.contains("helper") || s.contains("xpc")
               || s.contains("service") {
                hits.append(app.processIdentifier)
            }
        }
        added = hits
    }

    func begin() {
        for pid in added { FocusStealPreventer.shared.disallow(pid) }
    }
    func end() {
        for pid in added {
            FocusStealPreventer.shared.removeDisallowed(pid)
        }
    }
}

// MARK: - PreserveFrontmostWatcher

/// While the user stays on another app, an activation of the target (or
/// any non-allowed app slipping past the tap) re-keys oldFront's window.
final class PreserveFrontmostWatcher {
    private let oldFront: pid_t
    private var obs: NSObjectProtocol?

    init(oldFront: pid_t) { self.oldFront = oldFront }

    func begin() {
        obs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[
                      NSWorkspace.applicationUserInfoKey]
                      as? NSRunningApplication
            else { return }
            if app.processIdentifier != self.oldFront {
                _ = makeWindowKeyWithoutActivating(pid: self.oldFront)
            }
        }
    }
    func end() {
        if let obs { NSWorkspace.shared.notificationCenter
            .removeObserver(obs) }
        obs = nil
    }
}

// MARK: - withFocusPreserved

extension EventDispatch {

    /// [ALGORITHMS §6.1] full protected-action wrapper. `pid` is the
    /// action target; nil pid skips the victim/disallow wiring (the
    /// preventer still arms). The defer runs on BOTH paths — +5s cleanup
    /// is scheduled before the response reaches the wire.
    static func withFocusPreserved<T>(
        style: PreventerStyle = .preserved,
        pid: pid_t? = nil,
        _ body: () throws -> T
    ) throws -> T {
        let preventer = FocusStealPreventer.shared
        let targetPid = pid ?? 0
        let oldFront = NSWorkspace.shared.frontmostApplication?
            .processIdentifier ?? 0
        let preservingOther = style == .preserved
            && oldFront > 0 && oldFront != targetPid

        preventer.begin()
        preventer.disallow(pid)
        let victim = VictimObserver(targetPid: targetPid)
        victim.begin()
        let watcher: PreserveFrontmostWatcher?
        if preservingOther {
            preventer.setOnlyAllow(oldFront)
            let w = PreserveFrontmostWatcher(oldFront: oldFront)
            w.begin()
            watcher = w
        } else {
            watcher = nil
        }
        // Pump the main runloop ~1ms so the just-installed taps/watchers
        // observe any already-in-flight activation events.
        RunLoop.main.run(until: Date().addingTimeInterval(0.001))

        defer {
            // immediate conditional repair (both paths): the user's app
            // still frontmost → re-key its window (victim re-key).
            if style == .preserved, oldFront > 0,
               NSWorkspace.shared.frontmostApplication?
                   .processIdentifier == oldFront {
                _ = makeWindowKeyWithoutActivating(pid: oldFront)
            }
            // +5s teardown — identical repair check, then unwinding in
            // Alma's order: onlyAllow → disallowed → preventer → watcher
            // → victimObserver.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if oldFront > 0,
                   NSWorkspace.shared.frontmostApplication?
                       .processIdentifier == oldFront {
                    _ = makeWindowKeyWithoutActivating(pid: oldFront)
                }
                preventer.setOnlyAllow(nil)
                preventer.removeDisallowed(targetPid)
                preventer.end()
                watcher?.end()
                victim.end()
            }
        }
        return try body()
    }
}
