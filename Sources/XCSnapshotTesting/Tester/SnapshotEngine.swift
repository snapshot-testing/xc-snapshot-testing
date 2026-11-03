// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// The storage and reporting side of a snapshot assertion.
///
/// A ``SnapshotTester`` runs the assertion and delegates to its engine everything that depends on
/// where the references live: finding them, reading them, writing them and describing failures.
/// `XCSnapshotTesting` stores references as files in a `__Snapshots__` directory, and
/// `InlineSnapshotTesting` stores them in the source of the test.
@_spi(Internals)
public protocol SnapshotEngine<Executor>: Sendable where Executor.Output: BytesRepresentable {

    /// The executor of the snapshots this engine handles.
    associatedtype Executor: SnapshotExecutor

    /// Returns the base location of the snapshots of the test file at `filePath`.
    ///
    /// The tester appends the name of the test to it to get the location of a reference.
    ///
    /// - Parameters:
    ///   - filePath: The `#filePath` of the test.
    ///   - tester: The tester making the assertion.
    func sourceURL(
        for filePath: StaticString,
        using tester: SnapshotTester<Self>
    ) throws -> URL

    /// Returns a directory to keep the output of a failed comparison, so that it can be diffed against the reference.
    ///
    /// - Parameters:
    ///   - filePath: The `#filePath` of the test.
    ///   - tester: The tester making the assertion.
    /// - Returns: The directory, or `nil` if the engine keeps no such output.
    func temporaryURL(
        for filePath: StaticString,
        using tester: SnapshotTester<Self>
    ) throws -> URL?

    /// Returns whether a reference exists at `url`.
    func contentExists(
        at url: URL
    ) -> Bool

    /// Reads the reference at `url`.
    ///
    /// - Parameters:
    ///   - url: The location of the reference.
    ///   - tester: The tester making the assertion.
    func loadSnapshot(
        from url: URL,
        using tester: SnapshotTester<Self>
    ) throws -> Executor.Output

    /// Applies `operation` to a serialized snapshot.
    ///
    /// - Parameters:
    ///   - operation: What to do with the snapshot.
    ///   - contents: The serialized snapshot.
    ///   - url: The location of the snapshot.
    ///   - tester: The tester making the assertion.
    func perform(
        _ operation: SnapshotPerformOperation,
        contents: Data,
        to url: URL,
        using tester: SnapshotTester<Self>
    ) throws

    /// Returns the message to report for a failed assertion.
    ///
    /// - Parameters:
    ///   - context: The details of the failure.
    ///   - tester: The tester making the assertion.
    func generateFailureMessage(
        for context: SnapshotFailContext,
        using tester: SnapshotTester<Self>
    ) -> String
}
