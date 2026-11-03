// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(macOS) || os(watchOS) || os(visionOS)
import CoreGraphics

extension CGImage {

    /// Draws the image into a bitmap context of `format`.
    ///
    /// - Parameters:
    ///   - format: The pixel format and color space of the context.
    ///   - data: A buffer for the pixels. When `nil`, the context allocates its own.
    /// - Returns: The context, or `nil` if it cannot be created.
    func context(format: ImageFormat = .sRGB, with data: UnsafeMutableRawPointer? = nil) -> CGContext? {
        guard
            let context = CGContext(
                data: data,
                width: self.width,
                height: self.height,
                bitsPerComponent: format.bitsPerComponent,
                bytesPerRow: self.width * format.bytesPerPixel,
                space: format.cgColorSpace,
                bitmapInfo: format.bitmapInfo
            )
        else { return nil }

        context.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        return context
    }
}
#endif
