// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

extension SyncSnapshot where Output == StringBytes {
    /// A snapshot strategy that captures a value's textual description from `String`'s
    /// `init(describing:)` initializer.
    ///
    /// ``` swift
    /// try assert(of: user, as: .description)
    /// ```
    ///
    /// Records:
    ///
    /// ```
    /// User(bio: "Blobbed around the world.", id: 1, name: "Blobby")
    /// ```
    public static var description: SyncSnapshot<Input, Output> {
        IdentitySyncSnapshot.lines.pullback {
            String(describing: $0)
        }
    }
}

extension SyncSnapshot where Output == StringBytes {
    /// A snapshot strategy for comparing any structure based on their JSON representation.
    ///
    /// This strategy serializes the input value into a JSON-formatted string using
    /// `JSONSerialization` with the following options:
    /// - `.prettyPrinted` for human-readable formatting
    /// - `.sortedKeys` to ensure consistent key ordering
    /// - `.fragmentsAllowed` for partial JSON outputs
    ///
    /// The result is a `StringBytes` snapshot containing the JSON-encoded data.
    ///
    /// - Available on: macOS 10.13+, watchOS 4.0+, tvOS 11.0+
    /// - Example: `assert(of: user, as: .json)`
    public static var json: SyncSnapshot<Input, Output> {
        let options: JSONSerialization.WritingOptions = [
            .prettyPrinted,
            .sortedKeys,
            .fragmentsAllowed,
        ]

        let snapshot = IdentitySyncSnapshot.lines.pullback { (data: Input) in
            // Writing an object that is not JSON raises an Objective-C exception, which Swift cannot
            // catch and which aborts the whole test process. The object is checked inside an array
            // so that a fragment (a string, a number) is judged by its own value.
            guard JSONSerialization.isValidJSONObject([data]) else {
                throw InvalidJSONObjectError(type: type(of: data))
            }

            return try String(
                decoding: JSONSerialization.data(
                    withJSONObject: data,
                    options: options
                ),
                as: UTF8.self
            )
        }

        return .init(
            pathExtension: "json",
            attachmentGenerator: snapshot.attachmentGenerator,
            executor: snapshot.executor
        )
    }
}

struct InvalidJSONObjectError: Error, LocalizedError, CustomStringConvertible {

    let type: Any.Type

    var description: String {
        "\(type) can't be written as JSON: it holds a value that JSON has no representation for, "
            + "such as a date, NaN or infinity, a dictionary whose keys are not strings, or a custom type."
    }

    var errorDescription: String? { description }
}
