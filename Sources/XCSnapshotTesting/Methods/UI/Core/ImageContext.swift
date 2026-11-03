// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
import CoreGraphics

/// The layout of the 8-bit RGBA bitmaps used to compare images.
enum ImageContext {
    static let bitsPerComponent = 8
    static let bytesPerPixel = 4
}
#endif
