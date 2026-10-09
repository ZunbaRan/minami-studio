import Foundation
import AppKit
import ScreenCaptureKit
import AVFoundation
import CoreImage
import CoreGraphics

// MARK: - Recording surface (minami-studio extension — beyond-Alma territory)
//
// SCStream → AVAssetWriter screen recording + cursor telemetry sidecar.
// Capture core (60fps stream config, window-mode display-filter + CIContext
// crop, pause/resume timestamp rebasing, guarded tail-frame finalization)
// adapted from Recordly's electron/native/ScreenCaptureKitRecorder.swift
// (AGPL-3.0, github.com/webadderallorg/Recordly) — this project is AGPL-3.0.
// Adaptations: runs inside the daemon instead of a stdio helper process,
// no microphone/sidecar audio tracks, window-loss reported via daemon event
// broadcast instead of process exit, completion-handler + semaphore style
// (no async/await) to match daemon concurrency conventions.
//
// Design contract (docs/RECORDLY-ZOOM-PIPELINE.md): showsCursor=false so the
// OS cursor is never baked into the video; cursor moves/clicks are captured
// to <out>.cursor.json and re-rendered by the zoom export stage.

private let recordCaptureFPS = 60
private let maxAudioTailSeconds: Double = 2.0

final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "studio.rec.video")
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let imageContext = CIContext(options: [.cacheIntermediates: false])

    private var isRecording = false
    private var isPaused = false
    private var sessionStarted = false
    private(set) var frameCount = 0

    private var outputURL: URL?
    private(set) var outputSize = CGSize.zero
    private(set) var trackedWindowId: CGWindowID?
    /// Telemetry normalization rect in global top-left-origin points.
    private(set) var normRect = CGRect.zero
    private var cropRectNorm: CGRect?
    private var cropDisplayId: CGDirectDisplayID?
    private var excludedPids = Set<Int32>()
    private var capturesAudio = false

    private var firstSampleTime = CMTime.zero
    private var lastVideoPTS = CMTime.zero
    private var lastVideoDuration = CMTime.zero
    private var lastSampleBuffer: CMSampleBuffer?
    private var lastCroppedPB: CVPixelBuffer?
    private var firstAudioTime: CMTime?
    private var lastAudioPTS = CMTime.invalid

    private var pauseStart: CMTime?
    private var pendingResumeAdjustment = false
    private var accumulatedPaused = CMTime.zero

    private var firstFrameSem: DispatchSemaphore?
    private var windowWatch: DispatchSourceTimer?

    /// Fired off-queue when the tracked window disappears mid-recording.
    var onWindowGone: (() -> Void)?
    /// Fired off-queue when the stream dies unexpectedly.
    var onStreamError: ((String) -> Void)?

    var recording: Bool { queue.sync { isRecording } }
    var paused: Bool { queue.sync { isPaused } }
    var frames: Int { queue.sync { frameCount } }

    // MARK: start

    /// Blocks the caller's queue until the stream is configured and started.
    /// `firstFrameSem` is armed here; the caller waits on it afterwards so
    /// record_start only reports success once a real frame hit the writer.
    func start(out: String, displayId: CGDirectDisplayID?, windowId: CGWindowID?,
               windowFrame: CGRect?, fps: Int, audio: Bool,
               excludedProcessIds: [Int32]) throws {
        var thrown: Error?
        queue.sync {
            do { try startLocked(out: out, displayId: displayId, windowId: windowId,
                                 windowFrame: windowFrame, fps: fps, audio: audio,
                                 excludedProcessIds: excludedProcessIds) }
            catch { thrown = error }
        }
        if let thrown { throw thrown }
    }

    private func startLocked(out: String, displayId: CGDirectDisplayID?, windowId: CGWindowID?,
                             windowFrame: CGRect?, fps: Int, audio: Bool,
                             excludedProcessIds: [Int32]) throws {
        guard !isRecording else {
            throw DaemonError("invalid_state", "recording already in progress")
        }
        let content = try shareableContent()
        let cfg = SCStreamConfiguration()
        capturesAudio = audio
        let requestedFPS = max(1, min(120, fps <= 0 ? recordCaptureFPS : fps))
        cfg.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(requestedFPS))
        cfg.queueDepth = 6
        cfg.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        cfg.colorSpaceName = CGColorSpace.sRGB
        cfg.colorMatrix = CGDisplayStream.yCbCrMatrix_ITU_R_709_2
        cfg.showsCursor = false
        cfg.capturesAudio = audio
        cfg.sampleRate = 48000
        cfg.channelCount = 2
        cfg.excludesCurrentProcessAudio = true

        excludedPids = Set(excludedProcessIds)
        let excludedApps = content.applications.filter { excludedPids.contains($0.processID) }

        let filter: SCContentFilter
        var outW: Int
        var outH: Int

        if let windowId {
            guard let window = content.windows.first(where: { $0.windowID == windowId }) else {
                throw DaemonError("invalid_arg", "window_id \(windowId) not capturable")
            }
            let visibleFrame = windowFrame
                .flatMap { $0.width > 0 && $0.height > 0 ? $0 : nil } ?? window.frame
            guard let display = Self.display(containing: visibleFrame, in: content.displays) else {
                throw DaemonError("invalid_arg", "no display contains window_id \(windowId)")
            }
            let scaleFactor = Self.scaleFactor(for: display.displayID)
            let captureRect = visibleFrame.intersection(display.frame)
            filter = SCContentFilter(display: display, excludingApplications: excludedApps,
                                     exceptingWindows: [])
            cropRectNorm = CGRect(
                x: (captureRect.minX - display.frame.minX) / display.frame.width,
                y: (captureRect.minY - display.frame.minY) / display.frame.height,
                width: captureRect.width / display.frame.width,
                height: captureRect.height / display.frame.height)
            cropDisplayId = display.displayID
            trackedWindowId = windowId
            normRect = captureRect
            outW = max(2, Int(captureRect.width) * scaleFactor) & ~1
            outH = max(2, Int(captureRect.height) * scaleFactor) & ~1
            cfg.width = max(2, Int(display.frame.width) * scaleFactor)
            cfg.height = max(2, Int(display.frame.height) * scaleFactor)
            cfg.pixelFormat = kCVPixelFormatType_32BGRA
        } else {
            let targetDisplay = displayId ?? CGMainDisplayID()
            guard let display = content.displays.first(where: { $0.displayID == targetDisplay }) else {
                throw DaemonError("invalid_arg", "display_id \(targetDisplay) not found")
            }
            filter = SCContentFilter(display: display, excludingApplications: excludedApps,
                                     exceptingWindows: [])
            let scaleFactor = Self.scaleFactor(for: display.displayID)
            cropRectNorm = nil
            cropDisplayId = nil
            trackedWindowId = nil
            normRect = display.frame
            outW = max(2, Int(display.frame.width) * scaleFactor)
            outH = max(2, Int(display.frame.height) * scaleFactor)
            cfg.width = outW
            cfg.height = outH
        }
        outputSize = CGSize(width: outW, height: outH)

        let url = URL(fileURLWithPath: out)
        outputURL = url
        let fileType: AVFileType = url.pathExtension.lowercased() == "mp4" ? .mp4 : .mov
        let writer = try AVAssetWriter(url: url, fileType: fileType)

        guard let assistant = AVOutputSettingsAssistant(preset: .preset3840x2160) else {
            throw DaemonError("internal", "unable to create output settings assistant")
        }
        let sourceFormat = try CMVideoFormatDescription(
            videoCodecType: CMFormatDescription.MediaSubType(
                rawValue: cropRectNorm == nil
                    ? kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                    : kCVPixelFormatType_32BGRA),
            width: outW, height: outH)
        assistant.sourceVideoFormat = sourceFormat
        guard var videoSettings = assistant.videoSettings else {
            throw DaemonError("internal", "output settings unavailable")
        }
        videoSettings[AVVideoWidthKey] = outW
        videoSettings[AVVideoHeightKey] = outH
        videoSettings[AVVideoColorPropertiesKey] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings,
                                        sourceFormatHint: sourceFormat)
        vInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(vInput) else {
            throw DaemonError("internal", "unable to add video writer input")
        }
        writer.add(vInput)
        videoInput = vInput
        pixelAdaptor = cropRectNorm.map { _ in
            AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: vInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: outW,
                    kCVPixelBufferHeightKey as String: outH,
                ])
        }
        if capturesAudio {
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000,
            ])
            aInput.expectsMediaDataInRealTime = true
            if writer.canAdd(aInput) {
                writer.add(aInput)
                audioInput = aInput
            }
        }

        let s = SCStream(filter: filter, configuration: cfg, delegate: self)
        stream = s
        try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if capturesAudio {
            try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        }
        try streamSync(s.startCapture)

        guard writer.startWriting() else {
            throw DaemonError("internal",
                writer.error?.localizedDescription ?? "unable to start writing")
        }
        writer.startSession(atSourceTime: .zero)
        assetWriter = writer
        sessionStarted = true
        isRecording = true
        isPaused = false
        pauseStart = nil
        pendingResumeAdjustment = false
        accumulatedPaused = .zero
        frameCount = 0
        firstSampleTime = .zero
        lastVideoPTS = .zero
        lastVideoDuration = .zero
        firstAudioTime = nil
        lastAudioPTS = .invalid
        lastSampleBuffer = nil
        lastCroppedPB = nil
        firstFrameSem = DispatchSemaphore(value: 0)
        armWindowWatchLocked()
    }

    /// Wait until AVAssetWriter accepted the first real frame (Recordly's
    /// "Recording started" barrier). 12s like upstream's helper spawn timeout.
    func waitFirstFrame() -> Bool {
        guard let sem = firstFrameSem else { return true }
        return sem.wait(timeout: .now() + 12) == .success
    }

    // MARK: pause / resume

    func pause() -> Bool {
        queue.sync {
            guard isRecording, !isPaused else { return isRecording && isPaused }
            isPaused = true
            pauseStart = CMClockGetTime(CMClockGetHostTimeClock())
            pendingResumeAdjustment = false
            return true
        }
    }

    func resume() -> Bool {
        queue.sync {
            guard isRecording, isPaused else { return isRecording && !isPaused }
            isPaused = false
            pendingResumeAdjustment = true
            return true
        }
    }

    // MARK: stop

    /// Synchronous finalization on the recorder queue: stops the stream,
    /// appends the guarded tail frame, ends the session and finishes writers.
    /// Returns (path, frames, videoDurationSeconds).
    func stop() throws -> (path: String, frames: Int, durationS: Double) {
        var out: Result<(String, Int, Double), Error>!
        queue.sync {
            guard self.isRecording else {
                out = .failure(DaemonError("invalid_state", "no recording in progress"))
                return
            }
            out = Result {
                let path = try self.finishLocked()
                return (path, self.lastFramesWritten, self.lastDurationS)
            }
        }
        return try out.get()
    }

    private var lastFramesWritten = 0
    private var lastDurationS = 0.0

    private func finishLocked() throws -> String {
        isRecording = false
        windowWatch?.cancel()
        windowWatch = nil
        if let s = stream {
            // Stream may already have been stopped by the system.
            try? streamSync(s.stopCapture)
        }
        stream = nil

        // Tail frame gives the last captured frame its full duration; append
        // only after the encoder queue drains — appending to a backed-up
        // input raises an uncatchable ObjC exception and kills the file.
        if let sample = lastSampleBuffer, let vInput = videoInput,
           waitReady(vInput, of: assetWriter) {
            let tailTime = lastVideoPTS + duration(of: sample)
            if let adaptor = pixelAdaptor, let pb = lastCroppedPB {
                adaptor.append(pb, withPresentationTime: tailTime)
            } else {
                let timing = CMSampleTimingInfo(duration: sample.duration,
                                                presentationTimeStamp: tailTime,
                                                decodeTimeStamp: sample.decodeTimeStamp)
                if let retimed = try? CMSampleBuffer(copying: sample, withNewTiming: [timing]) {
                    vInput.append(retimed)
                }
            }
        }

        let videoEnd = lastVideoPTS + (lastSampleBuffer.map { duration(of: $0) } ?? .zero)
        var endTime = videoEnd
        if lastAudioPTS.isValid, lastAudioPTS > videoEnd {
            let tail = lastAudioPTS - videoEnd
            let cap = CMTime(seconds: maxAudioTailSeconds, preferredTimescale: 600)
            endTime = videoEnd + CMTimeMinimum(tail, cap)
        }
        if let w = assetWriter, w.status == .writing {
            w.endSession(atSourceTime: endTime)
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            // finishWriting's completion takes no error arg; status is
            // checked via writer.status/.error below.
            try streamSync { done in w.finishWriting { done(nil) } }
        }
        let finalizeFailure: Error? = assetWriter.flatMap { w in
            w.status == .completed
                ? nil
                : (w.error ?? DaemonError("internal",
                        "recording could not be finalized (writer status \(w.status.rawValue))"))
        }
        let path = outputURL?.path ?? ""
        lastFramesWritten = frameCount
        lastDurationS = CMTimeGetSeconds(videoEnd)
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelAdaptor = nil
        cropRectNorm = nil
        cropDisplayId = nil
        excludedPids.removeAll()
        lastCroppedPB = nil
        outputURL = nil
        sessionStarted = false
        firstSampleTime = .zero
        lastVideoPTS = .zero
        lastVideoDuration = .zero
        firstAudioTime = nil
        lastAudioPTS = .invalid
        lastSampleBuffer = nil
        frameCount = 0
        isPaused = false
        pauseStart = nil
        pendingResumeAdjustment = false
        accumulatedPaused = .zero
        capturesAudio = false
        if let finalizeFailure { throw finalizeFailure }
        return path
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard sessionStarted, sb.isValid, isRecording else { return }

        if outputType == .screen {
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let attachment = attachments.first,
                  let statusRaw = attachment[SCStreamFrameInfo.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusRaw),
                  status == .complete else { return }
            guard let vInput = videoInput,
                  assetWriter?.status == .writing,
                  vInput.isReadyForMoreMediaData else { return }
            guard let pts = adjustedPresentationTime(for: sb, outputType: outputType) else { return }
            if frameCount > 0 && pts <= lastVideoPTS { return }

            lastSampleBuffer = sb
            let appended: Bool
            if pixelAdaptor != nil {
                appended = appendCroppedFrame(sb, at: pts)
            } else {
                let timing = CMSampleTimingInfo(duration: sb.duration,
                                                presentationTimeStamp: pts,
                                                decodeTimeStamp: sb.decodeTimeStamp)
                if let retimed = try? CMSampleBuffer(copying: sb, withNewTiming: [timing]) {
                    appended = vInput.append(retimed)
                } else {
                    appended = false
                }
            }
            if appended {
                lastVideoPTS = pts
                lastVideoDuration = sb.duration
                frameCount += 1
                if frameCount == 1 { firstFrameSem?.signal() }
            } else if frameCount == 0 {
                firstSampleTime = .zero
            }
            return
        }

        if outputType == .audio, capturesAudio {
            guard frameCount > 0, let aInput = audioInput,
                  assetWriter?.status == .writing,
                  aInput.isReadyForMoreMediaData,
                  let pts = adjustedPresentationTime(for: sb, outputType: outputType),
                  !lastAudioPTS.isValid || pts > lastAudioPTS else { return }
            if firstAudioTime == nil { firstAudioTime = pts }
            let timing = CMSampleTimingInfo(duration: sb.duration,
                                            presentationTimeStamp: pts,
                                            decodeTimeStamp: sb.decodeTimeStamp)
            if let retimed = try? CMSampleBuffer(copying: sb, withNewTiming: [timing]),
               aInput.append(retimed) {
                lastAudioPTS = pts
            }
        }
    }

    private func appendCroppedFrame(_ sb: CMSampleBuffer, at pts: CMTime) -> Bool {
        guard let crop = cropRectNorm,
              let adaptor = pixelAdaptor,
              let pool = adaptor.pixelBufferPool,
              let source = CMSampleBufferGetImageBuffer(sb) else { return false }
        var dest: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dest) == kCVReturnSuccess,
              let dest else { return false }
        let srcW = CGFloat(CVPixelBufferGetWidth(source))
        let srcH = CGFloat(CVPixelBufferGetHeight(source))
        let sourceRect = CGRect(x: crop.minX * srcW, y: (1 - crop.maxY) * srcH,
                                width: crop.width * srcW, height: crop.height * srcH)
        let destSize = CGSize(width: CVPixelBufferGetWidth(dest),
                              height: CVPixelBufferGetHeight(dest))
        let image = CIImage(cvPixelBuffer: source)
            .cropped(to: sourceRect)
            .transformed(by: CGAffineTransform(translationX: -sourceRect.minX,
                                               y: -sourceRect.minY))
            .transformed(by: CGAffineTransform(
                scaleX: destSize.width / sourceRect.width,
                y: destSize.height / sourceRect.height))
        imageContext.render(image, to: dest,
                            bounds: CGRect(origin: .zero, size: destSize),
                            colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        let ok = adaptor.append(dest, withPresentationTime: pts)
        if ok { lastCroppedPB = dest }
        return ok
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStreamError?(error.localizedDescription)
    }

    // MARK: timestamp plumbing (pause/rebase — adapted from Recordly)

    private func adjustedPresentationTime(for sb: CMSampleBuffer,
                                          outputType: SCStreamOutputType) -> CMTime? {
        if isPaused { return nil }
        let sampleTime = sb.presentationTimeStamp
        if pendingResumeAdjustment {
            // Anchor the resume adjustment to video; audio frames arriving
            // first would otherwise produce a backwards video timestamp.
            guard outputType == .screen, let pauseStart else { return nil }
            let gap = sampleTime - pauseStart
            if gap > .zero { accumulatedPaused = accumulatedPaused + gap }
            self.pauseStart = nil
            pendingResumeAdjustment = false
        }
        if outputType == .screen, firstSampleTime == .zero {
            firstSampleTime = sampleTime
        }
        if firstSampleTime == .zero { return nil } // audio before first video frame
        return max(.zero, sampleTime - firstSampleTime - accumulatedPaused)
    }

    private func duration(of sb: CMSampleBuffer) -> CMTime {
        if sb.duration.isValid && sb.duration > .zero { return sb.duration }
        if lastVideoDuration.isValid && lastVideoDuration > .zero { return lastVideoDuration }
        return CMTime(value: 1, timescale: CMTimeScale(recordCaptureFPS))
    }

    private func waitReady(_ input: AVAssetWriterInput, of writer: AVAssetWriter?) -> Bool {
        guard let writer else { return false }
        var attempts = 100 // 100 × 10ms = 1s
        while writer.status == .writing {
            if input.isReadyForMoreMediaData { return true }
            attempts -= 1
            if attempts <= 0 { return false }
            usleep(10_000)
        }
        return false
    }

    /// Run an SCStream/AVAssetWriter completion-handler call synchronously.
    /// Completions arrive on the callee's internal queue, never on `queue`,
    /// so semaphore waits are safe inside queue.sync.
    private func streamSync(_ call: (@escaping (Error?) -> Void) throws -> Void) throws {
        var failure: Error?
        let sem = DispatchSemaphore(value: 0)
        try call { err in failure = err; sem.signal() }
        if sem.wait(timeout: .now() + 15) == .timedOut {
            throw DaemonError("internal", "stream operation timed out")
        }
        if let failure { throw DaemonError.wrap(failure) }
    }

    // MARK: window validation (tracked window gone → auto-finalize)

    private func armWindowWatchLocked() {
        windowWatch?.cancel()
        windowWatch = nil
        guard let wid = trackedWindowId else { return }
        let t = DispatchSource.makeTimerSource(
            queue: DispatchQueue(label: "studio.rec.windowwatch"))
        t.schedule(deadline: .now() + 0.5, repeating: 0.5)
        t.setEventHandler { [weak self] in self?.checkWindow(wid) }
        windowWatch = t
        t.resume()
    }

    private func checkWindow(_ wid: CGWindowID) {
        guard recording else { return }
        guard let content = try? shareableContent() else { return }
        guard let window = content.windows.first(where: { $0.windowID == wid }) else {
            queue.async { self.trackedWindowId = nil }
            onWindowGone?()
            return
        }
        guard let display = Self.display(containing: window.frame, in: content.displays) else {
            return
        }
        let captureRect = window.frame.intersection(display.frame)
        guard captureRect.width > 0, captureRect.height > 0 else { return }
        let newCrop = CGRect(
            x: (captureRect.minX - display.frame.minX) / display.frame.width,
            y: (captureRect.minY - display.frame.minY) / display.frame.height,
            width: captureRect.width / display.frame.width,
            height: captureRect.height / display.frame.height)
        if cropDisplayId != display.displayID {
            let excludedApps = content.applications.filter {
                excludedPids.contains($0.processID)
            }
            let filter = SCContentFilter(display: display,
                                         excludingApplications: excludedApps,
                                         exceptingWindows: [])
            if let s = stream {
                try? streamSync { done in s.updateContentFilter(filter, completionHandler: done) }
            }
        }
        queue.async {
            guard self.isRecording else { return }
            self.cropRectNorm = newCrop
            self.cropDisplayId = display.displayID
            self.normRect = captureRect
        }
    }

    // MARK: helpers

    private func shareableContent() throws -> SCShareableContent {
        var result: SCShareableContent?
        var failure: Error?
        let sem = DispatchSemaphore(value: 0)
        // Completion arrives on the main runloop — safe from this worker queue
        // because the daemon pumps NSApp.run() on main. Never call this inside
        // a main.sync block (AGENTS.md pitfall #2).
        SCShareableContent.getWithCompletionHandler { content, err in
            result = content
            failure = err
            sem.signal()
        }
        if sem.wait(timeout: .now() + 10) == .timedOut {
            throw DaemonError("internal", "SCShareableContent timed out")
        }
        if let failure { throw DaemonError.wrap(failure) }
        guard let c = result else {
            throw DaemonError("internal", "SCShareableContent returned nil")
        }
        return c
    }

    private static func display(containing frame: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        let mid = CGPoint(x: frame.midX, y: frame.midY)
        return displays.first(where: { $0.frame.contains(mid) })
            ?? displays.filter { $0.frame.intersects(frame) }.max {
                $0.frame.intersection(frame).width * $0.frame.intersection(frame).height
                    < $1.frame.intersection(frame).width * $1.frame.intersection(frame).height
            }
    }

    private static func scaleFactor(for displayId: CGDirectDisplayID) -> Int {
        guard let mode = CGDisplayCopyDisplayMode(displayId) else { return 1 }
        return max(1, mode.pixelWidth / max(1, mode.width))
    }
}

// MARK: - Cursor telemetry recorder
//
// 33ms position poll + passive CGEvent tap for clicks, normalized to the
// captured display/window rect, serialized to <out>.cursor.json:
//   {"version":1,"samples":[{timeMs,cx,cy,interactionType}]}
// interactionType ∈ move | click | double-click | right-click | middle-click |
// mouseup — same vocabulary as Recordly's sidecar so the zoom stage can reuse
// its interaction-classification model verbatim.

final class CursorTelemetryRecorder {
    private let queue = DispatchQueue(label: "studio.rec.cursor")
    private var samples: [JSONDict] = []
    private var timer: DispatchSourceTimer?
    private var eventTap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var startUptime: CFTimeInterval = 0
    private var pausedAccum: CFTimeInterval = 0
    private var pauseStart: CFTimeInterval?
    private var normRect = CGRect.zero
    private(set) var isCapturing = false
    private(set) var tapInstalled = false
    /// Click-state heuristic for double-click: leftMouseDown with
    /// clickState >= 2 reports "double-click" instead of "click".

    private var elapsedMs: Int {
        var elapsed = CACurrentMediaTime() - startUptime - pausedAccum
        if let pauseStart { elapsed -= CACurrentMediaTime() - pauseStart }
        return max(0, Int(elapsed * 1000))
    }

    func start(normRect: CGRect) {
        queue.sync {
            samples.removeAll()
            self.normRect = normRect
            startUptime = CACurrentMediaTime()
            pausedAccum = 0
            pauseStart = nil
            isCapturing = true
        }
        installTap()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.033, repeating: 0.033)
        t.setEventHandler { [weak self] in self?.pollPosition() }
        timer = t
        t.resume()
    }

    func pause() {
        queue.sync {
            guard pauseStart == nil else { return }
            pauseStart = CACurrentMediaTime()
        }
    }

    func resume() {
        queue.sync {
            guard let p = pauseStart else { return }
            pausedAccum += CACurrentMediaTime() - p
            pauseStart = nil
        }
    }

    /// Stops capture and writes the sidecar JSON next to the video file.
    /// Returns the sidecar path, or nil when nothing was captured.
    func stop(videoPath: String) -> String? {
        let out = queue.sync { () -> [JSONDict] in
            isCapturing = false
            timer?.cancel()
            timer = nil
            defer { samples = [] }
            return samples
        }
        uninstallTap()
        guard !out.isEmpty else { return nil }
        let telemetryPath = videoPath + ".cursor.json"
        let payload: JSONDict = [
            "version": 1,
            "video": (videoPath as NSString).lastPathComponent,
            "norm_rect": [
                "x": normRect.origin.x, "y": normRect.origin.y,
                "w": normRect.size.width, "h": normRect.size.height,
            ],
            "samples": out,
        ]
        guard let data = jsonString(payload).data(using: .utf8) else { return nil }
        try? data.write(to: URL(fileURLWithPath: telemetryPath), options: .atomic)
        return telemetryPath
    }

    private func normalized(_ p: CGPoint) -> (cx: Double, cy: Double) {
        let w = max(1, normRect.width), h = max(1, normRect.height)
        return (min(1, max(0, (p.x - normRect.minX) / w)),
                min(1, max(0, (p.y - normRect.minY) / h)))
    }

    private func pollPosition() {
        guard isCapturing, pauseStart == nil,
              let loc = CGEvent(source: nil)?.location else { return }
        let n = normalized(loc)
        samples.append(["timeMs": elapsedMs, "cx": n.cx, "cy": n.cy,
                        "interactionType": "move"])
    }

    private func pushInteraction(_ type: String, at p: CGPoint) {
        queue.async {
            guard self.isCapturing else { return }
            let n = self.normalized(p)
            self.samples.append(["timeMs": self.elapsedMs, "cx": n.cx, "cy": n.cy,
                                 "interactionType": type])
        }
    }

    // MARK: CGEvent tap (passive, session scope — sees user AND daemon-injected clicks)

    private func installTap() {
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<CursorTelemetryRecorder>
                    .fromOpaque(refcon).takeUnretainedValue()
                me.noteTapEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr)
        guard let tap else { return } // no permission → moves-only telemetry
        tapInstalled = true
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        tapSource = src
        // The daemon main runloop (NSApp.run) services the tap.
        onMainThread {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func uninstallTap() {
        guard let tap = eventTap, let src = tapSource else { return }
        eventTap = nil
        tapSource = nil
        tapInstalled = false
        onMainThread {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
    }

    fileprivate func noteTapEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let loc = event.location
        switch type {
        case .leftMouseDown:
            let clickState = event.getIntegerValueField(.mouseEventClickState)
            pushInteraction(clickState >= 2 ? "double-click" : "click", at: loc)
        case .rightMouseDown:
            pushInteraction("right-click", at: loc)
        case .otherMouseDown:
            pushInteraction("middle-click", at: loc)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            pushInteraction("mouseup", at: loc)
        default:
            break
        }
    }
}

// MARK: - RecordManager (singleton; command handlers below)

final class RecordManager {
    static let shared = RecordManager()
    private let lock = NSLock()
    private var recorder: ScreenRecorder?
    private var telemetry: CursorTelemetryRecorder?
    private var outPath = ""
    private var startWall = Date()

    /// Daemon event hook — wired lazily by cmdRecordStart to broadcast().
    var eventSink: ((String, JSONDict) -> Void)?

    var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }
        return recorder != nil
    }

    /// record_start {out, display_id?|window_id?, fps?, audio?, exclude_pids?}
    /// Blocks until the first frame lands in the writer (12s cap).
    func start(args: JSONDict, out: String) throws -> JSONDict {
        lock.lock()
        if recorder != nil {
            lock.unlock()
            throw DaemonError("invalid_state", "recording already in progress")
        }
        let rec = ScreenRecorder()
        recorder = rec
        lock.unlock()

        let windowId = args.int("window_id").map { CGWindowID($0) }
        let displayId = args.int("display_id").map { CGDirectDisplayID($0) }
        let fps = args.int("fps") ?? recordCaptureFPS
        let audio = args.bool("audio") ?? false
        let excluded = (args.array("exclude_pids") ?? []).compactMap {
            ($0 as? NSNumber)?.int32Value
        }
        // Optional explicit window rect (AX-visible frame beats SCWindow.frame
        // for windows with borders/shadows — same as Recordly's config).
        var windowFrame: CGRect?
        if let wf = args.dict("window_frame"),
           let x = wf["x"] as? Double ?? (wf["x"] as? NSNumber)?.doubleValue,
           let y = wf["y"] as? Double ?? (wf["y"] as? NSNumber)?.doubleValue,
           let w = wf["w"] as? Double ?? (wf["w"] as? NSNumber)?.doubleValue,
           let h = wf["h"] as? Double ?? (wf["h"] as? NSNumber)?.doubleValue {
            windowFrame = CGRect(x: x, y: y, width: w, height: h)
        }

        do {
            try rec.start(out: out, displayId: displayId, windowId: windowId,
                          windowFrame: windowFrame, fps: fps, audio: audio,
                          excludedProcessIds: excluded)
        } catch {
            lock.lock()
            recorder = nil
            lock.unlock()
            throw error
        }

        rec.onWindowGone = { [weak self] in
            self?.autoFinalize(reason: "window_unavailable")
        }
        rec.onStreamError = { [weak self] msg in
            self?.eventSink?("studio.rec.stream_error", ["message": msg])
            self?.autoFinalize(reason: "stream_error")
        }

        guard rec.waitFirstFrame() else {
            _ = try? rec.stop()
            lock.lock()
            recorder = nil
            lock.unlock()
            throw DaemonError("internal", "timed out waiting for first captured frame")
        }

        let tel = CursorTelemetryRecorder()
        telemetry = tel
        tel.start(normRect: rec.normRect)
        outPath = out
        startWall = Date()

        return [
            "recording": true,
            "out": out,
            "width": Int(rec.outputSize.width),
            "height": Int(rec.outputSize.height),
            "fps": fps,
            "audio": audio,
            "window_id": windowId.map { Int($0) } ?? NSNull(),
            "display_id": displayId.map { Int($0) } ?? NSNull(),
            "cursor_tap": tel.tapInstalled,
        ]
    }

    /// record_stop {} — finalizes the file and writes <out>.cursor.json.
    func stop() throws -> JSONDict {
        lock.lock()
        guard let rec = recorder else {
            lock.unlock()
            throw DaemonError("invalid_state", "no recording in progress")
        }
        let tel = telemetry
        recorder = nil
        telemetry = nil
        lock.unlock()

        let result = try rec.stop()
        let telemetryPath = tel?.stop(videoPath: result.path)
        var d: JSONDict = [
            "recording": false,
            "out": result.path,
            "frames": result.frames,
            "duration_s": result.durationS,
        ]
        if let telemetryPath { d["cursor_telemetry"] = telemetryPath }
        return d
    }

    func pause() throws -> JSONDict {
        lock.lock()
        guard let rec = recorder else {
            lock.unlock()
            throw DaemonError("invalid_state", "no recording in progress")
        }
        let tel = telemetry
        lock.unlock()
        let ok = rec.pause()
        if ok { tel?.pause() }
        return ["recording": true, "paused": ok && rec.paused]
    }

    func resume() throws -> JSONDict {
        lock.lock()
        guard let rec = recorder else {
            lock.unlock()
            throw DaemonError("invalid_state", "no recording in progress")
        }
        let tel = telemetry
        lock.unlock()
        let ok = rec.resume()
        if ok { tel?.resume() }
        return ["recording": true, "paused": rec.paused]
    }

    func status() -> JSONDict {
        lock.lock()
        guard let rec = recorder else {
            lock.unlock()
            return ["recording": false]
        }
        let tel = telemetry
        lock.unlock()
        var d: JSONDict = [
            "recording": true,
            "paused": rec.paused,
            "out": outPath,
            "frames": rec.frames,
            "elapsed_ms": Int(Date().timeIntervalSince(startWall) * 1000),
            "width": Int(rec.outputSize.width),
            "height": Int(rec.outputSize.height),
        ]
        if let wid = rec.trackedWindowId { d["window_id"] = Int(wid) }
        if let tel { d["cursor_tap"] = tel.tapInstalled }
        return d
    }

    /// Called when the tracked window dies or the stream errors out: finalize
    /// what we have and broadcast the reason. Never throws.
    private func autoFinalize(reason: String) {
        lock.lock()
        guard let rec = recorder else {
            lock.unlock()
            return
        }
        let tel = telemetry
        recorder = nil
        telemetry = nil
        lock.unlock()

        let result = try? rec.stop()
        let path = result?.path ?? ""
        let telemetryPath = path.isEmpty ? nil : tel?.stop(videoPath: path)
        var payload: JSONDict = ["reason": reason, "out": path]
        if let result {
            payload["frames"] = result.frames
            payload["duration_s"] = result.durationS
        }
        if let telemetryPath { payload["cursor_telemetry"] = telemetryPath }
        eventSink?("studio.rec.stopped", payload)
    }
}

// MARK: - Daemon command handlers

extension Daemon {
    func cmdRecordStart(_ a: JSONDict) throws -> JSONDict {
        let out = try requireStr(a, "out")
        // Event frames ride the daemon's broadcast bus (subscribers only).
        RecordManager.shared.eventSink = { [weak self] topic, payload in
            self?.broadcast(topic: topic, payload: payload)
        }
        return try RecordManager.shared.start(args: a, out: out)
    }

    func cmdRecordStop(_ a: JSONDict) throws -> JSONDict {
        try RecordManager.shared.stop()
    }

    func cmdRecordPause(_ a: JSONDict) throws -> JSONDict {
        try RecordManager.shared.pause()
    }

    func cmdRecordResume(_ a: JSONDict) throws -> JSONDict {
        try RecordManager.shared.resume()
    }

    func cmdRecordStatus(_ a: JSONDict) throws -> JSONDict {
        RecordManager.shared.status()
    }
}
