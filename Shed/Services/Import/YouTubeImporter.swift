//
//  YouTubeImporter.swift
//  Shed
//
//  Downloads best-available audio with yt-dlp, then converts it to WAV with
//  ffmpeg. Reports coarse progress through a callback.
//

import Foundation

nonisolated struct YouTubeImporter {
    private let binaries: BinaryLocator
    private let runner: ProcessRunner
    private let workingDirectory: WorkingDirectory
    private let converter: AudioConverter

    init(
        binaries: BinaryLocator = BinaryLocator(),
        runner: ProcessRunner = ProcessRunner(),
        workingDirectory: WorkingDirectory = WorkingDirectory(),
        converter: AudioConverter = AudioConverter()
    ) {
        self.binaries = binaries
        self.runner = runner
        self.workingDirectory = workingDirectory
        self.converter = converter
    }

    /// Validates the URL, downloads audio, converts to WAV, and returns a Track.
    /// `onStatus` is called as the import moves between phases.
    nonisolated func makeTrack(
        from urlString: String,
        onStatus: @escaping @Sendable (ImportStatus) -> Void
    ) async throws -> Track {
        guard let url = Self.validate(urlString) else { throw ShedError.invalidURL }

        let ytDlp = try binaries.ytDlp()
        _ = try binaries.ffmpeg() // fail early if ffmpeg is missing too

        let token = "yt_" + UUID().uuidString.prefix(8)
        let template = try workingDirectory.makeDestination(token: "\(token)__%(title)s", ext: "%(ext)s")

        // MARK: Download
        onStatus(.downloading(progress: nil))
        let downloadArgs = [
            "--no-playlist",
            "--newline",
            "-f", "bestaudio/best",
            "-o", template.path,
            url.absoluteString
        ]
        let download = try await runner.run(executable: ytDlp, arguments: downloadArgs) { line in
            if let progress = Self.parseProgress(line) {
                onStatus(.downloading(progress: progress))
            }
        }
        guard download.didSucceed else {
            throw ShedError.downloadFailed(Self.tail(of: download.output))
        }

        let downloaded = try locateDownloadedFile(token: token)

        // MARK: Convert
        onStatus(.converting)
        let wav = try workingDirectory.makeWAVDestination(token: token)
        try await converter.convertToWAV(input: downloaded, output: wav)
        try? FileManager.default.removeItem(at: downloaded) // tidy up the source

        let duration = try LocalFileImporter.duration(of: wav)
        let title = Self.title(from: downloaded, token: token)
        return Track(displayName: title, source: .youTube, workingURL: wav, duration: duration)
    }

    // MARK: - Helpers

    private nonisolated func locateDownloadedFile(token: String) throws -> URL {
        let dir = try workingDirectory.importsURL()
        let contents = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        guard let match = contents.first(where: {
            $0.lastPathComponent.hasPrefix("\(token)__") && $0.pathExtension.lowercased() != "wav"
        }) else {
            throw ShedError.downloadFailed("Couldn’t find the downloaded audio file.")
        }
        return match
    }

    /// Recovers a readable title from the templated filename `token__Title.ext`.
    private static func title(from url: URL, token: String) -> String {
        let base = url.deletingPathExtension().lastPathComponent
        let prefix = "\(token)__"
        if base.hasPrefix(prefix) {
            let title = String(base.dropFirst(prefix.count))
            if !title.isEmpty { return title }
        }
        return "YouTube Audio"
    }

    static func validate(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }

    /// Pulls a 0...1 progress value out of a yt-dlp `[download] 12.3%` line.
    private static func parseProgress(_ line: String) -> Double? {
        guard line.contains("[download]") else { return nil }
        for token in line.split(separator: " ") where token.hasSuffix("%") {
            let number = token.dropLast()
            if let value = Double(number) { return min(1, max(0, value / 100)) }
        }
        return nil
    }

    private static func tail(of output: String, lines: Int = 6) -> String {
        output.split(separator: "\n").suffix(lines).joined(separator: "\n")
    }
}
