// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

/// The format of the stored images is tested with generated pixels, decoding the PNG that ends up on disk.
@MainActor
@Suite("Image format")
struct ImageFormatTests {

    private typealias Factory = ImageFactory

    private func decode(_ data: Data) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func serialized(_ bytes: ImageBytes) throws -> CGImage {
        try decode(DataSerialization().serialize(bytes))
    }

    private func flatImage() -> SDKImage {
        Factory.image(Factory.flat(100))
    }

    private nonisolated static let formats: [ImageFormat] = [
        .sRGB,
        .displayP3,
        ImageFormat(colorSpace: .sRGB, bitDepth: .sixteen),
        ImageFormat(colorSpace: .displayP3, bitDepth: .sixteen),
    ]

    // MARK: - Description

    @Test func theDefaultFormatIsSRGBWithEightBits() {
        #expect(ImageFormat() == .sRGB)
        #expect(ImageFormat.sRGB == ImageFormat(colorSpace: .sRGB, bitDepth: .eight))
        #expect(ImageFormat.displayP3 == ImageFormat(colorSpace: .displayP3, bitDepth: .eight))
    }

    @Test(arguments: formats)
    func thePixelLayoutFollowsTheFormat(format: ImageFormat) {
        let isSixteen = format.bitDepth == .sixteen

        #expect(format.bitsPerComponent == (isSixteen ? 16 : 8))
        #expect(format.bytesPerPixel == (isSixteen ? 8 : 4))
        #expect(format.needsExtendedRange == (format != .sRGB))
    }

    @Test func aFormatDescribesTheImageItIsReadFrom() {
        #expect(ImageFormat(describing: Factory.flat(10)) == .sRGB)
        #expect(
            ImageFormat(describing: Factory.rgba8(colorSpace: Factory.displayP3) { _, _ in (0, 255, 0) }) == .displayP3
        )
        #expect(ImageFormat(describing: Factory.rgba16()) == ImageFormat(colorSpace: .sRGB, bitDepth: .sixteen))
        #expect(ImageFormat(describing: Factory.grayscale8()) == .sRGB)
    }

    // MARK: - Encoding

    @Test(arguments: formats)
    func theStoredPNGKeepsTheFormat(format: ImageFormat) throws {
        let data = try #require(format.pngData(Factory.flat(100)))
        let image = try decode(data)

        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]), "the payload is a PNG")
        #expect(image.bitsPerComponent == format.bitsPerComponent)
        #expect(ImageFormat(describing: image) == format)
    }

    @Test func theConversionKeepsOrClipsWideGamutColorsAccordingToTheFormat() throws {
        let p3 = Factory.rgba8(colorSpace: Factory.displayP3) { _, _ in (0, 255, 0) }

        let kept = try decode(try #require(ImageFormat.displayP3.pngData(p3)))
        let clipped = try decode(try #require(ImageFormat.sRGB.pngData(p3)))

        #expect(ImageFormat(describing: kept) == .displayP3)
        #expect(ImageFormat(describing: clipped) == .sRGB)
    }

    // MARK: - Environment

    @Test func imagesFollowThePlatformWithoutAFormat() {
        #expect(SnapshotEnvironment.current.imageFormat == nil)
        #expect(ImageBytes(rawValue: flatImage()).format == nil)
    }

    @Test func theEnvironmentSetsTheFormatOfRecordedImages() throws {
        for format in Self.formats {
            let image = try withTestingEnvironment {
                $0.imageFormat = format
            } operation: {
                try serialized(ImageBytes(rawValue: flatImage()))
            }

            #expect(ImageFormat(describing: image) == format)
        }

        #expect(SnapshotEnvironment.current.imageFormat == nil, "the override ends with the operation")
    }

    @Test func theFormatOfTheImageWinsOverTheEnvironment() throws {
        let image = try withTestingEnvironment {
            $0.imageFormat = .displayP3
        } operation: {
            try serialized(ImageBytes(rawValue: flatImage(), format: .sRGB))
        }

        #expect(ImageFormat(describing: image) == .sRGB)
    }

    // MARK: - Strategies

    @Test func aSyncStrategyStampsItsFormatOnTheImages() async throws {
        let snapshot = IdentitySyncSnapshot<ImageBytes>.image.imageFormat(.displayP3)

        let output = try await snapshot.executor(flatImage())

        #expect(output.format == .displayP3)
        #expect(snapshot.pathExtension == "png")
    }

    @Test func anAsyncStrategyStampsItsFormatAndDrawsInIt() async throws {
        final class Box: @unchecked Sendable { var format: ImageFormat? }
        let seen = Box()

        let snapshot = AsyncSnapshot<SDKImage, ImageBytes>(
            pathExtension: "png",
            attachmentGenerator: ImageDiffAttachmentGenerator(precision: 1, perceptualPrecision: 1),
            executor: Async(SDKImage.self) { image in
                seen.format = SnapshotEnvironment.current.imageFormat
                return ImageBytes(rawValue: image)
            }
        )
        .imageFormat(ImageFormat(colorSpace: .displayP3, bitDepth: .sixteen))

        let output = try await snapshot.executor(flatImage())

        #expect(output.format == ImageFormat(colorSpace: .displayP3, bitDepth: .sixteen))
        #expect(seen.format == ImageFormat(colorSpace: .displayP3, bitDepth: .sixteen), "the renderer sees the format")
        #expect(SnapshotEnvironment.current.imageFormat == nil)
    }

    // MARK: - Comparison

    // AppKit hands the pixels of an image over in 8-bit sRGB, so the comparison cannot go further there.
    #if !os(macOS)
    @Test func aWideGamutReferenceIsComparedInDisplayP3() {
        // Both greens are outside of sRGB and clip to the same color there, which would hide the difference.
        let reference = Factory.image(Factory.rgba8(colorSpace: Factory.displayP3) { _, _ in (0, 255, 0) })
        let sameColor = Factory.image(Factory.rgba8(colorSpace: Factory.displayP3) { _, _ in (0, 255, 0) })
        let otherColor = Factory.image(Factory.rgba8(colorSpace: Factory.displayP3) { _, _ in (13, 255, 0) })

        #expect(reference.compare(sameColor, precision: 1, perceptualPrecision: 1) == nil)
        #expect(reference.compare(otherColor, precision: 1, perceptualPrecision: 1) != nil)
    }

    @Test func aSixteenBitReferenceNoticesAStepSmallerThanEightBits() {
        let reference = Factory.image(Factory.rgba16(value: 0x8000))
        let sameValue = Factory.image(Factory.rgba16(value: 0x8000))
        let nextStep = Factory.image(Factory.rgba16(value: 0x8001))

        #expect(reference.compare(sameValue, precision: 1, perceptualPrecision: 1) == nil)
        #expect(reference.compare(nextStep, precision: 1, perceptualPrecision: 1) != nil)
    }

    @Test func aReferenceInTheStandardFormatKeepsBeingComparedInSRGB() {
        let reference = Factory.image(Factory.flat(100))

        #expect(reference.compare(Factory.image(Factory.flat(100)), precision: 1, perceptualPrecision: 1) == nil)
        #expect(reference.compare(Factory.image(Factory.flat(101)), precision: 1, perceptualPrecision: 1) != nil)
    }
    #endif
}
#endif
