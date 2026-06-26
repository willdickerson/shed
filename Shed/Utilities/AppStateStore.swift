//
//  AppStateStore.swift
//  Shed
//
//  Lightweight UserDefaults-backed persistence of the last session.
//

import Foundation

/// Snapshot of persisted UI state, restored on launch.
nonisolated struct PersistedState: Codable, Sendable {
    var workingPath: String?
    var displayName: String?
    var source: TrackSource?
    var youTubeURLString: String
    var speed: Double
    var semitones: Int
    var cents: Int
    var loop: LoopRegion?
    var loopEnabled: Bool

    static let `default` = PersistedState(
        workingPath: nil,
        displayName: nil,
        source: nil,
        youTubeURLString: "",
        speed: 1.0,
        semitones: 0,
        cents: 0,
        loop: nil,
        loopEnabled: false
    )
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
