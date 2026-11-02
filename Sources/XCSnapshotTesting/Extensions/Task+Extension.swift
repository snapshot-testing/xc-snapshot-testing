// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

extension Task where Failure == Error {

    /// Runs `closure`, and throws ``TaskTimeout`` if it takes longer than `timeout` seconds.
    ///
    /// Cancelling the task that waits cancels `closure` and ends the wait with a `CancellationError`.
    public static func timeout(
        _ timeout: TimeInterval,
        execute closure: @Sendable @escaping () async throws -> Success
    ) async throws -> Success {
        let cancellation = TimeoutCancellation()

        return try await withTaskCancellationHandler {
            try await withUnsafeThrowingContinuation { continuation in
                let completion = TimeoutCompletion(continuation)

                let regularTask = Task<Void, Never> {
                    let result: Result<Success, Error>

                    do {
                        result = .success(try await closure())
                    } catch {
                        result = .failure(error)
                    }

                    do {
                        try Task<Never, Never>.checkCancellation()
                    } catch {
                        completion.resume(with: .failure(error))
                        return
                    }

                    completion.resume(with: result)
                }

                let timeoutTask = Task<Void, Error> {
                    try await Task<Never, Never>.sleep(
                        nanoseconds: timeout.nanoseconds
                    )

                    // Once the timeout wins, the slow operation must not keep running nor resume again.
                    if completion.resume(with: .failure(TaskTimeout())) {
                        regularTask.cancel()
                    }
                }

                Task<Void, Never> {
                    _ = try? await timeoutTask.value
                    timeoutTask.cancel()
                }

                Task<Void, Never> {
                    _ = await regularTask.value
                    timeoutTask.cancel()
                }

                cancellation.arm {
                    regularTask.cancel()
                    timeoutTask.cancel()
                    completion.resume(with: .failure(_Concurrency.CancellationError()))
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
}

/// Carries the cancellation of the waiting task over to the tasks that `Task.timeout` started.
///
/// They are unstructured, so they don't inherit it, and the cancellation may arrive before they exist.
private final class TimeoutCancellation: @unchecked Sendable {

    private let lock = NSLock()
    private var isCancelled = false
    private var action: (@Sendable () -> Void)?

    func arm(_ action: @escaping @Sendable () -> Void) {
        let runNow = lock.withLock { () -> Bool in
            guard !isCancelled else { return true }
            self.action = action
            return false
        }

        if runNow {
            action()
        }
    }

    func cancel() {
        let action = lock.withLock { () -> (@Sendable () -> Void)? in
            isCancelled = true
            defer { self.action = nil }
            return self.action
        }

        action?()
    }
}

/// Resumes the continuation at most once, no matter which of the competing tasks finishes first.
private final class TimeoutCompletion<Success: Sendable>: @unchecked Sendable {

    private let lock = NSLock()
    private var continuation: UnsafeContinuation<Success, Error>?

    init(_ continuation: UnsafeContinuation<Success, Error>) {
        self.continuation = continuation
    }

    /// - Returns: `true` when this call resumed the continuation, `false` when it was already resumed.
    @discardableResult
    func resume(with result: Result<Success, Error>) -> Bool {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }

        guard let continuation else {
            return false
        }

        continuation.resume(with: result)
        return true
    }
}

public struct TaskTimeout: Error {}
