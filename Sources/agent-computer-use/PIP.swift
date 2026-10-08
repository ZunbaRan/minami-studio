import AppKit
import AVFoundation
import ScreenCaptureKit
import ApplicationServices
import CoreMedia

// PIP.swift — native picture-in-picture subsystem, faithful to the .153/.164
// evidence:
//   [LIVE] pip_open → {"opened":true,"session":{window_id,pid,title,
//                     floater_frame:{x,y,w,h},has_first_frame,last_frame_age_ms}}
//          pip_status → {"sessions":[…],"armed":[…]}
//          pip_close {window_id} | {"all":true}
//          pip_arm {window_id,pid,title} → {"armed":[…]}
//          pip_disarm {window_id} | {"all":true}
//   [DISASM] PIPFloaterWindow NSPanel literals, SCStreamConfiguration setters,
//            AVSampleBufferDisplayLayer enqueue path, AX destroy/minimize
//            observers, "alma.lens.*" NotificationCenter broadcast family,
//            PIPLens {moveTo/showBadge/triggerClick/hide} inside the panel.
// Errors (verbatim strings): "No AX window element for windowId=%u",
//   '"width" and "height" are required when pip_open carries a preferred size',
//   "PIP auto-open on minimise failed for wid=%u: %s",
//   "App has no windows to arm." / "App has no windows to mirror."

private func pipLog(_ s: String) {
    FileHandle.standardError.write("[pip] \(s)\n".data(using: .utf8)!)
}

/// Main-thread hop for AppKit work — the shared variant lives in Support.swift.
private func onMain<T>(_ body: () throws -> T) throws -> T {
    try onMainThread(body)
}

// MARK: - Lens broadcast names (verbatim "alma.lens.*" family)

enum LensBus {
    static let move = Notification.Name("alma.lens.move")
    static let click = Notification.Name("alma.lens.click")
    static let scrollBadge = Notification.Name("alma.lens.scrollBadge")
    static let typeBadge = Notification.Name("alma.lens.typeBadge")
    static let hide = Notification.Name("alma.lens.hide")

    /// Emitted by action paths; consumed by every PIPSession's panel lens.
    /// userInfo: {"point": NSValue(CGPoint), "slideMs": Int} — slideMs
    /// defaults to 180 (disasm literal).
    static func postMove(_ p: CGPoint, slideMs: Int = 180) {
        NotificationCenter.default.post(name: move, object: nil,
            userInfo: ["point": NSValue(point: p), "slideMs": slideMs])
    }
    static func postClick() {
        NotificationCenter.default.post(name: click, object: nil)
    }
    static func postScroll(direction: String) {
        NotificationCenter.default.post(name: scrollBadge, object: nil,
                                        userInfo: ["direction": direction])
    }
    static func postType() {
        NotificationCenter.default.post(name: typeBadge, object: nil)
    }
    static func postHide() {
        NotificationCenter.default.post(name: hide, object: nil)
    }
}

// MARK: - PIPLens — the agent cursor rendered INSIDE the mirror panel.
// Never painted on the user's real desktop (verbatim design note from the
// Electron side applies here too).

final class PIPLens {
    let hostLayer = CALayer()
    private let cursorDot = CALayer()
    private let badgeLayer = CALayer()

    init() {
        cursorDot.frame = CGRect(x: -8, y: -8, width: 16, height: 16)
        cursorDot.cornerRadius = 8
        cursorDot.backgroundColor = NSColor.controlAccentColor.cgColor
        cursorDot.borderColor = NSColor.white.cgColor
        cursorDot.borderWidth = 2
        cursorDot.isHidden = true
        hostLayer.addSublayer(cursorDot)
        hostLayer.addSublayer(badgeLayer)
        badgeLayer.frame = CGRect(x: 12, y: 12, width: 26, height: 26)
        badgeLayer.cornerRadius = 13
        badgeLayer.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        badgeLayer.isHidden = true
    }

    func moveTo(_ p: CGPoint, slideMs: Int) {
        cursorDot.isHidden = false
        CATransaction.begin()
        CATransaction.setAnimationDuration(Double(slideMs) / 1000.0)
        cursorDot.position = p
        CATransaction.commit()
    }

    func showBadge(symbol: String) {
        if let img = NSImage(systemSymbolName: symbol,
                             accessibilityDescription: nil) {
            badgeLayer.contents = img.cgImage(
                forProposedRect: nil, context: nil, hints: nil)
        }
        badgeLayer.isHidden = false
        badgeLayer.opacity = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0
        fade.beginTime = CACurrentMediaTime() + 1.0
        fade.duration = 0.4
        fade.fillMode = .forwards; fade.isRemovedOnCompletion = false
        badgeLayer.add(fade, forKey: "badgeFade")
    }

    func triggerClick() {
        cursorDot.isHidden = false
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0; pulse.toValue = 1.6
        pulse.duration = 0.15
        pulse.autoreverses = true
        cursorDot.add(pulse, forKey: "clickPulse")
    }

    func hide() { cursorDot.isHidden = true; badgeLayer.isHidden = true }
}

// MARK: - PIPContentView — AVSampleBufferDisplayLayer sink.
// [DISASM] enqueue: layer.status == .failed → flush(); if
// isReadyForMoreMediaData → enqueueSampleBuffer; then placeholder hidden.

final class PIPContentView: NSView {
    let videoLayer = AVSampleBufferDisplayLayer()
    let lens = PIPLens()
    private var placeholder: NSView?
    let sourceAspect: CGFloat

    init(frame: CGRect, sourceAspect: CGFloat) {
        self.sourceAspect = sourceAspect
        super.init(frame: frame)
        wantsLayer = true
        videoLayer.videoGravity = .resizeAspect
        videoLayer.frame = bounds
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer!.addSublayer(videoLayer)
        layer!.addSublayer(lens.hostLayer)
        lens.hostLayer.frame = bounds
        lens.hostLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unsupported") }

    func enqueue(sampleBuffer sb: CMSampleBuffer) {
        if videoLayer.status == .failed { videoLayer.flush() }
        if videoLayer.isReadyForMoreMediaData {
            videoLayer.enqueue(sb)
        }
        hidePlaceholder()
    }
    func hidePlaceholder() { placeholder?.isHidden = true }
    override func layout() {
        videoLayer.frame = bounds
        lens.hostLayer.frame = bounds
    }
}

// MARK: - PIPFloaterWindow — borderless always-on-top NSPanel.
// [DISASM] verbatim literals: level=.floating(3), collectionBehavior 0x111
// (canJoinAllSpaces|stationary|fullScreenAuxiliary), hidesOnDeactivate=false,
// movableByWindowBackground, transparent titlebar, hidden title, shadow,
// minSize 200×150, title " — <title>", contentAspectRatio 1:1 then source.

final class PIPFloaterWindow: NSPanel {
    let mirrorOf: CGWindowID
    init(mirrorOf wid: CGWindowID, title: String?, size: CGSize,
         sourceAspect: CGFloat) {
        mirrorOf = wid
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.nonactivatingPanel, .titled, .closable,
                               .resizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .windowBackgroundColor
        hasShadow = true
        minSize = CGSize(width: 200, height: 150)
        self.title = " — \(title ?? "")"
        contentAspectRatio = NSSize(width: 1, height: 1)
        if sourceAspect > 0 {
            contentAspectRatio = NSSize(width: sourceAspect, height: 1)
        }
        contentView = PIPContentView(frame: NSRect(origin: .zero, size: size),
                                     sourceAspect: sourceAspect)
        // Default placement: bottom-right of the main screen (live probe
        // floater_frame {x:1154,y:705} on a ~1440-wide display).
        if let scr = NSScreen.main {
            let vf = scr.visibleFrame
            let origin = CGPoint(x: vf.maxX - size.width - 24,
                                 y: vf.minY + 24)
            setFrameOrigin(origin)
        }
    }
    override func close() {
        super.close()
        PIPManager.shared.noteClosed(mirrorOf)
    }
}

// MARK: - PIPSession — one live SCStream per mirrored window.

final class PIPSession: NSObject, SCStreamOutput, SCStreamDelegate {
    let windowId: CGWindowID
    let pid: pid_t?
    let title: String
    let floater: PIPFloaterWindow
    let scWindow: SCWindow
    let onClose: (CGWindowID) -> Void
    private var stream: SCStream?
    private var axObserver: AXObserver?
    private var axWindowElement: AXUIElement?
    private var frameCount = 0
    private var firstFrameAt: Double = 0
    private var lastFrameAt: Double = 0
    private let outputQ = DispatchQueue(label: "agent.cu.pip.output")

    init(windowId: CGWindowID, pid: pid_t?, title: String,
         scWindow: SCWindow, preferredSize: CGSize?,
         onClose: @escaping (CGWindowID) -> Void) throws {
        self.windowId = windowId; self.pid = pid; self.title = title
        self.scWindow = scWindow; self.onClose = onClose
        let src = scWindow.frame
        let size = preferredSize ?? CGSize(width: 334, height: 220) // live-probe default
        floater = PIPFloaterWindow(mirrorOf: windowId, title: title,
                                   size: size,
                                   sourceAspect: src.width / max(src.height, 1))
        super.init()
    }

    /// [DISASM] SCStreamConfiguration literals:
    ///   width/height = scWindow.frame × screen.backingScaleFactor (def 2)
    ///   minimumFrameInterval = CMTime(1,30) → 30fps cap
    ///   showsCursor=true, capturesAudio=false, pixelFormat='BGRA',
    ///   queueDepth=3, ignoreShadowsSingleWindow (macOS 14+)
    ///   filter = SCContentFilter(desktopIndependentWindow:)
    ///   only SCFrameStatus.complete buffers reach the view.
    func start() throws {
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let cfg = SCStreamConfiguration()
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        cfg.width = Int(scWindow.frame.width * scale)
        cfg.height = Int(scWindow.frame.height * scale)
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        cfg.showsCursor = true
        cfg.capturesAudio = false
        cfg.pixelFormat = kCVPixelFormatType_32BGRA
        cfg.queueDepth = 3
        if #available(macOS 14, *) { cfg.ignoreShadowsSingleWindow = true }
        let s = SCStream(filter: filter, configuration: cfg, delegate: self)
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQ)
        stream = s
        floater.orderFrontRegardless()
        s.startCapture { [weak self] err in
            if let err { self?.handleStreamError(err) }
        }
        installDestroyObserver()
        subscribeToLensBroadcasts()
    }

    /// AX observer: AXUIElementDestroyed on the mirrored window → onClose.
    /// Window element resolved via _AXUIElementGetWindow (same private SPI
    /// the rest of the daemon uses).
    private func installDestroyObserver() {
        guard let pid = pid else { return }
        let appEl = AXUIElementCreateApplication(pid)
        // Prefer the resolved window element; on this macOS AXWindows can
        // return degenerate app proxies, so fall back to observing the app
        // element and filtering delivered elements by wid.
        let winEl = AXBridge.windows(of: pid).first(where: {
            AXBridge.windowIDNumber(of: $0) == windowId
        }) ?? PIPMinimizeArmer.shared.axWindowElement(of: appEl, cgWindowId: windowId)
        let target = winEl ?? appEl
        axWindowElement = target
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, el, _, ctx in
            guard let ctx else { return }
            let me = Unmanaged<PIPSession>.fromOpaque(ctx)
                .takeUnretainedValue()
            var hit = AXBridge.windowIDNumber(of: el) == me.windowId
            if AXBridge.windowIDNumber(of: el) == nil {
                var ep = pid_t(0)
                AXUIElementGetPid(el, &ep)
                if let mp = me.pid, ep == mp { hit = true }
            }
            guard hit else { return }
            let wid = me.windowId, cb = me.onClose
            DispatchQueue.main.async { cb(wid) }
        }, &obs) == .success, let obs else { return }
        AXObserverAddNotification(obs, target,
            kAXUIElementDestroyedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           AXObserverGetRunLoopSource(obs), .defaultMode)
        axObserver = obs
    }

    /// PIPLens consumes the same "alma.lens.*" broadcast family the action
    /// layer posts — one post drives every open panel's virtual cursor.
    private func subscribeToLensBroadcasts() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: LensBus.move, object: nil,
                       queue: .main) { [weak self] n in
            guard let p = (n.userInfo?["point"] as? NSValue)?.pointValue,
                  let view = self?.floater.contentView as? PIPContentView
            else { return }
            // Convert screen point → panel video space (letterboxed).
            let local = view.convert(view.window?.convertPoint(fromScreen: p) ?? p,
                                     from: nil)
            view.lens.moveTo(local,
                slideMs: n.userInfo?["slideMs"] as? Int ?? 180)
        }
        nc.addObserver(forName: LensBus.click, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens.triggerClick()
        }
        nc.addObserver(forName: LensBus.scrollBadge, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens
                .showBadge(symbol: "arrow.up.and.down")
        }
        nc.addObserver(forName: LensBus.typeBadge, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens
                .showBadge(symbol: "keyboard")
        }
        nc.addObserver(forName: LensBus.hide, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens.hide()
        }
    }

    private func handleStreamError(_ e: Error) {
        pipLog("PIP stream stopped for windowId=\(windowId): \(e)")
        let cb = onClose, wid = windowId
        DispatchQueue.main.async { cb(wid) }
    }

    func shutdown() {
        if let obs = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(obs), .defaultMode)
            if let el = axWindowElement {
                AXObserverRemoveNotification(obs, el,
                    kAXUIElementDestroyedNotification as CFString)
            }
        }
        if let stream {
            Task { try? await stream.stopCapture() }
        }
        stream = nil
        floater.close()
    }

    func stream(_ s: SCStream, didOutputSampleBuffer sb: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferIsValid(sb) else { return }
        if let atts = CMSampleBufferGetSampleAttachmentsArray(sb,
                    createIfNecessary: false) as? [[String: Any]],
           let st = atts.first?[SCStreamFrameInfo.status.rawValue] as? Int,
           st != 0 { return } // .complete only
        frameCount += 1
        let now = CACurrentMediaTime()
        if firstFrameAt == 0 { firstFrameAt = now }
        lastFrameAt = now
        DispatchQueue.main.async { [weak self] in
            (self?.floater.contentView as? PIPContentView)?.enqueue(sampleBuffer: sb)
        }
    }
    func stream(_ s: SCStream, didStopWithError error: Error) {
        handleStreamError(error)
    }

    /// Live-probe session dict: {window_id, pid, title,
    /// floater_frame:{x,y,w,h}, has_first_frame, last_frame_age_ms}.
    func statusSnapshot() -> JSONDict {
        let f = floater.frame
        var d: JSONDict = [
            "window_id": windowId,
            "title": title,
            "floater_frame": [
                "x": Double(f.origin.x), "y": Double(f.origin.y),
                "w": Double(f.size.width), "h": Double(f.size.height),
            ],
            "has_first_frame": frameCount > 0,
            "last_frame_age_ms": frameCount > 0
                ? Int((CACurrentMediaTime() - lastFrameAt) * 1000.0)
                : NSNull(),
        ]
        if let pid { d["pid"] = pid }
        return d
    }
}

// MARK: - PIPManager — sessions + arm list, all on main.

final class PIPManager {
    static let shared = PIPManager()
    private var sessions: [CGWindowID: PIPSession] = [:]

    /// Resolves a CGWindowID → SCWindow via SCShareableContent (async API,
    /// blocking wait on a semaphore — caller is a daemon worker thread).
    private func scWindow(for wid: CGWindowID) throws -> SCWindow {
        var result: SCWindow?
        var failure: Error?
        let sem = DispatchSemaphore(value: 0)
        SCShareableContent.getWithCompletionHandler { content, err in
            if let err { failure = err }
            else {
                result = content?.windows.first { $0.windowID == wid }
            }
            sem.signal()
        }
        if sem.wait(timeout: .now() + 5) == .timedOut {
            throw DaemonError("internal", "SCShareableContent timed out")
        }
        if let failure { throw DaemonError.wrap(failure) }
        guard let w = result else {
            throw DaemonError("internal",
                "No SCWindow with id \(wid) (was the window closed?)")
        }
        return w
    }

    /// pip_open {window_id, title?, width?, height?, pid?}
    /// [DISASM] existing sessions are checked BEFORE fresh SC lookup and
    /// brought to front; optional pid is preserved (may stay null).
    func open(windowId: CGWindowID, pid: pid_t?, title: String?,
              preferredSize: CGSize?) throws -> JSONDict {
        if let existing = onMainThread({ () -> JSONDict? in
            guard let s = sessions[windowId] else { return nil }
            s.floater.orderFrontRegardless()
            return ["opened": true, "session": s.statusSnapshot()]
        }) { return existing }
        // SCShareableContent delivery needs a spinning main runloop — resolve
        // it BEFORE hopping to main, otherwise main.sync deadlocks.
        let scw = try scWindow(for: windowId)
        let title = title ?? scw.title ?? ""
        return try onMain {
            if let s = sessions[windowId] {
                s.floater.orderFrontRegardless()
                return ["opened": true, "session": s.statusSnapshot()]
            }
            let s = try PIPSession(
                windowId: windowId, pid: pid,
                title: title,
                scWindow: scw, preferredSize: preferredSize
            ) { [weak self] wid in self?.noteClosed(wid) }
            sessions[windowId] = s
            do { try s.start() }
            catch { sessions[windowId] = nil; throw error }
            return ["opened": true, "session": s.statusSnapshot()]
        }
    }

    private func scOwnerPid(_ wid: CGWindowID) -> pid_t? {
        let opts = CGWindowListOption(arrayLiteral: .optionAll)
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        return list.first(where: {
            ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == wid
        })?[kCGWindowOwnerPID as String] as? pid_t
    }

    /// pip_close {window_id} | {all:true}
    /// [LIVE] all → {"closed":"all"}; single → {"closed":Bool,"window_id":N}.
    func close(windowId: CGWindowID?, all: Bool) throws -> JSONDict {
        try onMain {
            if all {
                sessions.values.forEach { $0.shutdown() }
                sessions.removeAll()
                return ["closed": "all"]
            }
            guard let wid = windowId else {
                throw DaemonError("invalid_arg",
                    "missing \"window_id\" (or pass \"all\": true)")
            }
            guard let s = sessions.removeValue(forKey: wid) else {
                return ["closed": false, "window_id": Int(wid)]
            }
            s.shutdown()
            return ["closed": true, "window_id": Int(wid)]
        }
    }

    /// pip_status {} → {"sessions":[…],"armed":[…]}
    func status() throws -> JSONDict {
        try onMain {
            ["sessions": sessions.values.map { $0.statusSnapshot() },
             "armed": PIPMinimizeArmer.shared.statusList()]
        }
    }

    /// Session teardown must run the full shutdown (stream stop, observer
    /// removal, floater close) — not just drop the dictionary entry.
    func noteClosed(_ wid: CGWindowID) {
        guard let s = sessions.removeValue(forKey: wid) else { return }
        s.shutdown()
    }
}

// MARK: - PIPMinimizeArmer — "re-open as PiP when the user minimizes".
// [SYM] arm(windowId:pid:title:) / disarm / disarmAll / statusList.
// Two notifications per arm [DISASM]: AXWindowMiniaturized → auto pip_open;
// AXUIElementDestroyed → arm entry dies with the window.

final class PIPMinimizeArmer {
    static let shared = PIPMinimizeArmer()

    private struct Arm {
        let windowId: CGWindowID
        let pid: pid_t
        let title: String?
        var observer: AXObserver?
    }
    private var arms: [CGWindowID: Arm] = [:]

    /// arm — direct-ID path validates the window belongs to `pid`
    /// (a valid id owned by another pid must NOT arm [DISASM]). Returns the
    /// stored arm tuple — duplicate arms report the stored entry.
    func arm(windowId: CGWindowID, pid: pid_t, title: String?) throws
        -> JSONDict {
        try onMain {
            if let existing = arms[windowId] {
                var d: JSONDict = ["window_id": Int(existing.windowId),
                                   "pid": Int(existing.pid)]
                if let t = existing.title { d["title"] = t }
                return d
            }
            // ownership gate: the CG id must resolve in this PID's window
            // set (AX match preferred; CG owner fallback for degraded AX).
            var owned = false
            for w in AXBridge.windows(of: pid) {
                if AXBridge.windowIDNumber(of: w) == windowId {
                    owned = true; break
                }
            }
            if !owned {
                let opts = CGWindowListOption(arrayLiteral: .optionAll)
                let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID)
                    as? [[String: Any]] ?? []
                owned = list.contains(where: {
                    ($0[kCGWindowNumber as String] as? NSNumber)?
                        .uint32Value == windowId
                        && ($0[kCGWindowOwnerPID as String] as? Int32) == pid
                })
            }
            guard owned else {
                throw DaemonError("invalid_arg",
                    "No AX window element for windowId=\(windowId) "
                    + "(pid \(pid))")
            }
            // Observe at the APP element: on this macOS AXWindows returns
            // degenerate AXApplication proxies (no wid, no bounds), so the
            // per-window element Alma's disasm resolves does not exist to
            // subscribe to. The notification callback delivers the real
            // window element — _AXUIElementGetWindow on it filters by wid;
            // a single armed window for the pid falls through unfiltered.
            let appEl = AXUIElementCreateApplication(pid)
            var ob: AXObserver?
            guard AXObserverCreate(pid, { _, el, notif, ctx in
                let me = Unmanaged<PIPMinimizeArmer>.fromOpaque(ctx!)
                    .takeUnretainedValue()
                var eid = AXBridge.windowIDNumber(of: el)
                if eid == nil {
                    // delivered element didn't resolve — fall back to the
                    // sole armed window for that pid
                    var ep = pid_t(0)
                    AXUIElementGetPid(el, &ep)
                    let pidsArms = me.arms.values.filter { $0.pid == ep }
                    if pidsArms.count == 1 { eid = pidsArms[0].windowId }
                }
                guard let wid = eid else { return }
                if (notif as String) == kAXUIElementDestroyedNotification {
                    DispatchQueue.main.async { _ = me.disarm(windowId: wid) }
                } else {
                    DispatchQueue.main.async { me.didMinimize(windowId: wid) }
                }
            }, &ob) == .success, let ob else {
                throw DaemonError("internal",
                    "AXObserverCreate failed: \(ob == nil ? -1 : 0)")
            }
            AXObserverAddNotification(ob, appEl,
                kAXWindowMiniaturizedNotification as CFString,
                Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(ob, appEl,
                kAXUIElementDestroyedNotification as CFString,
                Unmanaged.passUnretained(self).toOpaque())
            CFRunLoopAddSource(CFRunLoopGetMain(),
                               AXObserverGetRunLoopSource(ob), .defaultMode)
            arms[windowId] = Arm(windowId: windowId, pid: pid,
                                 title: title, observer: ob)
            var d: JSONDict = ["window_id": Int(windowId), "pid": Int(pid)]
            if let t = title { d["title"] = t }
            return d
        }
    }

    private func didMinimize(windowId: CGWindowID) {
        guard let a = arms[windowId] else { return }
        do {
            _ = try PIPManager.shared.open(windowId: windowId, pid: a.pid,
                                           title: a.title, preferredSize: nil)
        } catch {
            pipLog("PIP auto-open on minimise failed for wid=\(windowId): " +
                   "\(error.localizedDescription)") // verbatim string
        }
    }

    @discardableResult
    func disarm(windowId: CGWindowID) -> Bool {
        guard let a = arms.removeValue(forKey: windowId) else { return false }
        if let ob = a.observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(ob), .defaultMode)
        }
        return true
    }

    func disarmAll() {
        for k in arms.keys { _ = disarm(windowId: k) }
    }

    /// [LIVE] armed entries in pip_status / pip_arm responses.
    func statusList() -> [JSONDict] {
        arms.values.map {
            var d: JSONDict = ["window_id": $0.windowId, "pid": $0.pid]
            if let t = $0.title { d["title"] = t }
            return d
        }
    }

    /// CGWindowID → AX window element.
    /// Primary path is verbatim: app AXWindows + _AXUIElementGetWindow.
    /// Fallback [INFER]: Apple apps (Notes/Calculator) can return the app
    /// element itself from AXWindows; in that case BFS AXChildren (depth 2,
    /// CFEqual self-loop guard, 64-node cap) for real AXWindow elements.
    func axWindowElement(of app: AXUIElement,
                         cgWindowId: CGWindowID) -> AXUIElement? {
        var rv: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &rv) == .success,
           let wins = rv as? [AXUIElement],
           let hit = wins.first(where: { AXBridge.windowIDNumber(of: $0) == cgWindowId }) {
            return hit
        }
        var queue: [AXUIElement] = [app]
        var visited: [AXUIElement] = [app]
        var seen = 0
        while !queue.isEmpty && seen < 64 {
            let el = queue.removeFirst()
            seen += 1
            var cv: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &cv) == .success,
                  let kids = cv as? [AXUIElement] else { continue }
            for k in kids {
                if visited.contains(where: { CFEqual($0, k) }) { continue }
                visited.append(k)
                if AXBridge.windowIDNumber(of: k) == cgWindowId { return k }
                queue.append(k)
            }
        }
        return nil
    }
}

// MARK: - pip_* command handlers (wire projections per [LIVE]/[DISASM])

extension Daemon {

    /// Shared window picker: title exact → contains → focused → first.
    /// AX first, CG metadata fallback for degraded AXWindows hosts.
    private func pickWindow(pid: pid_t, title: String?)
        -> (el: AXUIElement?, wid: CGWindowID, title: String?)? {
        let wins = AXBridge.windows(of: pid)
        var target: AXUIElement?
        if let t = title, !t.isEmpty {
            target = wins.first {
                AXBridge.copyString($0, kAXTitleAttribute) == t
            } ?? wins.first {
                AXBridge.copyString($0, kAXTitleAttribute)?.contains(t)
                    == true
            }
        }
        if target == nil {
            target = wins.first {
                AXBridge.copyBool($0, kAXFocusedAttribute) == true
                    || AXBridge.copyBool($0, kAXMainAttribute) == true
            }
        }
        target = target ?? wins.first
        if let el = target, let wid = AXBridge.windowIDNumber(of: el) {
            return (el, wid, AXBridge.copyString(el, kAXTitleAttribute))
        }
        // CG fallback — same selection order over CGWindowList rows.
        let rows = WindowList.windows(pid: pid)
        var row: [String: Any]?
        if let t = title, !t.isEmpty {
            row = rows.first {
                ($0[kCGWindowName as String] as? String) == t
            } ?? rows.first {
                ($0[kCGWindowName as String] as? String)?.contains(t)
                    == true
            }
        }
        row = row ?? rows.first
        guard let r = row,
              let wid = (r[kCGWindowNumber as String] as? NSNumber)?
                  .uint32Value
        else { return nil }
        return (nil, wid, r[kCGWindowName as String] as? String)
    }

    /// pip_open — direct window_id, else app/title/focused/first resolution.
    /// Partial/invalid width/height collapse to nil preferred size.
    func cmdPipOpen(_ a: JSONDict) throws -> JSONDict {
        var size: CGSize?
        if let w = a.double("width"), let h = a.double("height"),
           w > 0, h > 0 {
            size = CGSize(width: w, height: h)
        }
        if let wid = a.int("window_id") {
            return try PIPManager.shared.open(
                windowId: CGWindowID(wid),
                pid: a.int("pid").map(pid_t.init),
                title: a.str("title"), preferredSize: size)
        }
        let app = try resolveApp(a)
        guard let picked = pickWindow(pid: app.processIdentifier,
                                      title: a.str("title")) else {
            throw DaemonError("invalid_arg",
                "App has no windows to mirror.")
        }
        return try PIPManager.shared.open(
            windowId: picked.wid, pid: app.processIdentifier,
            title: a.str("title") ?? picked.title, preferredSize: size)
    }

    /// pip_close — all:true wins; window_id is never parsed on the all path.
    func cmdPipClose(_ a: JSONDict) throws -> JSONDict {
        try PIPManager.shared.close(
            windowId: a.int("window_id").map(CGWindowID.init),
            all: a.bool("all") ?? false)
    }

    func cmdPipStatus(_ a: JSONDict) throws -> JSONDict {
        try PIPManager.shared.status()
    }

    /// pip_arm — id+pid direct (ownership enforced); otherwise app/title/
    /// focused/first reselection. Returns the resolved arm tuple.
    func cmdPipArm(_ a: JSONDict) throws -> JSONDict {
        if let wid = a.int("window_id") {
            var pid = a.int("pid").map(pid_t.init)
            if pid == nil {
                // derive owner from CGWindowList for an id-only request
                let list = CGWindowListCopyWindowInfo(
                    .optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
                pid = list.first(where: {
                    ($0[kCGWindowNumber as String] as? NSNumber)?
                        .uint32Value == CGWindowID(wid)
                })?[kCGWindowOwnerPID as String] as? pid_t
            }
            guard let p = pid else {
                throw DaemonError("invalid_arg",
                    "No AX window element for windowId=\(wid) (pid 0)")
            }
            return try PIPMinimizeArmer.shared.arm(
                windowId: CGWindowID(wid), pid: p, title: a.str("title"))
        }
        let app = try resolveApp(a)
        guard let picked = pickWindow(pid: app.processIdentifier,
                                      title: a.str("title")) else {
            throw DaemonError("invalid_arg",
                "App has no windows to arm.")
        }
        return try PIPMinimizeArmer.shared.arm(
            windowId: picked.wid, pid: app.processIdentifier,
            title: a.str("title") ?? picked.title)
    }

    /// pip_disarm — {"disarmed":"all"} | {"disarmed":Bool,"window_id":N};
    /// missing id is rejected, never silently accepted.
    func cmdPipDisarm(_ a: JSONDict) throws -> JSONDict {
        if a.bool("all") ?? false {
            try onMainThread { PIPMinimizeArmer.shared.disarmAll() }
            return ["disarmed": "all"]
        }
        guard let wid = a.int("window_id") else {
            throw DaemonError("invalid_arg",
                "missing \"window_id\" (or pass \"all\": true)")
        }
        let ok = try onMainThread {
            PIPMinimizeArmer.shared.disarm(windowId: CGWindowID(wid))
        }
        return ["disarmed": ok, "window_id": wid]
    }
}
