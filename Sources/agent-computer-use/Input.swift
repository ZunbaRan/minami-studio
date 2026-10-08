import AppKit
import Carbon
import CoreGraphics
import Foundation

// Input dispatch: KeyCodec (chord parse + char→keycode map), CGEvent delivery
// to pid (background-safe — never requires foreground), three-stage typeText
// (AX insert → physical keys → unicode events), press_key with AX-menu
// fallback, settle prelude/postlude.

// MARK: - Key names (daemon-side names; wrapper maps xdotool → these)

enum KeyCodec {

    static let namedKeys: [String: CGKeyCode] = [
        "return": 36, "enter": 36, "tab": 48, "space": 49, "delete": 51,
        "esc": 53, "escape": 53,
        "up": 126, "down": 125, "left": 123, "right": 124,
        "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "f13": 105, "f14": 107, "f15": 113, "f16": 106, "f17": 64,
        "f18": 79, "f19": 80, "f20": 90,
    ]

    static let modifierNames: [String: CGKeyCode] = [
        "cmd": 55, "command": 55, "meta": 55, "super": 55,
        "ctrl": 59, "control": 59,
        "opt": 58, "option": 58, "alt": 58,
        "shift": 56,
        "fn": 63,
    ]

    static let modifierFlags: [CGKeyCode: CGEventFlags] = [
        55: .maskCommand, 59: .maskControl, 58: .maskAlternate, 56: .maskShift, 63: .maskSecondaryFn,
    ]

    /// Parse "cmd+shift+s" / "Return" into (keyCode, flags).
    /// Error text verbatim: unknown key "X" in "<original>".
    static func parseChord(_ key: String) throws -> (CGKeyCode, CGEventFlags) {
        var flags = CGEventFlags()
        var code: CGKeyCode?
        for rawPart in key.split(separator: "+") {
            let part = rawPart.trimmingCharacters(in: .whitespaces).lowercased()
            if part.isEmpty { continue }
            if let mod = modifierNames[part] {
                flags.insert(modifierFlags[mod] ?? [])
            } else if let named = namedKeys[part] {
                code = named
            } else if part.count == 1, let ch = part.first {
                guard let mapped = keyCode(for: ch) else {
                    throw DaemonError("invalid_arg", "unknown key \"\(part)\" in \"\(key)\"")
                }
                code = mapped.code
                flags.formUnion(mapped.flags)
            } else {
                throw DaemonError("invalid_arg", "unknown key \"\(part)\" in \"\(key)\"")
            }
        }
        guard let c = code else {
            throw DaemonError("invalid_arg", "unknown key \"\(key)\" in \"\(key)\"")
        }
        return (c, flags)
    }

    /// char → (keycode, needed modifier flags) via the current keyboard
    /// layout (UCKeyboardLayout). nil = not typable physically.
    static func keyCode(for char: Character) -> (code: CGKeyCode, flags: CGEventFlags)? {
        guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        // TISGetInputSourceProperty returns a raw opaque pointer; the
        // documented pattern is unsafeBitCast to CFData.
        let data = unsafeBitCast(raw, to: CFData.self)
        let layout = unsafeBitCast(
            CFDataGetBytePtr(data),
            to: UnsafePointer<UCKeyboardLayout>.self
        )
        for ch in char.unicodeScalars {
            var dead: UInt32 = 0
            var out = [UniChar](repeating: 0, count: 4)
            var outLen = 0
            // try plain, then shift, then option — first that produces the char
            for (mask, flag): (UInt32, CGEventFlags) in [(0, []), (2, .maskShift), (32 | 2, [.maskAlternate, .maskShift]), (32, .maskAlternate)] {
                for code in (0 as CGKeyCode)...(127 as CGKeyCode) {
                    dead = 0; outLen = 0
                    let rc = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), mask,
                                            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                            &dead, 4, &outLen, &out)
                    if rc == noErr, outLen == 1, out[0] == UInt16(ch.value) {
                        return (code, flag)
                    }
                }
            }
            return nil
        }
        return nil
    }

    /// All chars physically mappable? nil → unicode fallback. (auto predicate
    /// is exactly `try? keyPresses` — no text heuristics.)
    static func keyPresses(for text: String) -> [(CGKeyCode, CGEventFlags)]? {
        var out: [(CGKeyCode, CGEventFlags)] = []
        for ch in text {
            if ch == "\n" { out.append((36, [])); continue }
            if ch == "\t" { out.append((48, [])); continue }
            guard let p = keyCode(for: ch) else { return nil }
            out.append(p)
        }
        return out
    }
}

// MARK: - MenuShortcuts (press_key AX-menu fallback — background delivery)

enum MenuShortcuts {
    /// Walk the app's menubar collecting (shortcut, AXUIElement) pairs.
    static func collect(pid: pid_t) -> [(String, AXUIElement)] {
        let app = AXUIElementCreateApplication(pid)
        var out: [(String, AXUIElement)] = []
        var barValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXMenuBar" as CFString, &barValue) == .success,
              let bar = barValue, CFGetTypeID(bar) == AXUIElementGetTypeID() else { return out }
        let menuBar = unsafeDowncast(bar, to: AXUIElement.self)
        func visit(_ el: AXUIElement) {
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

    /// AX shortcut modifiers: numeric mask — 0=cmd,1=opt,2=ctrl, bit2(4)=shift? empirically "+", "^", "@" chars vary; we match on char+modifier superset.
    static func chordString(char: String, modifiers: String) -> String {
        var parts: [String] = []
        if modifiers.contains("@") || modifiers.contains("0") { parts.append("cmd") }
        if modifiers.contains("^") || modifiers.contains("2") { parts.append("ctrl") }
        if modifiers.contains("~") || modifiers.contains("1") { parts.append("opt") }
        if modifiers.contains("$") || modifiers.contains("S") { parts.append("shift") }
        parts.append(glyphToKeyName(char))
        return parts.joined(separator: "+")
    }

    /// AXMenuItemCmdGlyph glyphs → the same key names press_key accepts
    /// (chords only match when both sides use these names).
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

    /// Find a menu item whose shortcut matches the requested chord.
    static func match(pid: pid_t, key: String) -> AXUIElement? {
        let wanted = key.lowercased()
        for (chord, el) in collect(pid: pid) where chord == wanted { return el }
        // second pass: compare just the char if modifiers parse differ
        let last = wanted.split(separator: "+").last.map(String.init) ?? wanted
        for (chord, el) in collect(pid: pid) where chord.split(separator: "+").last.map(String.init) == last && chord == wanted { return el }
        return nil
    }

    /// Wire projection for snap.menu_shortcuts — [{combo,title,path}]
    /// ([SYM] key names). path = ancestor menu titles joined " > ".
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

// MARK: - CGEvent delivery

enum KeyDelivery {
    case delivered
    case suppressed(reason: String)
    case menuPressed // via == "menu_ax_press"
}

extension EventDispatch {

    @discardableResult
    static func postToPid(_ event: CGEvent?, pid: pid_t) -> Bool {
        guard let e = event else { return false }
        e.postToPid(pid)
        return true
    }

    /// Mouse click at a screen point, delivered to pid without activating.
    static func clickAtPoint(_ p: CGPoint, pid: pid_t, button: String, clickCount: Int) throws {
        let (down, up): (CGEventType, CGEventType)
        let cgButton: CGMouseButton
        switch button {
        case "right": down = .rightMouseDown; up = .rightMouseUp; cgButton = .right
        case "middle": down = .otherMouseDown; up = .otherMouseUp; cgButton = .center
        default: down = .leftMouseDown; up = .leftMouseUp; cgButton = .left
        }
        LensBus.postMove(p)
        postToPid(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: p, mouseButton: cgButton), pid: pid)
        usleep(10_000)
        for _ in 0..<max(1, clickCount) {
            postToPid(CGEvent(mouseEventSource: nil, mouseType: down,
                              mouseCursorPosition: p, mouseButton: cgButton), pid: pid)
            usleep(8_000)
            postToPid(CGEvent(mouseEventSource: nil, mouseType: up,
                              mouseCursorPosition: p, mouseButton: cgButton), pid: pid)
            usleep(12_000)
        }
        LensBus.postClick()
    }

    static func dragToPid(from: CGPoint, to: CGPoint, pid: pid_t, button: CGMouseButton = .left) {
        postToPid(CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                          mouseCursorPosition: from, mouseButton: button), pid: pid)
        usleep(15_000)
        postToPid(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                          mouseCursorPosition: from, mouseButton: button), pid: pid)
        usleep(30_000)
        // a few intermediate moves for smoothness
        let steps = 8
        for i in 1...steps {
            let p = CGPoint(x: from.x + (to.x - from.x) * CGFloat(i) / CGFloat(steps),
                            y: from.y + (to.y - from.y) * CGFloat(i) / CGFloat(steps))
            postToPid(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                              mouseCursorPosition: p, mouseButton: button), pid: pid)
            usleep(15_000)
        }
        postToPid(CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                          mouseCursorPosition: to, mouseButton: button), pid: pid)
    }

    /// press_key — try the app's menu for the chord first (background-safe
    /// AXPress on the menu item, `via:"menu_ax_press"`), else CGEvent key to pid.
    static func pressKey(_ key: String, pid: pid_t) throws -> (delivered: Bool, via: String?, note: String?) {
        if let item = MenuShortcuts.match(pid: pid, key: key) {
            if AXUIElementPerformAction(item, kAXPressAction as CFString) == .success {
                return (true, "menu_ax_press", nil)
            }
        }
        let (code, flags) = try KeyCodec.parseChord(key)
        let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
        down?.flags = flags; up?.flags = flags
        guard postToPid(down, pid: pid), postToPid(up, pid: pid) else {
            return (false, nil, "the target app did not accept the key event")
        }
        return (true, nil, nil)
    }

    /// typeKeyPresses — physical path.
    static func typeKeyPresses(_ presses: [(CGKeyCode, CGEventFlags)], pid: pid_t) {
        for (code, flags) in presses {
            let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
            down?.flags = flags; up?.flags = flags
            postToPid(down, pid: pid)
            usleep(5_000)
            postToPid(up, pid: pid)
            usleep(8_000)
        }
    }

    /// unicode path — CGEventKeyboardSetUnicodeString, 20 unicode scalars per event.
    static func typeUnicodeText(_ text: String, pid: pid_t) {
        var chunk: [UniChar] = []
        chunk.reserveCapacity(20)
        func flush() {
            if chunk.isEmpty { return }
            let e = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            e?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            postToPid(e, pid: pid)
            usleep(10_000)
            chunk.removeAll(keepingCapacity: true)
        }
        for scalar in text.unicodeScalars {
            chunk.append(contentsOf: Array(scalar.utf16))
            if chunk.count >= 20 { flush() }
        }
        flush()
    }

    /// typeTextViaFocusedAXElement — two AX branches, in order:
    ///   1. write AXSelectedText = text (insert at cursor)
    ///   2. read AXValue, append text, write back
    /// Returns true if either succeeded.
    @discardableResult
    static func typeTextViaFocusedAXElement(_ text: String, pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        guard let focusedValue = AXBridge.copyAttr(app, kAXFocusedUIElementAttribute),
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return false }
        let focused = unsafeDowncast(focusedValue, to: AXUIElement.self)
        if AXUIElementSetAttributeValue(focused, "AXSelectedText" as CFString, text as CFTypeRef) == .success {
            return true
        }
        if let cur = AXBridge.copyString(focused, kAXValueAttribute) {
            let combined = cur + text
            if AXUIElementSetAttributeValue(focused, kAXValueAttribute as CFString, combined as CFTypeRef) == .success {
                return true
            }
        }
        return false
    }

    /// typeText — "auto" path, verified three-stage:
    ///   if try typeTextViaFocusedAXElement → done
    ///   else if let presses = try? keyPresses(for:) → physical
    ///   else → unicode
    static func typeText(_ text: String, pid: pid_t, method: String) throws {
        switch method {
        case "ax":
            guard typeTextViaFocusedAXElement(text, pid: pid) else {
                throw DaemonError("action_unsupported", "Element does not support action setting AXValue.")
            }
        case "physical":
            guard let presses = KeyCodec.keyPresses(for: text) else {
                throw DaemonError("invalid_arg", "text contains characters not mappable to physical keys")
            }
            try withFocusPreserved(pid: pid) { typeKeyPresses(presses, pid: pid) }
        case "unicode":
            try withFocusPreserved(pid: pid) { typeUnicodeText(text, pid: pid) }
        default: // "auto"
            LensBus.postType()
            if typeTextViaFocusedAXElement(text, pid: pid) { return }
            if let presses = KeyCodec.keyPresses(for: text) {
                try withFocusPreserved(pid: pid) { typeKeyPresses(presses, pid: pid) }
            } else {
                try withFocusPreserved(pid: pid) { typeUnicodeText(text, pid: pid) }
            }
        }
    }
}

// MARK: - Settle (prelude/postlude around pointer actions)

struct SettleToken {
    var pixelHash: UInt64
    var point: CGPoint
    var startedAt: Date
}

extension EventDispatch {
    /// Baseline: hash the target window pixels + remember the translated point.
    static func settlePrelude(pid: pid_t, point: CGPoint) -> SettleToken {
        SettleToken(
            pixelHash: cheapWindowPixelHash(pid: pid),
            point: point,
            startedAt: Date()
        )
    }

    /// Postlude: poll until window pixels differ from baseline (UI reacted)
    /// or the settle budget expires.
    static func settlePostlude(_ token: SettleToken, pid: pid_t) {
        let deadline = token.startedAt.addingTimeInterval(2.0)
        while Date() < deadline {
            usleep(50_000)
            if cheapWindowPixelHash(pid: pid) != token.pixelHash { return }
        }
    }

    /// Downsampled hash of the app's front window pixels — cheap UI-change signal.
    static func cheapWindowPixelHash(pid: pid_t) -> UInt64 {
        guard let wid = WindowList.frontWindowID(pid: pid),
              let img = onMainThread({
                  CGWindowListCreateImage(.null, [.optionIncludingWindow], wid, [.boundsIgnoreFraming])
              }) else {
            return 0
        }
        var h: UInt64 = 5381
        let step = max(1, (img.width * img.height) / 64)
        guard let provider = img.dataProvider, let data = provider.data,
              let bytes = CFDataGetBytePtr(data) else { return UInt64(img.width * img.height) }
        let total = CFDataGetLength(data)
        var i = 0
        while i < min(total, step * 64) {
            h = ((h << 5) &+ h) &+ UInt64(bytes[i])
            i += step * 4
        }
        return h
    }
}
