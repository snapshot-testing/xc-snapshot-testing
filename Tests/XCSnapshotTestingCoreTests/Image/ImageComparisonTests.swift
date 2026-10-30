#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import CoreImage
import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

/// Image comparison is tested with generated pixels, so the expectations are exact and independent of
/// how the system renders text, controls or symbols.
@MainActor
@Suite("Image comparison")
struct ImageComparisonTests {

    private typealias Factory = ImageFactory

    private func solid(_ value: UInt8) -> SDKImage {
        Factory.image(Factory.flat(value))
    }

    private func gradient(
        in colorSpace: CGColorSpace = Factory.sRGB,
        nudging nudged: (x: Int, y: Int)? = nil
    ) -> CGImage {
        Factory.rgba8(colorSpace: colorSpace) { x, y in
            let isNudged = nudged.map { $0.x == x && $0.y == y } ?? false
            return (UInt8(x * 16), UInt8(y * 16), isNudged ? 112 : 100)
        }
    }

    // MARK: - Exact comparison

    @Test func identicalImagesMatch() {
        #expect(solid(100).compare(solid(100), precision: 1, perceptualPrecision: 1) == nil)
    }

    @Test func differentSizesAreReported() throws {
        let small = Factory.image(Factory.flat(100, width: 8, height: 8))
        let large = Factory.image(Factory.flat(100, width: 16, height: 16))

        let message = try #require(small.compare(large, precision: 1, perceptualPrecision: 1))

        #expect(message.hasPrefix("Newly-taken snapshot@"))
        #expect(message.contains("does not match reference@"))
    }

    @Test func anyDifferenceFailsWhenPrecisionIsOne() throws {
        let message = try #require(solid(100).compare(solid(101), precision: 1, perceptualPrecision: 1))

        #expect(message == "Newly-taken snapshot does not match reference.")
    }

    @Test func aSmallFractionOfDifferentPixelsIsToleratedByPixelPrecision() {
        let reference = Factory.image(gradient())
        let snapshot = Factory.image(gradient(nudging: (3, 3)))

        #expect(reference.compare(snapshot, precision: 0.95, perceptualPrecision: 1) == nil)
    }

    @Test func pixelPrecisionReportsTheActualPrecision() throws {
        let reference = Factory.image(gradient())
        let snapshot = Factory.image(gradient(nudging: (3, 3)))

        let message = try #require(reference.compare(snapshot, precision: 0.9999, perceptualPrecision: 1))

        #expect(message.hasPrefix("Actual image precision "))
        #expect(message.hasSuffix(" is less than required 0.9999"))
    }

    // MARK: - Perceptual comparison

    @Test func perceptuallyImperceptibleDifferencesPass() {
        #expect(solid(120).compare(solid(121), precision: 1, perceptualPrecision: 0.99) == nil)
    }

    @Test func perceptualComparisonFailsOnRealDifferences() throws {
        let message = try #require(solid(100).compare(solid(200), precision: 1, perceptualPrecision: 0.99))

        #expect(message.contains("The percentage of pixels that match"))
        #expect(message.contains("The lowest perceptual color precision"))
    }

    @Test func aSingleStepInDarkTonesIsWithinTheDefaultPerceptualTolerance() {
        // Regression: with color management disabled, one 8-bit step at black measured a delta of 3.54
        // instead of 0.27, failing `perceptualPrecision: 0.99` on imperceptible anti-aliasing.
        for base in [UInt8(0), 4, 16, 24, 128, 215] {
            #expect(
                solid(base).compare(solid(base + 1), precision: 1, perceptualPrecision: 0.99) == nil,
                "base \(base)"
            )
        }
    }

    @Test func largerStepsAreStillDetected() {
        #expect(solid(128).compare(solid(136), precision: 1, perceptualPrecision: 0.99) != nil)
    }

    @Test func imagesInDifferentColorSpacesAreComparedByTheirColors() {
        // Regression: a Display P3 reference against an sRGB snapshot used to report a difference on
        // every pixel, even for the same colors, because the originals were compared unconverted.
        let reference = Factory.image(gradient(in: Factory.displayP3))

        let snapshot = Factory.image(redrawn(gradient(in: Factory.displayP3), into: Factory.sRGB, nudging: (7, 7)))

        #expect(reference.compare(snapshot, precision: 0.98, perceptualPrecision: 0.98) == nil)
    }

    @Test func aRealChangeIsStillDetectedAcrossColorSpaces() {
        let reference = Factory.image(gradient(in: Factory.displayP3))
        let snapshot = Factory.image(redrawn(gradient(in: Factory.displayP3), into: Factory.sRGB, fillingTopLeft: 8))

        #expect(reference.compare(snapshot, precision: 0.98, perceptualPrecision: 0.98) != nil)
    }

    // MARK: - The two ways to measure the difference

    /// Machines without a GPU (virtual machines, simulators on CI) cannot use Metal, so the comparison
    /// falls back to reading the difference pixel by pixel on the CPU. Both ways must agree.
    @Test(arguments: [true, false])
    func oneStepAtAnyToneIsWithinTheToleranceWhetherOrNotMetalIsUsed(usesMetal: Bool) {
        for base in [UInt8(0), 4, 16, 24, 128, 215] {
            let reference = CIImage(cgImage: Factory.flat(base))
            let snapshot = CIImage(cgImage: Factory.flat(base + 1))

            #expect(
                reference.perceptuallyCompare(
                    snapshot,
                    pixelPrecision: 1,
                    perceptualPrecision: 0.99,
                    usesMetal: usesMetal
                ) == nil,
                "base \(base), metal: \(usesMetal)"
            )
        }
    }

    @Test(arguments: [true, false])
    func aRealDifferenceIsReportedWhetherOrNotMetalIsUsed(usesMetal: Bool) throws {
        let reference = CIImage(cgImage: Factory.flat(100))
        let snapshot = CIImage(cgImage: Factory.flat(200))

        let message = try #require(
            reference.perceptuallyCompare(
                snapshot,
                pixelPrecision: 1,
                perceptualPrecision: 0.99,
                usesMetal: usesMetal
            )
        )

        #expect(message.contains("The percentage of pixels that match"))
        #expect(message.contains("The lowest perceptual color precision"))
    }

    @Test(arguments: [true, false])
    func theShareOfDifferentPixelsIsMeasuredWhetherOrNotMetalIsUsed(usesMetal: Bool) throws {
        let reference = CIImage(cgImage: Factory.rgba8(width: 10, height: 10) { _, _ in (100, 100, 100) })
        let snapshot = CIImage(
            cgImage: Factory.rgba8(width: 10, height: 10) { x, _ in x < 3 ? (250, 40, 40) : (100, 100, 100) }
        )

        let message = try #require(
            reference.perceptuallyCompare(
                snapshot,
                pixelPrecision: 0.9,
                perceptualPrecision: 0.99,
                usesMetal: usesMetal
            )
        )

        // Three of the ten columns changed, so about 70% of the pixels still match.
        #expect(message.contains("The percentage of pixels that match 0.7"), "metal: \(usesMetal), \(message)")
    }

    // MARK: - Pixel formats

    @Test func grayscaleReferencesDoNotCrashTheComparison() {
        let reference = Factory.image(Factory.grayscale8(value: 128))
        let snapshot = solid(128)

        _ = reference.compare(snapshot, precision: 1, perceptualPrecision: 1)
        _ = reference.compare(solid(10), precision: 1, perceptualPrecision: 0.99)
    }

    @Test func sixteenBitReferencesDoNotCrashTheComparison() {
        let reference = Factory.image(Factory.rgba16())

        _ = reference.compare(solid(128), precision: 1, perceptualPrecision: 1)
        _ = reference.compare(solid(10), precision: 0.9, perceptualPrecision: 0.9)
    }

    // MARK: - Difference image

    @Test(arguments: [0, 1, 2])
    func theDifferenceImageKeepsTheSizeOfTheInputs(format: Int) throws {
        let reference =
            switch format {
            case 0: Factory.image(Factory.flat(100))
            case 1: Factory.image(Factory.grayscale8(value: 100))
            default: Factory.image(Factory.rgba16())
            }

        let difference = reference.substract(solid(200))

        let png = try #require(difference.pngData())
        let cgImage = try #require(difference.cgImage)
        #expect(!png.isEmpty)
        #expect(cgImage.width == 16)
        #expect(cgImage.height == 16)
    }

    // MARK: - Helpers

    /// Redraws `image` into `colorSpace`, optionally nudging one pixel or filling a corner square.
    private func redrawn(
        _ image: CGImage,
        into colorSpace: CGColorSpace,
        nudging nudged: (x: Int, y: Int)? = nil,
        fillingTopLeft squareSize: Int = 0
    ) -> CGImage {
        let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        if let nudged {
            context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.45, 0.45, 0.46, 1])!)
            context.fill(CGRect(x: nudged.x, y: nudged.y, width: 1, height: 1))
        }

        if squareSize > 0 {
            context.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 0, 0, 1])!)
            context.fill(CGRect(x: 0, y: 0, width: squareSize, height: squareSize))
        }

        return context.makeImage()!
    }
}
#endif
