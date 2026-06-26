//
//  TrackSource.swift
//  Shed
//

import Foundation

/// Where a loaded track originally came from.
nonisolated enum TrackSource: String, Codable, Sendable {
    case localFile
    case youTube

    var displayName: String {
        switch self {
        case .localFile: return "Local File"
        case .youTube: return "YouTube"
        }
    }
}
