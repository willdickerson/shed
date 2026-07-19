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

        // A WAV already in the imports folder is opened in place — no duplicate
        // copy, and its per-song settings stay keyed to the same path.
        if ext == "wav", let imports = try? workingDirectory.importsURL(),
           source.deletingLastPathComponent().standardizedFileURL.path == imports.standardizedFileURL.path {
            let title = await Self.embeddedTitle(of: source) ?? Self.displayName(for: source)
            return Track(
                displayName: title,
                source: .localFile,
                workingURL: source,
                duration: try Self.duration(of: source),
                format: "WAV"
            )
        }

        let name = source.deletingPathExtension().lastPathComponent
        let destination = try workingDirectory.makeWAVDestination(name: name)

        if ext == "wav" {
            try copy(from: source, to: destination)
        } else {
            try await converter.convertToWAV(input: source, output: destination, title: name)
        }

        let duration = try Self.duration(of: destination)
        return Track(
            displayName: name,
            source: .localFile,
            workingURL: destination,
            duration: duration,
            format: ext.uppercased(),
            originalURL: source
        )
    }

    /// Reads the title embedded in a WAV's INFO chunk, if any. AVFoundation
    /// decodes the chunk as Windows-1252, so UTF-8 titles need re-decoding.
    static func embeddedTitle(of url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.metadata) else { return nil }
        for item in items where (item.key as? String) == "info-title" {
            guard let raw = try? await item.load(.stringValue), !raw.isEmpty else { continue }
            return raw.data(using: .windowsCP1252).flatMap { String(data: $0, encoding: .utf8) } ?? raw
        }
        return nil
    }

    /// Recovers the track name from an imports-folder filename, dropping the
    /// uniqueness suffix: "Blue in Green – 3F2A.wav" → "Blue in Green".
    static func displayName(for url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        if let range = base.range(of: " – ", options: .backwards),
           base[range.upperBound...].count == 4 {
            return String(base[..<range.lowerBound])
        }
        return base
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
