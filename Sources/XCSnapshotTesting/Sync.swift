// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Delivers the outcome of a ``Sync`` operation: a value or an error.
public struct SyncContinuation<Output>: Sendable {

    fileprivate let block: @Sendable (Result<Output, Error>) -> Void
    private let hasResumed = ResumeOnce()

    fileprivate init(
        block: @Sendable @escaping (Result<Output, Error>) -> Void
    ) {
        self.block = block
    }

    /// Delivers `result`.
    public func resume(with result: Result<Output, Error>) {
        guard hasResumed.claim() else {
            return
        }

        block(result)
    }

    /// Delivers `value`.
    public func resume(returning value: Output) {
        resume(with: .success(value))
    }

    /// Delivers `error`.
    public func resume(throwing error: Error) {
        resume(with: .failure(error))
    }
}

private final class ResumeOnce: @unchecked Sendable {

    private let lock = NSLock()
    private var isClaimed = false

    /// - Returns: `true` for the first caller only.
    func claim() -> Bool {
        lock.withLock {
            defer { isClaimed = true }
            return !isClaimed
        }
    }
}

/// A synchronous operation from an `Input` to an `Output`.
///
/// It is the executor of the snapshots that run synchronously. Operations are composed with `map`,
/// `pullback` and `sleep`, and the result is delivered through a callback.
public struct Sync<Input, Output>: SnapshotExecutor {

    private let producer: @Sendable (Input, SyncContinuation<Output>) -> Void

    /// Creates an operation from a block that delivers its output through a continuation.
    ///
    /// - Parameters:
    ///   - inputType: The type of the input. It is inferred from `block` when omitted.
    ///   - block: The work to do. It receives the input and a ``SyncContinuation`` for the output.
    public init(
        _ inputType: Input.Type = Input.self,
        _ block: @escaping @Sendable (Input, SyncContinuation<Output>) throws -> Void
    ) {
        self.producer = { input, continuation in
            do {
                try block(input, continuation)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Creates an operation from a block that returns its output or throws.
    ///
    /// - Parameters:
    ///   - inputType: The type of the input. It is inferred from `block` when omitted.
    ///   - block: The work to do. It receives the input.
    public init(
        _ inputType: Input.Type = Input.self,
        _ block: @escaping @Sendable (Input) throws -> Output
    ) {
        self.init(inputType) { input, continuation in
            continuation.resume(returning: try block(input))
        }
    }

    /// Runs the operation.
    ///
    /// - Parameters:
    ///   - input: The input of the operation.
    ///   - callback: Called with the output, or with the error the operation threw.
    public func callAsFunction(
        _ input: Input,
        callback: @escaping @Sendable (Result<Output, Error>) -> Void
    ) {
        producer(
            input,
            SyncContinuation(block: callback)
        )
    }

    func callAsFunction(_ input: Input) async throws -> Output where Output: Sendable {
        try await withUnsafeThrowingContinuation { continuation in
            self(input) {
                continuation.resume(with: $0)
            }
        }
    }
}

extension Sync {

    /// Transforms the output with a block that delivers the new output through a continuation.
    ///
    /// - Parameter block: Receives the output and a continuation for the new output.
    /// - Returns: An operation that produces the transformed output.
    public func map<NewOutput>(
        _ block: @escaping @Sendable (Output, SyncContinuation<NewOutput>) -> Void
    ) -> Sync<Input, NewOutput> {
        .init { input, continuation in
            self(input) { result in
                switch result {
                case .success(let output):
                    block(output, continuation)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Transforms the output with a block that may throw.
    ///
    /// - Parameter block: Receives the output and returns the new output.
    /// - Returns: An operation that produces the transformed output.
    public func map<NewOutput>(
        _ block: @escaping @Sendable (Output) throws -> NewOutput
    ) -> Sync<Input, NewOutput> {
        .init { input, continuation in
            self(input) { result in
                switch result {
                case .success(let output):
                    continuation.resume(
                        with: Result {
                            try block(output)
                        }
                    )
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Adapts the input of the operation to another type.
    ///
    /// - Parameter block: Converts a `NewInput` into the `Input` of this operation. It may throw.
    /// - Returns: An operation that takes a `NewInput`.
    public func pullback<NewInput>(
        _ block: @escaping @Sendable (NewInput) throws -> Input
    ) -> Sync<NewInput, Output> {
        .init { newInput, continuation in
            do {
                try self(block(newInput)) {
                    continuation.resume(with: $0)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Adapts the input of the operation to another type, with a block that delivers the converted
    /// input through a continuation.
    ///
    /// - Parameter block: Receives a `NewInput` and a continuation for the `Input` of this operation.
    /// - Returns: An operation that takes a `NewInput`.
    public func pullback<NewInput>(
        _ block: @escaping @Sendable (NewInput, SyncContinuation<Input>) -> Void
    ) -> Sync<NewInput, Output> {
        .init { newInput, continuation in
            block(
                newInput,
                .init {
                    switch $0 {
                    case .success(let input):
                        self(input) {
                            continuation.resume(with: $0)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
}

extension Sync where Output: Sendable {

    /// Transforms the output with an asynchronous block, which makes the operation asynchronous.
    ///
    /// - Parameter block: Receives the output and returns the new output. It may throw.
    /// - Returns: An ``Async`` operation that produces the transformed output.
    public func map<NewOutput: Sendable>(
        _ block: @escaping @Sendable (Output) async throws -> NewOutput
    ) -> Async<Input, NewOutput> where Input: Sendable {
        .init { input in
            let output = try await self(input)
            return try await block(output)
        }
    }

    /// Adapts the input of the operation to another type, with an asynchronous block that makes the
    /// operation asynchronous.
    ///
    /// - Parameter block: Converts a `NewInput` into the `Input` of this operation. It may throw.
    /// - Returns: An ``Async`` operation that takes a `NewInput`.
    public func pullback<NewInput: Sendable>(
        _ block: @escaping @Sendable (NewInput) async throws -> Input
    ) -> Async<NewInput, Output> where Output: Sendable {
        .init { newInput in
            let input = try await block(newInput)
            return try await self(input)
        }
    }
}

extension Sync where Input: Sendable, Output: Sendable {

    /// Waits after the operation has produced its output, before passing it on.
    ///
    /// - Parameter duration: The time to wait, in nanoseconds.
    /// - Returns: An ``Async`` operation with the same input and output.
    public func sleep(nanoseconds duration: UInt64) -> Async<Input, Output> {
        map {
            try await Task.sleep(nanoseconds: duration)
            return $0
        }
    }

    /// Waits until `deadline`, after the operation has produced its output, before passing it on.
    ///
    /// - Parameters:
    ///   - deadline: The instant to wait for.
    ///   - tolerance: How far from `deadline` the wait may end. With `nil`, the clock decides.
    ///   - clock: The clock that measures the wait.
    /// - Returns: An ``Async`` operation with the same input and output.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
    public func sleep<C>(
        until deadline: C.Instant,
        tolerance: C.Instant.Duration? = nil,
        clock: C = .continuous
    ) -> Async<Input, Output> where C: Clock {
        map {
            try await Task.sleep(
                until: deadline,
                tolerance: tolerance,
                clock: clock
            )
            return $0
        }
    }

    /// Waits for `duration`, after the operation has produced its output, before passing it on.
    ///
    /// - Parameters:
    ///   - duration: How long to wait.
    ///   - tolerance: How far from `duration` the wait may end. With `nil`, the clock decides.
    ///   - clock: The clock that measures the wait.
    /// - Returns: An ``Async`` operation with the same input and output.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, *)
    public func sleep<C>(
        for duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = .continuous
    ) -> Async<Input, Output> where C: Clock {
        map {
            try await Task.sleep(
                for: duration,
                tolerance: tolerance,
                clock: clock
            )
            return $0
        }
    }
}

/// Runs `block` on the main thread and waits for it, whatever the thread that calls.
///
/// From another thread this is a synchronous hop to the main queue, so it can't be used by code that
/// the main thread is itself waiting for (a `DispatchGroup` or a semaphore that is only released by
/// the caller): both would wait for each other. The assertions only call it for short reads and
/// renderings, from the thread of the test.
@_spi(Internals) public func performOnMainThread<R: Sendable>(
    _ block: @MainActor () throws -> R
) rethrows -> R {
    if Thread.isMainThread {
        try MainActor.assumeIsolated(block)
    } else {
        try DispatchQueue.main.sync(execute: block)
    }
}

/// Runs the executors one after the other without ever blocking the caller.
///
/// An executor that completes before it returns hands its result back to the loop, so any number of
/// them run without growing the stack. One that completes later continues the loop from its own
/// callback. Waiting here instead would hide the work from the timeout of the caller, and would
/// deadlock when an executor needs the thread that is waiting.
private final class SyncSequence<Input, Output>: @unchecked Sendable {

    private enum Slot {
        case pending
        case completed(Result<Output, Error>)
        case waiting
        case consumed
    }

    private let syncs: [Sync<Input, Output>]
    private let input: Input
    private let continuation: SyncContinuation<[Output]>

    private var outputs: [Output] = []
    private var index = 0

    init(
        _ syncs: [Sync<Input, Output>],
        input: Input,
        continuation: SyncContinuation<[Output]>
    ) {
        self.syncs = syncs
        self.input = input
        self.continuation = continuation
        self.outputs.reserveCapacity(syncs.count)
    }

    func run() {
        while index < syncs.count {
            let slot = Locked(Slot.pending)

            syncs[index](input) { [self] result in
                // Only the first result of an executor counts.
                let resumesTheLoop = slot.withLock { slot -> Bool in
                    switch slot {
                    case .pending:
                        slot = .completed(result)
                        return false
                    case .waiting:
                        slot = .consumed
                        return true
                    case .completed, .consumed:
                        return false
                    }
                }

                if resumesTheLoop, advance(with: result) {
                    run()
                }
            }

            let inline = slot.withLock { slot -> Result<Output, Error>? in
                guard case .completed(let result) = slot else {
                    slot = .waiting
                    return nil
                }

                slot = .consumed
                return result
            }

            guard let inline else {
                return
            }

            guard advance(with: inline) else {
                return
            }
        }

        continuation.resume(returning: outputs)
    }

    /// - Returns: `true` when the next executor has to run.
    private func advance(with result: Result<Output, Error>) -> Bool {
        switch result {
        case .success(let output):
            outputs.append(output)
            index += 1
            return true
        case .failure(let error):
            continuation.resume(throwing: error)
            return false
        }
    }
}

private final class Locked<Value>: @unchecked Sendable {

    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<R>(_ body: (inout Value) -> R) -> R {
        lock.withLock { body(&value) }
    }
}

extension Array {

    /// Combines the `Sync` values of the array into one that runs them one after another on the same input.
    ///
    /// The outputs come back in the order of the array. A `Sync` that fails is skipped: its error
    /// is dropped instead of being thrown.
    func sequence<Input, Output>() -> Sync<Input, [Output]> where Element == Sync<Input, Output> {
        guard !isEmpty else {
            return Sync { _ in [] }
        }

        return .init { input, continuation in
            SyncSequence(self, input: input, continuation: continuation).run()
        }
    }
}
