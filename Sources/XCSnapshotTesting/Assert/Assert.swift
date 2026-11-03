// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

// MARK: - Assert snapshot

/// Asserts that a value matches the reference stored for it.
///
/// The value goes through `snapshot`, and the output is compared with the reference file. The
/// assertion fails if there is no reference or if the output differs. The record mode decides
/// whether the reference is written, see ``RecordMode``. Failures are reported to the running test.
///
/// ```swift
/// try await assert(
///     of: view,
///     as: .image(layout: .fixed(width: 320, height: 200)),
///     named: "compact"
/// )
/// ```
///
/// - Parameters:
///   - input: The value to snapshot. It is evaluated when the assertion runs.
///   - snapshot: How to turn the value into the output that is compared.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - name: A name that tells this snapshot apart from the others in the same test. Without one, snapshots are numbered by the position of the call.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - isolation: The actor that evaluates `input`.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Throws: An error from evaluating `input`, running the snapshot, or reading and writing the references.
///
/// - Important: In a loop the call site is always the same, so every iteration would use the same reference. Pass a different `name` to each one.
public func assert<Input: Sendable, Output: BytesRepresentable>(
    of input: @Sendable @autoclosure () async throws -> Input,
    as snapshot: AsyncSnapshot<Input, Output>,
    serialization: DataSerialization = DataSerialization(),
    named name: String? = nil,
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = .zero,
    isolation: isolated Actor? = #isolation,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) async throws {
    let failure = try await verify(
        of: await input(),
        as: snapshot,
        serialization: serialization,
        named: name,
        record: recording,
        snapshotDirectory: snapshotDirectory,
        timeout: timeout,
        isolation: isolation,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )

    guard let message = failure else { return }

    try TestingSystem.shared.record(
        message: message,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
}

/// Asserts that a value matches the references of several snapshots, one for each key of `strategies`. The keys are the names of the snapshots.
///
/// ```swift
/// try await assert(
///     of: view,
///     as: [
///         "compact": .image(layout: .fixed(width: 320, height: 200)),
///         "regular": .image(layout: .fixed(width: 640, height: 400)),
///     ]
/// )
/// ```
///
/// - Parameters:
///   - input: The value to snapshot.
///   - strategies: The snapshots to assert, by name.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - isolation: The actor that evaluates `input`.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Throws: An error from evaluating `input`, running a snapshot, or reading and writing the references.
public func assert<Input: Sendable, Output: BytesRepresentable>(
    of input: @Sendable @autoclosure () async throws -> Input,
    as strategies: [String: AsyncSnapshot<Input, Output>],
    serialization: DataSerialization = DataSerialization(),
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = .zero,
    isolation: isolated Actor? = #isolation,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) async throws {
    for (name, configuration) in strategies {
        try await assert(
            of: await input(),
            as: configuration,
            serialization: serialization,
            named: name,
            record: recording,
            snapshotDirectory: snapshotDirectory,
            timeout: timeout,
            isolation: isolation,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

/// Asserts that a value matches the references of several snapshots, one for each element of `strategies`. They are named after the position of the call and of the element, such as `testName.L12C9@1` and `testName.L12C9@2`, where `L12C9` is the line and column of the call.
///
/// ```swift
/// try await assert(
///     of: view,
///     as: [
///         .image(layout: .fixed(width: 320, height: 200)),
///         .image(precision: 0.95),
///     ]
/// )
/// ```
///
/// - Parameters:
///   - input: The value to snapshot.
///   - strategies: The snapshots to assert.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - isolation: The actor that evaluates `input`.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Throws: An error from evaluating `input`, running a snapshot, or reading and writing the references.
public func assert<Input: Sendable, Output: BytesRepresentable>(
    of input: @Sendable @autoclosure () async throws -> Input,
    as strategies: [AsyncSnapshot<Input, Output>],
    serialization: DataSerialization = DataSerialization(),
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = .zero,
    isolation: isolated Actor? = #isolation,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) async throws {
    let uniqueID = SnapshotCallSite(line: line, column: column).suffix

    for (index, strategy) in strategies.enumerated() {
        try await assert(
            of: await input(),
            as: strategy,
            serialization: serialization,
            named: "\(uniqueID)@\(index + 1)",
            record: recording,
            snapshotDirectory: snapshotDirectory,
            timeout: timeout,
            isolation: isolation,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

// MARK: - Sync snapshot

/// Asserts that a value matches the reference stored for it.
///
/// The value goes through `snapshot`, and the output is compared with the reference file. The
/// assertion fails if there is no reference or if the output differs. The record mode decides
/// whether the reference is written, see ``RecordMode``. Failures are reported to the running test.
///
/// ```swift
/// try assert(
///     of: view,
///     as: .image(layout: .fixed(width: 320, height: 200)),
///     named: "compact"
/// )
/// ```
///
/// - Parameters:
///   - input: The value to snapshot. It is evaluated when the assertion runs.
///   - snapshot: How to turn the value into the output that is compared.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - name: A name that tells this snapshot apart from the others in the same test. Without one, snapshots are numbered by the position of the call.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Throws: An error from evaluating `input`, running the snapshot, or reading and writing the references.
///
/// - Important: In a loop the call site is always the same, so every iteration would use the same reference. Pass a different `name` to each one.
public func assert<Input, Output: BytesRepresentable>(
    of input: @autoclosure () throws -> Input,
    as snapshot: SyncSnapshot<Input, Output>,
    serialization: DataSerialization = DataSerialization(),
    named name: String? = nil,
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) throws {
    let failure = try verify(
        of: input(),
        as: snapshot,
        serialization: serialization,
        named: name,
        record: recording,
        snapshotDirectory: snapshotDirectory,
        timeout: timeout,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )

    guard let message = failure else { return }

    try TestingSystem.shared.record(
        message: message,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
}

/// Asserts that a value matches the references of several snapshots, one for each key of `strategies`. The keys are the names of the snapshots.
///
/// ```swift
/// try await assert(
///     of: view,
///     as: [
///         "compact": .image(layout: .fixed(width: 320, height: 200)),
///         "regular": .image(layout: .fixed(width: 640, height: 400)),
///     ]
/// )
/// ```
///
/// - Parameters:
///   - input: The value to snapshot.
///   - strategies: The snapshots to assert, by name.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Throws: An error from evaluating `input`, running a snapshot, or reading and writing the references.
public func assert<Input, Output: BytesRepresentable>(
    of input: Input,
    as strategies: [String: SyncSnapshot<Input, Output>],
    serialization: DataSerialization = DataSerialization(),
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) throws {
    for (name, configuration) in strategies {
        try assert(
            of: input,
            as: configuration,
            serialization: serialization,
            named: name,
            record: recording,
            snapshotDirectory: snapshotDirectory,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

/// Asserts that a value matches the references of several snapshots, one for each element of `strategies`. They are named after the position of the call and of the element, such as `testName.L12C9@1` and `testName.L12C9@2`, where `L12C9` is the line and column of the call.
///
/// ```swift
/// try await assert(
///     of: view,
///     as: [
///         .image(layout: .fixed(width: 320, height: 200)),
///         .image(precision: 0.95),
///     ]
/// )
/// ```
///
/// - Parameters:
///   - input: The value to snapshot.
///   - strategies: The snapshots to assert.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Throws: An error from evaluating `input`, running a snapshot, or reading and writing the references.
public func assert<Input, Output: BytesRepresentable>(
    of input: Input,
    as strategies: [SyncSnapshot<Input, Output>],
    serialization: DataSerialization = DataSerialization(),
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) async throws {
    let uniqueID = SnapshotCallSite(line: line, column: column).suffix

    for (index, strategy) in strategies.enumerated() {
        try assert(
            of: input,
            as: strategy,
            serialization: serialization,
            named: "\(uniqueID)@\(index + 1)",
            record: recording,
            snapshotDirectory: snapshotDirectory,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

/// Compares a value with the reference stored for it, and returns the failure message instead of reporting it.
///
/// It does what ``assert(of:as:serialization:named:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)`` does, but leaves it to the caller to report the failure.
///
/// - Parameters:
///   - input: The value to snapshot. It is evaluated when the assertion runs.
///   - snapshot: How to turn the value into the output that is compared.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - name: A name that tells this snapshot apart from the others in the same test. Without one, snapshots are numbered by the position of the call.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - isolation: The actor that evaluates `input`.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Returns: The failure message, or `nil` if the output matches the reference.
/// - Throws: An error from evaluating `input`, running the snapshot, or reading and writing the references.
public func verify<Input: Sendable, Output: BytesRepresentable>(
    of input: @Sendable @autoclosure () async throws -> Input,
    as snapshot: AsyncSnapshot<Input, Output>,
    serialization: DataSerialization = DataSerialization(),
    named name: String? = nil,
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = .zero,
    isolation: isolated Actor? = #isolation,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) async throws -> String? {
    let engine = SnapshotFileEngine<Async<Input, Output>>(
        sourceURL: snapshotDirectory.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )

    let tester = SnapshotTester(
        engine: engine,
        record: recording,
        timeout: timeout,
        name: name,
        serialization: serialization,
        fileID: fileID,
        filePath: filePath,
        function: testName,
        line: line,
        column: column
    )

    return try await tester(input(), for: snapshot)?.message
}

/// Compares a value with the reference stored for it, and returns the failure message instead of reporting it.
///
/// It does what ``assert(of:as:serialization:named:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)`` does, but leaves it to the caller to report the failure.
///
/// - Parameters:
///   - input: The value to snapshot. It is evaluated when the assertion runs.
///   - snapshot: How to turn the value into the output that is compared.
///   - serialization: How the output is encoded to, and decoded from, the reference file.
///   - name: A name that tells this snapshot apart from the others in the same test. Without one, snapshots are numbered by the position of the call.
///   - recording: Overrides the record mode of the environment for this assertion.
///   - snapshotDirectory: A directory for the references, instead of `__Snapshots__`.
///   - timeout: How long to wait for the snapshot, in seconds. Zero or `.infinity` means no limit.
///   - fileID: The `#fileID` of the call.
///   - filePath: The `#filePath` of the call.
///   - testName: The name of the test function.
///   - line: The line of the call.
///   - column: The column of the call.
/// - Returns: The failure message, or `nil` if the output matches the reference.
/// - Throws: An error from evaluating `input`, running the snapshot, or reading and writing the references.
public func verify<Input, Output: BytesRepresentable>(
    of input: @autoclosure () throws -> Input,
    as snapshot: SyncSnapshot<Input, Output>,
    serialization: DataSerialization = DataSerialization(),
    named name: String? = nil,
    record recording: RecordMode? = nil,
    snapshotDirectory: String? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: StaticString = #function,
    line: UInt = #line,
    column: UInt = #column
) throws -> String? {
    let engine = SnapshotFileEngine<Sync<Input, Output>>(
        sourceURL: snapshotDirectory.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )

    let tester = SnapshotTester(
        engine: engine,
        record: recording,
        timeout: timeout,
        name: name,
        serialization: serialization,
        fileID: fileID,
        filePath: filePath,
        function: testName,
        line: line,
        column: column
    )

    return try tester(input(), for: snapshot)?.message
}
