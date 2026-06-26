//
//  LoopRegion.swift
//  Shed
//

import Foundation

/// An A/B loop region expressed in seconds within the track timeline.
/// `start` is always <= `end`.
nonisolated struct LoopRegion: Equatable, Sendable, Codable {
    var start: TimeInterval
    var end: TimeInterval

    init(start: TimeInterval, end: TimeInterval) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    var duration: TimeInterval { end - start }

    /// Whether the region is long enough to be a usable loop.
    var isUsable: Bool { duration >= 0.05 }

    /// Returns a copy clamped into `0...trackDuration`.
    func clamped(to trackDuration: TimeInterval) -> LoopRegion {
        LoopRegion(
            start: Swift.max(0, Swift.min(start, trackDuration)),
            end: Swift.max(0, Swift.min(end, trackDuration))
        )
    }
}
