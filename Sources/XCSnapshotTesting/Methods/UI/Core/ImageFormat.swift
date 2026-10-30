// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
import CoreGraphics
import Foundation
import ImageIO

/// The color space and bit depth in which an image snapshot is stored.
///
/// Snapshots are stored in whatever format the platform renders them: a recent device draws in
/// Display P3, an older simulator in sRGB. Setting a format makes the stored file independent of
/// the machine that recorded it.
///
/// ```swift
/// try await withTestingEnvironment {
///     $0.imageFormat = .displayP3
/// } operation: {
///     try await assert(of: view, as: .image)
/// }
/// ```
///
/// The format only decides how a snapshot is **recorded**. Comparing always happens in the
/// format of the reference on disk, so changing the format never makes an existing reference fail:
/// it keeps being compared as it was recorded until it is recorded again.
///
/// - Note: On macOS the images are recorded in the format, but the comparison keeps happening in
///   8-bit sRGB, as AppKit hands the pixels of an image over in that format.
public struct ImageFormat: Sendable, Hashable {

    /// The color space of the stored pixels.
    public enum ColorSpace: Sendable, Hashable {

        /// The standard sRGB color space.
        case sRGB

        /// The wide gamut Display P3 color space.
        case displayP3
    }

    /// The number of bits stored for each color component.
    public enum BitDepth: Sendable, Hashable {

        /// 8 bits per component.
        case eight

        /// 16 bits per component, which keeps the gradients that 8 bits flatten into steps.
        case sixteen
    }

    /// The color space of the stored pixels.
    public var colorSpace: ColorSpace

    /// The number of bits stored for each color component.
    public var bitDepth: BitDepth

    /// Creates a format.
    ///
    /// - Parameters:
    ///   - colorSpace: The color space of the stored pixels.
    ///   - bitDepth: The number of bits stored for each color component.
    public init(colorSpace: ColorSpace = .sRGB, bitDepth: BitDepth = .eight) {
        self.colorSpace = colorSpace
        self.bitDepth = bitDepth
    }

    /// sRGB with 8 bits per component.
    public static let sRGB = ImageFormat(colorSpace: .sRGB, bitDepth: .eight)

    /// Display P3 with 8 bits per component.
    public static let displayP3 = ImageFormat(colorSpace: .displayP3, bitDepth: .eight)
}

// MARK: - Pixels

extension ImageFormat {

    var cgColorSpace: CGColorSpace {
        let name =
            switch colorSpace {
            case .sRGB: CGColorSpace.sRGB
            case .displayP3: CGColorSpace.displayP3
            }

        return CGColorSpace(name: name) ?? CGColorSpaceCreateDeviceRGB()
    }

    var bitsPerComponent: Int {
        switch bitDepth {
        case .eight: 8
        case .sixteen: 16
        }
    }

    var bytesPerPixel: Int {
        bitsPerComponent / 8 * 4
    }

    var bitmapInfo: UInt32 {
        let alpha = CGImageAlphaInfo.premultipliedLast.rawValue

        switch bitDepth {
        case .eight: return alpha
        case .sixteen: return alpha | CGBitmapInfo.byteOrder16Little.rawValue
        }
    }

    /// Whether drawing the view in the standard range would lose what the format can store.
    var needsExtendedRange: Bool {
        colorSpace != .sRGB || bitDepth != .eight
    }

    /// The format that describes an image already stored, which is how a reference is compared.
    init(describing image: CGImage) {
        let isWideGamut = image.colorSpace.map { $0.name == CGColorSpace.displayP3 || $0.isWideGamutRGB } ?? false

        self.init(
            colorSpace: isWideGamut ? .displayP3 : .sRGB,
            bitDepth: image.bitsPerComponent > 8 ? .sixteen : .eight
        )
    }

    /// Redraws the image in this format.
    func convert(_ image: CGImage) -> CGImage? {
        image.context(format: self)?.makeImage()
    }

    /// Encodes the image as a PNG that keeps this format: the color profile and the bit depth.
    func pngData(_ image: CGImage) -> Data? {
        guard let converted = convert(image) else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, converted, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
#endif
