// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("Serialization")
struct SerializationTests {

    private let serialization = DataSerialization()

    // MARK: - Default representations

    @Test func dataBytesRoundTrip() throws {
        let original = DataBytes(rawValue: Data([0xDE, 0xAD, 0xBE, 0xEF]))

        let data = try serialization.serialize(original)
        let restored = try serialization.deserialize(DataBytes.self, from: data)

        #expect(data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
        #expect(restored.rawValue == original.rawValue)
    }

    @Test func stringBytesRoundTrip() throws {
        let data = try serialization.serialize(StringBytes(rawValue: "héllo\nworld"))

        #expect(String(decoding: data, as: UTF8.self) == "héllo\nworld")
        #expect(try serialization.deserialize(StringBytes.self, from: data).rawValue == "héllo\nworld")
    }

    @Test func stringBytesCanBeWrittenAsALiteral() {
        let bytes: StringBytes = "literal"

        #expect(bytes.rawValue == "literal")
    }

    @Test func stringBytesRejectInvalidUTF8() {
        #expect(throws: BytesSerializationError.self) {
            try serialization.deserialize(StringBytes.self, from: Data([0xFF, 0xFE, 0xFD]))
        }
    }

    // MARK: - Containers

    @Test func readOnlyContainersCannotBeWritten() {
        let container = BytesContainer.readOnly(Data([1]), with: DataSerializationConfiguration())

        #expect(throws: (any Error).self) {
            try container.write(Data([2]))
        }
        #expect((try? container.read()) == Data([1]))
    }

    @Test func writeOnlyContainersCannotBeRead() throws {
        let container = BytesContainer.writeOnly(with: DataSerializationConfiguration())

        #expect(throws: (any Error).self) {
            try container.read()
        }

        try container.write(Data([7]))
        #expect(container.data == Data([7]))
    }

    @Test func writingReplacesThePreviousContents() throws {
        let container = BytesContainer.writeOnly(with: DataSerializationConfiguration())

        try container.write(Data([1, 2]))
        try container.write(Data([3]))

        #expect(container.data == Data([3]))
    }

    // MARK: - Configuration

    private struct PrefixKey: DataSerializationConfigurationKey {
        static let defaultValue = ""
    }

    private struct PrefixedBytes: BytesRepresentable {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(from container: BytesContainer) throws {
            let prefix = container.configuration[PrefixKey.self]
            let text = String(decoding: try container.read(), as: UTF8.self)
            self.rawValue = String(text.dropFirst(prefix.count))
        }

        func serialize(to container: BytesContainer) throws {
            try container.write(Data((container.configuration[PrefixKey.self] + rawValue).utf8))
        }
    }

    @Test func configurationKeysFallBackToTheirDefaultValue() {
        #expect(DataSerializationConfiguration()[PrefixKey.self] == "")
    }

    @Test func serializationConfigurationReachesTheBytesRepresentable() throws {
        var serialization = DataSerialization()
        serialization.configuration[PrefixKey.self] = ">> "

        let data = try serialization.serialize(PrefixedBytes(rawValue: "value"))

        #expect(String(decoding: data, as: UTF8.self) == ">> value")
        #expect(try serialization.deserialize(PrefixedBytes.self, from: data).rawValue == "value")
    }
}
