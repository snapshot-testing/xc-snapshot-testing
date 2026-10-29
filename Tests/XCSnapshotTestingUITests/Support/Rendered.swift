#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@_spi(Internals) @testable import XCSnapshotTesting

/// The colors the tests draw with. They are classified by their dominant channel, so the checks keep
/// working when the platform converts the color space of the image.
enum Swatch: String {
    case red, green, blue, white, black, clear

    @MainActor
    var color: SDKColor {
        switch self {
        case .red: SDKColor(red: 1, green: 0, blue: 0, alpha: 1)
        case .green: SDKColor(red: 0, green: 1, blue: 0, alpha: 1)
        case .blue: SDKColor(red: 0, green: 0, blue: 1, alpha: 1)
        case .white: SDKColor(red: 1, green: 1, blue: 1, alpha: 1)
        case .black: SDKColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .clear: SDKColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
    }
}

#if os(macOS)
typealias SDKColor = NSColor
#else
typealias SDKColor = UIColor
#endif

/// A rendered snapshot that can be asked for its size and for the color at a point.
@MainActor
struct Rendered {

    /// Size in points.
    let size: CGSize

    private let width: Int
    private let height: Int
    private let bytes: [UInt8]

    init(_ bytes: ImageBytes) throws {
        let image = bytes.rawValue

        guard let cgImage = image.cgImage else { throw RenderingFailure() }

        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        guard
            let context = CGContext(
                data: &pixels,
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: cgImage.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw RenderingFailure() }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

        self.size = image.size
        self.width = cgImage.width
        self.height = cgImage.height
        self.bytes = pixels
    }

    /// The raw pixel at a point, measured from the top left corner of the image.
    func pixel(x: CGFloat, y: CGFloat) -> [UInt8] {
        let column = min(max(Int(x / size.width * CGFloat(width)), 0), width - 1)
        let row = min(max(Int(y / size.height * CGFloat(height)), 0), height - 1)
        let offset = (row * width + column) * 4
        return Array(bytes[offset..<offset + 4])
    }

    /// The color at a point, as the closest of the test swatches.
    func swatch(x: CGFloat, y: CGFloat) -> Swatch {
        let pixel = pixel(x: x, y: y)
        let (red, green, blue, alpha) = (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]), Int(pixel[3]))

        if alpha < 40 { return .clear }
        // Pixels are premultiplied, so a translucent edge is only classified by its dominant channel.
        let strong = max(red, green, blue)
        if strong < 70 { return .black }
        if min(red, green, blue) > strong * 3 / 4 { return .white }
        if red == strong { return .red }
        if green == strong { return .green }
        return .blue
    }
}

struct RenderingFailure: Error {}

/// Runs the whole strategy (window, layout, snapshot) and returns the image it produced.
@MainActor
func render<Input: Sendable>(
    _ snapshot: AsyncSnapshot<Input, ImageBytes>,
    _ input: Input
) async throws -> Rendered {
    try Rendered(await snapshot.executor(input))
}
#endif
