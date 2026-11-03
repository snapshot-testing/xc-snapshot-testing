// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// A message and files that describe how a new output differs from its reference.
///
/// Test reports show the message and attach the files, such as a diff image.
public struct DiffAttachment: Sendable {

    /// A short description of the difference, for example `Image differs: 1,304 pixels modified (3% of total).`
    public let message: String

    /// Files that illustrate the difference, such as a diff image.
    public let attachments: [SnapshotAttachment]

    /// Creates a diff attachment.
    ///
    /// - Parameters:
    ///   - message: A short description of the difference.
    ///   - attachments: Files that illustrate the difference.
    public init(message: String, attachments: [SnapshotAttachment]) {
        self.message = message
        self.attachments = attachments
    }
}

/// Compares a new output with its reference and describes how they differ.
///
/// A generator returns `nil` when the values are equivalent, and a ``DiffAttachment`` otherwise.
/// ``Snapshot`` calls it to build the failure of a mismatch.
///
/// ```swift
/// struct LengthDiffAttachmentGenerator: DiffAttachmentGenerator {
///     func callAsFunction(from reference: StringBytes, with diffable: StringBytes) -> DiffAttachment? {
///         guard reference.rawValue.count != diffable.rawValue.count else { return nil }
///         return DiffAttachment(message: "The length changed.", attachments: [])
///     }
/// }
/// ```
public protocol DiffAttachmentGenerator<Value>: Sendable {

    /// The type of the values being compared.
    associatedtype Value: Sendable

    /// Compares the reference with a new value.
    ///
    /// - Parameters:
    ///   - reference: The stored value.
    ///   - diffable: The value produced by the current run.
    /// - Returns: A description of the difference, or `nil` if the values are equivalent.
    func callAsFunction(
        from reference: Value,
        with diffable: Value
    ) -> DiffAttachment?
}
