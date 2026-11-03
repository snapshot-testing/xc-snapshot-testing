// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if canImport(XCTest)
import XCTest
#endif

/// Runs a snapshot assertion for a ``SnapshotEngine``.
///
/// The tester runs the executor of a ``Snapshot``, asks the engine for the reference, and acts
/// according to the record mode:
///
/// - ``RecordMode/all``: writes the output as the new reference and fails.
/// - ``RecordMode/missing``: when there is no reference, writes one and fails.
/// - ``RecordMode/failed``: when the output differs from the reference, replaces it and fails.
/// - ``RecordMode/never``: never writes a reference.
///
/// A missing reference and a mismatch always fail. Calling the tester returns the failure rather
/// than reporting it, so each caller decides how to report it.
@_spi(Internals)
public struct SnapshotTester<Engine: SnapshotEngine>: Sendable {

    /// The executor of the engine.
    public typealias Executor = Engine.Executor

    /// The serialization used to encode and decode snapshots.
    public let serialization: DataSerialization

    /// The time limit for the executor, in seconds.
    ///
    /// An asynchronous executor runs without a limit when this is zero or less.
    public let timeout: TimeInterval

    /// The `#fileID` of the assertion.
    public let fileID: StaticString

    /// The `#filePath` of the assertion.
    public let filePath: StaticString

    /// The `#function` of the assertion.
    public let function: StaticString

    /// The line of the assertion.
    public let line: UInt

    /// The column of the assertion.
    public let column: UInt

    /// The platform name in the path of the reference. It is empty when snapshots are shared between platforms.
    public let platform: String

    /// The platform version in the path of the reference, or `nil` when the environment leaves it out.
    public let platformVersion: String?

    private let engine: Engine
    private let record: RecordMode
    private let name: String?

    /// Creates a tester.
    ///
    /// - Parameters:
    ///   - engine: The engine that finds, reads and writes references.
    ///   - record: The record mode, or `nil` to use the one of the environment.
    ///   - timeout: The time limit for the executor, in seconds.
    ///   - name: A name that tells this snapshot apart from the others in the same test.
    ///     When `nil`, the file name gets the position of the call if the environment adds the suffix.
    ///   - serialization: The serialization used to encode and decode snapshots.
    ///   - fileID: The `#fileID` of the assertion.
    ///   - filePath: The `#filePath` of the assertion.
    ///   - function: The `#function` of the assertion.
    ///   - line: The line of the assertion.
    ///   - column: The column of the assertion.
    public init(
        engine: Engine,
        record: RecordMode?,
        timeout: TimeInterval,
        name: String?,
        serialization: DataSerialization,
        fileID: StaticString,
        filePath: StaticString,
        function: StaticString,
        line: UInt,
        column: UInt
    ) {
        if !TestingSystem.shared.isSwiftTestingRunning {
            #if canImport(XCTest)
            XCTestCase.registerObserverIfNeeded()
            #endif
        }

        self.engine = engine
        self.record = record ?? SnapshotEnvironment.current.recordMode
        self.platform = SnapshotEnvironment.current.platform
        self.platformVersion = SnapshotEnvironment.current.platformVersion
        self.timeout = timeout
        self.name = name
        self.serialization = serialization
        self.fileID = fileID
        self.filePath = filePath
        self.function = function
        self.line = line
        self.column = column
    }

    /// Runs the asynchronous executor on `input` and asserts its output.
    ///
    /// - Parameters:
    ///   - input: The value to snapshot.
    ///   - snapshot: The snapshot that turns `input` into the output to assert.
    /// - Returns: `nil` if the output matches the reference, otherwise the failure.
    ///   Reaching the time limit is a failure, not a thrown error.
    /// - Throws: An error from the executor, the serialization or the engine.
    public func callAsFunction<Input: Sendable, Output: BytesRepresentable>(
        _ input: Input,
        for snapshot: Snapshot<Executor>
    ) async throws -> SnapshotFailure? where Executor == Async<Input, Output> {
        do {
            let diffable: Executor.Output

            if timeout.hasLimit {
                diffable = try await Task.timeout(timeout) {
                    try await snapshot.executor(input)
                }
            } else {
                diffable = try await snapshot.executor(input)
            }

            return try assert(
                diffable: diffable,
                pathExtension: snapshot.pathExtension,
                attachmentGenerator: snapshot.attachmentGenerator
            )
        } catch is TaskTimeout {
            return fail(
                reason: .timeout,
                snapshotURL: FileManager.default.temporaryDirectory,
                didWriteNewSnapshot: false
            )
        } catch {
            throw error
        }
    }

    /// Runs the synchronous executor on `input` and asserts its output.
    ///
    /// The calling thread blocks until the executor completes or the time limit is reached.
    ///
    /// - Parameters:
    ///   - input: The value to snapshot.
    ///   - snapshot: The snapshot that turns `input` into the output to assert.
    /// - Returns: `nil` if the output matches the reference, otherwise the failure.
    ///   Reaching the time limit is a failure, not a thrown error.
    /// - Throws: An error from the executor, the serialization or the engine.
    public func callAsFunction<Input, Output: BytesRepresentable>(
        _ input: Input,
        for snapshot: Snapshot<Executor>
    ) throws -> SnapshotFailure? where Executor == Sync<Input, Output> {
        let dispatchGroup = DispatchGroup()
        let unsafeDiffable = UnsafeSyncDiffable<Output>()

        dispatchGroup.enter()
        snapshot.executor(input) { result in
            unsafeDiffable.result = result
            dispatchGroup.leave()
        }

        let deadline: DispatchTime =
            timeout.hasLimit
            ? .now() + .nanoseconds(Int(clamping: timeout.nanoseconds))
            : .distantFuture

        let result = dispatchGroup.wait(timeout: deadline)

        switch result {
        case .success:
            return try assert(
                diffable: unsafeDiffable.result.get(),
                pathExtension: snapshot.pathExtension,
                attachmentGenerator: snapshot.attachmentGenerator
            )
        case .timedOut:
            return fail(
                reason: .timeout,
                snapshotURL: FileManager.default.temporaryDirectory,
                didWriteNewSnapshot: false
            )
        }
    }
}

extension SnapshotTester {

    /// Applies the record mode to the output of the executor.
    ///
    /// With `.all` the output is written and the assertion fails. In any other mode the output is
    /// compared with the reference.
    fileprivate func assert(
        diffable: Executor.Output,
        pathExtension: String?,
        attachmentGenerator: any DiffAttachmentGenerator<Executor.Output>
    ) throws -> SnapshotFailure? {
        let snapshotURL = try snapshotURL(
            pathExtension: pathExtension
        )

        guard record == .all else {
            return try assertWithReference(
                diffable: diffable,
                snapshotURL: snapshotURL,
                attachmentGenerator: attachmentGenerator
            )
        }

        try record(
            diffable,
            url: snapshotURL,
            write: true,
            attachments: nil
        )

        return fail(
            reason: .allRecordMode,
            snapshotURL: snapshotURL,
            didWriteNewSnapshot: true
        )
    }

    /// Compares the output with the reference if there is one.
    ///
    /// Without a reference, the output is written when the mode is `.missing`, and the assertion fails.
    private func assertWithReference(
        diffable: Executor.Output,
        snapshotURL: URL,
        attachmentGenerator: any DiffAttachmentGenerator<Executor.Output>
    ) throws -> SnapshotFailure? {
        guard !engine.contentExists(at: snapshotURL) else {
            return try compare(
                reference: engine.loadSnapshot(from: snapshotURL, using: self),
                diffable: diffable,
                snapshotURL: snapshotURL,
                attachmentGenerator: attachmentGenerator
            )
        }

        try record(
            diffable,
            url: snapshotURL,
            write: record == .missing,
            attachments: nil
        )

        return fail(
            reason: .missing,
            snapshotURL: snapshotURL,
            didWriteNewSnapshot: record == .missing
        )
    }

    /// Compares the output with the reference, using the attachment generator.
    ///
    /// When they match, the engine is notified and there is no failure. When they differ, the output is
    /// kept in the temporary directory, unless the mode is `.failed`, which replaces the reference
    /// instead. The failure carries the diff command and the description of the difference.
    private func compare(
        reference: Executor.Output,
        diffable: Executor.Output,
        snapshotURL: URL,
        attachmentGenerator: any DiffAttachmentGenerator<Executor.Output>
    ) throws -> SnapshotFailure? {
        guard
            let messageAttachment = attachmentGenerator(
                from: reference,
                with: diffable
            )
        else {
            try notify(diffable, to: snapshotURL)
            return nil
        }

        let failedURL: URL?

        if let temporaryURL = try engine.temporaryURL(for: filePath, using: self), record != .failed {
            let url = temporaryURL.appendingPathComponent(snapshotURL.lastPathComponent)

            try engine.perform(
                .write,
                contents: serialization.serialize(diffable),
                to: url,
                using: self
            )

            failedURL = url
        } else {
            failedURL = nil
        }

        try record(
            diffable,
            url: snapshotURL,
            write: record == .failed,
            attachments: messageAttachment.attachments
        )

        return fail(
            reason: .doesNotMatch,
            snapshotURL: snapshotURL,
            diff: failedURL.map {
                SnapshotEnvironment.current.diffTool(
                    currentFilePath: snapshotURL.path,
                    failedFilePath: $0.path
                )
            },
            additionalInformation: messageAttachment.message,
            didWriteNewSnapshot: record == .failed
        )
    }

    /// Tells the engine that the output matches its reference.
    private func notify(
        _ diffable: Executor.Output,
        to url: URL
    ) throws {
        let diffableData = try serialization.serialize(diffable)

        try engine.perform(
            .notify,
            contents: diffableData,
            to: url,
            using: self
        )
    }

    /// Serializes the output, writes it or only notifies the engine, and attaches the result to the test.
    ///
    /// The attachment is the diff of a failed comparison when `attachments` is given, otherwise the recorded snapshot.
    private func record(
        _ diffable: Executor.Output,
        url: URL,
        write: Bool,
        attachments: [SnapshotAttachment]?
    ) throws {
        let diffableData = try serialization.serialize(diffable)

        try engine.perform(
            write ? .write : .notify,
            contents: diffableData,
            to: url,
            using: self
        )

        if let attachments {
            add("Attached Failure Diff", attachments: attachments)
        } else {
            add(diffableData, for: url)
        }
    }

    /// Builds the failure, with the message written by the engine.
    private func fail(
        reason: SnapshotFailContext.Reason,
        snapshotURL: URL,
        diff: String? = nil,
        additionalInformation: String? = nil,
        didWriteNewSnapshot: Bool
    ) -> SnapshotFailure {
        let context = SnapshotFailContext(
            function: function,
            reason: reason,
            url: snapshotURL,
            diff: diff,
            additionalInformation: additionalInformation,
            didWriteNewSnapshot: didWriteNewSnapshot
        )

        return SnapshotFailure(
            message: engine.generateFailureMessage(for: context, using: self),
            context: context
        )
    }
}

// MARK: - Source URL

extension SnapshotTester {

    /// The location of the reference.
    ///
    /// It is the source URL of the engine plus the name of the test function. The function name is
    /// followed by `name`, or else by the position of the call (such as `L12C9`) when the environment
    /// adds the suffix, and then by the path extension.
    fileprivate func snapshotURL(
        pathExtension: String?
    ) throws -> URL {
        let sourceURL = try engine.sourceURL(for: filePath, using: self)
        // Only a function without parameters ends in empty parentheses
        let function = String(describing: function)
            .replacingOccurrences(of: "()", with: "")
            .sanitizingPathComponent()

        let pathComponent: String

        if let name {
            pathComponent = function + "." + name.sanitizingPathComponent()
        } else if SnapshotEnvironment.current.addsCounterSuffix {
            pathComponent = function + "." + SnapshotCallSite(line: line, column: column).suffix
        } else {
            pathComponent = function
        }

        let snapshotURL = sourceURL.appendingPathComponent(pathComponent)

        guard let pathExtension else {
            return snapshotURL
        }

        return snapshotURL.appendingPathExtension(pathExtension)
    }
}

// MARK: - Attachments

extension SnapshotTester {

    /// Attaches `attachments` to the running test, under the name `named`.
    func add(_ named: String, attachments: [SnapshotAttachment]) {
        TestingSystem.shared.add(
            named,
            attachments: attachments,
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    /// Attaches the recorded snapshot to the running test, named after the file at `url`.
    func add(
        _ diffable: Data,
        for url: URL
    ) {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(macOS)
        let attachment = SnapshotAttachment(
            uniformTypeIdentifier: url.pathExtension.uniformTypeIdentifier(),
            name: url.lastPathComponent,
            payload: diffable
        )
        #else
        let attachment = SnapshotAttachment(
            uniformTypeIdentifier: "public.\(url.pathExtension)",
            name: url.lastPathComponent,
            payload: diffable
        )
        #endif

        TestingSystem.shared.add(
            "Attached Recorded Snapshot",
            attachments: [attachment],
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}

/// The result of a synchronous executor that never called back.
struct UnsafeSyncDiffableError: Error {}

/// Carries the result of a synchronous executor from its callback to the thread that is waiting.
///
/// It starts as a failure, so a callback that never runs shows up as an error.
final class UnsafeSyncDiffable<Output: Sendable>: @unchecked Sendable {

    var result: Result<Output, Error> {
        get { lock.withLock { _result } }
        set { lock.withLock { _result = newValue } }
    }

    private let lock = NSLock()
    private var _result: Result<Output, Error>

    init() {
        self._result = .failure(UnsafeSyncDiffableError())
    }
}
