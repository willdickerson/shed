//
//  Track.swift
//  Shed
//

import Foundation

/// A loaded, playable track. `workingURL` always points at a decoded WAV file
/// inside Shed's working directory, so the rest of the app never has to worry
/// about the original container format.
nonisolated struct Track: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let source: TrackSource
    let workingURL: URL
    let duration: TimeInterval
    /// Original container format for display, e.g. "MP3" (working file is WAV).
    let format: String
    /// The user's original file (local imports only); nil for YouTube. Used by
    /// "Reveal Current File in Finder".
    let originalURL: URL?

    init(
        id: UUID = UUID(),
        displayName: String,
        source: TrackSource,
        workingURL: URL,
        duration: TimeInterval,
        format: String = "",
        originalURL: URL? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.workingURL = workingURL
        self.duration = duration
        self.format = format
        self.originalURL = originalURL
    }
}
