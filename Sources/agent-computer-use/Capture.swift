import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit
import Vision

// Capture subsystem — rebuilt on Alma's actual path:
//   one-shot window/display images come from SCScreenshotManager
//   (SCContentFilter desktopIndependentWindow / display), scale = main
//   screen backingScaleFactor, showsCursor=false, capturesAudio=false,
//   ignoreShadowsSingleWindow, frameInterval 1/60. macOS <14 → internal
//   "SCScreenshotManager requires macOS 14+. Please update macOS."
//   JPEG encode failure → "Failed to encode JPEG." (verbatim).
//   Coordinate mapping + ActionCursor + Vision OCR fallback per contract.

enum Capture {

    // MARK: - ShareableContentCache [FINDINGS §8]
    //
    // windowTTL 2s / displayTTL 30s, strict `< maxAge` freshness, one
    // in-flight fetch coalesced across callers. Fetch failure invalidates
    // content+fetchedAt (NOT inFlight bookkeeping of a joiner) and
    // normalizes the creator's error to sc_denied. window(id) miss →
    // invalidate → one fresh() retry → nil.

    private static var content: SCShareableContent?
    private static var fetchedAt = Date.distantPast
    private static var inFlight = false
    private static var inFlightSem: DispatchSemaphore?
    private static var inFlightResult: SCShareableContent?
    private static var inFlightError: DaemonError?
    private static var lastSuccess = Date.distantPast
    private static let cacheLock = NSLock()
    private static let windowTTL = 2.0, displayTTL = 30.0

    private static func invalidate() {
        content = nil; fetchedAt = .distantPast
    }

    /// actor fresh(maxAge:) — called under no lock; synchronizes the
    //  in-flight join via a semaphore stored at task creation.
    private static func fresh(maxAge: TimeInterval) throws
        -> SCShareableContent {
        cacheLock.lock()
        if let c = content,
           Date().timeIntervalSince(fetchedAt) < maxAge {
            cacheLock.unlock(); return c
        }
        if inFlight, let sem = inFlightSem {
            cacheLock.unlock()
            sem.wait()
            cacheLock.lock()
            defer { cacheLock.unlock() }
            if let r = inFlightResult { return r }
            throw inFlightError
                ?? DaemonError("sc_not_granted",
                    "Screen Recording permission not granted to "
                    + "agent-computer-use.")
        }
        inFlight = true
        let mySem = DispatchSemaphore(value: 0)
        inFlightSem = mySem
        cacheLock.unlock()

        var result: SCShareableContent?
        var failure: Error?
        SCShareableContent.getWithCompletionHandler { c, e in
            result = c; failure = e; mySem.signal()
        }
        mySem.wait() // no artificial timeout — Alma awaits unbounded

        cacheLock.lock()
        if let result, failure == nil {
            content = result
            fetchedAt = Date()
            lastSuccess = fetchedAt
            inFlightResult = result; inFlightError = nil
        } else {
            invalidate()
            inFlightResult = nil
            // creator failure normalizes to sc_not_granted
            inFlightError = DaemonError("sc_not_granted",
                "Screen Recording permission not granted to "
                + "agent-computer-use.")
        }
        inFlight = false
        let r = inFlightResult, e = inFlightError
        cacheLock.unlock()
        // wake joiners — they read the shared slot under the lock
        mySem.signal()
        if let r { return r }
        throw e ?? DaemonError("sc_not_granted",
            "Screen Recording permission not granted to "
            + "agent-computer-use.")
    }

    /// cache window(id): fresh(2s) → search → miss → invalidate →
    /// fresh(2s) retry → search → nil.
    static func scWindow(for wid: CGWindowID) throws -> SCWindow {
        var content = try fresh(maxAge: windowTTL)
        if let w = content.windows.first(where: { $0.windowID == wid }) {
            return w
        }
        cacheLock.lock(); invalidate(); cacheLock.unlock()
        content = try fresh(maxAge: windowTTL)
        guard let w = content.windows.first(where: { $0.windowID == wid })
        else {
            throw DaemonError("internal",
                "No SCWindow with id \(wid) (was the window closed?)")
        }
        return w
    }

    /// Display content uses the 30s TTL. Unknown/absent display_id falls
    /// back to the FIRST display [live probe: bogus display_id still
    /// captures].
    private static func scDisplay(for displayID: CGDirectDisplayID?)
        throws -> SCDisplay {
        let content = try fresh(maxAge: displayTTL)
        if let displayID,
           let d = content.displays.first(where: {
               $0.displayID == displayID }) {
            return d
        }
        guard let d = content.displays.first else {
            throw DaemonError("internal", "No shareable display available")
        }
        return d
    }

    /// Screen Recording permission probe — cached once by the daemon boot
    /// path; permissions cmd reports the cached probe, falling back to
    /// CGPreflight until the async probe has landed.
    private static var scPermCache: Bool?
    private static let scPermLock = NSLock()

    static func probeScreenRecording() {
        SCShareableContent.getWithCompletionHandler { content, err in
            scPermLock.lock()
            scPermCache = (err == nil && content != nil)
            scPermLock.unlock()
        }
    }

    static func screenRecordingCached() -> Bool {
        scPermLock.lock(); defer { scPermLock.unlock() }
        return scPermCache ?? CGPreflightScreenCaptureAccess()
    }

    // MARK: - one-shot capture (SCScreenshotManager)

    private static func captureImage(filter: SCContentFilter,
                                     pixelSize: CGSize) throws -> CGImage {
        guard #available(macOS 14.0, *) else {
            throw DaemonError("internal",
                "SCScreenshotManager requires macOS 14+. "
                + "Please update macOS.")
        }
        let cfg = SCStreamConfiguration()
        cfg.width = max(1, Int(pixelSize.width))
        cfg.height = max(1, Int(pixelSize.height))
        cfg.showsCursor = false
        cfg.capturesAudio = false
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        cfg.ignoreShadowsSingleWindow = true
        var result: CGImage?
        var failure: Error?
        let sem = DispatchSemaphore(value: 0)
        SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: cfg) { img, err in
            result = img; failure = err; sem.signal()
        }
        sem.wait() // awaited unbounded — no artificial timeout
        if let failure { throw DaemonError.wrap(failure) }
        guard let img = result else {
            throw DaemonError("internal", "capture returned no image")
        }
        return img
    }

    /// The width limit is applied BEFORE capture: the requested pixel
    /// size is clamped to maxWidth (proportionally), so the returned
    /// image is already within budget.
    private static func limitedSize(frame: CGRect, scale: CGFloat,
                                    maxWidth: Int) -> CGSize {
        var w = frame.width * scale, h = frame.height * scale
        if maxWidth > 0, Int(w) > maxWidth {
            let ratio = Double(maxWidth) / Double(w)
            w = CGFloat(maxWidth)
            h = CGFloat(max(1, Int(Double(h) * ratio)))
        }
        return CGSize(width: max(1, w), height: max(1, h))
    }

    /// Window JPEG: capture size = SCWindow.frame × main-screen scale,
    /// clamped to maxWidth before the filter is configured.
    static func windowShotToFile(wid: CGWindowID, out: String,
                                 maxWidth: Int, quality: Double)
        throws -> (Int, Int) {
        let scw = try scWindow(for: wid)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let px = limitedSize(frame: scw.frame, scale: scale,
                             maxWidth: maxWidth)
        let filter = SCContentFilter(desktopIndependentWindow: scw)
        let img = try captureImage(filter: filter, pixelSize: px)
        try writeJPEG(img, to: out, quality: quality)
        return (img.width, img.height)
    }

    /// Display JPEG: `displayID` nil OR unmatched → the FIRST SCDisplay
    /// (never an infinite composite of every screen, never an error).
    static func displayShotToFile(displayID: CGDirectDisplayID?,
                                  out: String, maxWidth: Int,
                                  quality: Double)
        throws -> (Int, Int, CGDirectDisplayID) {
        let d = try scDisplay(for: displayID)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let px = limitedSize(frame: d.frame, scale: scale,
                             maxWidth: maxWidth)
        let filter = SCContentFilter(display: d,
            excludingApplications: [], exceptingWindows: [])
        let img = try captureImage(filter: filter, pixelSize: px)
        try writeJPEG(img, to: out, quality: quality)
        return (img.width, img.height, d.displayID)
    }

    private static func writeJPEG(_ image: CGImage, to path: String,
                                  quality: Double) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(
                using: .jpeg,
                properties: [.compressionFactor: quality]) else {
            throw DaemonError("internal", "Failed to encode JPEG.")
        }
        do { try data.write(to: URL(fileURLWithPath: path)) }
        catch { throw DaemonError.wrap(error) }
    }

    static func defaultOutPath() -> String {
        "/tmp/alma-cu-state-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
    }

    // MARK: - ActionCursor emission (logical cursor, ≤8s, in-bounds)

    private static func cursorDict(in rect: CGRect?) -> JSONDict? {
        guard let rect, let n = ActionCursor.normalized(in: rect)
        else { return nil }
        return ["x": n.x, "y": n.y]
    }

    static func cursorForShot(wid: CGWindowID) -> JSONDict? {
        cursorDict(in: windowScreenRect(wid: wid))
    }

    static func cursorForDisplay(_ displayID: CGDirectDisplayID) -> JSONDict? {
        cursorDict(in: CGDisplayBounds(displayID))
    }

    // MARK: - screenshot ↔ screen coordinate mapping (per-pid persistence)

    struct Mapping {
        var wid: CGWindowID
        var windowRect: CGRect
        var imageW: Int
        var imageH: Int
        var path: String
        /// image px → screen point
        func point(forX x: Double, y: Double) -> CGPoint {
            CGPoint(
                x: windowRect.origin.x
                    + x * windowRect.width / Double(imageW),
                y: windowRect.origin.y
                    + y * windowRect.height / Double(imageH))
        }
    }

    private static var mappings: [pid_t: Mapping] = [:]
    private static let mapLock = NSLock()

    static func registerMapping(pid: pid_t, wid: CGWindowID,
                                windowRect: CGRect, imageW: Int,
                                imageH: Int, path: String) {
        mapLock.lock()
        mappings[pid] = Mapping(wid: wid, windowRect: windowRect,
                                imageW: imageW, imageH: imageH, path: path)
        mapLock.unlock()
    }

    static func mapping(for pid: pid_t) -> Mapping? {
        mapLock.lock(); defer { mapLock.unlock() }
        return mappings[pid]
    }

    // MARK: - visual refs [FINDINGS §6/VisualIndex]
    //
    // visualRefs[pid] = ref → SCREENSHOT-PIXEL CGRect (replaced only when
    // a nonempty region set is produced — a skipped/empty/failed OCR call
    // leaves the stale table in place). Click on vN takes the rect's
    // center and translates it through the pid's CURRENT mapping.

    private static var visualRefTable: [pid_t: [String: CGRect]] = [:]

    /// v-ref → desktop point: stored pixel-rect center through the
    /// pid's current mapping. nil when the ref is unknown.
    static func visualRefPoint(pid: pid_t, ref: String) -> CGPoint? {
        mapLock.lock()
        let rect = visualRefTable[pid]?[ref]
        mapLock.unlock()
        guard let rect = rect else { return nil }
        let cx = rect.origin.x + rect.size.width / 2
        let cy = rect.origin.y + rect.size.height / 2
        mapLock.lock()
        let m = mappings[pid]
        mapLock.unlock()
        return m?.point(forX: cx, y: cy)
    }

    /// Vision fast OCR over the last gas screenshot. Refs restart at v1
    /// per call; accepted refs cap at maxResults 80; NO confidence
    /// threshold/sort (only nonempty-text filter). Emits
    /// {ref,text,bounds{x,y,w,h},confidence} where bounds are screenshot
    /// pixel coordinates. On nonempty output the pid's visualRefs table
    /// is replaced; empty/error leaves the previous table untouched.
    static func ocrRegions(imagePath: String, pid: pid_t) -> [JSONDict]? {
        guard let img = NSImage(contentsOfFile: imagePath)?.cgImage(
                  forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        req.recognitionLanguages = ["en-US", "zh-Hans"]
        req.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        try? handler.perform([req])
        guard let observations = req.results else { return nil }
        var refs: [String: CGRect] = [:]
        var out: [JSONDict] = []
        var accepted = 0
        for obs in observations {
            if accepted >= 80 { break } // maxResults
            guard let cand = obs.topCandidates(1).first,
                  !cand.string.isEmpty else { continue }
            accepted += 1
            let ref = "v\(accepted)"
            // VN normalized lower-left → screenshot-pixel top-left
            let b = obs.boundingBox
            let px = b.origin.x * Double(img.width)
            let py = (1 - b.origin.y - b.height) * Double(img.height)
            let pw = b.width * Double(img.width)
            let ph = b.height * Double(img.height)
            refs[ref] = CGRect(x: px, y: py, width: pw, height: ph)
            out.append([
                "ref": ref, "text": cand.string,
                "confidence": Double(cand.confidence),
                "bounds": [
                    "x": px, "y": py, "w": pw, "h": ph,
                ],
            ])
        }
        guard !out.isEmpty else { return nil }
        mapLock.lock()
        visualRefTable[pid] = refs
        mapLock.unlock()
        return out
    }

    // MARK: - settle hash source (CG image bytes on the main thread — the
    // SCK-proxied CGWindowListCreateImage wedges off-main under NSApp)

    static func rgbaBytes(of wid: CGWindowID) -> Data? {
        guard let img = onMainThread({
            CGWindowListCreateImage(.null, [.optionIncludingWindow], wid,
                [.boundsIgnoreFraming])
        }), let provider = img.dataProvider,
           let data = provider.data as Data?
        else { return nil }
        return data
    }

    /// CGWindowList rect for a window id (screen coordinates, top-left).
    static func windowScreenRect(wid: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo(
                [.optionIncludingWindow], wid) as? [[String: Any]],
              let entry = list.first,
              let bounds = entry[kCGWindowBounds as String] as? [String: Any]
        else { return nil }
        return CGRect(
            x: bounds["X"] as? Double ?? 0,
            y: bounds["Y"] as? Double ?? 0,
            width: bounds["Width"] as? Double ?? 0,
            height: bounds["Height"] as? Double ?? 0)
    }
}

// MARK: - WindowList

enum WindowList {
    /// Front-most on-screen window id for pid (CGWindowList order).
    static func frontWindowID(pid: pid_t) -> CGWindowID? {
        guard let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for entry in list {
            if (entry[kCGWindowOwnerPID as String] as? Int32) == pid,
               let wid = (entry[kCGWindowNumber as String] as? NSNumber)?
                   .uint32Value {
                return wid
            }
        }
        return nil
    }

    /// All on-screen windows for pid, front-to-back.
    static func windows(pid: pid_t) -> [[String: Any]] {
        guard let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return list.filter {
            ($0[kCGWindowOwnerPID as String] as? Int32) == pid
        }
    }
}
