//
//  AudioEngineController.swift
//  Shed
//
//  Wraps AVAudioEngine + AVAudioPlayerNode + AVAudioUnitTimePitch.
//
//  Two playback modes:
//   • Normal — a single scheduled segment from a file position to the end.
//   • Loop   — the loop region is read into a buffer and scheduled with the
//              `.loops` option, so AVAudioPlayerNode repeats it gaplessly.
//
//  The playhead is tracked in *file time* (seconds into the source audio),
//  derived from the player node's render clock, so it's independent of the
//  time-pitch rate — changing speed or pitch never disturbs position or loop.
//

import AVFoundation
import Observation

@Observable
final class AudioEngineController {

    // MARK: Observable state

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    // MARK: Engine graph

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()

    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44_100

    // MARK: Playback parameters

    private var rate: Float = 1.0
    private var pitchCents: Float = 0

    // MARK: Loop

    private var loopRegion: LoopRegion?
    private var loopEnabled = false

    // MARK: Scheduling bookkeeping

    /// Whether a segment/buffer is currently scheduled and ready to play.
    private var hasActiveSchedule = false
    /// Normal mode: file frame where the scheduled segment begins.
    private var segmentStartFrame: AVAudioFramePosition = 0
    /// Loop mode: the region whose buffer is currently scheduled (nil in normal mode).
    private var scheduledLoop: LoopRegion?
    /// Loop mode: start time and length of the looping buffer.
    private var loopStartTime: TimeInterval = 0
    private var loopFrames: AVAudioFramePosition = 0

    private var isLoopingBuffer: Bool { scheduledLoop != nil }

    private var displayTask: Task<Void, Never>?

    init() {
        engine.attach(player)
        engine.attach(timePitch)
    }

    deinit {
        displayTask?.cancel()
        engine.stop()
    }

    // MARK: - Loading

    func load(url: URL) throws {
        stop()

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw ShedError.audioLoadFailed(error.localizedDescription)
        }

        audioFile = file
        let format = file.processingFormat
        sampleRate = format.sampleRate
        duration = sampleRate > 0 ? Double(file.length) / sampleRate : 0

        // Reconnecting the graph requires a stopped engine.
        if engine.isRunning { engine.stop() }
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        engine.prepare()

        currentTime = 0
        isPlaying = false
        applyRateAndPitch()
        scheduleNormal(fromFileTime: 0)
    }

    // MARK: - Transport

    func play() throws {
        guard audioFile != nil else { throw ShedError.noFileLoaded }

        if !engine.isRunning {
            do { try engine.start() }
            catch { throw ShedError.playbackEngine(error.localizedDescription) }
        }

        if let loop = activeLoop {
            // (Re)build the looping buffer unless we're resuming the same one.
            if !(isLoopingBuffer && scheduledLoop == loop && hasActiveSchedule) {
                scheduleLoop(loop)
            }
        } else if isLoopingBuffer {
            // Leaving loop mode: continue from the current position.
            scheduleNormal(fromFileTime: currentTime)
        } else if !hasActiveSchedule || currentTime >= duration - 0.02 {
            scheduleNormal(fromFileTime: currentTime >= duration - 0.02 ? 0 : currentTime)
        }

        player.play()
        isPlaying = true
        startDisplayLoop()
    }

    func pause() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
        stopDisplayLoop()
    }

    func togglePlayPause() throws {
        if isPlaying { pause() } else { try play() }
    }

    func stop() {
        player.stop()
        stopDisplayLoop()
        isPlaying = false
        hasActiveSchedule = false
        scheduledLoop = nil
        segmentStartFrame = 0
        currentTime = 0
        if audioFile != nil { scheduleNormal(fromFileTime: 0) }
    }

    func seek(to time: TimeInterval) {
        guard audioFile != nil else { return }

        // While looping, the playhead is constrained to the region; seeking
        // (re)anchors the loop at its start so playback stays seamless.
        if let loop = activeLoop {
            if isPlaying {
                scheduleLoop(loop)
                player.play()
            } else {
                currentTime = loop.start
            }
            return
        }

        let clamped = min(max(0, time), duration)
        let wasPlaying = isPlaying
        scheduleNormal(fromFileTime: clamped)
        if wasPlaying {
            if !engine.isRunning { try? engine.start() }
            player.play()
        }
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    // MARK: - Parameters

    func setSpeed(_ speed: Double) {
        rate = Float(speed)
        timePitch.rate = rate
    }

    func setPitch(cents: Int) {
        pitchCents = Float(cents)
        timePitch.pitch = pitchCents
    }

    func setLoop(_ region: LoopRegion?) {
        loopRegion = region
        reconcilePlayback()
    }

    func setLoopEnabled(_ enabled: Bool) {
        loopEnabled = enabled
        reconcilePlayback()
    }

    // MARK: - Private

    /// The loop region that should currently govern playback, if any.
    private var activeLoop: LoopRegion? {
        guard loopEnabled, let loop = loopRegion, loop.isUsable else { return nil }
        return loop
    }

    /// Brings playback in line with the current loop settings. Restarts the
    /// engine's schedule when playing; snaps the playhead into the region when
    /// paused, so the cursor is never left outside a drawn loop.
    private func reconcilePlayback() {
        guard audioFile != nil else { return }

        if isPlaying {
            if let loop = activeLoop {
                if !(isLoopingBuffer && scheduledLoop == loop) {
                    scheduleLoop(loop)
                    player.play()
                }
            } else if isLoopingBuffer {
                scheduleNormal(fromFileTime: currentTime)
                player.play()
            }
        } else if let loop = activeLoop, currentTime < loop.start || currentTime >= loop.end {
            currentTime = loop.start
        }
    }

    private func applyRateAndPitch() {
        timePitch.rate = rate
        timePitch.pitch = pitchCents
    }

    private func frame(for time: TimeInterval) -> AVAudioFramePosition {
        guard let file = audioFile else { return 0 }
        return max(0, min(AVAudioFramePosition(time * sampleRate), file.length))
    }

    /// Schedules a single segment from `fromFileTime` to the end of the file.
    private func scheduleNormal(fromFileTime time: TimeInterval) {
        guard let file = audioFile else { return }
        player.stop()
        scheduledLoop = nil
        let start = frame(for: time)
        segmentStartFrame = start
        currentTime = Double(start) / sampleRate

        let count = AVAudioFrameCount(file.length - start)
        guard count > 0 else { hasActiveSchedule = false; return }
        player.scheduleSegment(file, startingFrame: start, frameCount: count, at: nil)
        hasActiveSchedule = true
    }

    /// Reads `loop` into a buffer and schedules it to repeat seamlessly.
    private func scheduleLoop(_ loop: LoopRegion) {
        guard let file = audioFile else { return }
        let startFrame = frame(for: loop.start)
        let endFrame = frame(for: loop.end)
        let length = AVAudioFrameCount(max(0, endFrame - startFrame))

        guard length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: length)
        else {
            scheduleNormal(fromFileTime: loop.start)
            return
        }

        do {
            file.framePosition = startFrame
            try file.read(into: buffer, frameCount: length)
        } catch {
            scheduleNormal(fromFileTime: loop.start)
            return
        }

        player.stop()
        scheduledLoop = loop
        loopStartTime = Double(startFrame) / sampleRate
        loopFrames = AVAudioFramePosition(length)
        currentTime = loopStartTime
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        hasActiveSchedule = true
    }

    /// Playhead in file time, derived from the player node's render clock.
    private func computeCurrentTime() -> TimeInterval {
        guard
            let nodeTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: nodeTime)
        else { return currentTime }

        if isLoopingBuffer, loopFrames > 0 {
            var within = playerTime.sampleTime % loopFrames
            if within < 0 { within += loopFrames }
            return loopStartTime + Double(within) / sampleRate
        }
        return Double(segmentStartFrame + playerTime.sampleTime) / sampleRate
    }

    private func startDisplayLoop() {
        stopDisplayLoop()
        displayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(30))
                self?.tick()
            }
        }
    }

    private func stopDisplayLoop() {
        displayTask?.cancel()
        displayTask = nil
    }

    private func tick() {
        guard isPlaying else { return }
        let time = computeCurrentTime()

        // The looping buffer repeats on its own; only normal playback ends.
        if !isLoopingBuffer, time >= duration {
            currentTime = duration
            player.pause()
            isPlaying = false
            hasActiveSchedule = false
            stopDisplayLoop()
            return
        }

        currentTime = time
    }
}
