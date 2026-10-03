//
//  BinaryLocator.swift
//  Shed
//
//  Resolves the external tools Shed depends on. Beta builds bundle universal
//  copies inside the app, so it checks those first and only falls back to a
//  Homebrew / PATH install. yt-dlp additionally prefers Shed's self-updating
//  copy in Application Support. Fails loudly only when nothing usable is found.
//

import Foundation

nonisolated struct BinaryLocator {
    /// Extra directories to search before the system ones (used in tests).
    private let extraDirectories: [String]

    init(extraDirectories: [String] = []) {
        self.extraDirectories = extraDirectories
    }

    func ytDlp() throws -> URL { try resolve(name: "yt-dlp", preferring: Self.managedDirectory) }
    func ffmpeg() throws -> URL { try resolve(name: "ffmpeg") }
    func deno() throws -> URL { try resolve(name: "deno") }

    // MARK: - Resolution

    /// Where Shed keeps tools it updates itself (~/Library/Application Support/Shed/bin).
    static var managedDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Shed", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
    }

    /// The copy shipped inside the app, if present.
    func bundled(_ name: String) -> URL? {
        guard let path = bundledPath(for: name),
              FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    private func resolve(name: String, preferring preferred: URL? = nil) throws -> URL {
        let first = preferred.map { [$0.appendingPathComponent(name).path] } ?? []
        for path in first + candidatePaths(for: name)
        where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        throw ShedError.missingBinary(name: name, path: bundledPath(for: name) ?? "(not bundled)")
    }

    /// Search order: bundled → extras → Homebrew (Apple Silicon, then Intel) → PATH.
    private func candidatePaths(for name: String) -> [String] {
        var paths: [String] = []
        if let bundled = bundledPath(for: name) { paths.append(bundled) }
        paths.append(contentsOf: extraDirectories.map { "\($0)/\(name)" })
        paths.append("/opt/homebrew/bin/\(name)")
        paths.append("/usr/local/bin/\(name)")
        if let env = ProcessInfo.processInfo.environment["PATH"] {
            paths.append(contentsOf: env.split(separator: ":").map { "\($0)/\(name)" })
        }
        return paths
    }

    private func bundledPath(for name: String) -> String? {
        Bundle.main.resourceURL?
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(name)
            .path
    }
}
