//
//  ImportStatus.swift
//  Shed
//

import Foundation

/// Progress of an in-flight import (local file or YouTube). Drives the status
/// text shown in the import bar.
nonisolated enum ImportStatus: Equatable, Sendable {
    case idle
    case waiting
    case downloading(progress: Double?)
    case converting
    case loadingWaveform
    case ready
    case failed(String)

    var label: String {
        switch self {
        case .idle: return ""
        case .waiting: return "Waiting…"
        case let .downloading(progress):
            if let progress { return "Downloading audio… \(Int(progress * 100))%" }
            return "Downloading audio…"
        case .converting: return "Converting audio…"
        case .loadingWaveform: return "Loading waveform…"
        case .ready: return "Ready"
        case let .failed(message): return "Failed: \(message)"
        }
    }

    var isBusy: Bool {
        switch self {
        case .waiting, .downloading, .converting, .loadingWaveform: return true
        default: return false
        }
    }
}
