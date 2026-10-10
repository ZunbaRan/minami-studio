import Foundation
import AppKit
import AVFoundation
import CoreImage
import CoreGraphics

// MARK: - Zoom export (minami-studio extension — beyond-Alma territory)
//
// Offline compositor: raw recording (cursor never baked) + .cursor.json
// telemetry → auto-zoomed mp4. Camera model is a reimplementation of
// Recordly's post-production zoom (docs/RECORDLY-ZOOM-PIPELINE.md):
// click-cluster → ZoomRegion → easeOutZoom strength → focus-anchored
// affine → cursor-follow safe zone → chained pan → cursor re-rendered
// on top. Math/constants ported; no upstream code copied.

// MARK: Timing / scale constants (Recordly parity)

private enum ZM {
    static let transitionWindowMs = 1015.05
    static let zoomInWindowMs = transitionWindowMs * 1.5      // 1522.575
    static let zoomOutEarlyStartMs = 500.0
    static let zoomInOverlapMs = 1000.0
    static let animationDelayMs = 500.0
    static let chainedPanGapMs = 1350.0
    static let chainedPanDurationMs = 1000.0
    static let safeZoneRatio = 0.25
    static let clusterMergeGapMs = 2500.0
    static let clusterPadMs = 500.0
    static let clickRingMs = 500.0
    static let depthScales: [Int: Double] = [1: 1.25, 2: 1.5, 3: 1.8, 4: 2.2, 5: 3.5, 6: 5.0]
    static let defaultDepth = 3
}

// MARK: Data model

struct ZoomFocus {
    var cx: Double
    var cy: Double
}

struct ZoomRegion {
    var startMs: Double
    var endMs: Double
    var focus: ZoomFocus
    var depth: Int
}

struct CursorSample {
    var timeMs: Double
    var cx: Double
    var cy: Double
    var interactionType: String
}

// MARK: - Easing (mathUtils.ts port)

private func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }

private func sampleBezier(_ a1: Double, _ a2: Double, _ t: Double) -> Double {
    let u = 1 - t
    return 3 * a1 * u * u * t + 3 * a2 * u * t * t + t * t * t
}

private func sampleBezierDerivative(_ a1: Double, _ a2: Double, _ t: Double) -> Double {
    let u = 1 - t
    return 3 * a1 * u * u + 6 * (a2 - a1) * u * t + 3 * (1 - a2) * t * t
}

private func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                         _ t: Double) -> Double {
    let targetX = clamp01(t)
    var solvedT = targetX
    for _ in 0..<8 {
        let cx = sampleBezier(x1, x2, solvedT) - targetX
        let d = sampleBezierDerivative(x1, x2, solvedT)
        if abs(cx) < 1e-6 || abs(d) < 1e-6 { break }
        solvedT -= cx / d
    }
    var lo = 0.0, hi = 1.0
    solvedT = clamp01(solvedT)
    for _ in 0..<10 {
        let cx = sampleBezier(x1, x2, solvedT)
        if abs(cx - targetX) < 1e-6 { break }
        if cx < targetX { lo = solvedT } else { hi = solvedT }
        solvedT = (lo + hi) / 2
    }
    return sampleBezier(y1, y2, solvedT)
}

private func easeOutZoom(_ t: Double) -> Double { cubicBezier(0.16, 1, 0.3, 1, t) }

private func easeInOutCubic(_ t: Double) -> Double {
    let x = clamp01(t)
    return x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
}

// MARK: - Auto-zoom generation (zoomSuggestionUtils.ts port)

/// What the cursor did after a click — sets cluster strength, which picks
/// the cluster's focus click.
private enum ClickKind {
    case doubleClick, textSelection, dropdownOpen, textField, clickLike

    var strength: Double {
        switch self {
        case .doubleClick: return 1500
        case .textSelection: return 1300
        case .dropdownOpen: return 1200
        case .textField: return 1100
        case .clickLike: return 900
        }
    }
}

private let explicitClickTypes: Set<String> =
    ["click", "double-click", "right-click", "middle-click"]

private func classifyPostClick(samples: [CursorSample],
                               click: CursorSample) -> ClickKind {
    if click.interactionType == "double-click" { return .doubleClick }

    if let up = samples.first(where: {
        $0.interactionType == "mouseup" &&
        $0.timeMs > click.timeMs && $0.timeMs - click.timeMs < 3000
    }) {
        let dx = abs(up.cx - click.cx), dy = abs(up.cy - click.cy)
        if up.timeMs - click.timeMs >= 200 && dx > 0.03 && dx > dy * 1.8 {
            return .textSelection
        }
    }

    let moves = samples.filter {
        $0.interactionType == "move" &&
        $0.timeMs > click.timeMs + 100 && $0.timeMs <= click.timeMs + 2000
    }
    if moves.isEmpty { return .clickLike }

    var maxDist = 0.0, sumDx = 0.0, sumDy = 0.0
    for s in moves {
        maxDist = max(maxDist, hypot(s.cx - click.cx, s.cy - click.cy))
        sumDx += abs(s.cx - click.cx)
        sumDy += abs(s.cy - click.cy)
    }
    if maxDist < 0.02 { return .textField }
    let netDy = moves.last!.cy - click.cy
    if netDy > 0.03 && sumDy > sumDx * 1.5 { return .dropdownOpen }
    if sumDx > 0.03 && sumDx > sumDy * 1.8 { return .textSelection }
    return .clickLike
}

private func buildClickClusters(_ clicks: [(ms: Double, focus: ZoomFocus, strength: Double)],
                                mergeGapMs: Double) -> [ZoomRegion] {
    guard let first0 = clicks.first else { return [] }
    var clusters: [(first: Double, last: Double, focus: ZoomFocus)] = []
    var first = first0.ms, last = first0.ms
    var bestStrength = first0.strength, bestFocus = first0.focus

    for click in clicks.dropFirst() {
        if click.ms - last <= mergeGapMs {
            last = max(last, click.ms)
            if click.strength > bestStrength {
                bestStrength = click.strength
                bestFocus = click.focus
            }
        } else {
            clusters.append((first, last, bestFocus))
            first = click.ms; last = click.ms
            bestStrength = click.strength; bestFocus = click.focus
        }
    }
    clusters.append((first, last, bestFocus))
    return clusters.map {
        ZoomRegion(startMs: $0.first, endMs: $0.last, focus: $0.focus,
                   depth: ZM.defaultDepth)
    }
}

/// Click events → suggested regions (clusters ± pad, clipped to [0,totalMs]).
enum ZoomSuggest {
    static func regions(samples: [CursorSample], totalMs: Double,
                        depth: Int) -> [ZoomRegion] {
        let clicks = samples
            .filter { explicitClickTypes.contains($0.interactionType) }
            .sorted { $0.timeMs < $1.timeMs }
            .map { (ms: $0.timeMs, focus: ZoomFocus(cx: $0.cx, cy: $0.cy),
                    strength: classifyPostClick(samples: samples, click: $0).strength) }
        guard !clicks.isEmpty else { return [] }

        var taken: [(Double, Double)] = []
        var out: [ZoomRegion] = []
        for cluster in buildClickClusters(clicks, mergeGapMs: ZM.clusterMergeGapMs) {
            let start = max(0, cluster.startMs - ZM.clusterPadMs)
            let end = min(totalMs, cluster.endMs + ZM.clusterPadMs)
            guard end > start else { continue }
            if taken.contains(where: { end > $0.0 && start < $0.1 }) { continue }
            taken.append((start, end))
            out.append(ZoomRegion(startMs: start, endMs: end,
                                  focus: cluster.focus, depth: depth))
        }
        return out.sorted { $0.startMs < $1.startMs }
    }
}

// MARK: - Per-frame camera solve (zoomRegionUtils.ts + cursorFollowCamera.ts port)

private func focusBounds(_ scale: Double) -> (min: Double, max: Double) {
    let m = 1 / (2 * scale)
    return (m, 1 - m)
}

private func clampFocusToScale(_ f: ZoomFocus, _ scale: Double) -> ZoomFocus {
    let b = focusBounds(scale)
    return ZoomFocus(cx: min(b.max, max(b.min, min(1, max(0, f.cx)))),
                     cy: min(b.max, max(b.min, min(1, max(0, f.cy)))))
}

private func regionStrength(_ r: ZoomRegion, _ t: Double) -> Double {
    let adj = t - ZM.animationDelayMs
    let leadInStart = r.startMs + ZM.zoomInOverlapMs - ZM.zoomInWindowMs
    var zoomOutStart = r.endMs - ZM.zoomOutEarlyStartMs
    var zoomInEnd = leadInStart + ZM.zoomInWindowMs
    if zoomInEnd > zoomOutStart {
        let mid = (zoomInEnd + zoomOutStart) / 2
        zoomInEnd = mid; zoomOutStart = mid
    }
    let leadOutEnd = zoomOutStart + ZM.transitionWindowMs
    if adj < leadInStart || adj > leadOutEnd { return 0 }
    if adj < zoomInEnd { return easeOutZoom((adj - leadInStart) / ZM.zoomInWindowMs) }
    if adj <= zoomOutStart { return 1 }
    return 1 - easeOutZoom(clamp01((adj - zoomOutStart) / ZM.transitionWindowMs))
}

private struct ConnectedPair {
    let current: Int   // index into regions
    let next: Int
    var transitionStart: Double
    var transitionEnd: Double
}

private func connectedPairs(_ regions: [ZoomRegion]) -> [ConnectedPair] {
    var pairs: [ConnectedPair] = []
    for i in 0..<max(0, regions.count - 1) {
        let gap = regions[i + 1].startMs - regions[i].endMs
        if gap <= ZM.chainedPanGapMs {
            pairs.append(ConnectedPair(
                current: i, next: i + 1,
                transitionStart: regions[i].endMs + ZM.animationDelayMs,
                transitionEnd: regions[i].endMs + ZM.animationDelayMs + ZM.chainedPanDurationMs))
        }
    }
    return pairs
}

private func interpolateCursor(_ samples: [CursorSample], _ t: Double) -> ZoomFocus? {
    guard let first = samples.first, let last = samples.last else { return nil }
    if t <= first.timeMs { return ZoomFocus(cx: first.cx, cy: first.cy) }
    if t >= last.timeMs { return ZoomFocus(cx: last.cx, cy: last.cy) }
    var lo = 0, hi = samples.count - 1
    while lo < hi - 1 {
        let mid = (lo + hi) >> 1
        if samples[mid].timeMs <= t { lo = mid } else { hi = mid }
    }
    let a = samples[lo], b = samples[hi]
    let span = b.timeMs - a.timeMs
    let k = span > 0 ? (t - a.timeMs) / span : 0
    return ZoomFocus(cx: a.cx + (b.cx - a.cx) * k,
                     cy: a.cy + (b.cy - a.cy) * k)
}

struct CameraState {
    var initialized = false
    var lastTimeMs = 0.0
    var focusX = 0.5, focusY = 0.5
    var wasZoomed = false
    var reachedFullZoom = false
    var frozenX = 0.5, frozenY = 0.5
}

/// One camera evaluation: returns (scale, focus) for frame time t.
/// `state` persists across frames (sequential decode order).
struct ZoomCamera {
    let regions: [ZoomRegion]
    let samples: [CursorSample]
    private let pairs: [ConnectedPair]
    var state = CameraState()

    init(regions: [ZoomRegion], samples: [CursorSample]) {
        self.regions = regions.sorted { $0.startMs < $1.startMs }
        self.samples = samples.sorted { $0.timeMs < $1.timeMs }
        self.pairs = connectedPairs(self.regions)
    }

    /// Dominant region + strength at time t, honoring chained-pan holds.
    private func dominant(_ t: Double) -> (region: ZoomRegion, strength: Double)? {
        // Between pan end and next region start: hold next region fully on.
        for p in pairs where t >= p.transitionEnd && t < regions[p.next].startMs {
            let r = regions[p.next]
            let s = ZM.depthScales[r.depth] ?? 1.8
            return (ZoomRegion(startMs: r.startMs, endMs: r.endMs,
                               focus: clampFocusToScale(r.focus, s), depth: r.depth), 1)
        }
        var best: (ZoomRegion, Double)?
        for (i, r) in regions.enumerated() {
            var strength: Double
            if let out = pairs.first(where: { $0.current == i }) {
                if t >= out.transitionStart { strength = 0 }
                else {
                    let zoomOutStart = r.endMs - ZM.zoomOutEarlyStartMs + ZM.animationDelayMs
                    strength = t >= zoomOutStart ? 1 : regionStrength(r, t)
                }
            } else if let inc = pairs.first(where: { $0.next == i }) {
                if t < inc.transitionStart { strength = 0 }
                else {
                    let nextZoomOutStart = r.endMs - ZM.zoomOutEarlyStartMs + ZM.animationDelayMs
                    strength = t < nextZoomOutStart ? 1 : regionStrength(r, t)
                }
            } else {
                strength = regionStrength(r, t)
            }
            guard strength > 0 else { continue }
            if let b = best {
                if strength > b.1 || (strength == b.1 && r.startMs > b.0.startMs) {
                    best = (r, strength)
                }
            } else {
                best = (r, strength)
            }
        }
        guard let b = best else { return nil }
        let s = ZM.depthScales[b.0.depth] ?? 1.8
        return (ZoomRegion(startMs: b.0.startMs, endMs: b.0.endMs,
                           focus: clampFocusToScale(b.0.focus, s), depth: b.0.depth), b.1)
    }

    /// Active chained pan (if any): blend focus and scale over 1000ms.
    private func panBlend(_ t: Double) -> (scale: Double, focus: ZoomFocus)? {
        for p in pairs where t >= p.transitionStart && t < p.transitionEnd {
            let a = regions[p.current], b = regions[p.next]
            let k = easeInOutCubic((t - p.transitionStart) / ZM.chainedPanDurationMs)
            let sa = ZM.depthScales[a.depth] ?? 1.8
            let sb = ZM.depthScales[b.depth] ?? 1.8
            let fa = clampFocusToScale(a.focus, sa)
            let fb = clampFocusToScale(b.focus, sb)
            return (sa + (sb - sa) * k,
                    ZoomFocus(cx: fa.cx + (fb.cx - fa.cx) * k,
                              cy: fa.cy + (fb.cy - fa.cy) * k))
        }
        return nil
    }

    /// Cursor-follow camera: safe-zone recenter + zoom-out focus freeze.
    private mutating func cursorFollow(timeMs t: Double, zoomScale: Double,
                                       strength: Double,
                                       regionFocus: ZoomFocus) -> ZoomFocus {
        let clampedRegion = clampFocusToScale(regionFocus, zoomScale)
        if strength < 0.01 {
            if state.wasZoomed {
                state.wasZoomed = false
                state.initialized = false
                state.reachedFullZoom = false
            }
            return clampedRegion
        }
        guard let cursor = interpolateCursor(samples, t) else {
            return state.initialized
                ? ZoomFocus(cx: state.focusX, cy: state.focusY)
                : clampedRegion
        }
        if strength >= 0.99 { state.reachedFullZoom = true }
        if state.reachedFullZoom && strength < 0.99 {
            return ZoomFocus(cx: state.frozenX, cy: state.frozenY)
        }
        let backwards = state.initialized && t + 0.5 < state.lastTimeMs
        if !state.initialized || !state.wasZoomed || backwards {
            state.lastTimeMs = t
            state.initialized = true
            state.wasZoomed = true
            state.focusX = clampedRegion.cx; state.focusY = clampedRegion.cy
            state.frozenX = clampedRegion.cx; state.frozenY = clampedRegion.cy
            return clampedRegion
        }
        state.lastTimeMs = t
        // Recenter only when the cursor leaves the inner safe zone.
        let halfSpan = 1 / (2 * max(1, zoomScale))
        let inset = halfSpan * 2 * min(0.49, max(0, ZM.safeZoneRatio))
        var fx = state.focusX, fy = state.focusY
        if cursor.cx < fx - halfSpan + inset || cursor.cx > fx + halfSpan - inset {
            fx = cursor.cx
        }
        if cursor.cy < fy - halfSpan + inset || cursor.cy > fy + halfSpan - inset {
            fy = cursor.cy
        }
        let target = clampFocusToScale(ZoomFocus(cx: fx, cy: fy), zoomScale)
        state.focusX = target.cx; state.focusY = target.cy
        state.frozenX = target.cx; state.frozenY = target.cy
        return target
    }

    /// Frame solve → (targetScale, focus, progress). Transform applies
    /// scale' = 1+(S−1)·p and translation ·p (Recordly's lerp-to-identity).
    mutating func solve(timeMs t: Double) -> (scale: Double, focus: ZoomFocus,
                                              progress: Double) {
        if let pan = panBlend(t) {
            return (pan.scale, pan.focus, 1)
        }
        guard let (region, strength) = dominant(t) else {
            _ = cursorFollow(timeMs: t, zoomScale: 1, strength: 0,
                             regionFocus: ZoomFocus(cx: 0.5, cy: 0.5))
            return (1, ZoomFocus(cx: 0.5, cy: 0.5), 0)
        }
        let scale = ZM.depthScales[region.depth] ?? 1.8
        let focus = cursorFollow(timeMs: t, zoomScale: scale,
                                 strength: strength, regionFocus: region.focus)
        return (scale, focus, strength)
    }
}

// MARK: - Cursor artwork

/// Arrow cursor CGImage + hotspot (in points of the cursor image).
private func systemArrowCursor() -> (CGImage, CGPoint)? {
    var result: (CGImage, CGPoint)?
    let grab = {
        let img = NSCursor.arrow.image
        var rect = CGRect(origin: .zero, size: img.size)
        if let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            let hs = NSCursor.arrow.hotSpot
            result = (cg, CGPoint(x: hs.x / max(1, img.size.width),
                                  y: hs.y / max(1, img.size.height)))
        }
    }
    if Thread.isMainThread { grab() } else {
        DispatchQueue.main.sync { grab() }
    }
    return result
}

/// Pre-rendered click ring (white stroke) drawn expanding+fading over clicks.
private func makeRingImage(diameter: CGFloat) -> CGImage? {
    let s = max(16, diameter)
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(s), height: Int(s),
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    let lw = s * 0.08
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    ctx.setLineWidth(lw)
    ctx.strokeEllipse(in: CGRect(x: lw, y: lw,
                                 width: s - 2 * lw, height: s - 2 * lw))
    return ctx.makeImage()
}

// MARK: - Telemetry sidecar parsing

func loadCursorTelemetry(path: String) -> [CursorSample] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let raw = obj["samples"] as? [[String: Any]]
    else { return [] }
    return raw.compactMap { s in
        guard let t = (s["timeMs"] as? NSNumber)?.doubleValue,
              let cx = (s["cx"] as? NSNumber)?.doubleValue,
              let cy = (s["cy"] as? NSNumber)?.doubleValue
        else { return nil }
        return CursorSample(timeMs: t, cx: cx, cy: cy,
                            interactionType: s["interactionType"] as? String ?? "move")
    }
}

/// Resolves the asset duration in ms. The deprecated synchronous
/// `asset.duration` returns 0 for files whose moov atom sits at the end
/// (metadata not yet loaded), which silently empties every generated
/// region. Load it properly via load(.duration), then fall back to the
/// longest track timeRange, then to caller-provided telemetry bounds.
private func assetDurationMs(_ asset: AVAsset, fallbackMs: Double = 0) -> Double {
    var loaded = 0.0
    let sema = DispatchSemaphore(value: 0)
    Task {
        if let d = try? await asset.load(.duration) {
            loaded = CMTimeGetSeconds(d) * 1000
        }
        sema.signal()
    }
    _ = sema.wait(timeout: .now() + 5)
    if loaded > 0 { return loaded }
    let trackMs = asset.tracks.map {
        CMTimeGetSeconds($0.timeRange.duration) * 1000
    }.max() ?? 0
    return max(trackMs, fallbackMs)
}

// MARK: - Exporter

final class ZoomExporter {
    private let ciCtx = CIContext(options: [.cacheIntermediates: false])

    struct Options {
        var input: String
        var output: String
        var cursorPath: String?
        var regions: [ZoomRegion]?
        var depth: Int = ZM.defaultDepth
        var autoZoom: Bool = true
        var showCursor: Bool = true
        var clickRings: Bool = true
        var motionBlur: Bool = true
        var audio: Bool = true
    }

    /// Synchronous export — call off the main thread. Returns output stats.
    func export(_ opt: Options) throws -> JSONDict {
        let srcURL = URL(fileURLWithPath: opt.input)
        guard FileManager.default.fileExists(atPath: opt.input) else {
            throw DaemonError("invalid_arg", "input video not found: \(opt.input)")
        }
        let asset = AVAsset(url: srcURL)
        guard let track = asset.tracks(withMediaType: .video).first else {
            throw DaemonError("invalid_arg", "no video track in \(opt.input)")
        }
        let size = track.naturalSize
        let W = Int(size.width), H = Int(size.height)
        guard W > 1, H > 1 else {
            throw DaemonError("invalid_arg", "bad video dimensions \(W)x\(H)")
        }
        let cursorPath = opt.cursorPath ?? (opt.input + ".cursor.json")
        let samples = FileManager.default.fileExists(atPath: cursorPath)
            ? loadCursorTelemetry(path: cursorPath) : []
        let totalMs = assetDurationMs(asset,
                                      fallbackMs: samples.map(\.timeMs).max() ?? 0)

        var regions = opt.regions
        if regions == nil, opt.autoZoom {
            regions = ZoomSuggest.regions(samples: samples, totalMs: totalMs,
                                          depth: opt.depth)
        }
        regions = (regions ?? []).map {
            ZoomRegion(startMs: max(0, $0.startMs), endMs: min(totalMs, $0.endMs),
                       focus: $0.focus, depth: min(6, max(1, $0.depth)))
        }.filter { $0.endMs > $0.startMs }
        var camera = ZoomCamera(regions: regions ?? [], samples: samples)

        // Artwork: cursor at ~2% of frame height, ring ~7%.
        let cursorSize = max(24.0, Double(H) * 0.02)
        let ringSize = max(48.0, Double(H) * 0.07)
        let (cursorCG, hotspot) = systemArrowCursor() ?? (nil, CGPoint(x: 0.15, y: 0.08))
        let cursorCI = cursorCG.map { CIImage(cgImage: $0) }
        let cursorScale = cursorCG.map { cursorSize / Double($0.height) } ?? 0
        let ringCI = makeRingImage(diameter: CGFloat(ringSize)).map { CIImage(cgImage: $0) }

        // Reader
        let reader = try AVAssetReader(asset: asset)
        let rdOut = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        rdOut.alwaysCopiesSampleData = false
        guard reader.canAdd(rdOut) else {
            throw DaemonError("internal", "cannot add reader output")
        }
        reader.add(rdOut)

        // Audio passthrough: when the source carries a track, copy the
        // compressed samples through untouched (no re-encode).
        var rdAudioOut: AVAssetReaderTrackOutput?
        var audioTrack: AVAssetTrack?
        if opt.audio, let at = asset.tracks(withMediaType: .audio).first {
            let o = AVAssetReaderTrackOutput(track: at, outputSettings: nil)
            o.alwaysCopiesSampleData = false
            if reader.canAdd(o) {
                reader.add(o)
                rdAudioOut = o
                audioTrack = at
            }
        }

        // Writer — same assistant settings path as the recorder.
        let dstURL = URL(fileURLWithPath: opt.output)
        try? FileManager.default.removeItem(at: dstURL)
        let fileType: AVFileType = dstURL.pathExtension.lowercased() == "mp4" ? .mp4 : .mov
        let writer = try AVAssetWriter(url: dstURL, fileType: fileType)
        guard let assistant = AVOutputSettingsAssistant(preset: .preset3840x2160) else {
            throw DaemonError("internal", "unable to create output settings assistant")
        }
        let fmt = try CMVideoFormatDescription(
            videoCodecType: CMFormatDescription.MediaSubType(
                rawValue: kCVPixelFormatType_32BGRA),
            width: W, height: H)
        assistant.sourceVideoFormat = fmt
        guard var vSettings = assistant.videoSettings else {
            throw DaemonError("internal", "output settings unavailable")
        }
        vSettings[AVVideoWidthKey] = W
        vSettings[AVVideoHeightKey] = H
        vSettings[AVVideoColorPropertiesKey] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
        let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: vSettings,
                                     sourceFormatHint: fmt)
        vIn.expectsMediaDataInRealTime = false
        guard writer.canAdd(vIn) else {
            throw DaemonError("internal", "unable to add video writer input")
        }
        writer.add(vIn)
        var aIn: AVAssetWriterInput?
        if let audioTrack, opt.audio,
           let hint = audioTrack.formatDescriptions.first as! CMFormatDescription? {
            let input = AVAssetWriterInput(mediaType: .audio,
                                           outputSettings: nil,
                                           sourceFormatHint: hint)
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) {
                writer.add(input)
                aIn = input
            }
        }
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vIn,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: W,
                kCVPixelBufferHeightKey as String: H,
            ])

        guard reader.startReading(), writer.startWriting() else {
            throw DaemonError("internal",
                reader.error?.localizedDescription
                    ?? writer.error?.localizedDescription
                    ?? "export pipeline failed to start")
        }
        writer.startSession(atSourceTime: .zero)

        let outRect = CGRect(x: 0, y: 0, width: W, height: H)
        let black = CIImage(color: CIColor.black).cropped(to: outRect)
        let clickEvents = samples.filter {
            explicitClickTypes.contains($0.interactionType)
        }
        var frames = 0
        var prevTx = 0.0, prevTy = 0.0, prevS = 1.0, havePrev = false

        while let sb = rdOut.copyNextSampleBuffer() {
            guard let srcPB = CMSampleBufferGetImageBuffer(sb) else { continue }
            let pts = sb.presentationTimeStamp
            let t = max(0, CMTimeGetSeconds(pts)) * 1000
            let (targetScale, focus, progress) = camera.solve(timeMs: t)

            // computeZoomTransform port: s = 1+(S−1)·p,
            // offset = (center − focus·S)·p  (p lerps toward identity).
            let fx = focus.cx * Double(W)
            let fyCI = (1 - focus.cy) * Double(H)     // CI y is bottom-up
            let s = 1 + (targetScale - 1) * progress
            let tx = (Double(W) / 2 - fx * targetScale) * progress
            let ty = (Double(H) / 2 - fyCI * targetScale) * progress
            var composited = CIImage(cvPixelBuffer: srcPB)
                .transformed(by: CGAffineTransform(a: s, b: 0, c: 0, d: s,
                                                 tx: tx, ty: ty))
                .composited(over: black)

            // Motion blur from camera delta (scene only — cursor stays crisp):
            // pan → directional CIMotionBlur, scale delta → radial CIZoomBlur.
            if opt.motionBlur {
                if havePrev {
                    let panPx = hypot(tx - prevTx, ty - prevTy)
                    let ds = s - prevS
                    if panPx > 4 {
                        composited = composited.applyingFilter("CIMotionBlur",
                            parameters: [
                                "inputRadius": min(9, panPx * 0.3),
                                "inputAngle": atan2(ty - prevTy, tx - prevTx),
                            ]).cropped(to: outRect)
                    }
                    if abs(ds) > 0.01 {
                        composited = composited.applyingFilter("CIZoomBlur",
                            parameters: [
                                "inputAmount": min(12, abs(ds) * 30),
                                "inputCenter": CIVector(x: CGFloat(W) / 2,
                                                        y: CGFloat(H) / 2),
                            ]).cropped(to: outRect)
                    }
                }
                prevTx = tx; prevTy = ty; prevS = s; havePrev = true
            }

            // Click rings (viewport space, centered at click pos).
            if opt.clickRings, let ringCI {
                for c in clickEvents {
                    let age = t - c.timeMs
                    guard age >= 0, age <= ZM.clickRingMs else { continue }
                    let k = age / ZM.clickRingMs
                    let alpha = 1 - k
                    let scaleK = 0.35 + 0.65 * easeOutZoom(k)
                    let d = ringSize * scaleK
                    let faded = ringCI.applyingFilter("CIColorMatrix", parameters: [
                        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(alpha)),
                    ])
                    let placed = faded.transformed(by: CGAffineTransform(
                        a: d / ringSize, b: 0, c: 0, d: d / ringSize,
                        tx: c.cx * Double(W) - d / 2,
                        ty: (1 - c.cy) * Double(H) - d / 2))
                    composited = placed.composited(over: composited)
                }
            }

            // Cursor overlay (viewport space — never zoomed).
            if opt.showCursor, let cursorCI, cursorScale > 0,
               let pos = interpolateCursor(samples, t) {
                let pw = cursorSize * Double(cursorCI.extent.width) /
                    Double(cursorCI.extent.height)
                let px = pos.cx * Double(W) - hotspot.x * pw
                let py = (1 - pos.cy) * Double(H) - (1 - hotspot.y) * cursorSize
                let placed = cursorCI.transformed(by: CGAffineTransform(
                    a: cursorScale, b: 0, c: 0, d: cursorScale, tx: px, ty: py))
                composited = placed.composited(over: composited)
            }
            guard let pool = adaptor.pixelBufferPool else { break }
            var dest: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dest) == kCVReturnSuccess,
                  let dest else { break }
            var spins = 0
            while !vIn.isReadyForMoreMediaData, spins < 2000 {
                usleep(1000); spins += 1
            }
            ciCtx.render(composited, to: dest, bounds: outRect,
                         colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            if adaptor.append(dest, withPresentationTime: pts) { frames += 1 }
        }

        // Drain the audio track (compressed passthrough; writer muxes by PTS).
        if let rdAudioOut, let aIn {
            while let asb = rdAudioOut.copyNextSampleBuffer() {
                var spins = 0
                while !aIn.isReadyForMoreMediaData, spins < 2000 {
                    usleep(1000); spins += 1
                }
                aIn.append(asb)
            }
            aIn.markAsFinished()
        }

        vIn.markAsFinished()
        try awaitSync { done in writer.finishWriting { done() } }
        guard writer.status == .completed else {
            throw DaemonError("internal",
                writer.error?.localizedDescription ?? "export writer failed")
        }

        var d: JSONDict = [
            "out": opt.output,
            "frames": frames,
            "width": W,
            "height": H,
            "duration_s": CMTimeGetSeconds(asset.duration),
            "regions": regions?.count ?? 0,
            "cursor_samples": samples.count,
        ]
        if !samples.isEmpty { d["cursor_telemetry"] = cursorPath }
        return d
    }

    private func awaitSync(_ call: (@escaping () -> Void) -> Void) throws {
        let sem = DispatchSemaphore(value: 0)
        call { sem.signal() }
        if sem.wait(timeout: .now() + 120) == .timedOut {
            throw DaemonError("internal", "export finalize timed out")
        }
    }
}

// MARK: - Daemon command handlers

extension Daemon {
    /// zoom_export {in, out, cursor?, depth?, auto_zoom?, regions?, show_cursor?}
    func cmdZoomExport(_ a: JSONDict) throws -> JSONDict {
        let input = try requireStr(a, "in")
        let output = try requireStr(a, "out")
        var opt = ZoomExporter.Options(input: input, output: output)
        opt.cursorPath = a["cursor"] as? String
        opt.depth = a.int("depth") ?? ZM.defaultDepth
        opt.autoZoom = a.bool("auto_zoom") ?? true
        opt.showCursor = a.bool("show_cursor") ?? true
        opt.clickRings = a.bool("click_rings") ?? true
        opt.motionBlur = a.bool("motion_blur") ?? true
        opt.audio = a.bool("audio") ?? true
        if let rawRegions = a.array("regions") {
            opt.regions = rawRegions.compactMap { item in
                guard let r = item as? [String: Any],
                      let start = (r["start_ms"] as? NSNumber)?.doubleValue,
                      let end = (r["end_ms"] as? NSNumber)?.doubleValue,
                      let cx = (r["cx"] as? NSNumber)?.doubleValue,
                      let cy = (r["cy"] as? NSNumber)?.doubleValue
                else { return nil }
                return ZoomRegion(startMs: start, endMs: end,
                                  focus: ZoomFocus(cx: cx, cy: cy),
                                  depth: (r["depth"] as? NSNumber)?.intValue ?? ZM.defaultDepth)
            }
        }
        // Long-running: run off the connection queue would serialize the
        // daemon's per-connection pipeline anyway — same trade-off as
        // record_start's first-frame barrier. Acceptable for v1.
        return try ZoomExporter().export(opt)
    }

    /// zoom_suggest {in|cursor} — dry-run auto-zoom, returns the region list
    /// without rendering so callers can inspect/edit before zoom_export.
    func cmdZoomSuggest(_ a: JSONDict) throws -> JSONDict {
        var samples: [CursorSample]
        var totalMs: Double
        if let cursorPath = a["cursor"] as? String {
            samples = loadCursorTelemetry(path: cursorPath)
            totalMs = samples.map(\.timeMs).max() ?? 0
        } else {
            let input = try requireStr(a, "in")
            let asset = AVAsset(url: URL(fileURLWithPath: input))
            samples = loadCursorTelemetry(path: input + ".cursor.json")
            totalMs = assetDurationMs(asset,
                                      fallbackMs: samples.map(\.timeMs).max() ?? 0)
        }
        let depth = a.int("depth") ?? ZM.defaultDepth
        let regions = ZoomSuggest.regions(samples: samples, totalMs: totalMs,
                                          depth: depth)
        let clicks = samples.filter { explicitClickTypes.contains($0.interactionType) }
        return [
            "samples": samples.count,
            "clicks": clicks.count,
            "regions": regions.map {
                ["start_ms": $0.startMs, "end_ms": $0.endMs,
                 "cx": $0.focus.cx, "cy": $0.focus.cy, "depth": $0.depth] as JSONDict
            },
            "scale": ZM.depthScales[depth] ?? 1.8,
        ]
    }
}
