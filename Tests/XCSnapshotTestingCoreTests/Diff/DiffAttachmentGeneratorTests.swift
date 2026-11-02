// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("DiffAttachmentGenerator")
struct DiffAttachmentGeneratorTests {

    // MARK: - Strings

    @Test func equalStringsProduceNoAttachment() {
        let generator = StringDiffAttachmentGenerator()

        #expect(generator(from: "same", with: "same") == nil)
    }

    @Test func differentStringsProduceAPatchMessageAndAttachment() throws {
        let generator = StringDiffAttachmentGenerator()

        let attachment = try #require(generator(from: "one\ntwo", with: "one\n2"))

        #expect(attachment.message == "@@ −1,2 +1,2 @@\n\u{2007}one\n−two\n+2")
        let patch = try #require(attachment.attachments.first)
        #expect(attachment.attachments.count == 1)
        #expect(patch.uniformTypeIdentifier == "public.patch-file")
        #expect(patch.payload.map { String(decoding: $0, as: UTF8.self) } == attachment.message)
    }

    @Test func textWithWindowsLineEndingsIsComparedLineByLine() throws {
        // Regression: "\r\n" is a single Character, so the text was never split and was compared as one line.
        let generator = StringDiffAttachmentGenerator()

        let attachment = try #require(generator(from: "one\r\ntwo\r\nthree", with: "one\r\n2\r\nthree"))

        #expect(attachment.message == "@@ −1,3 +1,3 @@\n\u{2007}one\n−two\n+2\n\u{2007}three")
    }

    @Test func textsThatOnlyDifferInTheLineEndingsAreNotTheSame() throws {
        let generator = StringDiffAttachmentGenerator()

        let attachment = try #require(generator(from: "one\r\ntwo", with: "one\ntwo"))

        #expect(attachment.message.hasPrefix("The texts have the same lines"))
        #expect(attachment.attachments.count == 1)
    }

    @Test func textsThatOnlyDifferInTheFormOfAnAccentAreNotTheSame() throws {
        // `String` equality treats the two as equal, but the files are not.
        let generator = StringDiffAttachmentGenerator()
        let composed = "caf\u{E9}"
        let decomposed = "cafe\u{301}"
        #expect(composed == decomposed)

        let attachment = try #require(
            generator(from: StringBytes(rawValue: composed), with: StringBytes(rawValue: decomposed))
        )

        #expect(attachment.message.hasPrefix("The texts have the same lines"))
    }

    // MARK: - Data

    @Test func equalDataProducesNoAttachment() {
        let generator = DataDiffAttachmentGenerator()

        #expect(generator(from: DataBytes(rawValue: Data([1])), with: DataBytes(rawValue: Data([1]))) == nil)
    }

    @Test func dataWithTheSameLengthReportsAGenericMessage() throws {
        let generator = DataDiffAttachmentGenerator()

        let attachment = try #require(
            generator(from: DataBytes(rawValue: Data([1, 2])), with: DataBytes(rawValue: Data([1, 3])))
        )

        #expect(attachment.message == "Expected data to match")
        #expect(attachment.attachments.isEmpty)
    }

    @Test func dataWithDifferentLengthsReportsBothSizes() throws {
        let generator = DataDiffAttachmentGenerator()

        let attachment = try #require(
            generator(from: DataBytes(rawValue: Data([1, 2, 3])), with: DataBytes(rawValue: Data([1])))
        )

        #expect(attachment.message.hasPrefix("Expected "))
        #expect(attachment.message.contains(" to match "))
    }

    // MARK: - Attachments

    @Test func attachmentsDefaultToAGenericTypeIdentifier() {
        let attachment = SnapshotAttachment(uniformTypeIdentifier: nil, name: "n", payload: nil)

        #expect(attachment.uniformTypeIdentifier == "public.data")
        #expect(attachment.name == "n")
        #expect(attachment.payload == nil)
    }

    @Test func attachmentConvenienceInitializersSetTheirTypeIdentifier() {
        #expect(SnapshotAttachment(data: Data()).uniformTypeIdentifier == "public.data")
        #expect(SnapshotAttachment(string: "text").uniformTypeIdentifier == "public.plain-text")
        #expect(SnapshotAttachment(string: "text").payload == Data("text".utf8))
        #expect(SnapshotAttachment(data: Data(), uniformTypeIdentifier: "public.png").name == "")
    }
}
