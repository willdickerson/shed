//
//  WorkspaceViewModel.swift
//  Shed
//
//  Single source of truth for the workspace. Orchestrates the import and audio
//  services and exposes plain state to the views; it holds no framework logic
//  of its own.
//

import Foundation
import Observation

@Observable
@MainActor
final class WorkspaceViewModel {

    /// Selectable playback speeds (pitch preserved).
    static let speedOptions: [Double] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

    // MARK: Dependencies

    let audio: AudioEngineController
    private let localImporter: LocalFileImporter
    private let youTubeImporter: YouTubeImporter
    private let waveformGenerator: WaveformGenerator
    private let store: AppStateStore

    // MARK: Track / waveform

    private(set) var track: Track?
    private(set) var waveform: WaveformData?
    var importStatus: ImportStatus = .idle

    // MARK: User-editable state

    var youTubeURLString: String = ""
    private(set) var speed: Double = 1.0
    private(set) var semitones: Int = 0
    private(set) var cents: Int = 0
    private(set) var volume: Double = 1.0
    private(set) var loopRegion: LoopRegion?
    private(set) var loopEnabled: Bool = false

    // MARK: Error presentation

    var activeError: PresentedError?

    private var importTask: Task<Void, Never>?

    // MARK: Init

    init(
        audio: AudioEngineController? = nil,
        localImporter: LocalFileImporter = LocalFileImporter(),
        youTubeImporter: YouTubeImporter = YouTubeImporter(),
        waveformGenerator: WaveformGenerator = WaveformGenerator(),
        store: AppStateStore = AppStateStore()
    ) {
        self.audio = audio ?? AudioEngineController()
        self.localImporter = localImporter
        self.youTubeImporter = youTubeImporter
        self.waveformGenerator = waveformGenerator
        self.store = store
        restore()
    }

    // MARK: - Derived state

    var hasTrack: Bool { track != nil }
    var currentTime: TimeInterval { audio.currentTime }
    var duration: TimeInterval { track?.duration ?? 0 }
    var isPlaying: Bool { audio.isPlaying }
    var totalPitchCents: Int { semitones * 100 + cents }
    var isImporting: Bool { importStatus.isBusy }
    var speedPercent: String { "\(Int((speed * 100).rounded()))%" }

    /// "YouTube • MP3 • 3:35" for the titlebar subtitle.
    var trackSubtitle: String {
        guard let track else { return "" }
        var parts = [track.source.displayName]
        if !track.format.isEmpty { parts.append(track.format) }
        parts.append(TimeFormatting.clock(track.duration))
        return parts.joined(separator: " • ")
    }

    // MARK: - Import

    func importLocalFile(at url: URL) {
        startImport { [weak self] in
            guard let self else { return }
            let track = try await localImporter.makeTrack(from: url)
            try await finishLoading(track)
        }
    }

    func importYouTube() {
        let urlString = youTubeURLString
        startImport { [weak self] in
            guard let self else { return }
            let track = try await youTubeImporter.makeTrack(from: urlString) { status in
                Task { @MainActor [weak self] in self?.importStatus = status }
            }
            try await finishLoading(track)
        }
    }

    private func startImport(_ work: @escaping () async throws -> Void) {
        guard !isImporting else { return }
        importStatus = .waiting
        importTask?.cancel()
        importTask = Task { [weak self] in
            do {
                try await work()
            } catch {
                self?.handleImportFailure(error)
            }
        }
    }

    /// Loads the track into the engine and builds its waveform. Runs on the
    /// main actor; the waveform read itself hops off-thread inside the service.
    private func finishLoading(_ track: Track) async throws {
        importStatus = .loadingWaveform
        let waveform = try await waveformGenerator.generate(from: track.workingURL)

        try audio.load(url: track.workingURL)
        audio.setSpeed(speed)
        audio.setPitch(cents: totalPitchCents)

        self.track = track
        self.waveform = waveform
        clampLoopToTrack()
        audio.setLoop(loopRegion)
        audio.setLoopEnabled(loopEnabled)

        importStatus = .ready
        persist()
    }

    private func handleImportFailure(_ error: Error) {
        let shedError = (error as? ShedError) ?? ShedError.conversionFailed(error.localizedDescription)
        importStatus = .failed(shedError.errorDescription ?? "Unknown error")
        present(shedError)
    }

    // MARK: - Transport

    func togglePlayPause() {
        guard hasTrack else { return present(.noFileLoaded) }
        do { try audio.togglePlayPause() } catch { presentAny(error) }
    }

    func stop() { audio.stop() }

    func skipBackward() { audio.skip(by: -5) }
    func skipForward() { audio.skip(by: 5) }

    func seek(to time: TimeInterval) {
        guard hasTrack else { return }
        audio.seek(to: time)
    }

    // MARK: - Speed & pitch

    func setSpeed(_ value: Double) {
        speed = value
        audio.setSpeed(value)
        persist()
    }

    /// Steps to the next slower preset speed (bound to the `-` key).
    func decreaseSpeed() {
        guard let index = Self.speedOptions.firstIndex(of: speed), index > 0 else { return }
        setSpeed(Self.speedOptions[index - 1])
    }

    /// Steps to the next faster preset speed (bound to the `=` key).
    func increaseSpeed() {
        guard let index = Self.speedOptions.firstIndex(of: speed),
              index < Self.speedOptions.count - 1 else { return }
        setSpeed(Self.speedOptions[index + 1])
    }

    func setVolume(_ value: Double) {
        volume = value
        audio.setVolume(value)
    }

    func setSemitones(_ value: Int) {
        semitones = min(12, max(-12, value))
        audio.setPitch(cents: totalPitchCents)
        persist()
    }

    func setCents(_ value: Int) {
        cents = min(100, max(-100, value))
        audio.setPitch(cents: totalPitchCents)
        persist()
    }

    func resetPitch() {
        semitones = 0
        cents = 0
        audio.setPitch(cents: 0)
        persist()
    }

    var isPitchAdjusted: Bool { semitones != 0 || cents != 0 }

    // MARK: - Loop

    func toggleLoop() {
        if loopEnabled {
            // Turning looping off also clears the drawn region.
            clearLoop()
        } else {
            if loopRegion == nil {
                // Default to a 4-second loop starting at the playhead.
                loopRegion = LoopRegion(start: currentTime, end: min(duration, currentTime + 4))
                    .clamped(to: duration)
                audio.setLoop(loopRegion)
            }
            loopEnabled = true
            audio.setLoopEnabled(true)
            persist()
        }
    }

    /// Handles a click on the waveform: inside an active loop keeps looping,
    /// outside it exits loop mode and plays from the clicked position.
    func handleWaveformClick(at time: TimeInterval) {
        if loopEnabled, let loop = loopRegion {
            if time >= loop.start && time <= loop.end { return }
            clearLoop()
        }
        seek(to: time)
    }

    /// Creates a loop and enters loop mode in one step — used when the user
    /// drags a region on the waveform.
    func createLoop(_ region: LoopRegion) {
        loopRegion = region.clamped(to: duration)
        audio.setLoop(loopRegion)
        loopEnabled = true
        audio.setLoopEnabled(true)
        persist()
    }

    /// Updates the loop region while preserving whether looping is enabled.
    func setLoopRegion(_ region: LoopRegion?) {
        loopRegion = region.map { $0.clamped(to: duration) }
        audio.setLoop(loopRegion)
        persist()
    }

    func setLoopStartAtPlayhead() {
        let end = loopRegion?.end ?? duration
        createLoop(LoopRegion(start: currentTime, end: end))
    }

    func setLoopEndAtPlayhead() {
        let start = loopRegion?.start ?? 0
        createLoop(LoopRegion(start: start, end: currentTime))
    }

    func clearLoop() {
        loopRegion = nil
        loopEnabled = false
        audio.setLoop(nil)
        audio.setLoopEnabled(false)
        persist()
    }

    private func clampLoopToTrack() {
        guard let region = loopRegion else { return }
        let clamped = region.clamped(to: duration)
        loopRegion = clamped.isUsable ? clamped : nil
    }

    // MARK: - Errors

    func present(_ error: ShedError) {
        activeError = PresentedError(message: error.errorDescription ?? "Something went wrong.")
    }

    private func presentAny(_ error: Error) {
        if let shed = error as? ShedError { present(shed) }
        else { activeError = PresentedError(message: error.localizedDescription) }
    }

    // MARK: - Persistence

    private func restore() {
        let state = store.load()
        youTubeURLString = state.youTubeURLString
        speed = state.speed
        semitones = state.semitones
        cents = state.cents
        loopEnabled = state.loopEnabled
        loopRegion = state.loopEnabled ? state.loop : nil

        audio.setSpeed(speed)
        audio.setPitch(cents: totalPitchCents)
        audio.setVolume(volume)

        // Re-open the last track if its working WAV still exists.
        guard
            let path = state.workingPath,
            FileManager.default.fileExists(atPath: path),
            let name = state.displayName,
            let source = state.source
        else { return }

        let url = URL(fileURLWithPath: path)
        importTask = Task { [weak self] in
            guard let self else { return }
            do {
                let duration = try LocalFileImporter.duration(of: url)
                let restored = Track(
                    displayName: name,
                    source: source,
                    workingURL: url,
                    duration: duration,
                    format: state.format ?? ""
                )
                try await self.finishLoading(restored)
            } catch {
                // A failed restore is non-fatal; just start with an empty state.
                self.importStatus = .idle
            }
        }
    }

    private func persist() {
        let state = PersistedState(
            workingPath: track?.workingURL.path,
            displayName: track?.displayName,
            source: track?.source,
            format: track?.format,
            youTubeURLString: youTubeURLString,
            speed: speed,
            semitones: semitones,
            cents: cents,
            loop: loopRegion,
            loopEnabled: loopEnabled
        )
        store.save(state)
    }
}

/// Wrapper so SwiftUI can present an error via `.alert(item:)`.
struct PresentedError: Identifiable {
    let id = UUID()
    let message: String
}
