import Foundation
@preconcurrency import XCTest

@_spi(Internals) @testable import XCSnapshotTesting

/// Covers the public `assert` overloads (single strategy, arrays and dictionaries, sync and async).
final class AssertTests: XCTestCase {

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

    private func files() throws -> [String] {
        let url = directory.appendingPathComponent("AssertTests")
        return try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
    }

    private func write(_ contents: String, as fileName: String) throws {
        let folder = directory.appendingPathComponent("AssertTests")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: folder.appendingPathComponent(fileName))
    }

    private func asyncLines(
        _ transform: @escaping @Sendable (String) -> String = { $0 }
    ) -> AsyncSnapshot<String, StringBytes> {
        AsyncSnapshot(
            pathExtension: "txt",
            attachmentGenerator: .lines,
            executor: Async { StringBytes(rawValue: transform($0)) }
        )
    }

    private struct Boom: Error {}

    // MARK: - Sync

    func testSyncAssertFailsWithoutAReferenceAndPassesAfterRecording() throws {
        try XCTExpectFailure("The first run has no reference") {
            try assert(
                of: "value",
                as: .lines,
                named: "a",
                record: .missing,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        } issueMatcher: {
            $0.compactDescription.contains("No reference was found on disk")
        }

        try assert(
            of: "value",
            as: .lines,
            named: "a",
            record: .never,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )
        XCTAssertEqual(try files(), ["snapshot.a.txt"])
    }

    func testSyncAssertReportsMismatches() throws {
        try write("expected", as: "snapshot.a.txt")

        try XCTExpectFailure {
            try assert(
                of: "actual",
                as: .lines,
                named: "a",
                record: .never,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        } issueMatcher: {
            $0.compactDescription.contains("does not match reference.")
        }
    }

    func testSyncDictionaryOfStrategiesUsesTheKeysAsNames() throws {
        try XCTExpectFailure {
            try assert(
                of: "value",
                as: ["first": .lines, "second": .lines],
                record: .missing,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        }

        XCTAssertEqual(try files(), ["snapshot.first.txt", "snapshot.second.txt"])
    }

    func testSyncArrayOfStrategiesGivesEachStrategyItsOwnFile() async throws {
        let upper = IdentitySyncSnapshot<StringBytes>.lines.pullback { (value: String) in value.uppercased() }
        let plain = IdentitySyncSnapshot<StringBytes>.lines.pullback { (value: String) in value }

        expectFailure(containing: "Automatically recorded snapshot")

        try await assert(
            of: "value",
            as: [plain, upper],
            record: .missing,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )

        let names = try files()
        XCTAssertEqual(names.count, 2, "each strategy needs its own reference: \(names)")
        let contents = try names.map {
            String(decoding: try Data(contentsOf: directory.appendingPathComponent("AssertTests/\($0)")), as: UTF8.self)
        }
        XCTAssertEqual(Set(contents), ["value", "VALUE"])
    }

    func testSyncStrategiesPropagateTheirErrors() async throws {
        let failing = SyncSnapshot<String, StringBytes>(
            pathExtension: "txt",
            attachmentGenerator: .lines,
            executor: Sync { _ in throw Boom() }
        )

        // Regression: the array and dictionary overloads used `try?`, hiding errors of the strategies.
        await XCTAssertThrowsErrorAsync(
            try await assert(
                of: "value",
                as: [failing],
                record: .never,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        )
        XCTAssertThrowsError(
            try assert(
                of: "value",
                as: ["failing": failing],
                record: .never,
                snapshotDirectory: directory.path,
                testName: "snapshot"
            )
        ) {
            XCTAssertTrue($0 is Boom)
        }
    }

    // MARK: - Async

    func testAsyncAssertMatchesARecordedReference() async throws {
        _ = try await verify(
            of: "value",
            as: asyncLines(),
            named: "a",
            record: .missing,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )

        try await assert(
            of: "value",
            as: asyncLines(),
            named: "a",
            record: .never,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )
    }

    func testAsyncAssertReportsMissingReferences() async throws {
        expectFailure(containing: "No reference was found on disk")

        try await assert(
            of: "value",
            as: asyncLines(),
            named: "a",
            record: .never,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )
    }

    func testAsyncDictionaryOfStrategiesUsesTheKeysAsNames() async throws {
        expectFailure(containing: "Automatically recorded snapshot")

        try await assert(
            of: "value",
            as: ["x": asyncLines(), "y": asyncLines { $0.uppercased() }],
            record: .missing,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )

        XCTAssertEqual(try files(), ["snapshot.x.txt", "snapshot.y.txt"])
    }

    func testAsyncArrayOfStrategiesNumbersTheSnapshots() async throws {
        expectFailure(containing: "Automatically recorded snapshot")

        try await assert(
            of: "value",
            as: [asyncLines(), asyncLines { $0.uppercased() }],
            record: .missing,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )

        let names = try files()
        XCTAssertEqual(names.count, 2)
        XCTAssertTrue(names.allSatisfy { $0.contains("@") }, "\(names)")
    }

    // MARK: - Testing system

    func testTheTestingSystemRecordsFailuresThroughXCTest() throws {
        XCTAssertFalse(TestingSystem.shared.isSwiftTestingRunning)
        XCTAssertFalse(TestingSystem.shared.isSwiftTestingCompletionAttached)

        try XCTExpectFailure {
            try TestingSystem.shared.record(
                message: "custom failure",
                fileID: #fileID,
                filePath: #filePath,
                line: #line,
                column: #column
            )
        } issueMatcher: {
            $0.compactDescription.contains("custom failure")
        }
    }

    func testTheTestingSystemAddsAttachmentsToTheCurrentTest() {
        TestingSystem.shared.add(
            "Attached",
            attachments: [
                SnapshotAttachment(string: "text"),
                SnapshotAttachment(uniformTypeIdentifier: "public.json", name: "named", payload: Data("{}".utf8)),
            ],
            fileID: #fileID,
            filePath: #filePath,
            line: #line,
            column: #column
        )
    }

    // MARK: - Expectations

    /// Marks the failures reported from now on as expected, as long as they match the text.
    private func expectFailure(containing text: String) {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.compactDescription.contains(text) }
        XCTExpectFailure("Expected while testing the assertion", options: options)
    }

    private func XCTAssertThrowsErrorAsync(_ body: @autoclosure () async throws -> Void) async {
        do {
            try await body()
            XCTFail("Expected the call to throw")
        } catch {
            XCTAssertTrue(error is Boom, "\(error)")
        }
    }
}
