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
    /// userInfo: {"screenPoint": NSValue(CGPoint), "slideMs": Int} —
    /// the key is `screenPoint` [native-cursor-contract §4]; slideMs
    /// defaults to 180 (disasm literal). Posts are gated by `enabled`
    /// (daemon --lens flag) — Lens visual work only happens when enabled.
    static var enabled = true
    static func postMove(_ p: CGPoint, slideMs: Int = 180) {
        guard enabled else { return }
        NotificationCenter.default.post(name: move, object: nil,
            userInfo: ["screenPoint": NSValue(point: p), "slideMs": slideMs])
    }
    static func postClick() {
        guard enabled else { return }
        NotificationCenter.default.post(name: click, object: nil)
    }
    static func postScroll(direction: String) {
        guard enabled else { return }
        NotificationCenter.default.post(name: scrollBadge, object: nil,
                                        userInfo: ["direction": direction])
    }
    static func postType() {
        guard enabled else { return }
        NotificationCenter.default.post(name: typeBadge, object: nil)
    }
    static func postHide() {
        guard enabled else { return }
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

    /// [DISASM 0x10004f36c–f4cc] nextCascadeOrigin(size:) — a monotonic
    /// global counter (never decremented on close) under `cascadeLock`:
    ///   step  = counter × 28.0   (counter read BEFORE increment)
    ///   x     = max(vf.maxX − w − 24 − step,  vf.minX + 12)
    ///   y     = max(vf.maxY − h − 24 − step,  vf.minY + 12)
    ///   mainScreen nil → (100, 100)
    /// Top-right anchoring in Cocoa coords (visually under the menu bar);
    /// each new floater stairs 28pt down-left. Verified live:
    ///   vf.maxY=949 → h=200 y=725, h=426 n=1 y=471, x 1248→1220→1192→1164.
    private static let cascadeLock = NSLock()
    private static var cascadeCount = 0
    static func nextCascadeOrigin(size: CGSize) -> CGPoint {
        cascadeLock.lock()
        defer { cascadeLock.unlock() }
        let n = cascadeCount
        cascadeCount += 1
        guard let scr = NSScreen.main else {
            return CGPoint(x: 100, y: 100)
        }
        let vf = scr.visibleFrame
        let step = CGFloat(n) * 28.0
        let x = max(vf.maxX - size.width - 24 - step, vf.minX + 12)
        let y = max(vf.maxY - size.height - 24 - step, vf.minY + 12)
        return CGPoint(x: x, y: y)
    }

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
        // [DISASM] window chrome label: "Alma PIP" or "Alma PIP — <title>".
        self.title = (title?.isEmpty == false)
            ? "Alma PIP — \(title!)" : "Alma PIP"
        contentAspectRatio = NSSize(width: 1, height: 1)
        if sourceAspect > 0 {
            contentAspectRatio = NSSize(width: sourceAspect, height: 1)
        }
        contentView = PIPContentView(frame: NSRect(origin: .zero, size: size),
                                     sourceAspect: sourceAspect)
        setFrameOrigin(PIPFloaterWindow.nextCascadeOrigin(size: size))
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
        // [DISASM 0x10004ad14–ada4] default size is aspect-derived:
        //   sourceW=max(sw,1) sourceH=max(sh,1) aspect=W/H
        //   width=min(max(sourceW/3,240),960) height=width/aspect
        let size = preferredSize ?? {
            let sw = max(src.width, 1), sh = max(src.height, 1)
            let aspect = sw / sh
            let w = min(max(sw / 3, 240), 960)
            return CGSize(width: w, height: w / aspect)
        }()
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
        // [DISASM] the observer attaches to the RESOLVED window element
        // only — no app-element fallback (resolution failure installs
        // nothing). The destroyed notification is then authoritative:
        // AX element death can precede CGWindow removal, so no existence
        // re-check; the wid of the dead element is unreadable anyway.
        guard let winEl = ((try? AXBridge.windows(of: pid)) ?? []).first(where: {
            AXBridge.windowIDNumber(of: $0) == windowId
        }) ?? PIPMinimizeArmer.shared.axWindowElement(of: appEl, cgWindowId: windowId)
        else { return }
        let target = winEl
        axWindowElement = target
        var obs: AXObserver?
        guard AXObserverCreate(pid, { _, _, _, ctx in
            guard let ctx else { return }
            let me = Unmanaged<PIPSession>.fromOpaque(ctx)
                .takeUnretainedValue()
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

    /// NotificationCenter observer tokens — removed on shutdown so closed
    /// sessions stop reacting to lens broadcasts [contract: observer cleanup].
    private var lensTokens: [NSObjectProtocol] = []

    /// PIPLens consumes the same "alma.lens.*" broadcast family the action
    /// layer posts — one post drives every open panel's virtual cursor.
    private func subscribeToLensBroadcasts() {
        let nc = NotificationCenter.default
        lensTokens.append(nc.addObserver(forName: LensBus.move, object: nil,
                       queue: .main) { [weak self] n in
            guard let self,
                  let p = (n.userInfo?["screenPoint"] as? NSValue)?.pointValue,
                  let view = self.floater.contentView as? PIPContentView
            else { return }
            // [native-cursor-contract §6] live source-window points map into
            // a centered aspect-fit video rect; points outside the source
            // are rejected; native y is inverted (1 − v).
            let src = self.scWindow.frame
            guard src.width > 0, src.height > 0, src.contains(p) else { return }
            let u = (p.x - src.minX) / src.width
            let v = 1.0 - (p.y - src.minY) / src.height
            let videoBounds = view.videoLayer.bounds
            let scale = min(videoBounds.width / src.width,
                            videoBounds.height / src.height)
            let fitW = src.width * scale, fitH = src.height * scale
            let fit = CGRect(x: videoBounds.midX - fitW / 2,
                             y: videoBounds.midY - fitH / 2,
                             width: fitW, height: fitH)
            let local = CGPoint(x: fit.minX + u * fit.width,
                                y: fit.minY + v * fit.height)
            view.lens.moveTo(local,
                slideMs: n.userInfo?["slideMs"] as? Int ?? 180)
        })
        lensTokens.append(nc.addObserver(forName: LensBus.click, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens.triggerClick()
        })
        lensTokens.append(nc.addObserver(forName: LensBus.scrollBadge, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens
                .showBadge(symbol: "arrow.up.and.down")
        })
        lensTokens.append(nc.addObserver(forName: LensBus.typeBadge, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens
                .showBadge(symbol: "keyboard")
        })
        lensTokens.append(nc.addObserver(forName: LensBus.hide, object: nil,
                       queue: .main) { [weak self] _ in
            (self?.floater.contentView as? PIPContentView)?.lens.hide()
        })
    }

    private func handleStreamError(_ e: Error) {
        pipLog("PIP stream stopped for windowId=\(windowId): \(e)")
        let cb = onClose, wid = windowId
        DispatchQueue.main.async { cb(wid) }
    }

    func shutdown() {
        let nc = NotificationCenter.default
        for t in lensTokens { nc.removeObserver(t) }
        lensTokens.removeAll()
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
    /// pid is retained as JSON null when absent — never omitted
    /// [PIP_EXTRA_CONTRACTS §3 SessionStatus].
    func statusSnapshot() -> JSONDict {
        let f = floater.frame
        return [
            "window_id": Int(windowId),
            "pid": pid.map { Int($0) } ?? NSNull() as Any,
            "title": title,
            "floater_frame": [
                "x": Double(f.origin.x), "y": Double(f.origin.y),
                "w": Double(f.size.width), "h": Double(f.size.height),
            ],
            "has_first_frame": frameCount > 0,
            "last_frame_age_ms": lastFrameAt > 0
                ? Int((CACurrentMediaTime() - lastFrameAt) * 1000.0)
                : NSNull(),
        ]
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
            // [STRINGS 0x100049534–618]
            throw DaemonError("internal",
                "No SCWindow with id \(wid) (window closed or off-screen?)")
        }
        return w
    }

    /// pip_open {window_id, title?, width?, height?, pid?}
    /// [DISASM] existing sessions are checked BEFORE fresh SC lookup and
    /// brought to front; optional pid is preserved (may stay null).
    /// New-session title: provided nonempty ?? SCWindow.title ?? "".
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
        let resolvedTitle = (title?.isEmpty == false) ? title! : (scw.title ?? "")
        return try onMain {
            if let s = sessions[windowId] {
                s.floater.orderFrontRegardless()
                return ["opened": true, "session": s.statusSnapshot()]
            }
            let s = try PIPSession(
                windowId: windowId, pid: pid,
                title: resolvedTitle,
                scWindow: scw, preferredSize: preferredSize
            ) { [weak self] wid in self?.noteClosed(wid) }
            sessions[windowId] = s
            do { try s.start() }
            catch { sessions[windowId] = nil; throw error }
            return ["opened": true, "session": s.statusSnapshot()]
        }
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

    /// Used by the minimize disposition's session-exists check.
    func hasSession(_ wid: CGWindowID) -> Bool {
        onMainThread { sessions[wid] != nil }
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
        let title: String            // stored nonoptional; empty stays ""
        let element: AXUIElement     // the AX window element observed
        var observer: AXObserver?
    }
    private var arms: [CGWindowID: Arm] = [:]
    private let lock = NSLock()

    /// arm — [0x10004e480]. A duplicate ID is a no-op success; the call's
    /// own resolved tuple is echoed (status keeps the original entry).
    /// Fresh entry: find the first AXWindows element whose
    /// _AXUIElementGetWindow equals window_id → else internal
    /// `No AX window element for windowId=N pid=P`; AXObserverCreate
    /// failure → internal `AXObserverCreate failed: <int>`; both
    /// AddNotification return codes are IGNORED.
    func arm(windowId: CGWindowID, pid: pid_t, title: String?) throws {
        try onMain {
            lock.lock()
            let dup = arms[windowId] != nil
            lock.unlock()
            if dup { return } // no-op; response echoes this call's tuple

            let appEl = AXUIElementCreateApplication(pid)
            // (try? ...) — AX enumeration errors are swallowed per contract.
            let wins = (try? AXBridge.windows(of: pid)) ?? []
            guard let el = wins.first(where: {
                AXBridge.windowIDNumber(of: $0) == windowId
            }) ?? axWindowElement(of: appEl, cgWindowId: windowId) else {
                throw DaemonError("internal",
                    "No AX window element for windowId=\(windowId) pid=\(pid)")
            }
            var ob: AXObserver?
            let createErr = AXObserverCreate(pid, { _, el, notif, ctx in
                let me = Unmanaged<PIPMinimizeArmer>.fromOpaque(ctx!)
                    .takeUnretainedValue()
                if (notif as String) == kAXUIElementDestroyedNotification {
                    // A destroyed element's wid is unreadable and AX death
                    // races CG removal — identify the arm by element
                    // identity (registration is on the window element).
                    DispatchQueue.main.async {
                        me.lock.lock()
                        let wid = me.arms.values.first(where: {
                            CFEqual($0.element, el)
                        })?.windowId
                            ?? AXBridge.windowIDNumber(of: el)
                        me.lock.unlock()
                        if let wid { _ = me.disarm(windowId: wid) }
                    }
                } else if (notif as String) == kAXWindowMiniaturizedNotification {
                    guard let wid = AXBridge.windowIDNumber(of: el) else { return }
                    DispatchQueue.main.async { me.didMinimize(windowId: wid) }
                }
            }, &ob)
            guard createErr == .success, let ob else {
                throw DaemonError("internal",
                    "AXObserverCreate failed: \(createErr.rawValue)")
            }
            // Both AddNotification return codes ignored per disasm.
            AXObserverAddNotification(ob, el,
                kAXWindowMiniaturizedNotification as CFString,
                Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(ob, el,
                kAXUIElementDestroyedNotification as CFString,
                Unmanaged.passUnretained(self).toOpaque())
            CFRunLoopAddSource(CFRunLoopGetMain(),
                               AXObserverGetRunLoopSource(ob), .defaultMode)
            lock.lock()
            arms[windowId] = Arm(windowId: windowId, pid: pid,
                                 title: title ?? "",
                                 element: el, observer: ob)
            lock.unlock()
        }
    }

    /// Queued minimize disposition [0x100052cd8+]:
    ///   1. session already open for wid → disarm + return
    ///   2. arm entry gone → return
    ///   3. open(id, pid, nonempty title, nil size) — off-main so the
    ///      SCShareableContent semaphore never blocks the runloop
    ///   4. success → disarm   5. failure → stderr log, retain arm
    private func didMinimize(windowId: CGWindowID) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.lock.lock()
            let a = self.arms[windowId]
            self.lock.unlock()
            guard let a else { return }
            if PIPManager.shared.hasSession(windowId) {
                DispatchQueue.main.async { _ = self.disarm(windowId: windowId) }
                return
            }
            do {
                _ = try PIPManager.shared.open(
                    windowId: windowId, pid: a.pid,
                    title: a.title.isEmpty ? nil : a.title,
                    preferredSize: nil)
                DispatchQueue.main.async {
                    _ = self.disarm(windowId: windowId)
                }
            } catch {
                FileHandle.standardError.write(
                    ("PIP auto-open on minimise failed for wid=\(windowId): "
                     + "\(error.localizedDescription)\n")
                    .data(using: .utf8)!)
            }
        }
    }

    /// disarm [0x10004eabc]: remove entry, remove run-loop source AND both
    /// AX notifications (return codes ignored); returns whether it existed.
    @discardableResult
    func disarm(windowId: CGWindowID) -> Bool {
        lock.lock()
        guard let a = arms.removeValue(forKey: windowId) else {
            lock.unlock(); return false
        }
        lock.unlock()
        if let ob = a.observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(ob), .defaultMode)
            AXObserverRemoveNotification(ob, a.element,
                kAXWindowMiniaturizedNotification as CFString)
            AXObserverRemoveNotification(ob, a.element,
                kAXUIElementDestroyedNotification as CFString)
        }
        return true
    }

    func disarmAll() {
        lock.lock()
        let keys = Array(arms.keys)
        lock.unlock()
        for k in keys { _ = disarm(windowId: k) }
    }

    /// ArmedStatus {window_id, pid, title} — title always present ("" stored).
    func statusList() -> [JSONDict] {
        lock.lock(); defer { lock.unlock() }
        return arms.values.map {
            ["window_id": Int($0.windowId), "pid": Int($0.pid),
             "title": $0.title]
        }
    }

    /// CGWindowID → AX window element.
    /// Primary path is verbatim: app AXWindows + _AXUIElementGetWindow.
    /// Fallback [INFER]: Apple apps (Notes/Calculator) can return the app
    /// element itself from AXWindows; in that case BFS AXChildren (CFEqual
    /// self-loop guard, 64-node cap) for real AXWindow elements.
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

    /// Shared window picker [0x1000890dc–298]: title exact → title
    /// contains → focused (CFEqual vs AXFocusedWindow) → first.
    /// An unmatched title is a preference, not an error. AX enumeration
    /// errors are swallowed to an empty list.
    private func pickWindow(pid: pid_t, title: String?)
        -> (wid: CGWindowID, title: String?)? {
        let app = AXUIElementCreateApplication(pid)
        let wins = (try? AXBridge.windows(of: pid)) ?? []
        guard !wins.isEmpty else { return nil }
        var target: AXUIElement?
        if let t = title, !t.isEmpty {
            target = wins.first {
                AXBridge.copyString($0, kAXTitleAttribute) == t
            } ?? wins.first {
                AXBridge.copyString($0, kAXTitleAttribute)?.contains(t)
                    == true
            }
        }
        if target == nil,
           let focused = AXBridge.copyAttr(app,
                    kAXFocusedWindowAttribute) as! AXUIElement? {
            target = wins.first { CFEqual($0, focused) }
        }
        target = target ?? wins.first
        guard let el = target,
              let wid = AXBridge.windowIDNumber(of: el)
        else { return nil }
        return (wid, AXBridge.copyString(el, kAXTitleAttribute))
    }

    /// pip_open — direct window_id path takes no ownership/bundle
    /// resolution; app path: resolveApp → selectWindow rules. Partial or
    /// nonpositive width/height collapses to nil preferred size. Empty
    /// resolved title becomes nil before manager.open [0x10007c6a8–c7c0].
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
            throw DaemonError("internal", "App has no windows to mirror.")
        }
        return try PIPManager.shared.open(
            windowId: picked.wid, pid: app.processIdentifier,
            title: picked.title, preferredSize: size)
    }

    /// pip_close — `all` is read FIRST; window_id is never parsed on the
    /// all path (invalid/out-of-range input included) [0x10007c70c–c7b4].
    func cmdPipClose(_ a: JSONDict) throws -> JSONDict {
        if a.bool("all") ?? false {
            return try PIPManager.shared.close(windowId: nil, all: true)
        }
        guard let wid = a.int("window_id") else {
            throw DaemonError("invalid_arg",
                "missing \"window_id\" (or pass \"all\": true)")
        }
        return try PIPManager.shared.close(
            windowId: CGWindowID(wid), all: false)
    }

    func cmdPipStatus(_ a: JSONDict) throws -> JSONDict {
        try PIPManager.shared.status()
    }

    /// pip_arm — direct path requires BOTH window_id AND pid (no CG
    /// derivation for id-only); otherwise resolveApp → selectWindow.
    /// Response: {"armed":{window_id,pid,title:<resolved, may be "">}}.
    func cmdPipArm(_ a: JSONDict) throws -> JSONDict {
        var wid: CGWindowID
        var pid: pid_t
        var title: String
        if let w = a.int("window_id"), let p = a.int("pid") {
            wid = CGWindowID(w)
            pid = pid_t(p)
            title = a.str("title") ?? ""
        } else {
            let app = try resolveApp(a)
            guard let picked = pickWindow(pid: app.processIdentifier,
                                          title: a.str("title")) else {
                throw DaemonError("internal", "App has no windows to arm.")
            }
            wid = picked.wid
            pid = app.processIdentifier
            title = picked.title ?? ""
        }
        try PIPMinimizeArmer.shared.arm(
            windowId: wid, pid: pid,
            title: title.isEmpty ? nil : title)
        return ["armed": ["window_id": Int(wid), "pid": Int(pid),
                          "title": title]]
    }

    /// pip_disarm — `all` first, same contract as pip_close:
    /// {"disarmed":"all"} | {"disarmed":Bool,"window_id":N}.
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
