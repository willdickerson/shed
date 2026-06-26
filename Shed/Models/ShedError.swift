//
//  ShedError.swift
//  Shed
//
//  A single typed error surface for the whole app so the UI can present
//  human-readable messages instead of leaking framework errors.
//

import Foundation

nonisolated enum ShedError: LocalizedError, Equatable {
    case missingBinary(name: String, path: String)
    case invalidURL
    case downloadFailed(String)
    case conversionFailed(String)
    case unsupportedFile(String)
    case audioLoadFailed(String)
    case waveformFailed(String)
    case workingDirectory(String)
    case noFileLoaded
    case playbackEngine(String)

    var errorDescription: String? {
        switch self {
        case let .missingBinary(name, path):
            return "Couldn’t find “\(name)”. Shed expected it at \(path). Install it with: brew install yt-dlp ffmpeg"
        case .invalidURL:
            return "That doesn’t look like a valid URL. Paste a full YouTube link."
        case let .downloadFailed(detail):
            return "The download failed.\n\(detail)"
        case let .conversionFailed(detail):
            return "Audio conversion failed.\n\(detail)"
        case let .unsupportedFile(ext):
            return "Files of type “\(ext)” aren’t supported."
        case let .audioLoadFailed(detail):
            return "Couldn’t load the audio.\n\(detail)"
        case let .waveformFailed(detail):
            return "Couldn’t read the waveform.\n\(detail)"
        case let .workingDirectory(detail):
            return "Couldn’t prepare Shed’s working folder.\n\(detail)"
        case .noFileLoaded:
            return "Open an audio file or import a YouTube URL first."
        case let .playbackEngine(detail):
            return "The audio engine ran into a problem.\n\(detail)"
        }
    }
}
