// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
import CoreServices
import UniformTypeIdentifiers
#endif

/// A ``SnapshotEngine`` that keeps references as files.
///
/// References go in `__Snapshots__/<platform>/<platform version>`, next to the test file, in a folder
/// named after the file. The platform version is part of the path only when the environment asks for it.
struct SnapshotFileEngine<Executor: SnapshotExecutor>: SnapshotEngine
where Executor.Output: BytesRepresentable {

    /// A directory to use instead of `__Snapshots__`. The platform is not added to it.
    let sourceURL: URL?

    /// Returns the directory for the references of the test file, creating it if needed.
    func sourceURL(
        for filePath: StaticString,
        using tester: SnapshotTester<SnapshotFileEngine<Executor>>
    ) throws -> URL {
        let fileURL = URL(
            fileURLWithPath: String(describing: filePath),
            isDirectory: false
        )

        var sourceURL =
            sourceURL
            ?? snapshotURL(
                fileURL.deletingLastPathComponent(),
                at: "__Snapshots__",
                using: tester
            )

        sourceURL.appendPathComponent(fileURL.deletingPathExtension().lastPathComponent)

        return sourceURL
    }

    /// Returns the directory for the outputs of failed comparisons, creating it if needed.
    ///
    /// It sits in the directory named by the `SNAPSHOT_ARTIFACTS` environment variable, or in the
    /// temporary directory when the variable is not set.
    func temporaryURL(
        for filePath: StaticString,
        using tester: SnapshotTester<SnapshotFileEngine<Executor>>
    ) throws -> URL? {
        let fileURL = URL(
            fileURLWithPath: String(describing: filePath),
            isDirectory: false
        )

        var snapshotURL = snapshotURL(
            ProcessInfo.artifactsDirectory,
            at: "Snapshots",
            using: tester
        )

        snapshotURL.appendPathComponent(fileURL.deletingPathExtension().lastPathComponent)

        return snapshotURL
    }

    func contentExists(at url: URL) -> Bool {
        url.isFileURL && FileManager.default.fileExists(atPath: url.path)
    }

    func loadSnapshot(
        from url: URL,
        using tester: SnapshotTester<SnapshotFileEngine<Executor>>
    ) throws -> Executor.Output {
        try tester.serialization.deserialize(
            Executor.Output.self,
            from: Data(contentsOf: url)
        )
    }

    /// Writes the contents atomically for a `.write` operation. A `.notify` operation does nothing.
    func perform(
        _ operation: SnapshotPerformOperation,
        contents: Data,
        to url: URL,
        using tester: SnapshotTester<SnapshotFileEngine<Executor>>
    ) throws {
        guard case .write = operation else {
            return
        }

        // The folders are created when there is something to put in them. Doing it for every
        // assertion left empty folders behind, and failed on a checkout that is read-only even
        // when the assertion only compares.
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try contents.write(to: url, options: .atomic)
    }

    /// Returns the failure message for `context.reason`.
    func generateFailureMessage(
        for context: SnapshotFailContext,
        using tester: SnapshotTester<SnapshotFileEngine<Executor>>
    ) -> String {
        switch context.reason {
        case .missing:
            return missing(context)
        case .doesNotMatch:
            return doesNotMatch(context)
        case .allRecordMode:
            return allRecordMode(context)
        case .timeout:
            return timeout(context, timeout: tester.timeout)
        }
    }
}

extension SnapshotFileEngine {

    /// Appends `componentPath`, the platform and the platform version, when there is one, to `url`.
    fileprivate func snapshotURL(
        _ url: URL,
        at componentPath: String,
        using tester: SnapshotTester<SnapshotFileEngine<Executor>>
    ) -> URL {
        var snapshotsURL = url

        snapshotsURL.appendPathComponent(componentPath)

        // They come from the environment, so they are made safe to use as a folder name like the rest
        if !tester.platform.isEmpty {
            snapshotsURL.appendPathComponent(tester.platform.sanitizingPathComponent())
        }

        if let platformVersion = tester.platformVersion {
            snapshotsURL.appendPathComponent(platformVersion.sanitizingPathComponent())
        }

        return snapshotsURL
    }
}

extension SnapshotFileEngine {

    /// The message for an assertion with no reference.
    fileprivate func missing(_ context: SnapshotFailContext) -> String {
        let name = String(describing: context.function)

        if context.didWriteNewSnapshot {
            return """
                No reference was found on disk. Automatically recorded snapshot: …

                open "\(context.url.absoluteString)"

                Re-run "\(name)" to assert against the newly-recorded snapshot.
                """
        } else {
            return
                "No reference was found on disk. New snapshot was not recorded because recording is disabled"
        }
    }

    /// The message for an output that differs from the reference, with the diff command and the description of the difference.
    fileprivate func doesNotMatch(_ context: SnapshotFailContext) -> String {
        let name = String(describing: context.function)

        var message = "Snapshot \"\(name)\" does not match reference."

        if context.didWriteNewSnapshot {
            message += """
                 A new snapshot was automatically recorded.

                open "\(context.url.absoluteString)"
                """
        }

        if let diff = context.diff {
            message += "\n\n" + diff
        }

        if let additionalInformation = context.additionalInformation {
            message += "\n\n" + additionalInformation.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return message
    }

    /// The message for an assertion that replaced the reference because the record mode is `.all`.
    fileprivate func allRecordMode(_ context: SnapshotFailContext) -> String {
        let name = String(describing: context.function)

        return """
            Record mode is on. Automatically recorded snapshot: …

            open "\(context.url.absoluteString)"

            Turn record mode off and re-run "\(name)" to assert against the newly-recorded snapshot
            """
    }

    /// The message for an executor that did not finish within `timeout` seconds.
    fileprivate func timeout(_ context: SnapshotFailContext, timeout: TimeInterval) -> String {
        """
        Exceeded timeout of \(timeout) seconds waiting for snapshot.

        This can happen when an asynchronously rendered view (like a web view) has not loaded. \
        Ensure that every subview of the view hierarchy has loaded to avoid timeouts, or, if a \
        timeout is unavoidable, consider setting the "timeout" parameter of "assert" to \
        a higher value.
        """
    }
}
