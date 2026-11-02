// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@MainActor
@Suite("Window pool", .serialized)
struct WindowPoolTests {

    private func lease() -> WindowLease {
        WindowLease(window: SDKWindow())
    }

    @Test func anIdleWindowIsPreferredOverABusyOne() async {
        let busy = lease()
        let idle = lease()
        await busy.lock()

        #expect(WindowPool.leastBusy(of: [busy, idle]) === idle)
        #expect(WindowPool.leastBusy(of: [idle, busy]) === idle)

        busy.unlock()
    }

    @Test func theWindowWithTheFewestWaitersIsPreferred() async {
        let crowded = lease()
        let quiet = lease()
        await crowded.lock()
        await quiet.lock()

        // Regression: the comparison used to be inverted, so the most disputed window was chosen.
        let waiters = [crowded, crowded, quiet].map { lease in
            Task { @MainActor in await lease.lock() }
        }
        while crowded.pendingTasks < 2 || quiet.pendingTasks < 1 { await Task.yield() }

        #expect(WindowPool.leastBusy(of: [crowded, quiet]) === quiet)
        #expect(WindowPool.leastBusy(of: [quiet, crowded]) === quiet)

        for _ in 0..<3 {
            crowded.unlock()
            quiet.unlock()
            await Task.yield()
        }
        for waiter in waiters { await waiter.value }
    }

    @Test func tiesGoToTheEarliestWindow() {
        let first = lease()
        let second = lease()

        #expect(WindowPool.leastBusy(of: [first, second]) === first)
    }

    @Test func aWindowIsNotBusyAfterItIsReleased() async {
        let window = lease()

        await window.lock()
        #expect(window.load == 1)

        window.unlock()
        #expect(window.load == 0)
    }

    @Test func theLimitOfConcurrentTestsCannotBeBelowOne() async throws {
        let pool = WindowPool(nil)

        // Regression: a limit of zero used to trap on the empty selection once a window existed.
        for limit in [0, -3] {
            let window = try await pool.acquire(sessionRole: .windowApplication, maxConcurrentTests: limit)
            pool.release(window)
        }
    }
}
#endif
