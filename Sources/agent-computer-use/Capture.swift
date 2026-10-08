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

    // MARK: - SCShareableContent bridge (worker-thread safe; main runloop
    // spins so the async delivery lands)

    private static func shareableContent() throws -> SCShareableContent {
        var result: SCShareableContent?
        var failure: Error?
        let sem = DispatchSemaphore(value: 0)
        SCShareableContent.getWithCompletionHandler { content, err in
            result = content; failure = err; sem.signal()
        }
        if sem.wait(timeout: .now() + 5) == .timedOut {
            throw DaemonError("internal", "SCShareableContent timed out")
        }
        if let failure { throw DaemonError.wrap(failure) }
        guard let c = result else {
            throw DaemonError("internal", "no shareable content")
        }
        return c
    }

    static func scWindow(for wid: CGWindowID) throws -> SCWindow {
        let content = try shareableContent()
        guard let w = content.windows.first(where: { $0.windowID == wid })
        else {
            throw DaemonError("internal",
                "No SCWindow with id \(wid) (was the window closed?)")
        }
        return w
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
        if sem.wait(timeout: .now() + 10) == .timedOut {
            throw DaemonError("internal", "SCScreenshotManager timed out")
        }
        if let failure { throw DaemonError.wrap(failure) }
        guard let img = result else {
            throw DaemonError("internal", "capture returned no image")
        }
        return img
    }

    /// Window JPEG: point dimensions = SCWindow.frame × main-screen scale,
    /// then downsampled to maxWidth when positive.
    static func windowShotToFile(wid: CGWindowID, out: String,
                                 maxWidth: Int, quality: Double)
        throws -> (Int, Int) {
        let scw = try scWindow(for: wid)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let px = CGSize(width: scw.frame.width * scale,
                        height: scw.frame.height * scale)
        let filter = SCContentFilter(desktopIndependentWindow: scw)
        var img = try captureImage(filter: filter, pixelSize: px)
        if maxWidth > 0, img.width > maxWidth {
            img = downscale(img, toWidth: maxWidth)
        }
        try writeJPEG(img, to: out, quality: quality)
        return (img.width, img.height)
    }

    /// Display JPEG: `displayID` nil → the FIRST SCDisplay (not an
    /// infinite composite of every screen).
    static func displayShotToFile(displayID: CGDirectDisplayID?,
                                  out: String, maxWidth: Int,
                                  quality: Double)
        throws -> (Int, Int, CGDirectDisplayID) {
        let content = try shareableContent()
        let scd: SCDisplay?
        if let displayID {
            scd = content.displays.first { $0.displayID == displayID }
        } else {
            scd = content.displays.first
        }
        guard let d = scd else {
            throw DaemonError("internal", "No shareable display available")
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let px = CGSize(width: d.frame.width * scale,
                        height: d.frame.height * scale)
        let filter = SCContentFilter(display: d,
            excludingApplications: [], exceptingWindows: [])
        var img = try captureImage(filter: filter, pixelSize: px)
        if maxWidth > 0, img.width > maxWidth {
            img = downscale(img, toWidth: maxWidth)
        }
        try writeJPEG(img, to: out, quality: quality)
        return (img.width, img.height, d.displayID)
    }

    private static func downscale(_ image: CGImage,
                                  toWidth maxWidth: Int) -> CGImage {
        let scale = Double(maxWidth) / Double(image.width)
        let w = maxWidth, h = max(1, Int(Double(image.height) * scale))
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
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

    // MARK: - visual refs (OCR fallback regions → clickable vN points)

    private static var visualRefTable: [pid_t: [String: CGPoint]] = [:]

    static func visualRef(pid: pid_t, ref: String) -> CGPoint? {
        mapLock.lock(); defer { mapLock.unlock() }
        return visualRefTable[pid]?[ref]
    }

    /// Vision fast OCR over the last gas screenshot; publishes vN refs as
    /// SCREEN points (translated through the pid's mapping). Returns wire
    /// region dicts or nil when OCR can't run / produced nothing.
    static func ocrRegions(imagePath: String, pid: pid_t) -> [JSONDict]? {
        guard let m = mapping(for: pid),
              let img = NSImage(contentsOfFile: imagePath)?.cgImage(
                  forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .fast
        req.recognitionLanguages = ["en-US", "zh-Hans"]
        req.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: img, options: [:])
        try? handler.perform([req])
        guard let observations = req.results,
              !observations.isEmpty else { return nil }
        var refs: [String: CGPoint] = [:]
        var out: [JSONDict] = []
        for (i, obs) in observations.prefix(80).enumerated() {
            guard let text = obs.topCandidates(1).first?.string,
                  !text.isEmpty else { continue }
            // VN boxes are normalized, bottom-left origin → image px
            // top-left origin.
            let b = obs.boundingBox
            let px = b.origin.x * Double(img.width)
            let py = (1 - b.origin.y - b.height) * Double(img.height)
            let pw = b.width * Double(img.width)
            let ph = b.height * Double(img.height)
            let center = m.point(forX: px + pw / 2, y: py + ph / 2)
            let ref = "v\(i + 1)"
            refs[ref] = center
            let tl = m.point(forX: px, y: py)
            let br = m.point(forX: px + pw, y: py + ph)
            out.append([
                "ref": ref, "text": text,
                "bounds": [
                    "x": tl.x, "y": tl.y,
                    "w": br.x - tl.x, "h": br.y - tl.y,
                ],
            ])
        }
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
