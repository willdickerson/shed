//
//  WorkspaceViewModel.swift
//  Shed
//
//  Single source of truth for the workspace. Orchestrates the import and audio
//  services and exposes plain state to the views; it holds no framework logic
//  of its own.
//

import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class WorkspaceViewModel {

    /// Selectable playback speeds (pitch preserved).
    static let speedOptions: [Double] = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

    // MARK: Dependencies

    let audio: AudioEngineController
    private let localImporter: LocalFileImporter
    private let youTubeImporter: YouTubeImporter
    private let waveformGenerator: WaveformGenerator
    private let tuningAnalyzer: TuningAnalyzer
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
    private(set) var tuningState: TuningAnalysisState = .idle

    // MARK: Recents

    private(set) var recentTracks: [RecentTrack] = []

    // MARK: Presentation (driven by both the toolbar and the File menu)

    var isShowingFileImporter = false
    var isShowingYouTubeSheet = false

    // MARK: Error presentation

    var activeError: PresentedError?

    private var importTask: Task<Void, Never>?
    private var tuningTask: Task<Void, Never>?

    /// Per-song speed/pitch/loop, keyed by working-file path.
    private var trackSettings: [String: TrackSettings] = [:]

    // MARK: Init

    init(
        audio: AudioEngineController? = nil,
        localImporter: LocalFileImporter = LocalFileImporter(),
        youTubeImporter: YouTubeImporter = YouTubeImporter(),
        waveformGenerator: WaveformGenerator = WaveformGenerator(),
        tuningAnalyzer: TuningAnalyzer = TuningAnalyzer(),
        store: AppStateStore = AppStateStore()
    ) {
        self.audio = audio ?? AudioEngineController()
        self.localImporter = localImporter
        self.youTubeImporter = youTubeImporter
        self.waveformGenerator = waveformGenerator
        self.tuningAnalyzer = tuningAnalyzer
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

    func requestOpenFile() { isShowingFileImporter = true }
    func requestYouTubeImport() { isShowingYouTubeSheet = true }

    func importLocalFile(at url: URL) {
        startImport { [weak self] in
            guard let self else { return }
            let track = try await localImporter.makeTrack(from: url)
            try await finishLoading(track)
        }
    }

    /// Reopens a recent track straight from its persisted working file — no
    /// re-download or re-conversion.
    func openRecent(_ item: RecentTrack) {
        let url = URL(fileURLWithPath: item.path)
        guard FileManager.default.fileExists(atPath: item.path) else {
            recentTracks.removeAll { $0.path == item.path }
            persist()
            present(.audioLoadFailed("“\(item.name)” is no longer available."))
            return
        }
        startImport { [weak self] in
            guard let self else { return }
            let duration = try LocalFileImporter.duration(of: url)
            let track = Track(displayName: item.name, source: item.source,
                              workingURL: url, duration: duration, format: item.format)
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

        self.track = track
        self.waveform = waveform
        tuningTask?.cancel()
        tuningState = .idle
        loopUndoStack.removeAll()

        // Restore this song's own settings (defaults for a song not seen before).
        let saved = trackSettings[track.workingURL.path]
        speed = saved?.speed ?? 1.0
        semitones = saved?.semitones ?? 0
        cents = saved?.cents ?? 0
        loopEnabled = saved?.loopEnabled ?? false
        loopRegion = (saved?.loopEnabled == true) ? saved?.loop : nil
        clampLoopToTrack()

        audio.setSpeed(speed)
        audio.setPitch(cents: totalPitchCents)
        audio.setLoop(loopRegion)
        audio.setLoopEnabled(loopEnabled)

        addRecent(track)
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

    // MARK: - Recents & Finder

    private func addRecent(_ track: Track) {
        let item = RecentTrack(path: track.workingURL.path, name: track.displayName,
                               source: track.source, format: track.format)
        recentTracks.removeAll { $0.path == item.path }
        recentTracks.insert(item, at: 0)
        if recentTracks.count > 8 { recentTracks = Array(recentTracks.prefix(8)) }
        persist()
    }

    func clearRecentFiles() {
        recentTracks = []
        persist()
    }

    func revealCurrentFileInFinder() {
        guard let track else { return }
        let url = track.originalURL ?? track.workingURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

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
        collapseTuningResult()
        persist()
    }

    func setCents(_ value: Int) {
        cents = min(100, max(-100, value))
        audio.setPitch(cents: totalPitchCents)
        collapseTuningResult()
        persist()
    }

    func resetPitch() {
        semitones = 0
        cents = 0
        audio.setPitch(cents: 0)
        collapseTuningResult()
        persist()
    }

    var isPitchAdjusted: Bool { semitones != 0 || cents != 0 }

    // MARK: - Tuning analysis

    func findTuningOffset() {
        guard let track, tuningState != .analyzing else { return }
        tuningState = .analyzing
        let url = track.workingURL
        tuningTask?.cancel()
        tuningTask = Task { [weak self] in
            guard let self else { return }
            do {
                let estimate = try await tuningAnalyzer.analyze(url: url)
                guard !Task.isCancelled else { return }
                tuningState = estimate.map { .result($0) } ?? .failed
            } catch {
                tuningState = .failed
            }
        }
    }

    /// Applies the estimated correction to the Cents control, then briefly
    /// confirms before returning to idle. Never invoked automatically.
    func applyTuningCorrection() {
        guard case let .result(estimate) = tuningState else { return }
        setCents(Int((-estimate.offsetCents).rounded()))
        tuningState = .applied
        tuningTask?.cancel()
        tuningTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled else { return }
            if tuningState == .applied { tuningState = .idle }
        }
    }

    /// Collapses a presented result back to idle (used for "click elsewhere").
    /// Leaves analysis-in-progress and the transient confirmation untouched.
    func collapseTuningResult() {
        switch tuningState {
        case .result, .failed: tuningState = .idle
        default: break
        }
    }

    // MARK: - Loop

    private struct LoopSnapshot: Equatable {
        var region: LoopRegion?
        var enabled: Bool
    }
    private var loopUndoStack: [LoopSnapshot] = []

    var canUndoLoop: Bool { !loopUndoStack.isEmpty }

    /// Records the loop state before a change so it can be undone.
    private func snapshotLoop() {
        loopUndoStack.append(LoopSnapshot(region: loopRegion, enabled: loopEnabled))
        if loopUndoStack.count > 25 { loopUndoStack.removeFirst() }
    }

    /// Restores the loop to its state before the last change (⌘Z) — brings back
    /// a loop cleared by accident.
    func undoLoop() {
        guard let previous = loopUndoStack.popLast() else { return }
        loopRegion = previous.region
        loopEnabled = previous.enabled
        audio.setLoop(loopRegion)
        audio.setLoopEnabled(loopEnabled)
        persist()
    }

    func toggleLoop() {
        snapshotLoop()
        if loopEnabled {
            // Turning looping off also clears the drawn region.
            loopRegion = nil
            loopEnabled = false
            audio.setLoop(nil)
            audio.setLoopEnabled(false)
        } else {
            if loopRegion == nil {
                // Default to a 4-second loop starting at the playhead.
                loopRegion = LoopRegion(start: currentTime, end: min(duration, currentTime + 4))
                    .clamped(to: duration)
                audio.setLoop(loopRegion)
            }
            loopEnabled = true
            audio.setLoopEnabled(true)
        }
        persist()
    }

    /// Handles a click on the waveform: inside an active loop, repositions the
    /// playhead within it and keeps looping; outside, exits loop mode and plays
    /// from the clicked position.
    func handleWaveformClick(at time: TimeInterval) {
        if loopEnabled, let loop = loopRegion {
            if time >= loop.start && time <= loop.end {
                seek(to: time)
                return
            }
            clearLoop()
        }
        seek(to: time)
    }

    /// Creates a loop and enters loop mode in one step — used when the user
    /// drags a region on the waveform.
    func createLoop(_ region: LoopRegion) {
        snapshotLoop()
        loopRegion = region.clamped(to: duration)
        audio.setLoop(loopRegion)
        loopEnabled = true
        audio.setLoopEnabled(true)
        persist()
    }

    /// Updates the loop region while preserving whether looping is enabled.
    func setLoopRegion(_ region: LoopRegion?) {
        snapshotLoop()
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

    /// Return key: jump to the loop start while looping, else the track start.
    func returnToStart() {
        if loopEnabled, let loop = loopRegion, loop.isUsable {
            seek(to: loop.start)
        } else {
            seek(to: 0)
        }
    }

    func clearLoop() {
        snapshotLoop()
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
        trackSettings = state.trackSettings ?? [:]
        // Keep only recents whose working file still exists.
        recentTracks = (state.recentTracks ?? []).filter {
            FileManager.default.fileExists(atPath: $0.path)
        }

        audio.setVolume(volume)

        // Re-open the last track if its working WAV still exists; its own
        // settings are applied in finishLoading.
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
        // Capture the current song's settings, then keep only settings for songs
        // still in Recents so the store stays bounded.
        if let path = track?.workingURL.path {
            trackSettings[path] = TrackSettings(
                speed: speed, semitones: semitones, cents: cents,
                loop: loopRegion, loopEnabled: loopEnabled
            )
        }
        var keep = Set(recentTracks.map(\.path))
        if let path = track?.workingURL.path { keep.insert(path) }
        trackSettings = trackSettings.filter { keep.contains($0.key) }

        let state = PersistedState(
            workingPath: track?.workingURL.path,
            displayName: track?.displayName,
            source: track?.source,
            format: track?.format,
            youTubeURLString: youTubeURLString,
            recentTracks: recentTracks,
            trackSettings: trackSettings
        )
        store.save(state)
    }
}

/// Wrapper so SwiftUI can present an error via `.alert(item:)`.
struct PresentedError: Identifiable {
    let id = UUID()
    let message: String
}
