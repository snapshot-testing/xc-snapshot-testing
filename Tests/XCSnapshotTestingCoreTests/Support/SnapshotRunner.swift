import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

/// Runs the executor of a snapshot strategy, returning the raw value it produces.
enum SnapshotRunner {

    private final class Box<Value>: @unchecked Sendable {
        var result: Result<Value, Error>?
    }

    static func run<Input, Output: BytesRepresentable>(
        _ snapshot: SyncSnapshot<Input, Output>,
        _ input: Input
    ) throws -> Output.RawValue {
        try run(snapshot.executor, input).rawValue
    }

    static func run<Input, Output>(_ executor: Sync<Input, Output>, _ input: Input) throws -> Output {
        let box = Box<Output>()
        let group = DispatchGroup()

        group.enter()
        executor(input) {
            box.result = $0
            group.leave()
        }
        group.wait()

        return try #require(box.result).get()
    }

    static func run<Input: Sendable, Output: BytesRepresentable>(
        _ snapshot: AsyncSnapshot<Input, Output>,
        _ input: Input
    ) async throws -> Output.RawValue {
        try await snapshot.executor(input).rawValue
    }
}
