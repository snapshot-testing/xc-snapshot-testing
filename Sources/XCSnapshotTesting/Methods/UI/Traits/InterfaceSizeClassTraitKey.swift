// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
/// How much space the interface has in one direction, as in UIKit's `UIUserInterfaceSizeClass`.
public enum InterfaceSizeClass: Sendable, Hashable {
    /// The size class is not specified.
    case unspecified
    /// There is room: a large screen, or the long side of a device.
    case regular
    /// There is little room: a small screen, or the short side of a device.
    case compact
}

/// A structure representing the horizontal and vertical interface size classes for a device.
///
/// `DeviceInterfaceSizeClass` combines horizontal and vertical size classes to fully describe the layout environment of a device.
/// This helps in creating adaptive UIs that respond appropriately to different screen sizes and orientations.
public struct DeviceInterfaceSizeClass: Sendable, Hashable {

    /// The horizontal interface size class.
    public let horizontal: InterfaceSizeClass

    /// The vertical interface size class.
    public let vertical: InterfaceSizeClass

    /// Initializes a `DeviceInterfaceSizeClass` with the specified horizontal and vertical size classes.
    ///
    /// - Parameters:
    ///   - horizontal: The horizontal interface size class.
    ///   - vertical: The vertical interface size class.
    public init(horizontal: InterfaceSizeClass, vertical: InterfaceSizeClass) {
        self.horizontal = horizontal
        self.vertical = vertical
    }
}

/// Chooses the size classes of a device from the size being rendered, so they follow the orientation.
///
/// ```swift
/// let sizeClass = DeviceDynamicInterfaceSizeClass { size in
///     DeviceInterfaceSizeClass(
///         horizontal: size.width < 768 ? .compact : .regular,
///         vertical: .regular
///     )
/// }
/// ```
public struct DeviceDynamicInterfaceSizeClass: Sendable {

    private let provider: @Sendable (CGSize) -> DeviceInterfaceSizeClass

    /// Creates a `DeviceDynamicInterfaceSizeClass` instance using a provider closure.
    ///
    /// - Parameter provider: A closure that takes a size and returns the corresponding interface size class.
    public init(provider: @escaping @Sendable (CGSize) -> DeviceInterfaceSizeClass) {
        self.provider = provider
    }

    /// Creates a `DeviceDynamicInterfaceSizeClass` instance with a constant value.
    ///
    /// - Parameter constant: The interface size class to always return.
    public init(constant: DeviceInterfaceSizeClass) {
        self.init(provider: { _ in constant })
    }

    /// Evaluates the interface size class for the given size.
    ///
    /// - Parameter size: The size to evaluate.
    /// - Returns: The interface size class corresponding to the provided size.
    public func callAsFunction(_ size: CGSize) -> DeviceInterfaceSizeClass {
        provider(size)
    }
}

// MARK: - iPhone
extension DeviceDynamicInterfaceSizeClass {

    // MARK: - iPhone Duo

    public static let iPhoneDuo = withCompactLandscape

    public static let iPhoneDuoUnfolded = iPadOS

    // MARK: - iPhone 18

    public static let iPhone18ProMax = withRegularLandscape

    public static let iPhone18Pro = withCompactLandscape

    // MARK: - iPhone 17

    /// Size classes of the iPhone 17 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone17ProMax = withRegularLandscape

    /// Size classes of the iPhone 17 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone17Pro = withCompactLandscape

    /// Size classes of the iPhone 17.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone17 = withCompactLandscape

    /// Size classes of the iPhone 17e.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone17e = withCompactLandscape

    // MARK: - iPhone Air

    /// Size classes of the iPhone Air.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhoneAir = withRegularLandscape

    // MARK: - iPhone 16

    /// Size classes of the iPhone 16 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone16ProMax = withRegularLandscape

    /// Size classes of the iPhone 16 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone16Pro = withCompactLandscape

    /// Size classes of the iPhone 16 Plus.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone16Plus = withRegularLandscape

    /// Size classes of the iPhone 16.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone16 = withCompactLandscape

    /// Size classes of the iPhone 16e.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone16e = withCompactLandscape

    // MARK: - iPhone 15

    /// Size classes of the iPhone 15 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone15ProMax = withRegularLandscape

    /// Size classes of the iPhone 15 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone15Pro = withCompactLandscape

    /// Size classes of the iPhone 15 Plus.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone15Plus = withRegularLandscape

    /// Size classes of the iPhone 15.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone15 = withCompactLandscape

    // MARK: - iPhone 14

    /// Size classes of the iPhone 14 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone14ProMax = withRegularLandscape

    /// Size classes of the iPhone 14 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone14Pro = withCompactLandscape

    /// Size classes of the iPhone 14 Plus.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone14Plus = withRegularLandscape

    /// Size classes of the iPhone 14.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone14 = withCompactLandscape

    // MARK: - iPhone 13

    /// Size classes of the iPhone 13 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone13ProMax = withRegularLandscape

    /// Size classes of the iPhone 13 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone13Pro = withCompactLandscape

    /// Size classes of the iPhone 13.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone13 = withCompactLandscape

    /// Size classes of the iPhone 13 mini.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone13Mini = withCompactLandscape

    // MARK: - iPhone 12

    /// Size classes of the iPhone 12 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone12ProMax = withRegularLandscape

    /// Size classes of the iPhone 12 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone12Pro = withCompactLandscape

    /// Size classes of the iPhone 12.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone12 = withCompactLandscape

    /// Size classes of the iPhone 12 mini.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone12Mini = withCompactLandscape

    // MARK: - iPhone 11

    /// Size classes of the iPhone 11 Pro Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone11ProMax = withRegularLandscape

    /// Size classes of the iPhone 11 Pro.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhone11Pro = withCompactLandscape

    /// Size classes of the iPhone 11.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhone11 = withRegularLandscape

    // MARK: - iPhone XS

    /// Size classes of the iPhone XS Max.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhoneXSMax = withRegularLandscape

    /// Size classes of the iPhone XS.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhoneXS = withCompactLandscape

    // MARK: - iPhone XR

    /// Size classes of the iPhone XR.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    public static let iPhoneXR = withRegularLandscape

    // MARK: - iPhone X

    /// Size classes of the iPhone X.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    @available(*, deprecated, message: "iPhoneX is not supported by iOS 17 or later.")
    public static let iPhoneX = withCompactLandscape

    // MARK: - iPhone 8

    /// Size classes of the iPhone 8 Plus.
    ///
    /// Portrait is compact width and regular height. Landscape is regular width and compact height.
    @available(*, deprecated, message: "iPhone8Plus is not supported by iOS 17 or later.")
    public static let iPhone8Plus = withRegularLandscape

    /// Size classes of the iPhone 8.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    @available(*, deprecated, message: "iPhone8 is not supported by iOS 17 or later.")
    public static let iPhone8 = withCompactLandscape

    // MARK: - iPhone SE

    /// Size classes of the iPhone SE.
    ///
    /// Portrait is compact width and regular height. Landscape is compact width and compact height.
    public static let iPhoneSE = withCompactLandscape

    // MARK: - iPhone Private Methods

    private static let withRegularLandscape = iOS(
        landscape: .init(horizontal: .regular, vertical: .compact)
    )

    private static let withCompactLandscape = iOS(
        landscape: .init(horizontal: .compact, vertical: .compact)
    )

    /// Size classes of an iPhone: compact width and regular height in portrait, and `landscape()` in landscape.
    private static func iOS(
        landscape: @autoclosure @escaping @Sendable () -> DeviceInterfaceSizeClass
    ) -> DeviceDynamicInterfaceSizeClass {
        DeviceDynamicInterfaceSizeClass {
            if $0.width > $0.height {
                return landscape()
            }

            return .init(
                horizontal: .compact,
                vertical: .regular
            )
        }
    }
}

// MARK: - iPads
extension DeviceDynamicInterfaceSizeClass {

    /// Size classes of an iPad, resolved from the size being rendered.
    ///
    /// The width is regular when it is at least 75% of the height, otherwise compact.
    /// The height is regular when it is more than 50% of the width, otherwise compact.
    public static let iPadOS = DeviceDynamicInterfaceSizeClass { size in
        let horizontal: InterfaceSizeClass
        let vertical: InterfaceSizeClass

        if size.width >= size.height * 0.75 {
            horizontal = .regular
        } else {
            horizontal = .compact
        }

        if size.height > size.width * 0.5 {
            vertical = .regular
        } else {
            vertical = .compact
        }

        return .init(horizontal: horizontal, vertical: vertical)
    }
}

// MARK: - Regular Sizes
extension DeviceDynamicInterfaceSizeClass {

    /// Size classes of macOS, always regular in both directions.
    public static let macOS = DeviceDynamicInterfaceSizeClass(
        constant: DeviceInterfaceSizeClass(horizontal: .regular, vertical: .regular)
    )

    /// Size classes of tvOS, always regular in both directions.
    public static let tvOS = DeviceDynamicInterfaceSizeClass(
        constant: DeviceInterfaceSizeClass(horizontal: .regular, vertical: .regular)
    )

    /// Size classes of visionOS, always regular in both directions.
    public static let visionOS = DeviceDynamicInterfaceSizeClass(
        constant: DeviceInterfaceSizeClass(horizontal: .regular, vertical: .regular)
    )
}

// MARK: - WatchOS
extension DeviceDynamicInterfaceSizeClass {

    /// Size classes of watchOS, always compact in both directions.
    public static let watchOS = DeviceDynamicInterfaceSizeClass(
        constant: DeviceInterfaceSizeClass(horizontal: .compact, vertical: .compact)
    )
}

#if os(iOS) || os(tvOS) || os(visionOS)
/// Stores ``Traits/deviceInterfaceSizeClass``, applied as the horizontal and vertical size classes.
private struct DeviceInterfaceSizeClassTraitKey: TraitKey {

    static let defaultValue = DeviceInterfaceSizeClass(
        horizontal: .unspecified,
        vertical: .unspecified
    )

    @available(iOS 17, tvOS 17, *)
    static func apply(_ value: Value, to traitsOverrides: inout UITraitOverrides) {
        traitsOverrides.verticalSizeClass = .init(value.vertical)
        traitsOverrides.horizontalSizeClass = .init(value.horizontal)
    }

    static func apply(_ value: Value, to traitCollection: inout UITraitCollection) {
        #if os(visionOS)
        traitCollection = traitCollection.modifyingTraits {
            $0.verticalSizeClass = .init(value.vertical)
            $0.horizontalSizeClass = .init(value.horizontal)
        }
        #else
        if #available(iOS 17, tvOS 17, *) {
            traitCollection = traitCollection.modifyingTraits {
                $0.verticalSizeClass = .init(value.vertical)
                $0.horizontalSizeClass = .init(value.horizontal)
            }
        } else {
            traitCollection = .init(traitsFrom: [
                .init(verticalSizeClass: .init(value.vertical)),
                .init(horizontalSizeClass: .init(value.horizontal)),
            ])
        }
        #endif
    }
}

extension UIUserInterfaceSizeClass {

    fileprivate init(_ interfaceSizeClass: InterfaceSizeClass) {
        switch interfaceSizeClass {
        case .unspecified:
            self = .unspecified
        case .regular:
            self = .regular
        case .compact:
            self = .compact
        }
    }
}

extension Traits {

    /// Specifies the size class for the device interface.
    public var deviceInterfaceSizeClass: DeviceInterfaceSizeClass {
        get { self[DeviceInterfaceSizeClassTraitKey.self] }
        set { self[DeviceInterfaceSizeClassTraitKey.self] = newValue }
    }

    /// Creates a `Traits` instance with the specified device interface size class.
    public init(deviceInterfaceSizeClass: DeviceInterfaceSizeClass) {
        self.init()
        self.deviceInterfaceSizeClass = deviceInterfaceSizeClass
    }
}
#endif
#endif
