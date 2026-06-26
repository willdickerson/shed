//
//  BinaryLocator.swift
//  Shed
//
//  Resolves the external tools Shed depends on and fails loudly if they're
//  missing, so the UI can tell the user how to install them.
//

import Foundation

nonisolated struct BinaryLocator {
    let ytDlpPath: String
    let ffmpegPath: String

    init(
        ytDlpPath: String = "/opt/homebrew/bin/yt-dlp",
        ffmpegPath: String = "/opt/homebrew/bin/ffmpeg"
    ) {
        self.ytDlpPath = ytDlpPath
        self.ffmpegPath = ffmpegPath
    }

    func ytDlp() throws -> URL {
        try resolve(name: "yt-dlp", path: ytDlpPath)
    }

    func ffmpeg() throws -> URL {
        try resolve(name: "ffmpeg", path: ffmpegPath)
    }

    private func resolve(name: String, path: String) throws -> URL {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw ShedError.missingBinary(name: name, path: path)
        }
        return URL(fileURLWithPath: path)
    }
}
