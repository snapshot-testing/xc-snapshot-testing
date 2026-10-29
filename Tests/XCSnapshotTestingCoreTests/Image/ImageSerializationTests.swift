#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@MainActor
@Suite("Image serialization")
struct ImageSerializationTests {

    private typealias Factory = ImageFactory

    private func png(of image: SDKImage) throws -> Data {
        try #require(image.pngData())
    }

    // MARK: - ImageBytes

    @Test func imagesRoundTripThroughPNG() throws {
        let original = Factory.image(Factory.rgba8(width: 8, height: 4) { x, _ in (UInt8(x * 30), 10, 200) })
        let serialization = DataSerialization()

        let data = try serialization.serialize(ImageBytes(rawValue: original))
        let restored = try serialization.deserialize(ImageBytes.self, from: data)

        let cgImage = try #require(restored.rawValue.cgImage)
        #expect(cgImage.width == 8)
        #expect(cgImage.height == 4)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]), "the payload is a PNG")
    }

    @Test func undecodableDataIsRejected() {
        #expect(throws: BytesSerializationError.self) {
            try DataSerialization().deserialize(ImageBytes.self, from: Data([1, 2, 3, 4]))
        }
    }

    @Test func imageScaleDefaultsToOne() {
        #expect(DataSerialization().configuration.imageScale == 1)
    }

    @Test func imageScaleCanBeConfigured() throws {
        var serialization = DataSerialization()
        serialization.configuration.imageScale = 2

        let data = try serialization.serialize(ImageBytes(rawValue: Factory.image(Factory.flat(100))))
        let restored = try serialization.deserialize(ImageBytes.self, from: data)

        #expect(serialization.configuration.imageScale == 2)
        #if !os(macOS)
        #expect(restored.rawValue.scale == 2)
        #endif
        #expect(restored.rawValue.cgImage != nil)
    }

    @Test func theImageSnapshotUsesThePNGExtension() {
        #expect(IdentitySyncSnapshot<ImageBytes>.image.pathExtension == "png")
        #expect(SyncSnapshot<SDKImage, ImageBytes>.image.pathExtension == "png")
        #expect(
            SyncSnapshot<SDKImage, ImageBytes>.image(precision: 0.9, perceptualPrecision: 0.9).pathExtension == "png"
        )
    }

    // MARK: - Diff attachments

    @Test func equalImagesProduceNoAttachment() {
        let generator = ImageDiffAttachmentGenerator(precision: 1, perceptualPrecision: 1)
        let image = ImageBytes(rawValue: Factory.image(Factory.flat(100)))

        #expect(generator(from: image, with: image) == nil)
    }

    @Test func differentImagesProduceAMessageAndThreePNGAttachments() throws {
        let generator = ImageDiffAttachmentGenerator(precision: 1, perceptualPrecision: 1)

        let attachment = try #require(
            generator(
                from: ImageBytes(rawValue: Factory.image(Factory.flat(100))),
                with: ImageBytes(rawValue: Factory.image(Factory.flat(200)))
            )
        )

        #expect(attachment.message == "Newly-taken snapshot does not match reference.")
        #expect(attachment.attachments.map(\.name) == ["reference", "failure", "difference"])
        #expect(attachment.attachments.allSatisfy { $0.uniformTypeIdentifier == "public.png" })
        #expect(attachment.attachments.allSatisfy { !($0.payload ?? Data()).isEmpty })
    }

    @Test func theFailureAttachmentCarriesTheNewSnapshot() throws {
        let generator = ImageDiffAttachmentGenerator(precision: 1, perceptualPrecision: 1)

        let attachment = try #require(
            generator(
                from: ImageBytes(rawValue: Factory.image(Factory.flat(100))),
                with: ImageBytes(rawValue: Factory.image(Factory.flat(200)))
            )
        )

        let failure = try #require(attachment.attachments.first { $0.name == "failure" }?.payload)
        let pixel = try #require(Factory.pixel(of: failure))
        #expect(abs(Int(pixel[0]) - 200) <= 8, "the new snapshot is mostly 200 gray, got \(pixel)")
    }

    @Test func attachmentsCanBeCreatedFromImages() throws {
        let attachment = try #require(SnapshotAttachment(image: Factory.image(Factory.flat(10))))

        #expect(attachment.uniformTypeIdentifier == "public.png")
        #expect(attachment.name == "")
        #expect(attachment.payload != nil)
    }
}
#endif
