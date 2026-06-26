//
//  Viewport.swift
//  Shed
//
//  The visible horizontal window into the waveform. `zoom` of 1 shows the whole
//  song; higher values zoom in. View state only — no audio/business logic.
//

import Foundation

struct Viewport: Equatable {
    var zoom: Double = 1
    var start: TimeInterval = 0

    static let maxZoom: Double = 24

    func visibleDuration(total: TimeInterval) -> TimeInterval {
        guard total > 0 else { return 0 }
        return total / min(max(1, zoom), Self.maxZoom)
    }

    /// `start` clamped so the visible window stays inside the track.
    func clampedStart(total: TimeInterval) -> TimeInterval {
        let visible = visibleDuration(total: total)
        return min(max(0, start), max(0, total - visible))
    }

    /// Re-centers the window on `time`, keeping it inside the track.
    mutating func center(on time: TimeInterval, total: TimeInterval) {
        let visible = visibleDuration(total: total)
        start = min(max(0, time - visible / 2), max(0, total - visible))
    }
}
