import AppKit
import ApplicationServices
import Foundation

// Focus-safety subsystem.
// Verified .153 semantics (code-evidence/native/focus-guard.md, disasm L29172+):
//   withFocusPreserved body → RunLoop.main pump (~1ms) → defer restores the
//   target's key window WITHOUT activating → DispatchQueue.main
//   .asyncAfter(.now()+5.0) tears down the preventer (setOnlyAllow on the
//   current frontmost pid, removeDisallowed(target), end()).
// Mechanism notes: input is delivered via CGEventPostToPid so the target never
// needs the foreground; the preventer additionally watches frontmost-app
// transitions and re-keys the user's window if the target pops forward.

enum PreventerStyle {
    case preserved   // keep user's frontmost
    case activating  // allow the target to activate (explicit user-facing paths)
}

final class FocusStealPreventer {
    static let shared = FocusStealPreventer()

    private(set) var armed = false
    private(set) var armFailures = 0
    private var disallowed = Set<pid_t>()
    private var onlyAllow: pid_t?
    private var observer: NSObjectProtocol?
    private let lock = NSLock()

    private init() {}

    /// Arm the frontmost-app watcher. If a disallowed pid activates, the user's
    /// key window is restored without activating that app.
    func begin() {
        lock.lock()
        if armed { lock.unlock(); return }
        armed = true
        lock.unlock()

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self.lock.lock()
            let blocked = self.disallowed.contains(app.processIdentifier)
                || (self.onlyAllow != nil && self.onlyAllow != app.processIdentifier)
            self.lock.unlock()
            if blocked {
                // Victim re-key: return the key window to the currently
                // frontmost allowed app without activating anything.
                if let cur = self.onlyAllow {
                    FocusStealPreventer.makeWindowKeyWithoutActivating(pid: cur)
                }
            }
        }
    }

    func disallow(_ pid: pid_t) {
        lock.lock(); disallowed.insert(pid); lock.unlock()
    }
    func setOnlyAllow(_ pid: pid_t?) {
        lock.lock(); onlyAllow = pid; lock.unlock()
    }
    func removeDisallowed(_ pid: pid_t) {
        lock.lock(); disallowed.remove(pid); lock.unlock()
    }

    func end() {
        lock.lock()
        armed = false
        disallowed.removeAll()
        onlyAllow = nil
        let obs = observer
        observer = nil
        lock.unlock()
        if let obs { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
    }

    func noteArmFailure() {
        lock.lock(); armFailures += 1; lock.unlock()
    }

    var status: JSONDict {
        lock.lock(); defer { lock.unlock() }
        return ["armed": armed, "arm_failures": armFailures]
    }

    /// Re-key the app's front window without activating it (AXMain write;
    /// the disassembly path uses an equivalent private key-window call —
    /// behavioral contract identical: window becomes key, app stays background).
    static func makeWindowKeyWithoutActivating(pid: pid_t) {
        let appEl = AXUIElementCreateApplication(pid)
        guard let win = AXBridge.copyElements(appEl, kAXWindowsAttribute).first else { return }
        AXUIElementSetAttributeValue(win, "AXMain" as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(win, kAXFocusedAttribute as CFString, true as CFTypeRef)
    }
}

enum EventDispatch {

    /// withFocusPreserved — verified flow:
    ///   begin preventer (disallow target pid if style preserved)
    ///   try body()
    ///   RunLoop.main.run(until: now + ~1ms)          // let AX/UI settle
    ///   defer: makeWindowKeyWithoutActivating(pid)   // re-key target, no activate
    ///   DispatchQueue.main.asyncAfter(.now()+5.0) {  // 5s focus tail
    ///       setOnlyAllow(currentFrontmost); removeDisallowed(pid); end()
    ///   }
    @discardableResult
    static func withFocusPreserved<T>(style: PreventerStyle = .preserved, pid: pid_t? = nil, _ body: () throws -> T) throws -> T {
        let preventer = FocusStealPreventer.shared
        preventer.begin()
        if style == .preserved, let pid {
            preventer.disallow(pid)
        }

        var result: Result<T, Error>!
        defer {
            // Inner defer (executes at scope exit, before asyncAfter schedule):
            // restore the target's key window if it lost key status.
            if let pid {
                FocusStealPreventer.makeWindowKeyWithoutActivating(pid: pid)
            }
            // 5-second delayed teardown on main queue — the "focus tail".
            // Gives the target's app-switch machinery time to settle before
            // the preventer window closes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                let cur = NSWorkspace.shared.frontmostApplication?.processIdentifier
                preventer.setOnlyAllow(cur)
                if let pid { preventer.removeDisallowed(pid) }
                preventer.end()
            }
        }

        do { result = .success(try body()) }
        catch { result = .failure(error) }

        // 1ms runloop pump so pending AX/event work settles before teardown.
        RunLoop.main.run(until: Date().addingTimeInterval(0.001))

        switch result! {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }
}
