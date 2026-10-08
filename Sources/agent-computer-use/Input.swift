import AppKit
import Carbon
import CoreGraphics
import Foundation

// Input dispatch — rebuilt to the .153 disassembly semantics:
//   KeyParser (verbatim named/ansi tables, chord syntax, error literals),
//   KeyboardLayoutTranslator (UCKeyTranslate reverse lookup, 4 mod-state
//   table), NSEvent→CGEvent pointer minting (windowNumber, eventNumber,
//   clickCount, pressure + fields 3/7/0x5b/0x5c + SetWindowLocation +
//   sentinel 0x2a), SynthPost dlopen path with postToPid fallback,
//   pressKey key_window/active_app/menu_ax_press/suppressed delivery,
//   typeText auto/physical/unicode + focused-AX insert, TypeVerification.

// MARK: - private SPI (Alma resolves these via dlopen too)

private enum SynthPost {
    typealias Fn = @convention(c) (Int32, CGEvent) -> Void
    static let fn: Fn? = {
        guard let h = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) else { return nil }
        guard let sym = dlsym(h, "CGEventPostToPid") else { return nil }
        return unsafeBitCast(sym, to: Fn.self)
    }()
    static func post(pid: pid_t, _ ev: CGEvent) {
        if let fn { fn(pid, ev) } else { ev.postToPid(pid) }
    }
}

private enum SetWindowLocation {
    typealias Fn = @convention(c) (CGEvent, CGPoint) -> Void
    static let fn: Fn? = {
        guard let h = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) else { return nil }
        guard let sym = dlsym(h, "CGEventSetWindowLocation") else { return nil }
        return unsafeBitCast(sym, to: Fn.self)
    }()
}

/// Sentinel marker written to field 0x2a on every synthesized event so Alma's
/// own tap/observer layers can recognize daemon-originated input.
private func tagSentinel(_ ev: CGEvent) {
    ev.setIntegerValueField(CGEventField(rawValue: 0x2a)!, value: 1)
}

// MARK: - KeyParser — verbatim tables
// modifiers: all "+"-separated parts EXCEPT the last, lowercased.
// named dict is consulted BEFORE the ansi single-char table.

enum KeyParser {
    struct Parsed { let keyCode: UInt16; let flags: CGEventFlags }

    /// DECODED VERBATIM (56 entries)
    static let named: [String: UInt16] = [
        "return": 0x24, "enter": 0x24, "tab": 0x30, "space": 0x31,
        "delete": 0x33, "backspace": 0x33, "forwarddelete": 0x75,
        "forward_delete": 0x75, "del": 0x75, "escape": 0x35, "esc": 0x35,
        "capslock": 0x39,
        "left": 0x7b, "right": 0x7c, "down": 0x7d, "up": 0x7e,
        "home": 0x73, "end": 0x77, "pageup": 0x74, "page_up": 0x74,
        "pagedown": 0x79, "page_down": 0x79, "help": 0x72, "clear": 0x47,
        "f1": 0x7a, "f2": 0x78, "f3": 0x63, "f4": 0x76, "f5": 0x60,
        "f6": 0x61, "f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6d,
        "f11": 0x67, "f12": 0x6f, "f13": 0x69, "f14": 0x6b, "f15": 0x71,
        "kp_0": 0x52, "kp_1": 0x53, "kp_2": 0x54, "kp_3": 0x55,
        "kp_4": 0x56, "kp_5": 0x57, "kp_6": 0x58, "kp_7": 0x59,
        "kp_8": 0x5b, "kp_9": 0x5c,
        "kp_enter": 0x4c, "kp_plus": 0x45, "kp_minus": 0x4e,
        "kp_multiply": 0x43, "kp_divide": 0x4b, "kp_decimal": 0x41,
        "kp_equals": 0x51,
    ]

    /// DECODED VERBATIM (48 entries) — ANSI/US layout
    static let ansi: [Character: UInt16] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0b, "q": 0x0c,
        "w": 0x0d, "e": 0x0e, "r": 0x0f, "y": 0x10, "t": 0x11, "1": 0x12,
        "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
        "9": 0x19, "7": 0x1a, "-": 0x1b, "8": 0x1c, "0": 0x1d, "]": 0x1e,
        "o": 0x1f, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25,
        "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29, "\\": 0x2a, ",": 0x2b,
        "/": 0x2c, "n": 0x2d, "m": 0x2e, ".": 0x2f, "`": 0x32, " ": 0x31,
    ]

    /// parts = split("+", omitting empties); modifiers = dropLast lowercased;
    /// key = last lowercased; named first, then single-char ansi.
    static func parse(_ s: String) throws -> Parsed {
        var flags = CGEventFlags()
        let parts = s.split(separator: "+", omittingEmptySubsequences: true)
        guard !parts.isEmpty else {
            throw DaemonError("invalid_arg", "empty key combo \"\(s)\"")
        }
        for tok in parts.dropLast() {
            switch tok.lowercased() {
            case "cmd", "command", "meta", "super": flags.insert(.maskCommand)
            case "ctrl", "control": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            case "alt", "option": flags.insert(.maskAlternate)
            case "fn", "function": flags.insert(.maskSecondaryFn)
            default:
                throw DaemonError("invalid_arg",
                    "unknown modifier \"\(tok)\" in \"\(s)\"")
            }
        }
        let key = String(parts.last!).lowercased()
        if let kc = named[key] { return Parsed(keyCode: kc, flags: flags) }
        if key.count == 1, let ch = key.first, let kc = ansi[ch] {
            return Parsed(keyCode: kc, flags: flags)
        }
        throw DaemonError("invalid_arg", "unknown key \"\(key)\" in \"\(s)\"")
    }
}

// MARK: - KeyboardLayoutTranslator (UCKeyTranslate reverse lookup)
// states table @0x10008ce10: (flags, modifierKeyState) = (0,0),
// (shift,2), (alt,8), (shift|alt,10). UCKeyTranslate action=3, buf len 8.

enum KeyboardLayoutTranslator {
    struct KeyPress { let keyCode: UInt16; let flags: CGEventFlags }

    private static let states: [(CGEventFlags, UInt32)] = [
        ([], 0),
        (.maskShift, 2),
        (.maskAlternate, 8),
        ([.maskShift, .maskAlternate], 10),
    ]

    static func keyPresses(for text: String) throws -> [KeyPress] {
        guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            throw DaemonError("internal", "Unable to get current keyboard layout.")
        }
        guard let raw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else {
            throw DaemonError("internal", "Unable to get keyboard layout data.")
        }
        let data = unsafeBitCast(raw, to: CFData.self)
        guard let uchr = CFDataGetBytePtr(data) else {
            throw DaemonError("internal", "Unable to get keyboard layout pointer.")
        }
        var out: [KeyPress] = []
        for ch in text {
            switch ch.unicodeScalars.first?.value {
            case 0x0a, 0x0d:
                out.append(KeyPress(keyCode: 0x24, flags: []))
            case 0x09:
                out.append(KeyPress(keyCode: 0x30, flags: []))
            default:
                guard let kp = reverseLookup(ch, uchr: uchr) else {
                    throw DaemonError("action_unsupported",
                        "type_text physical key translation for \"\(ch)\"")
                }
                out.append(kp)
            }
        }
        return out
    }

    /// Optional variant used by the auto predicate — `try?` on the throwing
    /// version is the Alma auto gate verbatim.
    static func canMap(_ text: String) -> Bool {
        (try? keyPresses(for: text)) != nil
    }

    private static func reverseLookup(_ ch: Character,
                                      uchr: UnsafePointer<UInt8>) -> KeyPress? {
        let layout = unsafeBitCast(uchr, to: UnsafePointer<UCKeyboardLayout>.self)
        let kbd = UInt32(LMGetKbdType())
        for kc in UInt16(0)..<UInt16(0x80) {
            for (flags, modState) in states {
                var dead: UInt32 = 0
                var buf = [UniChar](repeating: 0, count: 8)
                var len = 0
                let rc = UCKeyTranslate(layout, kc,
                    UInt16(kUCKeyActionDisplay), modState, kbd,
                    OptionBits(kUCKeyTranslateNoDeadKeysMask),
                    &dead, 8, &len, &buf)
                guard rc == noErr, len >= 1 else { continue }
                if String(utf16CodeUnits: buf, count: len) == String(ch) {
                    return KeyPress(keyCode: kc, flags: flags)
                }
            }
        }
        return nil
    }
}

// MARK: - MenuShortcuts (press_key AX-menu fallback + menu_shortcuts wire)

enum MenuShortcuts {
    /// Walk the app's menubar collecting (chord → element) pairs.
    static func collect(pid: pid_t, max: Int = 200) -> [(chord: String, el: AXUIElement)] {
        let app = AXUIElementCreateApplication(pid)
        var out: [(String, AXUIElement)] = []
        var barValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXMenuBar" as CFString, &barValue) == .success,
              let bar = barValue, CFGetTypeID(bar) == AXUIElementGetTypeID() else { return out }
        let menuBar = unsafeDowncast(bar, to: AXUIElement.self)
        func visit(_ el: AXUIElement) {
            if out.count >= max { return }
            if let cmd = AXBridge.copyString(el, kAXMenuItemCmdCharAttribute),
               !cmd.isEmpty {
                let mods = AXBridge.copyString(el, kAXMenuItemCmdModifiersAttribute) ?? ""
                out.append((chordString(char: cmd, modifiers: mods), el))
            }
            for child in AXBridge.copyElements(el, kAXChildrenAttribute) { visit(child) }
        }
        for child in AXBridge.copyElements(menuBar, kAXChildrenAttribute) { visit(child) }
        return out
    }

    /// AX shortcut modifiers → chord string in press_key syntax.
    static func chordString(char: String, modifiers: String) -> String {
        var parts: [String] = []
        if modifiers.contains("@") || modifiers.contains("0") { parts.append("cmd") }
        if modifiers.contains("^") || modifiers.contains("2") { parts.append("ctrl") }
        if modifiers.contains("~") || modifiers.contains("1") { parts.append("opt") }
        if modifiers.contains("$") || modifiers.contains("S") { parts.append("shift") }
        parts.append(glyphToKeyName(char))
        return parts.joined(separator: "+")
    }

    static func glyphToKeyName(_ char: String) -> String {
        switch char {
        case "\u{1B}", "⎋": return "esc"
        case "\t", "⇥": return "tab"
        case "\r", "\n", "↩", "⏎": return "return"
        case "\u{7F}", "⌫": return "delete"
        case " ", "␣": return "space"
        case "←": return "left"; case "→": return "right"
        case "↑": return "up"; case "↓": return "down"
        case "⇞": return "pageup"; case "⇟": return "pagedown"
        case "↖": return "home"; case "↘": return "end"
        default: return char.lowercased()
        }
    }

    /// [DISASM] iterate enabled menu items; match on parsed keyCode equality
    /// and modifier-flags equality masked to 0x1e0000 (cmd|ctrl|opt|shift).
    /// The FIRST matching item is AXPress'ed — a failed perform yields
    /// `suppressed` immediately (no second-match retry).
    static func matchAndPress(pid: pid_t, key: String) -> Bool? {
        guard let wanted = try? KeyParser.parse(key) else { return nil }
        for (chord, el) in collect(pid: pid) {
            if AXBridge.copyBool(el, kAXEnabledAttribute) == false { continue }
            guard let m = try? KeyParser.parse(chord) else { continue }
            guard m.keyCode == wanted.keyCode,
                  (m.flags.rawValue ^ wanted.flags.rawValue) & 0x1e0000 == 0
            else { continue }
            return AXUIElementPerformAction(
                el, kAXPressAction as CFString) == .success
        }
        return nil
    }

    /// Wire projection for snap.menu_shortcuts — [{combo,title,path}].
    static func wireEntries(pid: pid_t) -> [JSONDict] {
        let app = AXUIElementCreateApplication(pid)
        var out: [JSONDict] = []
        var barValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXMenuBar" as CFString, &barValue) == .success,
              let bar = barValue, CFGetTypeID(bar) == AXUIElementGetTypeID() else { return out }
        let menuBar = unsafeDowncast(bar, to: AXUIElement.self)
        func visit(_ el: AXUIElement, parents: [String]) {
            let title = AXBridge.copyString(el, kAXTitleAttribute) ?? ""
            var path = parents
            if !title.isEmpty { path.append(title) }
            if let cmd = AXBridge.copyString(el, kAXMenuItemCmdCharAttribute), !cmd.isEmpty {
                let mods = AXBridge.copyString(el, kAXMenuItemCmdModifiersAttribute) ?? ""
                out.append([
                    "combo": chordString(char: cmd, modifiers: mods),
                    "title": title,
                    "path": path.joined(separator: " > "),
                ])
            }
            for child in AXBridge.copyElements(el, kAXChildrenAttribute) { visit(child, parents: path) }
        }
        for child in AXBridge.copyElements(menuBar, kAXChildrenAttribute) { visit(child, parents: []) }
        return out
    }
}

// MARK: - KeyDelivery / MouseButton enums (raw values verbatim)

enum KeyDelivery: String {
    case keyWindow   = "key_window"
    case activeApp   = "active_app"
    case menuAXPress = "menu_ax_press"
    case suppressed  = "suppressed"
    var delivered: Bool { self != .suppressed }
}

enum MouseButtonTag {
    case left, right, middle
    var name: String {
        switch self {
        case .left: return "left"
        case .right: return "right"
        case .middle: return "middle"
        }
    }
    var tag: Int { self == .right ? 1 : (self == .middle ? 2 : 0) }
    var cgButton: CGMouseButton { CGMouseButton(rawValue: UInt32(tag))! }
    var down: CGEventType { CGEventType(rawValue: UInt32([1, 3, 25][tag]))! }
    var up: CGEventType { CGEventType(rawValue: UInt32([2, 4, 26][tag]))! }
    var dragged: CGEventType { CGEventType(rawValue: UInt32([6, 7, 27][tag]))! }
    var nsDown: NSEvent.EventType { NSEvent.EventType(rawValue: UInt([1, 3, 25][tag]))! }
    var nsUp: NSEvent.EventType { NSEvent.EventType(rawValue: UInt([2, 4, 26][tag]))! }
    var nsDragged: NSEvent.EventType { NSEvent.EventType(rawValue: UInt([6, 7, 27][tag]))! }
    static func parse(_ s: String?) -> MouseButtonTag {
        switch s?.lowercased() {
        case "right": return .right
        case "middle": return .middle
        default: return .left
        }
    }
}

// MARK: - ActionCursor (last synthesized action point; shot metadata)

enum ActionCursor {
    private static var point: CGPoint?
    private static var at: Date?
    private static let lock = NSLock()

    static func record(_ p: CGPoint) {
        lock.lock(); point = p; at = Date(); lock.unlock()
    }

    /// normalized cursor position inside `rect` while the record is fresh
    /// (Alma drops it after ~8s); nil when absent/stale/outside.
    static func normalized(in rect: CGRect?) -> (x: Double, y: Double)? {
        lock.lock()
        let p = point, t = at
        lock.unlock()
        guard let p, let t, let rect,
              Date().timeIntervalSince(t) <= 8.0,
              rect.width > 0, rect.height > 0,
              rect.contains(p) else { return nil }
        return ((p.x - rect.minX) / rect.width,
                (p.y - rect.minY) / rect.height)
    }
}

// MARK: - TypeVerification — read-back proof the text landed

enum TypeVerification {
    /// hasKeyWindow = AXFocusedWindow readable non-nil AND app.isActive
    /// [DISASM 0x10002d6b0 — the AND is real, not a shortcut].
    static func hasKeyWindow(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var v: CFTypeRef?
        let focusedOK = AXUIElementCopyAttributeValue(app,
            "AXFocusedWindow" as CFString, &v) == .success && v != nil
        return focusedOK
            && (NSRunningApplication(processIdentifier: pid)?.isActive == true)
    }

    struct Baseline {
        let element: AXUIElement?
        let value: String?
    }

    static func baseline(pid: pid_t) -> Baseline {
        let app = AXUIElementCreateApplication(pid)
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app,
                kAXFocusedUIElementAttribute as CFString, &v) == .success,
              let el = v, CFGetTypeID(el) == AXUIElementGetTypeID()
        else { return Baseline(element: nil, value: nil) }
        let ax = unsafeDowncast(el, to: AXUIElement.self)
        return Baseline(element: ax, value: readValue(ax))
    }

    private static func readValue(_ el: AXUIElement) -> String? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el,
                kAXValueAttribute as CFString, &v) == .success else { return nil }
        return v as? String
    }

    enum Outcome {
        case verified              // landed
        case unchanged             // failed
        case unverifiable(String)  // reason verbatim
    }

    /// check(baseline:typed:pid:) — pid arg unused in Alma's body; the
    /// re-read goes to the baseline element, not fresh focus.
    static func check(baseline b: Baseline, typed: String,
                      pid: pid_t) -> Outcome {
        if typed.isEmpty { return .verified }
        guard let el = b.element else {
            return .unverifiable("the app reported no focused element to compare")
        }
        guard let before = b.value else {
            return .unverifiable("the focused element exposes no readable text")
        }
        guard let after = readValue(el) else {
            return .unverifiable("the focused element stopped exposing readable text")
        }
        return after == before ? .unchanged : .verified
    }
}

// MARK: - EventDispatch

extension EventDispatch {

    /// 40ms between click rounds [DISASM]; monotonic event number [SYM].
    private static var eventNumberCounter: UInt32 = 0
    private static let eventNumberLock = NSLock()
    static func nextEventNumber() -> UInt32 {
        eventNumberLock.lock(); defer { eventNumberLock.unlock() }
        eventNumberCounter &+= 1
        return eventNumberCounter
    }

    /// resolveClickWindowID: first CG window containing the point, else the
    /// app's first window; nil when no windows.
    private static func resolveClickWindowID(forPid pid: pid_t,
                                             screenPoint p: CGPoint) -> CGWindowID? {
        let ws = WindowList.windows(pid: pid)
        guard !ws.isEmpty else { return nil }
        for w in ws {
            guard let wid = (w[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let b = w[kCGWindowBounds as String] as? [String: Any]
            else { continue }
            let r = CGRect(x: b["X"] as? Double ?? 0, y: b["Y"] as? Double ?? 0,
                           width: b["Width"] as? Double ?? 0,
                           height: b["Height"] as? Double ?? 0)
            if r.contains(p) { return wid }
        }
        return (ws.first?[kCGWindowNumber as String] as? NSNumber)?.uint32Value
    }

    static func windowBounds(cgWindowId wid: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], wid) as? [[String: Any]],
              let first = info.first,
              let b = first[kCGWindowBounds as String] as? [String: Any]
        else { return nil }
        return CGRect(x: b["X"] as? Double ?? 0, y: b["Y"] as? Double ?? 0,
                      width: b["Width"] as? Double ?? 0,
                      height: b["Height"] as? Double ?? 0)
    }

    /// Mint one mouse CGEvent through NSEvent (Alma's construction path) with
    /// all observed field writes, then SynthPost.
    private static func postMouse(type nsType: NSEvent.EventType,
                                  at p: CGPoint,
                                  button: MouseButtonTag,
                                  clickCount: Int,
                                  pid: pid_t, winID: CGWindowID?,
                                  winBounds: CGRect?,
                                  modifiers: CGEventFlags = [],
                                  forceCommandFlag: Bool = false) throws {
        guard let ns = NSEvent.mouseEvent(
                with: nsType, location: p,
                modifierFlags: NSEvent.ModifierFlags(
                    rawValue: UInt(modifiers.rawValue)),
                timestamp: 0, windowNumber: Int(winID ?? 0),
                context: nil, eventNumber: Int(nextEventNumber()),
                clickCount: clickCount, pressure: 1.0),
              let ev = ns.cgEvent
        else {
            throw DaemonError("internal", "NSEvent→CGEvent failed (click)")
        }
        ev.setIntegerValueField(CGEventField(rawValue: 3)!,
                                value: Int64(button.tag))
        ev.setIntegerValueField(CGEventField(rawValue: 7)!, value: 3)
        if let winID, let wb = winBounds {
            ev.setIntegerValueField(CGEventField(rawValue: 0x5b)!,
                                    value: Int64(winID))
            ev.setIntegerValueField(CGEventField(rawValue: 0x5c)!,
                                    value: Int64(winID))
            ev.location = p
            SetWindowLocation.fn?(ev, CGPoint(x: p.x - wb.origin.x,
                                              y: p.y - wb.origin.y))
        } else {
            ev.location = p
        }
        var flags = modifiers
        if forceCommandFlag { flags.insert(CGEventFlags(rawValue: 0x100000)) }
        if flags.rawValue != 0 { ev.flags = flags }
        tagSentinel(ev)
        SynthPost.post(pid: pid, ev)
    }

    /// click(at:button:clickCount:pid:) — NSEvent minting + 40ms rounds.
    static func click(at p: CGPoint, button: MouseButtonTag, clickCount: Int,
                      pid: pid_t, modifiers: CGEventFlags = []) throws {
        try withFocusPreserved(style: .preserved, pid: pid) {
            let winID = resolveClickWindowID(forPid: pid, screenPoint: p)
            let wb = winID.flatMap { windowBounds(cgWindowId: $0) }
            for i in 0..<max(1, clickCount) {
                try postMouse(type: button.nsDown, at: p, button: button,
                              clickCount: i + 1, pid: pid, winID: winID,
                              winBounds: wb, modifiers: modifiers)
                try postMouse(type: button.nsUp, at: p, button: button,
                              clickCount: i + 1, pid: pid, winID: winID,
                              winBounds: wb, modifiers: modifiers)
                if i < clickCount - 1 { usleep(40_000) }
            }
            LensBus.postMove(p)
            LensBus.postClick()
        }
        ActionCursor.record(p)
    }

    /// drag(from:to:button:pid:steps=12) — 8ms between dragged events;
    /// dragged/up carry the 0x100000 flag.
    static func drag(from s: CGPoint, to e: CGPoint,
                     button: MouseButtonTag, pid: pid_t,
                     steps: Int = 12) throws {
        try withFocusPreserved(style: .preserved, pid: pid) {
            let winID = resolveClickWindowID(forPid: pid, screenPoint: s)
            let wb = winID.flatMap { windowBounds(cgWindowId: $0) }
            try postMouse(type: button.nsDown, at: s, button: button,
                          clickCount: 1, pid: pid, winID: winID, winBounds: wb)
            for i in 1..<steps {
                let t = Double(i) / Double(steps)
                let pt = CGPoint(x: s.x + (e.x - s.x) * t,
                                 y: s.y + (e.y - s.y) * t)
                try postMouse(type: button.nsDragged, at: pt, button: button,
                              clickCount: 1, pid: pid, winID: winID,
                              winBounds: wb, forceCommandFlag: true)
                usleep(8_000)
            }
            try postMouse(type: button.nsUp, at: e, button: button,
                          clickCount: 1, pid: pid, winID: winID,
                          winBounds: wb, forceCommandFlag: true)
            LensBus.postMove(e)
            LensBus.postClick()
        }
        ActionCursor.record(e)
    }

    /// scroll(at:direction:pages:pid:) — CGEventSource .hidSystemState,
    /// scrollWheelEvent2 in line units, one event per page.
    static func scrollWheel(at p: CGPoint, direction: String, pages: Int,
                            pid: pid_t) throws {
        var dx = 0, dy = 0
        switch direction.lowercased() {
        case "up": dy = pages
        case "down": dy = -pages
        case "left": dx = -pages
        case "right": dx = pages
        default: break
        }
        try withFocusPreserved(style: .preserved, pid: pid) {
            guard let src = CGEventSource(stateID: .hidSystemState) else {
                throw DaemonError("internal", "CGEventSource creation failed")
            }
            for _ in 0..<max(pages, 1) {
                guard let ev = CGEvent(scrollWheelEvent2Source: src,
                        units: .line, wheelCount: 2,
                        wheel1: Int32(clamping: dy),
                        wheel2: Int32(clamping: dx), wheel3: 0)
                else {
                    throw DaemonError("internal", "CGEvent creation failed (scroll)")
                }
                ev.location = p
                tagSentinel(ev)
                SynthPost.post(pid: pid, ev)
            }
            LensBus.postScroll(direction: direction)
        }
        ActionCursor.record(p)
    }

    /// pressKey — direct event only when the app has a key window or is
    /// active (via: key_window/active_app); otherwise an ENABLED menu item
    /// owning the chord is AXPress'ed (menu_ax_press); nothing posted →
    /// suppressed. The daemon NEVER posts a bare keystroke into a
    /// background app.
    static func pressKey(_ key: String, pid: pid_t) throws -> KeyDelivery {
        let parsed = try KeyParser.parse(key)
        let hasKey = TypeVerification.hasKeyWindow(pid: pid)
        let active = NSRunningApplication(processIdentifier: pid)?.isActive == true
        if hasKey || active {
            return try withFocusPreserved(style: .preserved, pid: pid) {
                guard let src = CGEventSource(stateID: .privateState) else {
                    throw DaemonError("internal", "CGEventSource creation failed")
                }
                guard let down = CGEvent(keyboardEventSource: src,
                                         virtualKey: CGKeyCode(parsed.keyCode), keyDown: true),
                      let up = CGEvent(keyboardEventSource: src,
                                       virtualKey: CGKeyCode(parsed.keyCode), keyDown: false)
                else {
                    throw DaemonError("internal", "CGEvent creation failed (key)")
                }
                if parsed.flags.rawValue != 0 {
                    down.flags = parsed.flags
                    up.flags = parsed.flags
                }
                tagSentinel(down); tagSentinel(up)
                SynthPost.post(pid: pid, down)
                SynthPost.post(pid: pid, up)
                return hasKey ? .keyWindow : .activeApp
            }
        }
        if let ok = MenuShortcuts.matchAndPress(pid: pid, key: key) {
            return ok ? .menuAXPress : .suppressed
        }
        return .suppressed
    }

    /// typeKeyPresses — private-source keyboard events, 4ms apart.
    static func typeKeyPresses(_ presses: [KeyboardLayoutTranslator.KeyPress],
                               pid: pid_t) throws {
        guard let src = CGEventSource(stateID: .privateState) else {
            throw DaemonError("internal", "CGEventSource creation failed")
        }
        for kp in presses {
            guard let down = CGEvent(keyboardEventSource: src,
                                     virtualKey: CGKeyCode(kp.keyCode), keyDown: true),
                  let up = CGEvent(keyboardEventSource: src,
                                   virtualKey: CGKeyCode(kp.keyCode), keyDown: false)
            else {
                throw DaemonError("internal", "CGEvent creation failed (physical text)")
            }
            if kp.flags.rawValue != 0 {
                down.flags = kp.flags; up.flags = kp.flags
            }
            tagSentinel(down); tagSentinel(up)
            SynthPost.post(pid: pid, down)
            SynthPost.post(pid: pid, up)
            usleep(4_000)
        }
    }

    /// typeUnicodeText — chunks of ≤20 unicode SCALARS (never splits a
    /// surrogate pair), each re-encoded to UTF-16; keyCode 0 down+up events
    /// both carry the chunk.
    static func typeUnicodeText(_ text: String, pid: pid_t) throws {
        guard let src = CGEventSource(stateID: .privateState) else {
            throw DaemonError("internal", "CGEventSource creation failed")
        }
        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let n = min(20, scalars.count - i)
            let chunk = Array(String(String.UnicodeScalarView(
                scalars[i..<i + n])).utf16)
            i += n
            for down in [true, false] {
                guard let ev = CGEvent(keyboardEventSource: src,
                                       virtualKey: 0, keyDown: down) else {
                    throw DaemonError("internal", "CGEvent creation failed (text)")
                }
                chunk.withUnsafeBufferPointer { bp in
                    ev.keyboardSetUnicodeString(
                        stringLength: bp.count, unicodeString: bp.baseAddress)
                }
                tagSentinel(ev)
                SynthPost.post(pid: pid, ev)
            }
        }
    }

    /// typeTextViaFocusedAXElement — [DISASM 0x100023b60]:
    ///   AXSelectedText settable AND write succeeds → true
    ///   else AXValue settable → append (existing String ?? "") + text
    ///   else false
    /// Note: a FAILED settable AXSelectedText write still falls through to
    /// the AXValue arm (unlike the ref-route which throws).
    static func typeTextViaFocusedAXElement(_ text: String,
                                            pid: pid_t) throws -> Bool {
        let app = AXUIElementCreateApplication(pid)
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app,
                kAXFocusedUIElementAttribute as CFString, &v) == .success,
              let focused = v, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        let f = unsafeDowncast(focused, to: AXUIElement.self)
        var settable = DarwinBoolean(false)
        _ = AXUIElementIsAttributeSettable(f,
            "AXSelectedText" as CFString, &settable)
        if settable.boolValue,
           AXUIElementSetAttributeValue(
               f, "AXSelectedText" as CFString, text as CFTypeRef) == .success {
            return true
        }
        _ = AXUIElementIsAttributeSettable(f,
            kAXValueAttribute as CFString, &settable)
        guard settable.boolValue else { return false }
        var cur: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(f,
            kAXValueAttribute as CFString, &cur)
        return AXUIElementSetAttributeValue(
            f, kAXValueAttribute as CFString,
            ((cur as? String ?? "") + text) as CFTypeRef) == .success
    }

    /// typeText auto dispatcher:
    ///   focused-AX insert → done (no verification — AX write is direct)
    ///   else try? keyPresses → physical
    ///   else → unicode
    static func typeTextAuto(_ text: String, pid: pid_t) throws {
        if try typeTextViaFocusedAXElement(text, pid: pid) { return }
        if let presses = try? KeyboardLayoutTranslator.keyPresses(for: text) {
            try withFocusPreserved(style: .preserved, pid: pid) {
                try typeKeyPresses(presses, pid: pid)
            }
        } else {
            try withFocusPreserved(style: .preserved, pid: pid) {
                try typeUnicodeText(text, pid: pid)
            }
        }
    }
}

// MARK: - waitUntilReady

extension EventDispatch {
    /// Post-launch readiness: poll until the app's AX tree responds
    /// (AXWindows or AXChildren non-empty), 100ms steps, up to 4s.
    /// Non-fatal — returns when the budget is spent either way.
    static func waitUntilReady(pid: pid_t, maxSeconds: Double = 4.0) {
        let deadline = Date().addingTimeInterval(maxSeconds)
        let app = AXUIElementCreateApplication(pid)
        while Date() < deadline {
            var v: CFTypeRef?
            if AXUIElementCopyAttributeValue(app,
                    kAXWindowsAttribute as CFString, &v) == .success,
               let arr = v as? [Any], !arr.isEmpty { return }
            var c: CFTypeRef?
            if AXUIElementCopyAttributeValue(app,
                    kAXChildrenAttribute as CFString, &c) == .success,
               let arr = c as? [Any], !arr.isEmpty { return }
            usleep(100_000)
        }
    }
}
