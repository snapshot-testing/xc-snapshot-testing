// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
@preconcurrency import XCTest

@_spi(Internals) @testable import XCSnapshotTesting

/// Exercises the whole assertion flow (`verify` -> `SnapshotTester` -> `SnapshotFileEngine`) against a
/// temporary directory, so no reference image or text file has to be checked in and nothing depends
/// on the platform the tests run on.
final class SnapshotTesterTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Helpers

    /// The engine places the files at `<directory>/<test file name>/<function>.<name>.<extension>`.
    private func reference(_ name: String, pathExtension: String = "txt") -> URL {
        directory
            .appendingPathComponent("SnapshotTesterTests")
            .appendingPathComponent("snapshot.\(name).\(pathExtension)")
    }

    private func write(_ contents: String, named name: String) throws {
        let url = reference(name)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }

    private func contents(of name: String) throws -> String {
        String(decoding: try Data(contentsOf: reference(name)), as: UTF8.self)
    }

    private func verify(
        _ value: String,
        named name: String? = "a",
        record: RecordMode,
        line: UInt = 1
    ) throws -> String? {
        try XCSnapshotTesting.verify(
            of: value,
            as: .lines,
            named: name,
            record: record,
            snapshotDirectory: directory.path,
            testName: "snapshot",
            line: line
        )
    }

    // MARK: - Missing reference

    func testMissingReferenceIsNotRecordedWhenRecordingIsNever() throws {
        let message = try verify("hello", record: .never)

        XCTAssertEqual(
            message,
            "No reference was found on disk. New snapshot was not recorded because recording is disabled"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: reference("a").path))
    }

    func testMissingReferenceIsRecordedWhenRecordingIsMissing() throws {
        let message = try XCTUnwrap(verify("hello", record: .missing))

        XCTAssertTrue(message.hasPrefix("No reference was found on disk. Automatically recorded snapshot: …"))
        XCTAssertTrue(message.contains("Re-run \"snapshot\" to assert against the newly-recorded snapshot."))
        XCTAssertEqual(try contents(of: "a"), "hello")
    }

    func testMissingReferenceIsRecordedWhenRecordingIsFailed() throws {
        _ = try verify("hello", record: .failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reference("a").path))
    }

    // MARK: - Matching reference

    func testMatchingReferencePasses() throws {
        try write("hello", named: "a")

        for mode in [RecordMode.never, .missing, .failed] {
            XCTAssertNil(try verify("hello", record: mode), "record mode: \(mode)")
        }
    }

    func testRecordedSnapshotPassesOnTheNextRun() throws {
        _ = try verify("hello", record: .missing)
        XCTAssertNil(try verify("hello", record: .never))
    }

    // MARK: - Mismatching reference

    func testMismatchReportsTheDiffAndKeepsTheReference() throws {
        try write("one\ntwo\nthree", named: "a")

        let message = try XCTUnwrap(verify("one\n2\nthree", record: .never))

        XCTAssertTrue(message.hasPrefix("Snapshot \"snapshot\" does not match reference."))
        XCTAssertTrue(message.contains("@−"), "the default diff tool output is expected")
        XCTAssertTrue(message.contains("−two"), "the removed line is expected in the patch")
        XCTAssertTrue(message.contains("+2"), "the added line is expected in the patch")
        XCTAssertFalse(message.contains("A new snapshot was automatically recorded."))
        XCTAssertEqual(try contents(of: "a"), "one\ntwo\nthree")
    }

    func testMismatchOverwritesTheReferenceWhenRecordingIsFailed() throws {
        try write("old", named: "a")

        let message = try XCTUnwrap(verify("new", record: .failed))

        XCTAssertTrue(message.contains("A new snapshot was automatically recorded."))
        XCTAssertEqual(try contents(of: "a"), "new")
    }

    func testAllRecordModeAlwaysOverwritesAndFails() throws {
        try write("same", named: "a")

        let message = try XCTUnwrap(verify("same", record: .all))

        XCTAssertTrue(message.hasPrefix("Record mode is on. Automatically recorded snapshot: …"))
        XCTAssertTrue(message.contains("Turn record mode off and re-run \"snapshot\""))

        _ = try verify("different", record: .all)
        XCTAssertEqual(try contents(of: "a"), "different")
    }

    // MARK: - Diff tool

    func testCustomDiffToolIsUsedInTheFailureMessage() async throws {
        try write("old", named: "a")

        let message = try await withTestingEnvironment(diffTool: .ksdiff) {
            try verify("new", record: .never)
        }

        XCTAssertTrue(try XCTUnwrap(message).contains("ksdiff \""))
        XCTAssertFalse(try XCTUnwrap(message).contains("@−"))
    }

    // MARK: - Data snapshots

    func testDataMismatchWithTheSameLength() throws {
        let url = directory.appendingPathComponent("SnapshotTesterTests/snapshot.data")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: url)

        let message = try XCTUnwrap(
            XCSnapshotTesting.verify(
                of: Data([1, 2, 4]),
                as: .data,
                named: "data",
                record: .never,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        )

        XCTAssertTrue(message.contains("does not match reference."))
        XCTAssertTrue(message.contains("Expected data to match"))
    }

    func testDataMismatchWithDifferentLength() throws {
        let url = directory.appendingPathComponent("SnapshotTesterTests/snapshot.data")
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([1, 2, 3]).write(to: url)

        let message = try XCTUnwrap(
            XCSnapshotTesting.verify(
                of: Data([1, 2]),
                as: .data,
                named: "data",
                record: .never,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        )

        XCTAssertTrue(message.contains("Expected 2 bytes to match 3 bytes"))
    }

    // MARK: - File names

    func testUnnamedSnapshotsReceiveACounterSuffix() throws {
        // The counter follows the position of the assertion in the test, so each call site gets its own.
        _ = try verify("first", named: nil, record: .missing, line: 10)
        _ = try verify("second", named: nil, record: .missing, line: 20)
        _ = try verify("first, again", named: nil, record: .missing, line: 10)

        XCTAssertEqual(try contents(of: "1"), "first")
        XCTAssertEqual(try contents(of: "2"), "second")
        XCTAssertFalse(FileManager.default.fileExists(atPath: reference("3").path))
    }

    func testCounterSuffixCanBeDisabled() async throws {
        try await withTestingEnvironment {
            $0.addsCounterSuffix = false
        } operation: {
            _ = try verify("only", named: nil, record: .missing)
        }

        let url = directory.appendingPathComponent("SnapshotTesterTests/snapshot.txt")
        XCTAssertEqual(String(decoding: try Data(contentsOf: url), as: UTF8.self), "only")
    }

    func testNamedSnapshotsDropInvalidPathCharacters() throws {
        _ = try verify("value", named: "with spaces/and slash", record: .missing)

        let files = try FileManager.default.contentsOfDirectory(
            atPath: directory.appendingPathComponent("SnapshotTesterTests").path
        )

        XCTAssertEqual(files, ["snapshot.with spacesand slash.txt"])
    }

    // MARK: - Timeouts

    func testSyncSnapshotTimeout() throws {
        let slow = SyncSnapshot<String, StringBytes>(
            pathExtension: "txt",
            attachmentGenerator: .lines,
            executor: Sync { input, continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    continuation.resume(returning: StringBytes(rawValue: input))
                }
            }
        )

        let message = try XCTUnwrap(
            XCSnapshotTesting.verify(
                of: "value",
                as: slow,
                named: "a",
                record: .missing,
                snapshotDirectory: directory.path,
                timeout: 0.05,
                testName: "snapshot"
            )
        )

        XCTAssertTrue(message.hasPrefix("Exceeded timeout of 0.05 seconds waiting for snapshot."))
        XCTAssertFalse(FileManager.default.fileExists(atPath: reference("a").path))
    }

    func testAsyncSnapshotTimeout() async throws {
        let slow = AsyncSnapshot<String, StringBytes>(
            pathExtension: "txt",
            attachmentGenerator: .lines,
            executor: Async { input in
                try await Task.sleep(nanoseconds: 3_000_000_000)
                return StringBytes(rawValue: input)
            }
        )

        let message = try await XCSnapshotTesting.verify(
            of: "value",
            as: slow,
            named: "a",
            record: .missing,
            snapshotDirectory: directory.path,
            timeout: 1,
            testName: "snapshot"
        )

        XCTAssertTrue(try XCTUnwrap(message).hasPrefix("Exceeded timeout of 1.0 seconds waiting for snapshot."))
    }

    func testAsyncSnapshotWithinTheTimeoutRecordsNormally() async throws {
        let fast = AsyncSnapshot<String, StringBytes>(
            pathExtension: "txt",
            attachmentGenerator: .lines,
            executor: Async { StringBytes(rawValue: $0) }
        )

        let message = try await XCSnapshotTesting.verify(
            of: "value",
            as: fast,
            named: "a",
            record: .missing,
            snapshotDirectory: directory.path,
            timeout: 2,
            testName: "snapshot"
        )

        XCTAssertTrue(try XCTUnwrap(message).hasPrefix("No reference was found on disk."))
        XCTAssertEqual(try contents(of: "a"), "value")
    }

    func testErrorsThrownByTheSnapshotArePropagated() throws {
        struct Boom: Error {}

        let failing = SyncSnapshot<String, StringBytes>(
            pathExtension: "txt",
            attachmentGenerator: .lines,
            executor: Sync { _ in throw Boom() }
        )

        XCTAssertThrowsError(
            try XCSnapshotTesting.verify(
                of: "value",
                as: failing,
                record: .never,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        ) {
            XCTAssertTrue($0 is Boom)
        }
    }
}
