// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@Suite("Extensions")
struct ExtensionTests {

    // MARK: - String

    @Test func pointerReferencesAreRemoved() {
        #expect(
            "<UIView: 0x7f8b1c004a00; frame = (0 0; 10 10)>".sanitizingPointersReferences()
                == "<UIView; frame = (0 0; 10 10)>"
        )
        #expect("Object:0xabc123 end".sanitizingPointersReferences() == "Object end")
        #expect("no pointers here".sanitizingPointersReferences() == "no pointers here")
    }

    @Test func pathComponentsDropInvalidCharactersAndEmptyParentheses() {
        #expect("testExample()".sanitizingPathComponent() == "testExample")
        #expect("a/b\\c:d*e?f\"g<h>i|j".sanitizingPathComponent() == "abcdefghij")
        #expect("line\nbreak".sanitizingPathComponent() == "linebreak")
        #expect("keeps spaces".sanitizingPathComponent() == "keeps spaces")
    }

    #if canImport(Darwin)
    @Test func uniformTypeIdentifierIsResolvedFromTheExtension() {
        #expect("png".uniformTypeIdentifier() == "public.png")
        #expect("txt".uniformTypeIdentifier() == "public.plain-text")
        #expect("definitely-not-an-extension".uniformTypeIdentifier()?.hasPrefix("dyn.") ?? true)
    }

    // MARK: - CGSize and CGRect

    @Test func scaleIsOneWhenTheContentFits() {
        #expect(CGSize(width: 100, height: 100).scaleThatFits(CGSize(width: 50, height: 100)) == 1)
    }

    @Test func scaleFollowsTheTightestDimension() {
        let container = CGSize(width: 100, height: 100)

        #expect(container.scaleThatFits(CGSize(width: 200, height: 100)) == 0.5)
        #expect(container.scaleThatFits(CGSize(width: 100, height: 400)) == 0.25)
        #expect(container.scaleThatFits(CGSize(width: 400, height: 400)) == 0.25)
    }

    @Test func scaleToFitShrinksTheSizeKeepingItsAspectRatio() {
        let result = CGSize(width: 100, height: 100).scaleToFit(CGSize(width: 400, height: 200))

        #expect(result == CGSize(width: 100, height: 50))
    }

    @Test func rectScalingKeepsTheCenter() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 40)

        let scaled = rect.scale(by: 2)

        #expect(scaled.size == CGSize(width: 200, height: 80))
        #expect(scaled.midX == rect.midX)
        #expect(scaled.midY == rect.midY)
        #expect(rect.scale(by: 1) == rect)
    }
    #endif

    // MARK: - ProcessInfo

    @Test func artifactsDirectoryDefaultsToTheTemporaryDirectory() {
        let directory = ProcessInfo.artifactsDirectory

        if let configured = ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] {
            #expect(directory.path == URL(fileURLWithPath: configured, isDirectory: true).path)
        } else {
            #expect(
                directory.standardizedFileURL.path
                    == URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
            )
        }
        #expect(directory.hasDirectoryPath)
    }

    // MARK: - TimeInterval

    @Test func intervalsBecomeWholeNanoseconds() {
        #expect((1 as TimeInterval).nanoseconds == 1_000_000_000)
        #expect((0.5 as TimeInterval).nanoseconds == 500_000_000)
        #expect((0.0000000001 as TimeInterval).nanoseconds == 1, "a fraction is rounded up, not dropped")
    }

    @Test func onlyAPositiveFiniteIntervalIsALimit() {
        #expect((5 as TimeInterval).hasLimit)
        #expect((0.001 as TimeInterval).hasLimit)
        #expect(!(0 as TimeInterval).hasLimit)
        #expect(!TimeInterval.infinity.hasLimit)
        #expect(!(-1 as TimeInterval).hasLimit)
        #expect(!TimeInterval.nan.hasLimit)
    }

    @Test func intervalsThatCannotBeCountedDoNotTrap() {
        #expect((0 as TimeInterval).nanoseconds == 0)
        #expect((-1 as TimeInterval).nanoseconds == 0)
        #expect(TimeInterval.nan.nanoseconds == 0)
        #expect(TimeInterval.infinity.nanoseconds == .max)
        #expect(TimeInterval.greatestFiniteMagnitude.nanoseconds == .max)
        #expect((1e11 as TimeInterval).nanoseconds == .max)
    }

    // MARK: - Task.timeout

    @Test func timeoutReturnsTheResultOfFastOperations() async throws {
        let value = try await Task.timeout(2) { 42 }

        #expect(value == 42)
    }

    @Test func timeoutsShorterThanASecondAreHonored() async throws {
        // Regression: the seconds were truncated, so 0.5 became 0 and the timeout won immediately.
        let value = try await Task<Int, Error>.timeout(0.5) {
            try await Task.sleep(nanoseconds: 50_000_000)
            return 7
        }

        #expect(value == 7)
    }

    @Test func timeoutsThatCannotBeCountedDoNotTrap() async throws {
        let value = try await Task<Int, Error>.timeout(.infinity) { 1 }
        #expect(value == 1)

        await #expect(throws: TaskTimeout.self) {
            try await Task<Int, Error>.timeout(.nan) {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                return 1
            }
        }
    }

    @Test func cancellingTheWaitingTaskCancelsTheOperationAndEndsTheWait() async throws {
        // Regression: the tasks started by `timeout` are unstructured, so they never learned of it,
        // and the wait lasted until the operation finished or the timeout came.
        let observedCancellation = Flag()
        let waiting = Task {
            try await Task<Int, Error>.timeout(30) {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    observedCancellation.set()
                    throw error
                }
                return 1
            }
        }

        try await Task.sleep(nanoseconds: 100_000_000)
        waiting.cancel()

        await #expect(throws: CancellationError.self) { try await waiting.value }

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(observedCancellation.isSet)
    }

    @Test func aTaskThatIsAlreadyCancelledDoesNotStartTheWait() async {
        let waiting = Task {
            // Let the cancellation arrive before the call
            while !Task.isCancelled { await Task.yield() }
            return try await Task<Int, Error>.timeout(30) {
                try await Task.sleep(nanoseconds: 60_000_000_000)
                return 1
            }
        }

        waiting.cancel()

        await #expect(throws: CancellationError.self) { try await waiting.value }
    }

    @Test func timeoutRethrowsErrorsOfTheOperation() async {
        struct Failure: Error {}

        await #expect(throws: Failure.self) {
            try await Task<Int, Error>.timeout(2) { throw Failure() }
        }
    }

    @Test func timeoutThrowsWhenTheOperationIsTooSlow() async {
        await #expect(throws: TaskTimeout.self) {
            try await Task<Int, Error>.timeout(1) {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                return 1
            }
        }
    }

    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set() { lock.withLock { value = true } }
    }

    @Test func timeoutCancelsTheOperationThatTookTooLong() async throws {
        // Regression: the slow operation used to keep running after the timeout, and resumed the
        // continuation a second time when it finally finished.
        let observedCancellation = Flag()

        await #expect(throws: TaskTimeout.self) {
            try await Task<Int, Error>.timeout(1) {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    observedCancellation.set()
                    throw error
                }
                return 1
            }
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(observedCancellation.isSet)
    }
}
