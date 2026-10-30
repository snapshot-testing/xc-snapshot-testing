// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@testable import XCSnapshotTesting

/// Builds images pixel by pixel so the tests control the exact bytes, the color space and the pixel
/// format, without depending on fonts, system controls or anything else that changes between OS versions.
enum ImageFactory {

    typealias Color = (red: UInt8, green: UInt8, blue: UInt8)

    static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    static let displayP3 = CGColorSpace(name: CGColorSpace.displayP3)!
    static let gray = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2)!

    /// An 8-bit RGBA image where every pixel is computed by `pixel(x, y)`.
    static func rgba8(
        width: Int = 16,
        height: Int = 16,
        colorSpace: CGColorSpace = sRGB,
        pixel: (_ x: Int, _ y: Int) -> Color
    ) -> CGImage {
        var bytes = [UInt8]()
        bytes.reserveCapacity(width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let color = pixel(x, y)
                bytes.append(contentsOf: [color.red, color.green, color.blue, 255])
            }
        }

        return make(
            bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    static func flat(_ value: UInt8, width: Int = 16, height: Int = 16) -> CGImage {
        rgba8(width: width, height: height) { _, _ in (value, value, value) }
    }

    /// An 8-bit image without color or alpha channels, as PNGs of fully achromatic content decode.
    static func grayscale8(width: Int = 16, height: Int = 16, value: UInt8 = 128) -> CGImage {
        make(
            [UInt8](repeating: value, count: width * height),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            colorSpace: gray,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
    }

    /// A 16-bit RGBA image (8 bytes per pixel), as wide-gamut captures can be.
    static func rgba16(width: Int = 16, height: Int = 16, value: UInt16 = 0x8000) -> CGImage {
        var bytes = [UInt8]()
        for _ in 0..<(width * height) {
            for component in [value, value, value, UInt16.max] {
                bytes.append(UInt8(component & 0xFF))
                bytes.append(UInt8(component >> 8))
            }
        }

        return make(
            bytes,
            width: width,
            height: height,
            bitsPerComponent: 16,
            bitsPerPixel: 64,
            colorSpace: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
        )
    }

    private static func make(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        bitsPerPixel: Int,
        colorSpace: CGColorSpace,
        bitmapInfo: UInt32
    ) -> CGImage {
        let provider = CGDataProvider(data: Data(bytes) as CFData)!

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: width * bitsPerPixel / 8,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    /// Wraps a `CGImage` in the image type of the platform.
    @MainActor
    static func image(_ cgImage: CGImage) -> SDKImage {
        #if os(macOS)
        NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        #else
        UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        #endif
    }

    /// Decodes the first pixel of a PNG, as 8-bit sRGB RGBA.
    static func pixel(of pngData: Data, x: Int = 0, y: Int = 0) -> [UInt8]? {
        guard
            let provider = CGDataProvider(data: pngData as CFData),
            let image = CGImage(
                pngDataProviderSource: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else { return nil }

        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard
            let context = CGContext(
                data: &bytes,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return Array(bytes[offset..<offset + 4])
    }
}
#endif
