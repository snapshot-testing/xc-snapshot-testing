// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// A value that can be written to and read from a ``BytesContainer``.
///
/// Snapshot outputs conform to it so they can be stored as references and compared.
/// ``DataBytes``, ``StringBytes`` and ``ImageBytes`` are the conforming types that come with the library.
public protocol BytesRepresentable: Sendable {

    /// The value that the type wraps, such as a `String`, a `Data` or an image.
    associatedtype RawValue

    /// The underlying value used for serialization and deserialization.
    /// This can be any type, such as `String`, `Data`, or `UIImage`.
    var rawValue: RawValue { get }

    /// Creates an instance that wraps `rawValue`.
    ///
    /// - Parameter rawValue: The value to wrap.
    init(rawValue: RawValue)

    /// Creates an instance from the data in a container.
    ///
    /// - Parameter container: A container in read mode.
    /// - Throws: An error if the data cannot be read.
    init(from container: BytesContainer) throws

    /// Writes the instance to a container.
    ///
    /// - Parameter container: A container in write mode.
    /// - Throws: An error if the instance cannot be written.
    func serialize(to container: BytesContainer) throws
}
