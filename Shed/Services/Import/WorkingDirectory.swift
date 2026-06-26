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

    /// A fresh, unique WAV destination inside the imports directory.
    func makeWAVDestination(token: String = UUID().uuidString) throws -> URL {
        try importsURL().appendingPathComponent("\(token).wav")
    }

    /// Unique path with a chosen extension, used as a yt-dlp download target.
    func makeDestination(token: String, ext: String) throws -> URL {
        try importsURL().appendingPathComponent("\(token).\(ext)")
    }
}
