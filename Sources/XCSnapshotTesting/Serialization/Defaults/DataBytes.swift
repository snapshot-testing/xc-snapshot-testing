// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// A ``BytesRepresentable`` that wraps `Data`.
public struct DataBytes: BytesRepresentable {

    /// The wrapped data.
    public let rawValue: Data

    /// Creates an instance with the contents of a read-only container.
    ///
    /// - Parameter container: The container to read from.
    /// - Throws: An error if `container` is not in read mode.
    public init(from container: BytesContainer) throws {
        self.rawValue = try container.read()
    }

    /// Creates an instance that wraps the given data.
    ///
    /// - Parameter rawValue: The data to wrap.
    public init(rawValue: Data) {
        self.rawValue = rawValue
    }

    /// Writes the wrapped data to a write-only container.
    ///
    /// - Parameter container: The container to write to.
    /// - Throws: An error if `container` is not in write mode.
    public func serialize(to container: BytesContainer) throws {
        try container.write(rawValue)
    }
}

extension IdentitySyncSnapshot<DataBytes> {
    /// A snapshot strategy for comparing raw data based on equality.
    public static let data = IdentitySyncSnapshot<DataBytes>(
        pathExtension: nil,
        attachmentGenerator: .data
    )
}
