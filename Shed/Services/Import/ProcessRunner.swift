//
//  ProcessRunner.swift
//  Shed
//
//  Thin async wrapper around `Process` for shelling out to command-line tools.
//

import Foundation

/// Result of running a process to completion.
nonisolated struct ProcessResult: Sendable {
    let terminationStatus: Int32
    /// Combined stdout + stderr, useful for surfacing failure detail.
    let output: String

    var didSucceed: Bool { terminationStatus == 0 }
}

nonisolated struct ProcessRunner {
    /// Runs `executable` with `arguments`, merging stdout and stderr into a
    /// single stream. `onLine` is invoked for each line as it is produced,
    /// which lets callers report live progress. Runs off the main actor.
    func run(
        executable: URL,
        arguments: [String],
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        // Share one pipe for stdout + stderr so a full error pipe can't deadlock
        // a process whose progress we're draining from stdout.
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw ShedError.conversionFailed("Couldn’t launch \(executable.lastPathComponent): \(error.localizedDescription)")
        }

        var collected = ""
        let handle = pipe.fileHandleForReading
        for try await line in handle.bytes.lines {
            collected += line + "\n"
            onLine?(line)
        }

        process.waitUntilExit()
        return ProcessResult(terminationStatus: process.terminationStatus, output: collected)
    }
}
