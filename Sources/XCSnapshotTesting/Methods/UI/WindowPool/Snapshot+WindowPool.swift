// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS)
@preconcurrency import AppKit
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
extension Snapshot {
    /// Runs `operation` in a window leased from the pool, and gives the window back afterwards,
    /// whether `operation` succeeds or throws.
    ///
    /// The number of windows in the pool is limited by ``SnapshotEnvironmentValues/maxConcurrentTests``.
    func withWindow<NewInput>(
        sessionRole: UISceneSession.Role,
        application: SDKApplication?,
        operation:
            @escaping @Sendable (SnapshotWindowConfiguration<NewInput>, Executor) async throws
            -> Async<NewInput, Output>
    ) -> AsyncSnapshot<NewInput, Output> {
        map { executor in
            Async(NewInput.self) { @MainActor newInput in
                let windowPool = application?.windowPool ?? WindowPool.shared

                let window = try await windowPool.acquire(
                    sessionRole: sessionRole,
                    maxConcurrentTests: SnapshotEnvironment.current.maxConcurrentTests
                )

                let configuration = SnapshotWindowConfiguration(
                    window: window,
                    input: newInput
                )

                defer {
                    configuration.restoration.restore()
                    windowPool.release(window)
                }

                let executor = try await operation(configuration, executor)
                return try await executor(newInput)
            }
        }
    }
}
#endif
