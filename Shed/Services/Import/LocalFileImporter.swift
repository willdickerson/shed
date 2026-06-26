//
//  LocalFileImporter.swift
//  Shed
//
//  Brings a user-selected local file into the working directory as a WAV.
//

import AVFoundation
import Foundation

nonisolated struct LocalFileImporter {
    static let supportedExtensions: Set<String> =
        ["wav", "mp3", "m4a", "aiff", "aif", "flac", "mp4", "mov"]

    private let workingDirectory: WorkingDirectory
    private let converter: AudioConverter

    init(
        workingDirectory: WorkingDirectory = WorkingDirectory(),
        converter: AudioConverter = AudioConverter()
    ) {
        self.workingDirectory = workingDirectory
        self.converter = converter
    }

    /// Imports `source`, returning a `Track` backed by a WAV in the working dir.
    /// Already-WAV files are copied; everything else is converted via ffmpeg.
    nonisolated func makeTrack(from source: URL) async throws -> Track {
        let ext = source.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            throw ShedError.unsupportedFile(ext.isEmpty ? "unknown" : ext)
        }

        let destination = try workingDirectory.makeWAVDestination()

        if ext == "wav" {
            try copy(from: source, to: destination)
        } else {
            try await converter.convertToWAV(input: source, output: destination)
        }

        let duration = try Self.duration(of: destination)
        let name = source.deletingPathExtension().lastPathComponent
        return Track(
            displayName: name,
            source: .localFile,
            workingURL: destination,
            duration: duration
        )
    }

    private nonisolated func copy(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw ShedError.audioLoadFailed(error.localizedDescription)
        }
    }

    static func duration(of url: URL) throws -> TimeInterval {
        do {
            let file = try AVAudioFile(forReading: url)
            let frames = Double(file.length)
            let rate = file.processingFormat.sampleRate
            guard rate > 0 else { throw ShedError.audioLoadFailed("Invalid sample rate.") }
            return frames / rate
        } catch let error as ShedError {
            throw error
        } catch {
            throw ShedError.audioLoadFailed(error.localizedDescription)
        }
    }
}
