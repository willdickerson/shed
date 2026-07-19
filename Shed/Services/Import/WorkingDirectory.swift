//
//  WorkingDirectory.swift
//  Shed
//
//  Manages ~/Library/Application Support/Shed/Imports.
//

import Foundation

nonisolated struct WorkingDirectory {
    private let fileManager = FileManager.default

    /// Returns (creating if needed) the Imports directory.
    func importsURL() throws -> URL {
        do {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let imports = base
                .appendingPathComponent("Shed", isDirectory: true)
                .appendingPathComponent("Imports", isDirectory: true)
            try fileManager.createDirectory(at: imports, withIntermediateDirectories: true)
            return imports
        } catch {
            throw ShedError.workingDirectory(error.localizedDescription)
        }
    }

    /// A unique WAV destination named after the track, e.g. "Blue in Green – 3F2A.wav",
    /// so the imports folder stays browsable in Finder.
    func makeWAVDestination(name: String) throws -> URL {
        let token = UUID().uuidString.prefix(4)
        return try importsURL().appendingPathComponent("\(Self.sanitized(name)) – \(token).wav")
    }

    /// Makes a display name safe to use as a filename.
    static func sanitized(_ name: String) -> String {
        var result = name
            .components(separatedBy: .controlCharacters).joined()
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces)
        while result.hasPrefix(".") { result.removeFirst() } // no hidden files
        if result.count > 60 {
            result = String(result.prefix(60)).trimmingCharacters(in: .whitespaces)
        }
        return result.isEmpty ? "Import" : result
    }

    /// Unique path with a chosen extension, used as a yt-dlp download target.
    func makeDestination(token: String, ext: String) throws -> URL {
        try importsURL().appendingPathComponent("\(token).\(ext)")
    }
}
