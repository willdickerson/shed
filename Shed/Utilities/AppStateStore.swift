//
//  AppStateStore.swift
//  Shed
//
//  Lightweight UserDefaults-backed persistence of the last session.
//

import Foundation

/// Per-song playback settings, keyed by working-file path. Lets loop and pitch
/// be remembered for each song rather than carried across songs.
nonisolated struct TrackSettings: Codable, Sendable, Equatable {
    var speed: Double
    var semitones: Int
    var cents: Int
    var loop: LoopRegion?
    var loopEnabled: Bool
}

/// Snapshot of persisted UI state, restored on launch.
nonisolated struct PersistedState: Codable, Sendable {
    var workingPath: String?
    var displayName: String?
    var source: TrackSource?
    /// Optional so older persisted blobs (without this key) still decode.
    var format: String?
    var youTubeURLString: String
    /// Recently loaded tracks, most recent first.
    var recentTracks: [RecentTrack]?
    /// Speed/pitch/loop per song, keyed by working-file path.
    var trackSettings: [String: TrackSettings]?

    static let `default` = PersistedState(
        workingPath: nil,
        displayName: nil,
        source: nil,
        format: nil,
        youTubeURLString: "",
        recentTracks: nil,
        trackSettings: nil
    )
}

/// A previously loaded track, reopenable from its persisted working file.
nonisolated struct RecentTrack: Codable, Sendable, Equatable, Identifiable {
    var path: String
    var name: String
    var source: TrackSource
    var format: String

    var id: String { path }
}

/// Persists `PersistedState` as a single JSON blob in UserDefaults.
nonisolated struct AppStateStore {
    private let defaults: UserDefaults
    private let key = "shed.persistedState.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PersistedState {
        guard
            let data = defaults.data(forKey: key),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else {
            return .default
        }
        return state
    }

    func save(_ state: PersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}
