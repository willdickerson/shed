//
//  WaveformData.swift
//  Shed
//

import Foundation

/// Downsampled waveform: one min/max amplitude pair per bucket. The renderer
/// aggregates these further to match the on-screen pixel width.
nonisolated struct WaveformData: Equatable, Sendable {
    /// Minimum sample value per bucket (typically negative).
    let mins: [Float]
    /// Maximum sample value per bucket (typically positive).
    let maxs: [Float]
    /// Largest absolute amplitude across the whole file, used to normalize.
    let peak: Float
    let duration: TimeInterval

    var bucketCount: Int { mins.count }

    static let empty = WaveformData(mins: [], maxs: [], peak: 1, duration: 0)
}
