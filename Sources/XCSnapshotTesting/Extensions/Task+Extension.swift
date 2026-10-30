// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

extension Task where Failure == Error {

    public static func timeout(
        _ timeout: TimeInterval,
        execute closure: @Sendable @escaping () async throws -> Success
    ) async throws -> Success {
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
                    nanoseconds: UInt64(timeout) * 1_000_000_000
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
        }
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
