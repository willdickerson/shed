//
//  AudioConverter.swift
//  Shed
//
//  Converts arbitrary audio/video containers to a working WAV using ffmpeg.
//

import Foundation

nonisolated struct AudioConverter {
    private let binaries: BinaryLocator
    private let runner: ProcessRunner

    init(binaries: BinaryLocator = BinaryLocator(), runner: ProcessRunner = ProcessRunner()) {
        self.binaries = binaries
        self.runner = runner
    }

    /// Decodes `input` to 16-bit PCM WAV at `output`, dropping any video track.
    func convertToWAV(input: URL, output: URL) async throws {
        let ffmpeg = try binaries.ffmpeg()
        let arguments = [
            "-y",                 // overwrite
            "-i", input.path,
            "-vn",                // no video
            "-acodec", "pcm_s16le",
            output.path
        ]

        let result = try await runner.run(executable: ffmpeg, arguments: arguments)
        guard result.didSucceed else {
            throw ShedError.conversionFailed(Self.tail(of: result.output))
        }
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw ShedError.conversionFailed("ffmpeg reported success but produced no output file.")
        }
    }

    /// Keeps the last few lines of ffmpeg output for a concise error message.
    private static func tail(of output: String, lines: Int = 6) -> String {
        let all = output.split(separator: "\n")
        return all.suffix(lines).joined(separator: "\n")
    }
}
