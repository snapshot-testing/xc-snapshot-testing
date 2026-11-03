// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// The step of a ``Snapshot`` that turns an `Input` into an `Output` that can be serialized.
///
/// ``Sync`` and ``Async`` are the executors that come with the library. `Output` must conform to
/// ``BytesRepresentable`` to be stored and compared.
public protocol SnapshotExecutor<Output>: Sendable {
    associatedtype Input
    associatedtype Output
}

/// A ``Snapshot`` whose executor is a ``Sync`` operation.
public typealias SyncSnapshot<Input, Output: BytesRepresentable> = Snapshot<Sync<Input, Output>>

/// A ``Snapshot`` whose executor is an ``Async`` operation.
public typealias AsyncSnapshot<Input: Sendable, Output: BytesRepresentable> = Snapshot<
    Async<Input, Output>
>

/// A ``SyncSnapshot`` that takes the raw value of its `Output` as input.
///
/// The executor only wraps the input in `Output`, so there is nothing to convert.
public typealias IdentitySyncSnapshot<Output: BytesRepresentable> = SyncSnapshot<Output.RawValue, Output>

/// An ``AsyncSnapshot`` that takes the raw value of its `Output` as input.
///
/// The executor only wraps the input in `Output`, so there is nothing to convert.
public typealias IdentityAsyncSnapshot<Output: BytesRepresentable> = AsyncSnapshot<Output.RawValue, Output>

/// Describes how a value becomes a snapshot, and how a mismatch is reported.
///
/// A snapshot has an executor that produces the output to compare, a generator that describes
/// the difference when the output does not match its reference, and the file extension of the
/// stored references.
public struct Snapshot<Executor: SnapshotExecutor>: Sendable where Executor.Output: BytesRepresentable {

    /// The type the executor takes as input.
    public typealias Input = Executor.Input

    /// The serializable type the executor produces.
    public typealias Output = Executor.Output

    /// The file extension of the stored references, such as `png`.
    ///
    /// With `nil`, the files have no extension.
    public let pathExtension: String?

    /// Describes the difference between the reference and the new output when they do not match.
    public let attachmentGenerator: any DiffAttachmentGenerator<Executor.Output>

    /// Turns the input into the output that is compared with the reference.
    public let executor: Executor

    /// Creates a snapshot.
    ///
    /// - Parameters:
    ///   - pathExtension: The file extension of the stored references, such as `"png"`.
    ///   - attachmentGenerator: Describes the difference when the output does not match.
    ///   - executor: Turns the input into the output to compare.
    ///
    /// ```swift
    /// let snapshot = Snapshot(
    ///     pathExtension: "json",
    ///     attachmentGenerator: StringDiffAttachmentGenerator(),
    ///     executor: Sync { (value: Value) in StringBytes(rawValue: encode(value)) }
    /// )
    /// ```
    public init<AttachmentGenerator>(
        pathExtension: String? = nil,
        attachmentGenerator: AttachmentGenerator,
        executor: Executor
    ) where AttachmentGenerator: DiffAttachmentGenerator<Executor.Output> {
        self.pathExtension = pathExtension
        self.attachmentGenerator = attachmentGenerator
        self.executor = executor
    }

    /// Replaces the executor, and keeps the file extension and the attachment generator.
    ///
    /// - Parameter closure: Receives the current executor and returns the new one, whose output must have the same type.
    /// - Returns: The snapshot with the new executor.
    public func map<NewExecutor: SnapshotExecutor>(
        _ closure: @Sendable (Executor) throws -> NewExecutor
    ) rethrows -> Snapshot<NewExecutor> where NewExecutor.Output == Executor.Output {
        Snapshot<NewExecutor>(
            pathExtension: pathExtension,
            attachmentGenerator: attachmentGenerator,
            executor: try closure(executor)
        )
    }
}

extension IdentitySyncSnapshot where Executor.Output: BytesRepresentable, Executor.Input == Executor.Output.RawValue {

    /// Creates a snapshot whose executor wraps the raw input in `Output`.
    ///
    /// - Parameters:
    ///   - pathExtension: The file extension of the stored references, such as `"png"`.
    ///   - attachmentGenerator: Describes the difference when the output does not match.
    public init<Output: BytesRepresentable, AttachmentGenerator>(
        pathExtension: String?,
        attachmentGenerator: AttachmentGenerator
    ) where AttachmentGenerator: DiffAttachmentGenerator<Output>, Executor == Sync<Output.RawValue, Output> {
        self.init(
            pathExtension: pathExtension,
            attachmentGenerator: attachmentGenerator,
            executor: .init { .init(rawValue: $0) }
        )
    }
}

extension IdentityAsyncSnapshot where Executor.Output: BytesRepresentable, Executor.Input == Executor.Output.RawValue {

    /// Creates a snapshot whose asynchronous executor wraps the raw input in `Output`.
    ///
    /// - Parameters:
    ///   - pathExtension: The file extension of the stored references, such as `"png"`.
    ///   - attachmentGenerator: Describes the difference when the output does not match.
    public init<Output: BytesRepresentable, AttachmentGenerator>(
        pathExtension: String?,
        attachmentGenerator: AttachmentGenerator
    ) where AttachmentGenerator: DiffAttachmentGenerator<Output>, Executor == Async<Output.RawValue, Output> {
        self.init(
            pathExtension: pathExtension,
            attachmentGenerator: attachmentGenerator,
            executor: .init { .init(rawValue: $0) }
        )
    }
}

extension AsyncSnapshot {

    /// Adapts the input of the snapshot to another type.
    ///
    /// ```swift
    /// let snapshot = IdentityAsyncSnapshot<StringBytes>.lines.pullback { (user: User) in
    ///     try await user.summary()
    /// }
    /// ```
    ///
    /// - Parameter closure: Converts a `NewInput` into the input of the executor. It may throw.
    /// - Returns: A snapshot that takes a `NewInput`.
    public func pullback<NewInput: Sendable, Input: Sendable, Output: BytesRepresentable>(
        _ closure: @escaping @Sendable (NewInput) async throws -> Input
    ) -> AsyncSnapshot<NewInput, Output> where Executor == Async<Input, Output> {
        map { executor in
            executor.pullback(closure)
        }
    }
}

extension SyncSnapshot {

    /// Adapts the input of the snapshot to another type.
    ///
    /// - Parameter closure: Converts a `NewInput` into the input of the executor. It may throw.
    /// - Returns: A snapshot that takes a `NewInput`.
    public func pullback<NewInput, Input, Output: BytesRepresentable>(
        _ closure: @escaping @Sendable (NewInput) throws -> Input
    ) -> SyncSnapshot<NewInput, Output> where Executor == Sync<Input, Output> {
        map { executor in
            executor.pullback(closure)
        }
    }

    /// Adapts the input of the snapshot to another type with an asynchronous closure, which makes the snapshot asynchronous.
    ///
    /// - Parameter closure: Converts a `NewInput` into the input of the executor. It may throw.
    /// - Returns: An ``AsyncSnapshot`` that takes a `NewInput`.
    public func pullback<NewInput, Input, Output: BytesRepresentable>(
        _ closure: @escaping @Sendable (NewInput) async throws -> Input
    ) -> AsyncSnapshot<NewInput, Output> where Executor == Sync<Input, Output> {
        map { executor in
            executor.pullback(closure)
        }
    }
}
