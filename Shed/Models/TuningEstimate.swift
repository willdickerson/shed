//
//  TuningEstimate.swift
//  Shed
//

import Foundation

/// Result of estimating how far a recording sits from standard (A440) tuning.
struct TuningEstimate: Equatable, Sendable {
    /// Signed offset in cents; negative is flat, positive is sharp.
    var offsetCents: Double
    /// How many stable pitch detections the estimate is based on.
    var detectionCount: Int
}

/// State of the "Find Tuning Offset" interaction.
enum TuningAnalysisState: Equatable, Sendable {
    case idle
    case analyzing
    case result(TuningEstimate)
    case applied
    case failed
}
