// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(macOS)
/// Represents a serializable image for snapshot testing.
///
/// `ImageBytes` wraps a `UIImage`or `NSImage` and provides serialization/deserialization capabilities,
/// enabling images to be compared in snapshot tests. Implements `BytesRepresentable`
/// to convert images to binary data (`Data`) and vice versa.
public struct ImageBytes: BytesRepresentable {

    /// Stores ``DataSerializationConfiguration/imageScale`` in the serialization configuration.
    fileprivate struct ImageScaleKey: DataSerializationConfigurationKey {
        static let defaultValue: Double = 1
    }

    #if os(macOS)
    /// The wrapped image.
    public let rawValue: NSImage
    #else
    /// The wrapped image.
    public let rawValue: UIKit.UIImage
    #endif

    /// The format the image is stored in.
    ///
    /// When `nil`, the format comes from ``SnapshotEnvironmentValues/imageFormat``.
    public let format: ImageFormat?

    /// Initializes an instance from image data in a `BytesContainer`.
    ///
    /// - Parameter container: Container holding the binary image data.
    /// - Throws: `BytesSerializationError` if deserialization fails (e.g., corrupted data).
    public init(from container: BytesContainer) throws {
        #if os(macOS)
        guard let image = SDKImage(data: try container.read()) else {
            throw BytesSerializationError()
        }
        #else
        guard
            let image = SDKImage(
                data: try container.read(),
                scale: container.configuration.imageScale
            )
        else {
            throw BytesSerializationError()
        }
        #endif
        self.rawValue = image
        self.format = nil
    }

    #if os(macOS)
    /// Initializes from a `NSImage`.
    ///
    /// - Parameter rawValue: Image to convert to bytes for snapshot testing.
    public init(rawValue: NSImage) {
        self.init(rawValue: rawValue, format: nil)
    }

    /// Initializes from a `NSImage` that is stored in a specific format.
    ///
    /// - Parameters:
    ///   - rawValue: Image to convert to bytes for snapshot testing.
    ///   - format: The format the image is stored in, or `nil` to follow the environment.
    public init(rawValue: NSImage, format: ImageFormat?) {
        self.rawValue = rawValue
        self.format = format
    }
    #else
    /// Initializes from a `UIImage`.
    ///
    /// - Parameter rawValue: Image to convert to bytes for snapshot testing.
    public init(rawValue: UIKit.UIImage) {
        self.init(rawValue: rawValue, format: nil)
    }

    /// Initializes from a `UIImage` that is stored in a specific format.
    ///
    /// - Parameters:
    ///   - rawValue: Image to convert to bytes for snapshot testing.
    ///   - format: The format the image is stored in, or `nil` to follow the environment.
    public init(rawValue: UIKit.UIImage, format: ImageFormat?) {
        self.rawValue = rawValue
        self.format = format
    }
    #endif

    /// The format used to store the image: its own, or else the one of the environment.
    var effectiveFormat: ImageFormat? {
        format ?? SnapshotEnvironment.current.imageFormat
    }

    /// Serializes the image to binary data and writes it to the container.
    ///
    /// - Parameter container: Destination container for the image data.
    /// - Throws: ``BytesSerializationError`` if the image cannot be encoded as PNG.
    public func serialize(to container: BytesContainer) throws {
        // Returning here would leave the container empty, and an empty file would then be recorded
        // over the reference.
        guard let data = rawValue.encodedPNG(format: effectiveFormat) else {
            throw BytesSerializationError()
        }

        try container.write(data)
    }
}

// MARK: - DataSerializationConfiguration

extension DataSerializationConfiguration {

    /// Gets/sets the image scaling factor during serialization/deserialization.
    ///
    /// Controls how images are resized when converting to `Data` or reading from a `BytesContainer`.
    /// - Note: Default value is `1.0`.
    public var imageScale: Double {
        get { self[ImageBytes.ImageScaleKey.self] }
        set { self[ImageBytes.ImageScaleKey.self] = newValue }
    }
}

// MARK: - IdentitySyncSnapshot

extension IdentitySyncSnapshot<ImageBytes> {

    /// Compares images, with the default precisions: every pixel must match exactly.
    public static var image: Self {
        .image()
    }

    #if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
    /// Compares images with the given precisions.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    ///
    /// ```swift
    /// let snapshot = IdentitySyncSnapshot<ImageBytes>.image(precision: 0.98)
    /// ```
    public static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1
    ) -> Self {
        .init(
            pathExtension: "png",
            attachmentGenerator: ImageDiffAttachmentGenerator(
                precision: precision,
                perceptualPrecision: perceptualPrecision
            )
        )
    }
    #else
    /// Creates a custom image snapshot configuration with a precision setting.
    ///
    /// watchOS has no perceptual comparison, so only the pixel tolerance is configurable.
    ///
    /// - Parameter precision: Pixel tolerance for comparison (e.g., `0.95` allows 5% difference).
    public static func image(
        precision: Float = 1
    ) -> Self {
        .init(
            pathExtension: "png",
            attachmentGenerator: ImageDiffAttachmentGenerator(
                precision: precision,
                perceptualPrecision: 1
            )
        )
    }
    #endif
}

// MARK: - IdentitySyncSnapshot

#if os(macOS)
extension SyncSnapshot where Input: NSImage, Output == ImageBytes {

    /// Compares images, with the default precisions: every pixel must match exactly.
    public static var image: SyncSnapshot<Input, Output> {
        .image()
    }

    /// Compares images with the given precisions.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    public static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1
    ) -> SyncSnapshot<Input, Output> {
        IdentitySyncSnapshot.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision
        ).pullback { $0 }
    }
}
#else
extension SyncSnapshot where Input: UIImage, Output == ImageBytes {

    /// Compares images, with the default precisions: every pixel must match exactly.
    public static var image: SyncSnapshot<Input, ImageBytes> {
        .image()
    }

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Compares images with the given precisions.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    public static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1
    ) -> SyncSnapshot<Input, Output> {
        IdentitySyncSnapshot.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision
        ).pullback { $0 }
    }
    #elseif os(watchOS)
    /// Creates a custom image snapshot configuration with a precision setting.
    ///
    /// watchOS has no perceptual comparison, so only the pixel tolerance is configurable.
    ///
    /// - Parameter precision: Pixel tolerance for comparison (e.g., `0.95` allows 5% difference).
    public static func image(
        precision: Float = 1
    ) -> SyncSnapshot<Input, Output> {
        IdentitySyncSnapshot.image(
            precision: precision
        ).pullback { $0 }
    }
    #endif
}
#endif
#endif
