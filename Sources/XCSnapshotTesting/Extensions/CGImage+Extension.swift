// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(macOS) || os(watchOS) || os(visionOS)
import CoreGraphics

extension CGImage {

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
