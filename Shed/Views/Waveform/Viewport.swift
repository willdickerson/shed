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

    /// Shifts the window by a scroll delta, where `width` is the view's width
    /// in points. Content follows the fingers, matching NSScrollView's
    /// direction. Returns whether the window actually moved.
    @discardableResult
    mutating func pan(byPixels deltaX: Double, width: Double, total: TimeInterval) -> Bool {
        let visible = visibleDuration(total: total)
        guard width > 0, visible > 0, visible < total else { return false }
        let current = clampedStart(total: total)
        let newStart = min(max(0, current - deltaX / width * visible), max(0, total - visible))
        guard newStart != current else { return false }
        start = newStart
        return true
    }
}
