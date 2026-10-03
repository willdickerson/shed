//
//  YtDlpUpdater.swift
//  Shed
//
//  YouTube changes often enough that a yt-dlp a few months old starts failing
//  (typically HTTP 403). The bundled copy can't update in place, so Shed keeps
//  its own copy in Application Support and lets yt-dlp self-update it.
//

import Foundation

actor YtDlpUpdater {
    static let shared = YtDlpUpdater()

    private static let lastCheckKey = "ytDlpLastUpdateCheck"
    private static let bundledStampKey = "ytDlpBundledStamp"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    private let binaries: BinaryLocator
    private let runner: ProcessRunner
    private var inFlight: Task<Bool, Never>?

    init(binaries: BinaryLocator = BinaryLocator(), runner: ProcessRunner = ProcessRunner()) {
        self.binaries = binaries
        self.runner = runner
    }

    /// Updates the managed yt-dlp if it hasn't been checked in a day, or always
    /// when `force` is set. `willUpdate` fires only if an update actually runs.
    /// Concurrent callers share one run. Returns whether the binary changed.
    @discardableResult
    func refresh(force: Bool = false, willUpdate: @escaping @Sendable () -> Void = {}) async -> Bool {
        if let running = inFlight {
            let updated = await running.value
            if updated || !force { return updated }
        }
        let task = Task { await self.performRefresh(force: force, willUpdate: willUpdate) }
        inFlight = task
        let updated = await task.value
        if inFlight == task { inFlight = nil }
        return updated
    }

    private func performRefresh(force: Bool, willUpdate: @Sendable () -> Void) async -> Bool {
        guard let managed = await install() else { return false }

        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(last) < Self.checkInterval {
            return false
        }
        defaults.set(Date(), forKey: Self.lastCheckKey)

        willUpdate()
        let before = Self.modificationDate(of: managed)
        _ = try? await runner.run(executable: managed, arguments: ["--update"])
        guard Self.modificationDate(of: managed) != before else { return false }

        // Never leave a broken binary behind; fall back to the bundled one.
        if await version(of: managed) == nil {
            if let bundled = binaries.bundled("yt-dlp") { try? Self.copy(bundled, to: managed) }
            return false
        }
        return true
    }

    /// Copies the bundled yt-dlp into the managed folder on first run, and again
    /// when an app update ships a newer one than the managed copy.
    private func install() async -> URL? {
        guard let managed = BinaryLocator.managedDirectory?.appendingPathComponent("yt-dlp") else { return nil }
        let hasManaged = FileManager.default.isExecutableFile(atPath: managed.path)
        guard let bundled = binaries.bundled("yt-dlp") else { return hasManaged ? managed : nil }

        let defaults = UserDefaults.standard
        let stamp = Self.stamp(of: bundled)
        if hasManaged {
            if stamp == defaults.string(forKey: Self.bundledStampKey) { return managed }
            if let shipped = await version(of: bundled), let current = await version(of: managed),
               shipped.compare(current, options: .numeric) != .orderedDescending {
                defaults.set(stamp, forKey: Self.bundledStampKey)
                return managed
            }
        }

        do {
            try Self.copy(bundled, to: managed)
        } catch {
            return hasManaged ? managed : nil
        }
        defaults.set(stamp, forKey: Self.bundledStampKey)
        return managed
    }

    private func version(of binary: URL) async -> String? {
        guard let result = try? await runner.run(executable: binary, arguments: ["--version"]),
              result.didSucceed else { return nil }
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    /// Atomically replaces `destination` with an executable, unquarantined copy of `source`.
    private static func copy(_ source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(".\(destination.lastPathComponent)-\(UUID().uuidString.prefix(8))")
        try fileManager.copyItem(at: source, to: temp)
        removexattr(temp.path, "com.apple.quarantine", 0)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temp.path)
        guard rename(temp.path, destination.path) == 0 else {
            try? fileManager.removeItem(at: temp)
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Identifies the bundled binary cheaply, so versions are compared only after an app update.
    private static func stamp(of url: URL) -> String {
        let attributes = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)-\(modified)"
    }
}
