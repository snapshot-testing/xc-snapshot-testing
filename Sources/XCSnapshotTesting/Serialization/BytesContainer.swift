// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Holds the bytes of a snapshot while it is read or written.
///
/// A container is either read-only or write-only. It also carries the configuration that applies to
/// the serialization, such as the scale of images.
public struct BytesContainer: Sendable {

    /// What the container allows: reading the data, or writing it.
    private enum OperationMode {
        case read
        case write
    }

    /// The error thrown when reading a write-only container or writing a read-only one.
    private struct OperationNotAllowed: Error {
        fileprivate init() {}
    }

    /// The data of the container, behind a lock, shared by all copies of the container.
    fileprivate class State: @unchecked Sendable {
        var data: Data {
            get { lock.withLock { _data } }
            set { lock.withLock { _data = newValue } }
        }

        private let lock = NSLock()
        private var _data: Data

        init(_ data: Data) {
            self._data = data
        }
    }

    // MARK: - Public properties

    /// The data serialization configuration used by this container.
    ///
    /// Defines how data will be serialized/deserialized, including options like image scaling
    /// or formatting.
    public let configuration: DataSerializationConfiguration

    // MARK: - Internal properties

    var data: Data {
        state.data
    }

    // MARK: - Private properties

    private let operationMode: OperationMode
    private let state: State

    // MARK: - Init

    private init(
        _ operationMode: OperationMode,
        data: Data,
        with configuration: DataSerializationConfiguration
    ) {
        self.operationMode = operationMode
        self.state = .init(data)
        self.configuration = configuration
    }

    // MARK: - Static internal methods

    /// Creates a read-only container initialized with existing data.
    ///
    /// - Parameter data: The binary data to store in the container.
    /// - Parameter configuration: The serialization configuration to use.
    /// - Returns: A read-only `BytesContainer` instance.
    static func readOnly(
        _ data: Data,
        with configuration: DataSerializationConfiguration
    ) -> BytesContainer {
        BytesContainer(
            .read,
            data: data,
            with: configuration
        )
    }

    /// Creates a write-only container for storing new data.
    ///
    /// - Parameter configuration: The serialization configuration to use.
    /// - Returns: A write-only `BytesContainer` instance.
    static func writeOnly(
        with configuration: DataSerializationConfiguration
    ) -> BytesContainer {
        BytesContainer(
            .write,
            data: Data(),
            with: configuration
        )
    }

    // MARK: - Public methods

    /// Retrieves data stored in the container.
    ///
    /// - Returns: The stored `Data` object.
    /// - Throws: An `OperationNotAllowed` error if the container is not in read mode.
    public func read() throws -> Data {
        guard case .read = operationMode else {
            throw OperationNotAllowed()
        }

        return state.data
    }

    /// Writes data to the container.
    ///
    /// - Parameter data: The data to store.
    /// - Throws: An `OperationNotAllowed` error if the container is not in write mode.
    public func write(_ data: Data) throws {
        guard case .write = operationMode else {
            throw OperationNotAllowed()
        }

        state.data = data
    }
}
