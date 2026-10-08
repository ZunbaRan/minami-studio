import AppKit
import CoreGraphics
import Foundation

// Capture subsystem: window screenshots (CGWindowList), display shots,
// screenshot→screen coordinate translation, per-pid mapping persistence.
// Verified: nested screenshot {path,width,height} response; default path
// /tmp/alma-cu-state-<ms>.jpg; coord_space "screenshot" resolves against the
// last screenshot's window rect; window capture refuses tiny windows (<14pt).

enum Capture {

    struct ShotResult {
        var path: String
        var width: Int
        var height: Int
    }

    /// Window screenshot at `wid` (or the app's front window). Downsamples to
    /// `maxWidth` px on the long edge when larger. Writes JPEG to
    /// /tmp/alma-cu-state-<ms>.jpg unless `outPath` given.
    static func windowShot(pid: pid_t, wid: CGWindowID?, maxWidth: Int, outPath: String? = nil) throws -> ShotResult {
        guard CGPreflightScreenCaptureAccess() else {
            throw DaemonError("sc_not_granted", "screen recording permission not granted")
        }
        let resolvedWid: CGWindowID? = wid ?? CGWindowID(WindowList.frontWindowID(pid: pid) ?? 0)
        guard let wid = resolvedWid, wid != 0 else {
            throw DaemonError("screenshot_error", "no capturable window for pid \(pid)")
        }
        let rect = windowScreenRect(wid: wid)
        guard let rect else {
            throw DaemonError("screenshot_error", "window \(wid) has no screen rect")
        }
        // Alma refuses windows that are too small to capture meaningfully.
        if rect.width < 14 || rect.height < 14 {
            throw DaemonError("screenshot_error", "window too small to capture (\(Int(rect.width))x\(Int(rect.height)))")
        }
        let listOption: CGWindowListOption = [.optionIncludingWindow]
        // CGWindowListCreateImage proxies through ScreenCaptureKit on modern
        // macOS; inside an NSApp.run() process its reply path wedges when
        // called from a worker thread — run it on the main queue.
        let image = onMainThread {
            CGWindowListCreateImage(.null, listOption, wid,
                [.boundsIgnoreFraming, .bestResolution])
        }
        guard let image else {
            throw DaemonError("screenshot_error", "window capture returned no image")
        }

        let finalImage: CGImage
        if image.width > maxWidth {
            let scale = Double(maxWidth) / Double(image.width)
            let w = maxWidth, h = max(1, Int(Double(image.height) * scale))
            let ctx = CGContext(
                data: nil, width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            ctx?.interpolationQuality = .high
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            finalImage = ctx?.makeImage() ?? image
        } else {
            finalImage = image
        }

        let path = outPath ?? "/tmp/alma-cu-state-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        try writeJPEG(finalImage, to: path)
        registerMapping(pid: pid, wid: wid, windowRect: rect, imageW: finalImage.width, imageH: finalImage.height, path: path)
        return ShotResult(path: path, width: finalImage.width, height: finalImage.height)
    }

    /// Full-display screenshot (`shot_display`).
    static func displayShot(maxWidth: Int, outPath: String? = nil) throws -> ShotResult {
        guard CGPreflightScreenCaptureAccess() else {
            throw DaemonError("sc_not_granted", "screen recording permission not granted")
        }
        guard let image = onMainThread({
            CGWindowListCreateImage(
                .infinite, .optionOnScreenOnly, kCGNullWindowID,
                [.boundsIgnoreFraming, .bestResolution]
            ) }) else {
            throw DaemonError("screenshot_error", "display capture returned no image")
        }
        let path = outPath ?? "/tmp/alma-cu-state-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        try writeJPEG(image, to: path)
        return ShotResult(path: path, width: image.width, height: image.height)
    }

    private static func writeJPEG(_ image: CGImage, to path: String) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw DaemonError("screenshot_error", "jpeg encode failed")
        }
        do { try data.write(to: URL(fileURLWithPath: path)) }
        catch { throw DaemonError("screenshot_error", "write \(path) failed: \(error.localizedDescription)") }
    }

    // MARK: - screenshot ↔ screen coordinate mapping (per-pid persistence)

    struct Mapping {
        var wid: CGWindowID
        var windowRect: CGRect
        var imageW: Int
        var imageH: Int
        var path: String
    }

    private static var mappings: [pid_t: Mapping] = [:]
    private static let mapLock = NSLock()

    static func registerMapping(pid: pid_t, wid: CGWindowID, windowRect: CGRect, imageW: Int, imageH: Int, path: String) {
        mapLock.lock()
        mappings[pid] = Mapping(wid: wid, windowRect: windowRect, imageW: imageW, imageH: imageH, path: path)
        mapLock.unlock()
    }

    static func mapping(for pid: pid_t) -> Mapping? {
        mapLock.lock(); defer { mapLock.unlock() }
        return mappings[pid]
    }

    /// coord_space "screenshot": scale image px → window points → screen.
    /// coord_space "screen": pass through.
    static func translateScreenshotCoord(pid: pid_t, x: Double, y: Double) throws -> CGPoint {
        guard let m = mapping(for: pid) else {
            throw DaemonError("invalid_arg", "no screenshot mapping for pid \(pid); run get_app_state first")
        }
        let sx = m.windowRect.width / Double(m.imageW)
        let sy = m.windowRect.height / Double(m.imageH)
        return CGPoint(
            x: m.windowRect.origin.x + x * sx,
            y: m.windowRect.origin.y + y * sy
        )
    }

    /// CGWindowList rect for a window id (screen coordinates, top-left origin).
    static func windowScreenRect(wid: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], wid) as? [[String: Any]],
              let entry = list.first,
              let bounds = entry[kCGWindowBounds as String] as? [String: Any]
        else { return nil }
        return CGRect(
            x: bounds["X"] as? Double ?? 0, y: bounds["Y"] as? Double ?? 0,
            width: bounds["Width"] as? Double ?? 0, height: bounds["Height"] as? Double ?? 0
        )
    }
}

// MARK: - WindowList

enum WindowList {
    /// Front-most on-screen window id for pid (CGWindowList order).
    static func frontWindowID(pid: pid_t) -> CGWindowID? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for entry in list {
            if (entry[kCGWindowOwnerPID as String] as? Int32) == pid,
               let wid = (entry[kCGWindowNumber as String] as? NSNumber)?.uint32Value {
                return wid
            }
        }
        return nil
    }

    /// All on-screen windows for pid, front-to-back.
    static func windows(pid: pid_t) -> [[String: Any]] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
    }
}
