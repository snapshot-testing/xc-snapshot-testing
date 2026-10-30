// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
import Accelerate.vImage
#elseif os(macOS)
@preconcurrency import AppKit
import Accelerate.vImage
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
typealias SDKImage = UIKit.UIImage
typealias SDKLabel = UIKit.UILabel
typealias SDKView = UIKit.UIView
typealias SDKViewController = UIKit.UIViewController
typealias SDKApplication = UIKit.UIApplication
typealias SDKWindow = UIKit.UIWindow
#elseif os(watchOS)
typealias SDKImage = UIKit.UIImage
#elseif os(macOS)
typealias SDKImage = AppKit.NSImage
typealias SDKLabel = AppKit.NSText
typealias SDKView = AppKit.NSView
typealias SDKViewController = AppKit.NSViewController
typealias SDKApplication = AppKit.NSApplication
typealias SDKWindow = AppKit.NSWindow
#endif

#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS) || os(macOS)
extension SDKImage {

    #if os(macOS)
    var scale: CGFloat {
        1.0
    }

    var cgImage: CGImage? {
        guard
            let pngData = pngData(),
            let dataProvider = CGDataProvider(data: pngData as CFData)
        else { return nil }

        return CGImage(
            pngDataProviderSource: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    func pngData() -> Data? {
        performOnMainThread {
            guard
                let bitmapRep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: Int(size.width),
                    pixelsHigh: Int(size.height),
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .calibratedRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ),
                let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
            else { return nil }

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            draw(in: NSRect(origin: .zero, size: size))
            NSGraphicsContext.restoreGraphicsState()

            return bitmapRep.representation(using: .png, properties: [:])
        }
    }
    #endif

    /// The PNG that is stored for this image: in `format` when there is one, and as the platform
    /// encodes it otherwise.
    func encodedPNG(format: ImageFormat?) -> Data? {
        guard let format, let source = pixels(in: format) else { return pngData() }
        return format.pngData(source) ?? pngData()
    }

    /// The pixels of the image in `format`, at the same size `pngData()` uses.
    private func pixels(in format: ImageFormat) -> CGImage? {
        #if os(macOS)
        let width = Int(size.width)
        let height = Int(size.height)

        guard
            width > 0, height > 0,
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: format.bitsPerComponent,
                bytesPerRow: 0,
                space: format.cgColorSpace,
                bitmapInfo: format.bitmapInfo
            )
        else { return nil }

        performOnMainThread {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            draw(in: NSRect(origin: .zero, size: size))
            NSGraphicsContext.restoreGraphicsState()
        }

        return context.makeImage()
        #else
        return cgImage
        #endif
    }

    /// Used when the image size has no width or no height to generated the default empty image
    @MainActor
    static var empty: SDKImage {
        #if os(iOS) || os(tvOS) || os(macOS)
        let label = SDKLabel(frame: CGRect(x: 0, y: 0, width: 400, height: 80))
        let text =
            "Error: No image could be generated for this view as its size was zero. Please set an explicit size in the test."
        label.backgroundColor = .red
        #if os(macOS)
        label.string = text
        label.alignment = .center
        label.isVerticallyResizable = true
        #else
        label.text = text
        label.textAlignment = .center
        label.numberOfLines = 3
        #endif
        return label.asImage()
        #else
        return SDKImage()
        #endif
    }

    @MainActor
    func substract(_ image: SDKImage) -> SDKImage {
        normalizedComponentDiff(image) ?? blendModeDiff(image)
    }

    @MainActor
    func compare(
        _ newValue: SDKImage,
        precision: Float,
        perceptualPrecision: Float,
        storedFormat: ImageFormat? = nil
    ) -> String? {
        guard let oldCgImage = self.cgImage else {
            return "Reference image could not be loaded."
        }
        guard let newCgImage = newValue.cgImage else {
            return "Newly-taken snapshot could not be loaded."
        }
        guard newCgImage.width != 0, newCgImage.height != 0 else {
            return "Newly-taken snapshot is empty."
        }
        guard oldCgImage.width == newCgImage.width, oldCgImage.height == newCgImage.height else {
            return "Newly-taken snapshot@\(newValue.size) does not match reference@\(self.size)."
        }
        // Both sides are compared in the format of the reference, so a reference recorded in
        // Display P3 or with 16 bits keeps every difference that an sRGB 8-bit comparison would hide.
        let format = ImageFormat(describing: oldCgImage)
        let pixelCount = oldCgImage.width * oldCgImage.height
        let byteCount = format.bytesPerPixel * pixelCount
        var oldBytes = [UInt8](repeating: 0, count: byteCount)
        guard let oldContext = oldCgImage.context(format: format, with: &oldBytes), let oldData = oldContext.data else {
            return "Reference image's data could not be loaded."
        }
        if let newContext = newCgImage.context(format: format), let newData = newContext.data {
            if memcmp(oldData, newData, byteCount) == 0 { return nil }
        }
        var newerBytes = [UInt8](repeating: 0, count: byteCount)
        guard
            let pngData = newValue.encodedPNG(format: storedFormat),
            let newerCgImage = SDKImage(data: pngData)?.cgImage,
            let newerContext = newerCgImage.context(format: format, with: &newerBytes),
            let newerData = newerContext.data
        else {
            return "Newly-taken snapshot's data could not be loaded."
        }
        if memcmp(oldData, newerData, byteCount) == 0 { return nil }
        if precision >= 1, perceptualPrecision >= 1 {
            return "Newly-taken snapshot does not match reference."
        }
        #if os(iOS) || os(tvOS) || os(macOS)
        if perceptualPrecision < 1 {
            // Compare the images remapped to the common color space above. Passing the originals
            // would compare, for example, a Display P3 reference against an extended sRGB snapshot,
            // which reports a difference on every pixel even when they are perceptually identical.
            guard
                let oldNormalized = oldContext.makeImage(),
                let newNormalized = newerContext.makeImage()
            else {
                return "Newly-taken snapshot's data could not be loaded."
            }
            return CIImage(cgImage: oldNormalized).perceptuallyCompare(
                CIImage(cgImage: newNormalized),
                pixelPrecision: precision,
                perceptualPrecision: perceptualPrecision
            )
        }
        #endif

        let byteCountThreshold = Int((1 - precision) * Float(byteCount))
        var differentByteCount = 0
        // NB: We are purposely using a verbose 'while' loop instead of a 'for in' loop.  When the
        //     compiler doesn't have optimizations enabled, like in test targets, a `while` loop is
        //     significantly faster than a `for` loop for iterating through the elements of a memory
        //     buffer. Details can be found in [SR-6983](https://github.com/apple/swift/issues/49531)
        var index = 0
        while index < byteCount {
            defer { index += 1 }
            if oldBytes[index] != newerBytes[index] {
                differentByteCount += 1
            }
        }
        if differentByteCount > byteCountThreshold {
            let actualPrecision = 1 - Float(differentByteCount) / Float(byteCount)
            return "Actual image precision \(actualPrecision) is less than required \(precision)"
        }

        return nil
    }
}

extension SDKImage {

    private func normalizedComponentDiff(_ image: SDKImage) -> SDKImage? {
        #if os(macOS)
        guard
            let oldCg = self.cgImage,
            let newCg = image.cgImage,
            oldCg.width == newCg.width,
            oldCg.height == newCg.height
        else { return nil }

        return nil
        #else
        guard
            let oldCgImage = self.cgImage,
            let pngData = image.pngData(),
            let newCgImage = SDKImage(data: pngData)?.cgImage,
            oldCgImage.width == newCgImage.width,
            oldCgImage.height == newCgImage.height
        else {
            return nil
        }

        guard
            let outputColorSpace = CGColorSpace(name: CGColorSpace.linearGray),
            let outputFormat = vImage_CGImageFormat(
                bitsPerComponent: ImageContext.bitsPerComponent,
                bitsPerPixel: ImageContext.bitsPerComponent,
                colorSpace: outputColorSpace,
                bitmapInfo: .init()
            )
        else {
            return nil
        }

        let width = oldCgImage.width
        let height = oldCgImage.height
        let pixelCount = width * height
        let scale = self.scale

        // NB: Redraw both images into the same 8-bit RGBA context `compare` uses. Reading the raw
        //     provider bytes assumes that layout, which reads out of bounds on grayscale or 24-bit
        //     images and points at the wrong pixels for 16-bit ones.
        let byteCount = ImageContext.bytesPerPixel * pixelCount
        var oldBytes = [UInt8](repeating: 0, count: byteCount)
        var newBytes = [UInt8](repeating: 0, count: byteCount)
        guard
            oldCgImage.context(with: &oldBytes) != nil,
            newCgImage.context(with: &newBytes) != nil
        else {
            return nil
        }

        var diffBytes = [UInt8](repeating: 0, count: pixelCount)
        var index = 0
        while index < pixelCount {
            defer { index += 1 }
            let pixelOffset = index * ImageContext.bytesPerPixel
            let rOld = Int16(oldBytes[pixelOffset])
            let gOld = Int16(oldBytes[pixelOffset + 1])
            let bOld = Int16(oldBytes[pixelOffset + 2])
            let aOld = Int16(oldBytes[pixelOffset + 3])

            let rNew = Int16(newBytes[pixelOffset])
            let gNew = Int16(newBytes[pixelOffset + 1])
            let bNew = Int16(newBytes[pixelOffset + 2])
            let aNew = Int16(newBytes[pixelOffset + 3])

            let rDiff = abs(rOld - rNew)
            let gDiff = abs(gOld - gNew)
            let bDiff = abs(bOld - bNew)
            let aDiff = abs(aOld - aNew)

            let maxDiff = max(rDiff, gDiff, bDiff, aDiff)
            diffBytes[index] = UInt8(maxDiff)
        }

        let outputCgImage: CGImage? = diffBytes.withUnsafeMutableBytes { diffPtr in
            var diffBuffer = vImage_Buffer(
                data: diffPtr.baseAddress,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width
            )
            do {
                var normalizedBuffer = try vImage_Buffer(
                    width: width,
                    height: height,
                    bitsPerPixel: UInt32(ImageContext.bitsPerComponent)
                )
                defer { normalizedBuffer.free() }

                let error = vImageContrastStretch_Planar8(
                    &diffBuffer,
                    &normalizedBuffer,
                    vImage_Flags(kvImageNoFlags)
                )

                let buffer = error == kvImageNoError ? normalizedBuffer : diffBuffer
                return try buffer.createCGImage(format: outputFormat)
            } catch {
                return nil
            }
        }

        guard let outputCgImage else { return nil }
        return SDKImage(cgImage: outputCgImage, scale: scale, orientation: .up)
        #endif
    }

    // MARK: - Fallback: blend mode tradicional
    private func blendModeDiff(_ image: SDKImage) -> SDKImage {
        #if os(macOS)
        guard
            let lhsImage = self.cgImage,
            let rhsImage = image.cgImage
        else {
            return SDKImage(size: .zero)
        }

        let oldCiImage = CIImage(cgImage: lhsImage)
        let newCiImage = CIImage(cgImage: rhsImage)
        let differenceFilter = CIFilter(name: "CIDifferenceBlendMode")!
        differenceFilter.setValue(oldCiImage, forKey: kCIInputImageKey)
        differenceFilter.setValue(newCiImage, forKey: kCIInputBackgroundImageKey)

        let maxSize = CGSize(
            width: max(self.size.width, image.size.width),
            height: max(self.size.height, image.size.height)
        )
        let rep = NSCIImageRep(ciImage: differenceFilter.outputImage!)
        let difference = NSImage(size: maxSize)
        difference.addRepresentation(rep)
        return difference
        #else
        let width = max(self.size.width, image.size.width)
        let height = max(self.size.height, image.size.height)
        let scale = max(self.scale, image.scale)
        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, true, scale)
        image.draw(in: CGRect(origin: .zero, size: size))
        self.draw(in: CGRect(origin: .zero, size: size), blendMode: .difference, alpha: 1)
        let differenceImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return differenceImage
        #endif
    }
}
#endif
