// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import SwiftAsyncStream
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("Layout wait")
struct LayoutWaitTests {

    @Test func aLayoutThatNeverHappensDoesNotHoldTheSnapshotForever() async throws {
        // Regression: the wait had no limit, so a snapshot without a timeout never finished.
        let signal = AsyncSignal()
        let start = Date()

        try await signal.waitForLayout(timeout: 0.1)

        #expect(Date().timeIntervalSince(start) >= 0.09, "the wait lasts the timeout")
    }

    @Test func aLayoutThatHappensEndsTheWaitRightAway() async throws {
        let signal = AsyncSignal()
        let start = Date()

        let layout = Task {
            try await Task.sleep(nanoseconds: 20_000_000)
            signal.signal()
        }

        try await signal.waitForLayout(timeout: 30)
        try await layout.value

        #expect(Date().timeIntervalSince(start) < 25, "the signal ended the wait, not the 30 s fallback")
    }

    @Test func theSignalIsArmedAgainForTheNextWait() async throws {
        let signal = AsyncSignal()
        signal.signal()

        try await signal.waitForLayout(timeout: 30)

        // Without arming it again, the second wait would return at once instead of waiting for its layout.
        let start = Date()
        try await signal.waitForLayout(timeout: 0.1)
        #expect(Date().timeIntervalSince(start) >= 0.09)
    }

    @Test func cancellingTheSnapshotCancelsTheWait() async {
        let signal = AsyncSignal()
        let task = Task { try await signal.waitForLayout(timeout: 30) }

        try? await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
