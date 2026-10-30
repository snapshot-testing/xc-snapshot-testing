// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Foundation
import QuartzCore
import Testing

#if os(macOS)
import AppKit
#endif

@_spi(Internals) @testable import XCSnapshotTesting

/// The strategies that draw without needing a window: they are checked on the pixels they produce.
@MainActor
@Suite("Image strategies")
struct ImageStrategiesTests {

    private func pixels(_ image: ImageBytes) throws -> (png: Data, size: CGSize) {
        let png = try #require(image.rawValue.pngData())
        let cgImage = try #require(image.rawValue.cgImage)
        return (png, CGSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - CGPath

    @Test func aPathIsDrawnIntoAnImageTheSizeOfItsBounds() throws {
        let path = CGPath(ellipseIn: CGRect(x: 5, y: 5, width: 20, height: 20), transform: nil)

        let output = try SnapshotRunner.run(SyncSnapshot<CGPath, ImageBytes>.image, path)

        let (png, size) = try pixels(ImageBytes(rawValue: output))
        #expect(size.width == 20)
        #expect(size.height == 20)
        #expect(ImageFactory.pixel(of: png, x: 10, y: 10)?[3] == 255, "the center is filled")
        #expect(ImageFactory.pixel(of: png, x: 0, y: 0)?[3] == 0, "the corner is outside the ellipse")
    }

    @Test func aPathCanBeDrawnWithAnotherMode() throws {
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: 10, height: 10), transform: nil)

        let output = try SnapshotRunner.run(SyncSnapshot<CGPath, ImageBytes>.image(drawingMode: .stroke), path)

        let (png, size) = try pixels(ImageBytes(rawValue: output))
        #expect(size == CGSize(width: 10, height: 10))
        #expect(ImageFactory.pixel(of: png, x: 5, y: 5)?[3] == 0, "stroking leaves the inside empty")
    }

    private func samplePath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addQuadCurve(to: CGPoint(x: 10, y: 10), control: CGPoint(x: 12, y: 5))
        path.addCurve(to: CGPoint(x: 0, y: 10), control1: CGPoint(x: 8, y: 12), control2: CGPoint(x: 2, y: 12))
        path.closeSubpath()
        path.move(to: CGPoint(x: 20.12345, y: 20))
        return path
    }

    @Test func pathElementsAreDescribedOnePerLine() throws {
        let description = try SnapshotRunner.run(SyncSnapshot<CGPath, StringBytes>.elementsDescription, samplePath())

        // `Close` is followed by a space, because every element is written as "<name> <points>".
        #expect(
            description
                == [
                    "MoveTo (0.0, 0.0)",
                    "LineTo (10.0, 0.0)",
                    "QuadCurveTo (12.0, 5.0) (10.0, 10.0)",
                    "CurveTo (8.0, 12.0) (2.0, 12.0) (0.0, 10.0)",
                    "Close ",
                    "",
                    "MoveTo (20.123, 20.0)",
                    "",
                ].joined(separator: "\n")
        )
    }

    @Test func pathElementsCanBeFormattedWithACustomNumberFormatter() throws {
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."
        formatter.maximumFractionDigits = 0

        let description = try SnapshotRunner.run(
            SyncSnapshot<CGPath, StringBytes>.elementsDescription(numberFormatter: formatter),
            samplePath()
        )

        #expect(description.hasPrefix("MoveTo (0, 0)\nLineTo (10, 0)\n"))
        #expect(description.hasSuffix("MoveTo (20, 20)\n"))
    }

    // MARK: - CALayer

    @Test func aLayerIsRenderedIntoAnImage() throws {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 20, height: 10)
        layer.backgroundColor = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)

        let output = try SnapshotRunner.run(SyncSnapshot<CALayer, ImageBytes>.image, layer)

        // The size is checked in points: on iOS the image is rendered at the scale of the screen.
        let png = try #require(output.pngData())
        let center = try #require(ImageFactory.pixel(of: png, x: 5, y: 2))
        #expect(output.size == CGSize(width: 20, height: 10))
        #expect(center[0] > 200 && center[1] < 60 && center[2] < 60, "the layer is red, got \(center)")
    }

    #if os(macOS)
    // MARK: - NSBezierPath

    @Test func aBezierPathIsDrawnIntoAnImage() throws {
        let path = NSBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 20, height: 20))

        let output = try SnapshotRunner.run(SyncSnapshot<NSBezierPath, ImageBytes>.image, path)

        let (png, size) = try pixels(ImageBytes(rawValue: output))
        #expect(size == CGSize(width: 20, height: 20))
        #expect(ImageFactory.pixel(of: png, x: 10, y: 10)?[3] == 255)
        #expect(ImageFactory.pixel(of: png, x: 0, y: 0)?[3] == 0)
    }

    @Test func bezierPathElementsAreDescribedOnePerLine() throws {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.line(to: CGPoint(x: 10, y: 0))
        path.curve(
            to: CGPoint(x: 10, y: 10),
            controlPoint1: CGPoint(x: 12, y: 2),
            controlPoint2: CGPoint(x: 12, y: 8)
        )
        path.close()
        path.move(to: CGPoint(x: 30, y: 30))

        let description = try SnapshotRunner.run(SyncSnapshot<NSBezierPath, StringBytes>.elementsDescription, path)

        #expect(
            description
                == [
                    "MoveTo (0.0, 0.0)",
                    "LineTo (10.0, 0.0)",
                    "CurveTo (12.0, 2.0) (12.0, 8.0) (10.0, 10.0)",
                    "Close ",
                    "",
                    "MoveTo (30.0, 30.0)",
                    "",
                ].joined(separator: "\n")
        )
    }
    #endif
}
#endif
