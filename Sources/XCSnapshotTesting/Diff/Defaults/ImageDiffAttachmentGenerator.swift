// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
/// Compares two images and attaches a diff image when they differ.
///
/// The attachments are the reference, the new image (or a placeholder if it is empty), and an image
/// that highlights the difference.
public struct ImageDiffAttachmentGenerator: DiffAttachmentGenerator {

    private let precision: Float
    private let perceptualPrecision: Float

    /// Creates a generator.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    public init(
        precision: Float,
        perceptualPrecision: Float
    ) {
        self.precision = precision
        self.perceptualPrecision = perceptualPrecision
    }

    /// Compares the images.
    ///
    /// - Parameters:
    ///   - reference: The stored image.
    ///   - diffable: The image produced by the current run.
    /// - Returns: A description of the difference with its attachments, or `nil` if the images match within the precisions.
    public func callAsFunction(
        from reference: ImageBytes,
        with diffable: ImageBytes
    ) -> DiffAttachment? {
        // Resolved here because the environment is not available on the main thread queue.
        let format = diffable.effectiveFormat

        return performOnMainThread {
            guard
                let message = reference.rawValue.compare(
                    diffable.rawValue,
                    precision: precision,
                    perceptualPrecision: perceptualPrecision,
                    storedFormat: format
                )
            else { return nil }

            let difference = reference.rawValue.substract(diffable.rawValue)
            var oldAttachment = SnapshotAttachment(image: reference.rawValue)
            oldAttachment?.name = "reference"
            let isEmptyImage = diffable.rawValue.size == .zero
            var newAttachment = SnapshotAttachment(
                image: isEmptyImage ? SDKImage.empty : diffable.rawValue
            )
            newAttachment?.name = "failure"
            var differenceAttachment = SnapshotAttachment(image: difference)
            differenceAttachment?.name = "difference"

            return DiffAttachment(
                message: message,
                attachments: [oldAttachment, newAttachment, differenceAttachment].compactMap(\.self)
            )
        }
    }
}
#endif
