// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// The configuration of the snapshot tests: record mode, diff tool, platform and so on.
///
/// Values are stored by key. A key is a type that conforms to ``SnapshotEnvironmentKey`` and
/// provides a default. Read the values of the running test through ``SnapshotEnvironment/current``,
/// and change them for a scope with ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:operation:file:line:)-(_,_,_,_,()->R,_,_)``.
///
/// ```swift
/// struct MyEnvironmentKey: SnapshotEnvironmentKey {
///     static let defaultValue = 42
/// }
///
/// try withTestingEnvironment {
///     $0[MyEnvironmentKey.self] = 100
/// } operation: {
///     print(SnapshotEnvironment.current[MyEnvironmentKey.self])  // 100
/// }
/// ```
public struct SnapshotEnvironmentValues: Sendable {

    @TaskLocal static var current: SnapshotEnvironmentValues?

    private var values: [ObjectIdentifier: Sendable] = [:]

    init() {}

    /// The value stored for `key`, or its default value if none was set.
    ///
    /// - Parameter key: The type of the key.
    public subscript<Key: SnapshotEnvironmentKey>(_ key: Key.Type) -> Key.Value {
        get {
            values[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue
        }
        set {
            values[ObjectIdentifier(key)] = newValue
        }
    }
}

/// Runs a asynchronous operation with some environment values changed.
///
/// The changes apply to the operation only. Afterwards, the environment is as it was before.
///
/// - Parameters:
///   - mutating: Changes the values of the environment.
///   - operation: The work to run.
///   - file: The file of the call, for diagnostics.
///   - line: The line of the call, for diagnostics.
/// - Returns: The result of `operation`.
/// - Throws: An error thrown by `operation`.
public nonisolated(nonsending) func withTestingEnvironment<R: Sendable>(
    _ mutating: @Sendable (inout SnapshotEnvironmentValues) -> Void,
    operation: nonisolated(nonsending) () async throws -> R,
    file: String = #file,
    line: UInt = #line
) async rethrows -> R {
    var argumentValues = SnapshotEnvironmentValues.current ?? SnapshotEnvironmentValues()
    mutating(&argumentValues)
    return try await SnapshotEnvironmentValues.$current.withValue(
        argumentValues,
        operation: operation,
        file: file,
        line: line
    )
}

/// Runs a synchronous operation with some environment values changed.
///
/// The changes apply to the operation only. Afterwards, the environment is as it was before.
///
/// - Parameters:
///   - mutating: Changes the values of the environment.
///   - operation: The work to run.
///   - file: The file of the call, for diagnostics.
///   - line: The line of the call, for diagnostics.
/// - Returns: The result of `operation`.
/// - Throws: An error thrown by `operation`.
public func withTestingEnvironment<R>(
    _ mutating: @Sendable (inout SnapshotEnvironmentValues) -> Void,
    operation: () throws -> R,
    file: String = #file,
    line: UInt = #line
) rethrows -> R {
    var argumentValues = SnapshotEnvironmentValues.current ?? SnapshotEnvironmentValues()
    mutating(&argumentValues)
    return try SnapshotEnvironmentValues.$current.withValue(
        argumentValues,
        operation: operation,
        file: file,
        line: line
    )
}

/// Runs a asynchronous operation with some environment values changed.
///
/// The changes apply to the operation only. Afterwards, the environment is as it was before.
///
/// - Parameters:
///   - record: The record mode, or `nil` to keep the current one.
///   - diffTool: The diff tool, or `nil` to keep the current one.
///   - maxConcurrentTests: The maximum number of windows used at once to render UI snapshots, or `nil` to keep the current limit.
///   - platform: The platform name in the path of the references, or `nil` to keep the current one.
///   - mutating: Makes further changes, after the ones above.
///   - operation: The work to run.
///   - file: The file of the call, for diagnostics.
///   - line: The line of the call, for diagnostics.
/// - Returns: The result of `operation`.
/// - Throws: An error thrown by `operation`.
public nonisolated(nonsending) func withTestingEnvironment<R: Sendable>(
    record: RecordMode? = nil,
    diffTool: DiffTool? = nil,
    maxConcurrentTests: Int? = nil,
    platform: String? = nil,
    environment mutating: (@Sendable (inout SnapshotEnvironmentValues) -> Void),
    operation: nonisolated(nonsending) () async throws -> R,
    file: String = #file,
    line: UInt = #line
) async rethrows -> R {
    try await withTestingEnvironment(
        {
            mutatingEnvironmentValues(
                record: record,
                diffTool: diffTool,
                maxConcurrentTests: maxConcurrentTests,
                platform: platform,
                mutating: &$0
            )
            mutating(&$0)
        },
        operation: operation,
        file: file,
        line: line
    )
}

/// Runs a asynchronous operation with some environment values changed.
///
/// The changes apply to the operation only. Afterwards, the environment is as it was before.
///
/// - Parameters:
///   - record: The record mode, or `nil` to keep the current one.
///   - diffTool: The diff tool, or `nil` to keep the current one.
///   - maxConcurrentTests: The maximum number of windows used at once to render UI snapshots, or `nil` to keep the current limit.
///   - platform: The platform name in the path of the references, or `nil` to keep the current one.
///   - operation: The work to run.
///   - file: The file of the call, for diagnostics.
///   - line: The line of the call, for diagnostics.
/// - Returns: The result of `operation`.
/// - Throws: An error thrown by `operation`.
public nonisolated(nonsending) func withTestingEnvironment<R: Sendable>(
    record: RecordMode? = nil,
    diffTool: DiffTool? = nil,
    maxConcurrentTests: Int? = nil,
    platform: String? = nil,
    operation: nonisolated(nonsending) () async throws -> R,
    file: String = #file,
    line: UInt = #line
) async rethrows -> R {
    try await withTestingEnvironment(
        {
            mutatingEnvironmentValues(
                record: record,
                diffTool: diffTool,
                maxConcurrentTests: maxConcurrentTests,
                platform: platform,
                mutating: &$0
            )
        },
        operation: operation,
        file: file,
        line: line
    )
}

/// Runs a synchronous operation with some environment values changed.
///
/// The changes apply to the operation only. Afterwards, the environment is as it was before.
///
/// - Parameters:
///   - record: The record mode, or `nil` to keep the current one.
///   - diffTool: The diff tool, or `nil` to keep the current one.
///   - maxConcurrentTests: The maximum number of windows used at once to render UI snapshots, or `nil` to keep the current limit.
///   - platform: The platform name in the path of the references, or `nil` to keep the current one.
///   - mutating: Makes further changes, after the ones above.
///   - operation: The work to run.
///   - file: The file of the call, for diagnostics.
///   - line: The line of the call, for diagnostics.
/// - Returns: The result of `operation`.
/// - Throws: An error thrown by `operation`.
public func withTestingEnvironment<R>(
    record: RecordMode? = nil,
    diffTool: DiffTool? = nil,
    maxConcurrentTests: Int? = nil,
    platform: String? = nil,
    environment mutating: (@Sendable (inout SnapshotEnvironmentValues) -> Void),
    operation: () throws -> R,
    file: String = #file,
    line: UInt = #line
) rethrows -> R {
    try withTestingEnvironment(
        {
            mutatingEnvironmentValues(
                record: record,
                diffTool: diffTool,
                maxConcurrentTests: maxConcurrentTests,
                platform: platform,
                mutating: &$0
            )
            mutating(&$0)
        },
        operation: operation,
        file: file,
        line: line
    )
}

/// Runs a synchronous operation with some environment values changed.
///
/// The changes apply to the operation only. Afterwards, the environment is as it was before.
///
/// - Parameters:
///   - record: The record mode, or `nil` to keep the current one.
///   - diffTool: The diff tool, or `nil` to keep the current one.
///   - maxConcurrentTests: The maximum number of windows used at once to render UI snapshots, or `nil` to keep the current limit.
///   - platform: The platform name in the path of the references, or `nil` to keep the current one.
///   - operation: The work to run.
///   - file: The file of the call, for diagnostics.
///   - line: The line of the call, for diagnostics.
/// - Returns: The result of `operation`.
/// - Throws: An error thrown by `operation`.
public func withTestingEnvironment<R>(
    record: RecordMode? = nil,
    diffTool: DiffTool? = nil,
    maxConcurrentTests: Int? = nil,
    platform: String? = nil,
    operation: () throws -> R,
    file: String = #file,
    line: UInt = #line
) rethrows -> R {
    try withTestingEnvironment(
        {
            mutatingEnvironmentValues(
                record: record,
                diffTool: diffTool,
                maxConcurrentTests: maxConcurrentTests,
                platform: platform,
                mutating: &$0
            )
        },
        operation: operation,
        file: file,
        line: line
    )
}

/// Sets in `environment` the values that are not `nil`, and leaves the others as they are.
private func mutatingEnvironmentValues(
    record: RecordMode?,
    diffTool: DiffTool?,
    maxConcurrentTests: Int?,
    platform: String?,
    mutating environment: inout SnapshotEnvironmentValues
) {
    if let record {
        environment.recordMode = record
    }

    if let diffTool {
        environment.diffTool = diffTool
    }

    if let maxConcurrentTests {
        environment.maxConcurrentTests = maxConcurrentTests
    }

    if let platform {
        environment.platform = platform
    }
}
