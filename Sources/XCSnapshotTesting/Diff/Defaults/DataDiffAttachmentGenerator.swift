// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Compares two blobs of data for equality.
///
/// It only reports that the data differ. It does not show what changed.
/// Use ``DiffAttachmentGenerator/data`` to get one.
public struct DataDiffAttachmentGenerator: DiffAttachmentGenerator {

    /// Creates a generator.
    public init() {}

    /// Compares the data.
    ///
    /// - Parameters:
    ///   - reference: The stored data.
    ///   - diffable: The data produced by the current run.
    /// - Returns: A message saying the data differ, or `nil` if they are equal.
    public func callAsFunction(
        from reference: DataBytes,
        with diffable: DataBytes
    ) -> DiffAttachment? {
        guard reference.rawValue != diffable.rawValue else {
            return nil
        }

        let message =
            reference.rawValue.count == diffable.rawValue.count
            ? "Expected data to match"
            : "Expected \(diffable.rawValue) to match \(reference.rawValue)"

        return DiffAttachment(
            message: message,
            attachments: []
        )
    }
}

extension DiffAttachmentGenerator where Self == DataDiffAttachmentGenerator {

    /// A generator that compares data for equality.
    public static var data: Self {
        DataDiffAttachmentGenerator()
    }
}
