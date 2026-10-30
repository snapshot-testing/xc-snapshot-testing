// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("Executors")
struct ExecutorCombinatorTests {

    private struct Failure: Error, Equatable {}

    // MARK: - Sync

    @Test func syncExecutorProducesItsOutput() throws {
        let executor = Sync<Int, Int> { $0 * 2 }

        #expect(try SnapshotRunner.run(executor, 21) == 42)
    }

    @Test func syncExecutorReportsThrownErrors() {
        let executor = Sync<Int, Int> { _ in throw Failure() }

        #expect(throws: Failure.self) { try SnapshotRunner.run(executor, 1) }
    }

    @Test func syncMapTransformsTheOutput() throws {
        let executor = Sync<Int, Int> { $0 + 1 }.map { String($0) }

        #expect(try SnapshotRunner.run(executor, 1) == "2")
    }

    @Test func syncMapWithAContinuationCanProduceAsynchronously() throws {
        let executor = Sync<Int, Int> { $0 }.map { (value: Int, continuation: SyncContinuation<String>) in
            DispatchQueue.global().async { continuation.resume(returning: "later \(value)") }
        }

        #expect(try SnapshotRunner.run(executor, 5) == "later 5")
    }

    @Test func syncMapPropagatesErrorsFromTheUpstreamExecutor() {
        let executor = Sync<Int, Int> { _ in throw Failure() }.map { String($0) }

        #expect(throws: Failure.self) { try SnapshotRunner.run(executor, 1) }
    }

    @Test func syncMapCapturesErrorsThrownByTheTransform() {
        let executor = Sync<Int, Int> { $0 }.map { (_: Int) throws -> Int in throw Failure() }

        #expect(throws: Failure.self) { try SnapshotRunner.run(executor, 1) }
    }

    @Test func syncPullbackTransformsTheInput() throws {
        let executor = Sync<Int, Int> { $0 * 3 }.pullback { (text: String) in Int(text) ?? 0 }

        #expect(try SnapshotRunner.run(executor, "4") == 12)
    }

    @Test func syncPullbackCapturesErrorsThrownByTheTransform() {
        let executor = Sync<Int, Int> { $0 }.pullback { (_: String) throws -> Int in throw Failure() }

        #expect(throws: Failure.self) { try SnapshotRunner.run(executor, "x") }
    }

    @Test func syncPullbackWithAContinuationCanProduceTheInputLater() throws {
        let executor = Sync<Int, Int> { $0 + 1 }.pullback {
            (text: String, continuation: SyncContinuation<Int>) in
            continuation.resume(returning: Int(text) ?? 0)
        }

        #expect(try SnapshotRunner.run(executor, "9") == 10)
    }

    @Test func syncPullbackWithAContinuationPropagatesFailures() {
        let executor = Sync<Int, Int> { $0 }.pullback {
            (_: String, continuation: SyncContinuation<Int>) in
            continuation.resume(throwing: Failure())
        }

        #expect(throws: Failure.self) { try SnapshotRunner.run(executor, "x") }
    }

    @Test func aSequenceOfSyncExecutorsCollectsEveryOutputInOrder() throws {
        let executors = (1...3).map { number in Sync<Void, Int> { _ in number * 10 } }

        #expect(try SnapshotRunner.run(executors.sequence(), ()) == [10, 20, 30])
    }

    // MARK: - Sync as Async

    @Test func syncCanBeMappedIntoAnAsyncExecutor() async throws {
        let executor = Sync<Int, Int> { $0 + 1 }.map { value async throws in value * 2 }

        #expect(try await executor(4) == 10)
    }

    @Test func syncCanBePulledBackFromAnAsyncTransform() async throws {
        let executor = Sync<Int, Int> { $0 + 1 }.pullback { (text: String) async throws in Int(text) ?? 0 }

        #expect(try await executor("4") == 5)
    }

    @Test func syncSleepsBeforeReturning() async throws {
        let executor = Sync<Int, Int> { $0 }.sleep(nanoseconds: 20_000_000)
        let start = ContinuousClock.now

        let value = try await executor(3)

        #expect(value == 3)
        #expect(ContinuousClock.now - start >= .milliseconds(15))
    }

    @Test func syncSleepsForADuration() async throws {
        let executor = Sync<Int, Int> { $0 }.sleep(for: .milliseconds(20))
        let start = ContinuousClock.now

        #expect(try await executor(1) == 1)
        #expect(ContinuousClock.now - start >= .milliseconds(15))
    }

    @Test func syncSleepsUntilADeadline() async throws {
        let executor = Sync<Int, Int> { $0 }.sleep(until: .now + .milliseconds(20))
        let start = ContinuousClock.now

        #expect(try await executor(1) == 1)
        #expect(ContinuousClock.now - start >= .milliseconds(15))
    }

    // MARK: - Async

    @Test func asyncMapAndPullbackCompose() async throws {
        let executor = Async<Int, Int> { $0 + 1 }
            .map { String($0) }
            .pullback { (text: String) in Int(text) ?? 0 }

        #expect(try await executor("41") == "42")
    }

    @Test func asyncSleepWaitsBeforeReturning() async throws {
        let start = ContinuousClock.now

        let value = try await Async<Int, Int> { $0 }.sleep(nanoseconds: 20_000_000)(7)

        #expect(value == 7)
        #expect(ContinuousClock.now - start >= .milliseconds(15))
    }

    @Test func asyncSleepWithAZeroDurationReturnsTheSameExecutor() async throws {
        #expect(try await Async<Int, Int> { $0 }.sleep(nanoseconds: 0)(3) == 3)
    }

    @Test func asyncSleepsForADurationAndUntilADeadline() async throws {
        let base = Async<Int, Int> { $0 }

        #expect(try await base.sleep(for: .milliseconds(5))(1) == 1)
        #expect(try await base.sleep(until: .now + .milliseconds(5))(2) == 2)
    }

    @Test func asyncErrorsPropagate() async {
        let executor = Async<Int, Int> { _ in throw Failure() }

        await #expect(throws: Failure.self) { try await executor(1) }
    }

    // MARK: - Snapshot

    @Test func mappingASnapshotKeepsItsMetadata() throws {
        let snapshot = SyncSnapshot<String, StringBytes>(
            pathExtension: "custom",
            attachmentGenerator: .lines,
            executor: Sync { StringBytes(rawValue: $0) }
        )

        let mapped = snapshot.map { executor in
            executor.map { StringBytes(rawValue: $0.rawValue.uppercased()) }
        }

        #expect(mapped.pathExtension == "custom")
        #expect(try SnapshotRunner.run(mapped, "abc") == "ABC")
    }

    @Test func pullingBackASyncSnapshotWithAnAsyncTransformProducesAnAsyncSnapshot() async throws {
        let snapshot = IdentitySyncSnapshot<StringBytes>.lines
            .pullback { (number: Int) async throws in "n=\(number)" }

        #expect(snapshot.pathExtension == "txt")
        #expect(try await snapshot.executor(5).rawValue == "n=5")
    }

    @Test func pullingBackAnAsyncSnapshotTransformsItsInput() async throws {
        let snapshot = IdentityAsyncSnapshot<StringBytes>(pathExtension: "txt", attachmentGenerator: .lines)
            .pullback { (number: Int) in "n=\(number)" }

        #expect(try await SnapshotRunner.run(snapshot, 3) == "n=3")
    }

    #if canImport(Darwin)
    // MARK: - Main thread

    @Test func performOnMainThreadRunsOnTheMainThreadFromAnyThread() async {
        let isMain = await Task.detached { performOnMainThread { Thread.isMainThread } }.value

        #expect(isMain)
    }
    #endif
}
