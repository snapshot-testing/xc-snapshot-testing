// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// An asynchronous operation from an `Input` to an `Output`.
///
/// It is the executor of the snapshots that run asynchronously. Operations are composed with `map`,
/// `pullback` and `sleep`.
public struct Async<Input: Sendable, Output: Sendable>: SnapshotExecutor {

    fileprivate let block: @Sendable (Input) async throws -> Output

    /// Initializes an `Async` instance with a specific input type and block.
    ///
    /// - Parameters:
    ///   - inputType: The type of input value. This is inferred from the block if not explicitly provided.
    ///   - block: An asynchronous closure that takes an input value and returns an output value, potentially throwing an error.
    public init(
        _ inputType: Input.Type = Input.self,
        _ block: @escaping @Sendable (Input) async throws -> Output
    ) {
        self.block = block
    }

    /// Runs the operation.
    ///
    /// - Parameter input: The input of the operation.
    /// - Returns: The output of the operation.
    /// - Throws: An error thrown by the operation.
    public func callAsFunction(_ input: Input) async throws -> Output {
        try await block(input)
    }
}

extension Async {

    /// Transforms the output with an asynchronous block.
    ///
    /// - Parameter block: Receives the output and returns the new output. It may throw.
    /// - Returns: An operation that produces the transformed output.
    public func map<NewOutput: Sendable>(
        _ block: @escaping @Sendable (Output) async throws -> NewOutput
    ) -> Async<Input, NewOutput> {
        .init { input in
            let output = try await self(input)
            return try await block(output)
        }
    }

    /// Adapts the input of the operation to another type.
    ///
    /// - Parameter block: Converts a `NewInput` into the `Input` of this operation. It may throw.
    /// - Returns: An operation that takes a `NewInput`.
    public func pullback<NewInput: Sendable>(
        _ block: @escaping @Sendable (NewInput) async throws -> Input
    ) -> Async<NewInput, Output> {
        .init { newInput in
            let input = try await block(newInput)
            return try await self(input)
        }
    }
}

extension Async {

    /// Waits after the operation has produced its output, before passing it on.
    ///
    /// - Parameter duration: The time to wait, in nanoseconds.
    public func sleep(nanoseconds duration: UInt64) -> Async<Input, Output> {
        guard duration > .zero else {
            return self
        }

        return map {
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
