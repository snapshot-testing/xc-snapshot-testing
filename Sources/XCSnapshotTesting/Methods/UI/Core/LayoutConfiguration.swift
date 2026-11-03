// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS) || os(macOS)
/// The safe area, size and traits that a UI snapshot is rendered with.
///
/// The presets, such as `iPhone15Pro` or `iPadPro12_9`, mimic the screen of a device. They only
/// set up the layout: the code still runs on the platform of the test, so a snapshot can differ from
/// the same screen on the real device.
public struct LayoutConfiguration: Sendable {

    // MARK: - Internal static methods

    #if os(macOS)
    /// Turns a ``SnapshotLayout`` into the configuration used to render.
    static func resolve(_ snapshotLayout: SnapshotLayout) -> LayoutConfiguration {
        switch snapshotLayout {
        case .sizeThatFits:
            return .init(safeArea: .init(), size: nil)
        case .fixed(let width, let height):
            let size = CGSize(width: width, height: height)
            return .init(safeArea: .init(), size: size)
        }
    }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    /// Turns a ``SnapshotLayout`` into the configuration used to render.
    ///
    /// The traits of a device layout are merged with `traits`, which win.
    static func resolve(
        _ snapshotLayout: SnapshotLayout,
        with traits: Traits
    ) -> LayoutConfiguration {
        switch snapshotLayout {
        case .device(let deviceConfig):
            return .init(
                safeArea: deviceConfig.safeArea,
                size: deviceConfig.size,
                traits: deviceConfig.traits.merging(traits)
            )
        case .sizeThatFits:
            return .init(safeArea: .zero, size: nil, traits: traits)
        case .fixed(let width, let height):
            let size = CGSize(width: width, height: height)
            return .init(safeArea: .zero, size: size, traits: traits)
        }
    }

    /// The layout of a snapshot, to be resolved when the snapshot runs.
    ///
    /// The traits of the environment are part of it. Resolving them when the strategy is created would
    /// fix the ones of whoever created it (a `static let` outside of any test), and a later
    /// `withTestingEnvironment` would not reach the snapshot.
    static func resolver(
        _ snapshotLayout: SnapshotLayout,
        traits: Traits
    ) -> @Sendable () -> LayoutConfiguration {
        { resolve(snapshotLayout, with: SnapshotEnvironment.current.traits.merging(traits)) }
    }
    #else
    static func resolve(_ snapshotLayout: SnapshotLayout) -> LayoutConfiguration {
        switch snapshotLayout {
        case .sizeThatFits:
            return .init(size: nil)
        case .fixed(let width, let height):
            let size = CGSize(width: width, height: height)
            return .init(size: size)
        }
    }
    #endif

    // MARK: - Public properties

    #if os(macOS)
    /// Margins for safe area layout (e.g., device notches or status bars).
    ///
    /// Default value: `.zero` (no additional margins).
    public let safeArea: NSEdgeInsets
    #elseif !os(watchOS)
    /// Margins for safe area layout (e.g., device notches or status bars).
    ///
    /// Default value: `.zero` (no additional margins).
    public let safeArea: UIEdgeInsets
    #endif

    /// Size of the element to render.
    ///
    /// When `nil`, the element uses its intrinsic content size.
    public let size: CGSize?

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Collection of UI traits like orientation, device size, and dark mode.
    ///
    /// Default value: `Traits()` (system default values).
    public let traits: Traits
    #endif

    // MARK: - Inits
    #if os(macOS)
    /// Initializes a `LayoutConfiguration` with the specified safe area and size.
    ///
    /// - Parameters:
    ///   - safeArea: The edge insets representing the safe area of the layout.
    ///   - size: The dimensions of the layout's viewing area.
    public init(
        safeArea: NSEdgeInsets = .init(),
        size: CGSize? = nil
    ) {
        self.safeArea = safeArea
        self.size = size
    }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    /// Initializes a layout configuration with default or custom values.
    ///
    /// - Parameters:
    ///   - safeArea: Margins for safe area (e.g., iPhone notch spacing).
    ///   - size: Desired element size (optional).
    ///   - traits: UI characteristics (e.g., portrait/landscape orientation).
    public init(
        safeArea: UIEdgeInsets = .zero,
        size: CGSize? = nil,
        traits: Traits = .init()
    ) {
        self.safeArea = safeArea
        self.size = size
        self.traits = traits
    }
    #else
    /// Initializes a layout configuration with default values.
    ///
    /// - Parameters:
    ///   - size: Desired element size (optional).
    public init(
        size: CGSize? = nil
    ) {
        self.size = size
    }
    #endif
}

#if os(iOS) || os(tvOS) || os(visionOS)

extension LayoutConfiguration {

    /// Edge insets whose sides are optional, so a side left out can fall back to a default value.
    fileprivate struct EdgeInsets {

        static var zero: Self {
            .init(
                top: .zero,
                left: .zero,
                bottom: .zero,
                right: .zero
            )
        }

        let top: CGFloat?
        let left: CGFloat?
        let bottom: CGFloat?
        let right: CGFloat?

        init(
            top: CGFloat? = nil,
            left: CGFloat? = nil,
            bottom: CGFloat? = nil,
            right: CGFloat? = nil
        ) {
            self.top = top
            self.left = left
            self.bottom = bottom
            self.right = right
        }
    }
}

// MARK: - iPhone Duo
extension LayoutConfiguration {

    /// The folded iPhone Duo, rendering its 5.4" outer display (466 x 678 pt).
    ///
    /// - Note: The size, scale, safe area and size classes were measured on the iPhone Duo simulator.
    ///   Its status bar sits in a side column rather than at the top, so the portrait safe area is
    ///   inset on the trailing edge (84 pt) and the landscape one on the leading edge.
    public static let iPhoneDuo: LayoutConfiguration = .iPhoneDuo(.portrait)

    public static func iPhoneDuo(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_4v2,
            portraitSafeArea: EdgeInsets(top: 0, bottom: 34, right: 84),
            landscapeSafeArea: EdgeInsets(top: 0, left: 84, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhoneDuo
        )
    }

    /// The unfolded iPhone Duo, rendering its 7.6" inner display (626 x 890 pt in portrait).
    ///
    /// - Note: Defaults to landscape, the orientation the device is held in when opened. The screen size
    ///   comes from the panel's published resolution at 3x. The simulator doesn't expose the inner display,
    ///   so the safe-area insets and size classes are unverified.
    public static let iPhoneDuoUnfolded: LayoutConfiguration = .iPhoneDuoUnfolded(.landscape)

    public static func iPhoneDuoUnfolded(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen7_6,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhoneDuoUnfolded
        )
    }
}

// MARK: - iPhone 18
extension LayoutConfiguration {

    public static let iPhone18ProMax: LayoutConfiguration = .iPhone18ProMax(.portrait)

    public static func iPhone18ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_9,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            landscapeSafeArea: EdgeInsets(top: 20, left: 62, bottom: 20, right: 62),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone18ProMax
        )
    }

    public static let iPhone18Pro: LayoutConfiguration = .iPhone18Pro(.portrait)

    public static func iPhone18Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_3,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            landscapeSafeArea: EdgeInsets(top: 20, left: 62, bottom: 20, right: 62),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone18Pro
        )
    }
}

// MARK: - iPhone 17
extension LayoutConfiguration {

    /// Layout of the iPhone 17e in portrait.
    public static let iPhone17e: LayoutConfiguration = .iPhone17e(.portrait)

    /// Layout of the iPhone 17e in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone17e(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone17e
        )
    }

    /// Layout of the iPhone 17 Pro Max in portrait.
    public static let iPhone17ProMax: LayoutConfiguration = .iPhone17ProMax(.portrait)

    /// Layout of the iPhone 17 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone17ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_9,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            landscapeSafeArea: EdgeInsets(top: 20, left: 62, bottom: 20, right: 62),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone17ProMax
        )
    }

    /// Layout of the iPhone 17 Pro in portrait.
    public static let iPhone17Pro: LayoutConfiguration = .iPhone17Pro(.portrait)

    /// Layout of the iPhone 17 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone17Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_3,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            landscapeSafeArea: EdgeInsets(top: 20, left: 62, bottom: 20, right: 62),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone17Pro
        )
    }

    /// Layout of the iPhone 17 in portrait.
    public static let iPhone17: LayoutConfiguration = .iPhone17(.portrait)

    /// Layout of the iPhone 17 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone17(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_3,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            landscapeSafeArea: EdgeInsets(top: 20, left: 62, bottom: 20, right: 62),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone17
        )
    }
}

// MARK: - iPhone Air
extension LayoutConfiguration {

    /// Layout of the iPhone Air in portrait.
    public static let iPhoneAir: LayoutConfiguration = .iPhoneAir(.portrait)

    /// Layout of the iPhone Air in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhoneAir(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_5v2,
            portraitSafeArea: EdgeInsets(top: 68, bottom: 34, right: 0),
            landscapeSafeArea: EdgeInsets(top: 20, left: 68, bottom: 29, right: 68),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhoneAir
        )
    }
}

// MARK: - iPhone 16
extension LayoutConfiguration {

    /// Layout of the iPhone 16 Pro Max in portrait.
    public static let iPhone16ProMax: LayoutConfiguration = .iPhone16ProMax(.portrait)

    /// Layout of the iPhone 16 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone16ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_9,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone16ProMax
        )
    }

    /// Layout of the iPhone 16 Pro in portrait.
    public static let iPhone16Pro: LayoutConfiguration = .iPhone16Pro(.portrait)

    /// Layout of the iPhone 16 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone16Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_3,
            portraitSafeArea: EdgeInsets(top: 62, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone16Pro
        )
    }

    /// Layout of the iPhone 16 Plus in portrait.
    public static let iPhone16Plus: LayoutConfiguration = .iPhone16Plus(.portrait)

    /// Layout of the iPhone 16 Plus in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone16Plus(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone16Plus
        )
    }

    /// Layout of the iPhone 16 in portrait.
    public static let iPhone16: LayoutConfiguration = .iPhone16(.portrait)

    /// Layout of the iPhone 16 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone16(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone16
        )
    }

    /// Layout of the iPhone 16e in portrait.
    public static let iPhone16e: LayoutConfiguration = .iPhone16e(.portrait)

    /// Layout of the iPhone 16e in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone16e(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone16e
        )
    }
}

// MARK: - iPhone 15
extension LayoutConfiguration {

    /// Layout of the iPhone 15 Pro Max in portrait.
    public static let iPhone15ProMax: LayoutConfiguration = .iPhone15ProMax(.portrait)

    /// Layout of the iPhone 15 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone15ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone15ProMax
        )
    }

    /// Layout of the iPhone 15 Pro in portrait.
    public static let iPhone15Pro: LayoutConfiguration = .iPhone15Pro(.portrait)

    /// Layout of the iPhone 15 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone15Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone15Pro
        )
    }

    /// Layout of the iPhone 15 Plus in portrait.
    public static let iPhone15Plus: LayoutConfiguration = .iPhone15Plus(.portrait)

    /// Layout of the iPhone 15 Plus in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone15Plus(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone15Plus
        )
    }

    /// Layout of the iPhone 15 in portrait.
    public static let iPhone15: LayoutConfiguration = .iPhone15(.portrait)

    /// Layout of the iPhone 15 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone15(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone15
        )
    }
}

// MARK: - iPhone 14
extension LayoutConfiguration {

    /// Layout of the iPhone 14 Pro Max in portrait.
    public static let iPhone14ProMax: LayoutConfiguration = .iPhone14ProMax(.portrait)

    /// Layout of the iPhone 14 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone14ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone14ProMax
        )
    }

    /// Layout of the iPhone 14 Pro in portrait.
    public static let iPhone14Pro: LayoutConfiguration = .iPhone14Pro(.portrait)

    /// Layout of the iPhone 14 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone14Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v2,
            portraitSafeArea: EdgeInsets(top: 59, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone14Pro
        )
    }

    /// Layout of the iPhone 14 Plus in portrait.
    public static let iPhone14Plus: LayoutConfiguration = .iPhone14Plus(.portrait)

    /// Layout of the iPhone 14 Plus in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone14Plus(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone14Plus
        )
    }

    /// Layout of the iPhone 14 in portrait.
    public static let iPhone14: LayoutConfiguration = .iPhone14(.portrait)

    /// Layout of the iPhone 14 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone14(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone14
        )
    }
}

// MARK: - iPhone 13
extension LayoutConfiguration {

    /// Layout of the iPhone 13 Pro Max in portrait.
    public static let iPhone13ProMax: LayoutConfiguration = .iPhone13ProMax(.portrait)

    /// Layout of the iPhone 13 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone13ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone13ProMax
        )
    }

    /// Layout of the iPhone 13 Pro in portrait.
    public static let iPhone13Pro: LayoutConfiguration = .iPhone13Pro(.portrait)

    /// Layout of the iPhone 13 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone13Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone13Pro
        )
    }

    /// Layout of the iPhone 13 in portrait.
    public static let iPhone13: LayoutConfiguration = .iPhone13(.portrait)

    /// Layout of the iPhone 13 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone13(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone13
        )
    }

    /// Layout of the iPhone 13 mini in portrait.
    public static let iPhone13Mini: LayoutConfiguration = .iPhone13Mini(.portrait)

    /// Layout of the iPhone 13 mini in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone13Mini(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_4,
            portraitSafeArea: EdgeInsets(top: 50, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone13Mini
        )
    }
}

// MARK: - iPhone 12
extension LayoutConfiguration {

    /// Layout of the iPhone 12 Pro Max in portrait.
    public static let iPhone12ProMax: LayoutConfiguration = .iPhone12ProMax(.portrait)

    /// Layout of the iPhone 12 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone12ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_7v1,
            portraitSafeArea: EdgeInsets(top: 50, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone12ProMax
        )
    }

    /// Layout of the iPhone 12 Pro in portrait.
    public static let iPhone12Pro: LayoutConfiguration = .iPhone12Pro(.portrait)

    /// Layout of the iPhone 12 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone12Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 50, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone12Pro
        )
    }

    /// Layout of the iPhone 12 in portrait.
    public static let iPhone12: LayoutConfiguration = .iPhone12(.portrait)

    /// Layout of the iPhone 12 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone12(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v1,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone12
        )
    }

    /// Layout of the iPhone 12 mini in portrait.
    public static let iPhone12Mini: LayoutConfiguration = .iPhone12Mini(.portrait)

    /// Layout of the iPhone 12 mini in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone12Mini(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_4,
            portraitSafeArea: EdgeInsets(top: 50, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone12Mini
        )
    }
}

// MARK: - iPhone 11
extension LayoutConfiguration {

    /// Layout of the iPhone 11 Pro Max in portrait.
    public static let iPhone11ProMax: LayoutConfiguration = .iPhone11ProMax(.portrait)

    /// Layout of the iPhone 11 Pro Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone11ProMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_5,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone11ProMax
        )
    }

    /// Layout of the iPhone 11 Pro in portrait.
    public static let iPhone11Pro: LayoutConfiguration = .iPhone11Pro(.portrait)

    /// Layout of the iPhone 11 Pro in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone11Pro(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_8,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone11Pro
        )
    }

    /// Layout of the iPhone 11 in portrait.
    public static let iPhone11: LayoutConfiguration = .iPhone11(.portrait)

    /// Layout of the iPhone 11 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhone11(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v3,
            portraitSafeArea: EdgeInsets(top: 47, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 2,
            deviceInterfaceSizeClass: .iPhone11
        )
    }
}

// MARK: - iPhone X
extension LayoutConfiguration {

    /// Layout of the iPhone XR in portrait.
    public static let iPhoneXR: LayoutConfiguration = .iPhoneXR(.portrait)

    /// Layout of the iPhone XR in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhoneXR(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_1v3,
            portraitSafeArea: EdgeInsets(top: 44, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 2,
            deviceInterfaceSizeClass: .iPhoneXR
        )
    }

    /// Layout of the iPhone XS Max in portrait.
    public static let iPhoneXSMax: LayoutConfiguration = .iPhoneXSMax(.portrait)

    /// Layout of the iPhone XS Max in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhoneXSMax(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen6_5,
            portraitSafeArea: EdgeInsets(top: 44, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhoneXSMax
        )
    }

    /// Layout of the iPhone XS in portrait.
    public static let iPhoneXS: LayoutConfiguration = .iPhoneXS(.portrait)

    /// Layout of the iPhone XS in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhoneXS(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_8,
            portraitSafeArea: EdgeInsets(top: 44, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhoneXS
        )
    }

    /// Layout of the iPhone X in portrait.
    @available(*, deprecated, message: "iPhoneX is not supported by iOS 17 or later.")
    public static let iPhoneX: LayoutConfiguration = .iPhoneX(.portrait)

    /// Layout of the iPhone X in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    @available(*, deprecated, message: "iPhoneX is not supported by iOS 17 or later.")
    public static func iPhoneX(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_8,
            portraitSafeArea: EdgeInsets(top: 44, bottom: 34, right: 0),
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhoneX
        )
    }
}

// MARK: - iPhone 8
extension LayoutConfiguration {

    /// Layout of the iPhone 8 in portrait.
    @available(*, deprecated, message: "iPhone8 is not supported by iOS 17 or later.")
    public static let iPhone8: LayoutConfiguration = .iPhone8(.portrait)

    /// Layout of the iPhone 8 in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    @available(*, deprecated, message: "iPhone8 is not supported by iOS 17 or later.")
    public static func iPhone8(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen4_7,
            portraitSafeArea: EdgeInsets(top: 20),
            landscapeSafeArea: EdgeInsets.zero,
            orientation: orientation,
            displayScale: 2,
            deviceInterfaceSizeClass: .iPhone8
        )
    }

    /// Layout of the iPhone 8 Plus in portrait.
    @available(*, deprecated, message: "iPhone8Plus is not supported by iOS 17 or later.")
    public static let iPhone8Plus: LayoutConfiguration = .iPhone8Plus(.portrait)

    /// Layout of the iPhone 8 Plus in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    @available(*, deprecated, message: "iPhone8Plus is not supported by iOS 17 or later.")
    public static func iPhone8Plus(_ orientation: DeviceOrientation) -> LayoutConfiguration {
        iPhone(
            size: .screen5_5,
            portraitSafeArea: EdgeInsets(top: 20),
            landscapeSafeArea: EdgeInsets.zero,
            orientation: orientation,
            displayScale: 3,
            deviceInterfaceSizeClass: .iPhone8Plus
        )
    }
}

// MARK: - iPhone SE
extension LayoutConfiguration {

    /// Layout of the iPhone SE in portrait.
    public static let iPhoneSE: LayoutConfiguration = .iPhoneSE(.portrait)

    /// Layout of the iPhone SE in the given orientation.
    ///
    /// - Parameter orientation: The device orientation.
    /// - Precondition: `orientation` uses the `.extended` ratio.
    public static func iPhoneSE(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPhone(
            size: .screen4_7,
            portraitSafeArea: EdgeInsets(top: 20),
            landscapeSafeArea: .zero,
            orientation: orientation,
            displayScale: 2,
            deviceInterfaceSizeClass: .iPhoneSE
        )
    }
}

// MARK: - iPhone
extension LayoutConfiguration {

    /// Builds the layout of an iPhone from its screen size and safe areas.
    ///
    /// In landscape the size is reflected, and a left or right inset that was left out falls back to
    /// the top inset of portrait, which is where the notch is.
    ///
    /// - Precondition: The ratio of `orientation` is `.extended`.
    fileprivate static func iPhone(
        size: CGSize,
        portraitSafeArea: EdgeInsets,
        landscapeSafeArea: EdgeInsets = .init(bottom: 21),
        orientation: DeviceOrientation,
        displayScale: CGFloat,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> LayoutConfiguration {
        let safeArea: UIEdgeInsets
        let screenSize: CGSize

        switch orientation {
        case .portrait(let ratio):
            precondition(ratio == .extended)

            safeArea = .init(
                top: portraitSafeArea.top ?? .zero,
                left: portraitSafeArea.left ?? .zero,
                bottom: portraitSafeArea.bottom ?? .zero,
                right: portraitSafeArea.right ?? .zero
            )
            screenSize = size
        case .landscape(let ratio):
            precondition(ratio == .extended)

            safeArea = UIEdgeInsets(
                top: landscapeSafeArea.top ?? .zero,
                left: landscapeSafeArea.left ?? portraitSafeArea.top ?? .zero,
                bottom: landscapeSafeArea.bottom ?? 21,
                right: landscapeSafeArea.right ?? portraitSafeArea.top ?? .zero
            )
            screenSize = size.reflected()
        }

        return .init(
            safeArea: safeArea,
            size: screenSize,
            traits: .iOS(
                displayScale: displayScale,
                size: screenSize,
                deviceInterfaceSizeClass: deviceInterfaceSizeClass
            )
        )
    }
}

// MARK: - iPad Pro
extension LayoutConfiguration {

    /// Layout of the iPad Pro 12.9-inch in landscape.
    public static let iPadPro12_9 = iPadPro12_9(.landscape)

    /// Layout of the iPad Pro 12.9-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadPro12_9(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 1_024, height: 1_366),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Pro 11-inch in landscape.
    public static let iPadPro11 = iPadPro11(.landscape)

    /// Layout of the iPad Pro 11-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadPro11(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 834, height: 1_194),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Pro 10.5-inch in landscape.
    @available(*, deprecated, message: "iPadPro10_5 is not supported by iPadOS 17 or later.")
    public static let iPadPro10_5 = iPadPro10_5(.landscape)

    /// Layout of the iPad Pro 10.5-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    @available(*, deprecated, message: "iPadPro10_5 is not supported by iPadOS 17 or later.")
    public static func iPadPro10_5(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 834, height: 1_194),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Pro 9.7-inch in landscape.
    @available(*, deprecated, message: "iPadPro9_7 is not supported by iPadOS 17 or later.")
    public static let iPadPro9_7 = iPadPro9_7(.landscape)

    /// Layout of the iPad Pro 9.7-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    @available(*, deprecated, message: "iPadPro9_7 is not supported by iPadOS 17 or later.")
    public static func iPadPro9_7(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 768, height: 1_024),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }
}

// MARK: - iPad Pro (M4, M5)
extension LayoutConfiguration {

    public static let iPadPro13 = iPadPro13(.landscape)

    public static func iPadPro13(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 1_032, height: 1_376),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    public static let iPadPro11v2 = iPadPro11v2(.landscape)

    public static func iPadPro11v2(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 834, height: 1_210),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }
}

// MARK: - iPad Air
extension LayoutConfiguration {

    /// Layout of the iPad Air 13-inch in landscape.
    public static let iPadAir13 = iPadAir13(.landscape)

    /// Layout of the iPad Air 13-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadAir13(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 1_024, height: 1_366),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Air 11-inch in landscape.
    public static let iPadAir11 = iPadAir11(.landscape)

    /// Layout of the iPad Air 11-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadAir11(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 820, height: 1_180),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Air 10.9-inch in landscape.
    public static let iPadAir10_9 = iPadAir10_9(.landscape)

    /// Layout of the iPad Air 10.9-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadAir10_9(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 820, height: 1_180),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Air 10.5-inch in landscape.
    public static let iPadAir10_5 = iPadAir10_5(.landscape)

    /// Layout of the iPad Air 10.5-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadAir10_5(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 820, height: 1_180),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad Air 9.7-inch in landscape.
    @available(*, deprecated, message: "iPadAir9_7 is not supported by iPadOS 17 or later.")
    public static let iPadAir9_7 = iPadAir9_7(.landscape)

    /// Layout of the iPad Air 9.7-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    @available(*, deprecated, message: "iPadAir9_7 is not supported by iPadOS 17 or later.")
    public static func iPadAir9_7(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 768, height: 1_024),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }
}

// MARK: - iPad
extension LayoutConfiguration {

    /// Layout of the iPad 11-inch in landscape.
    public static let iPad11 = iPad11(.landscape)

    /// Layout of the iPad 11-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPad11(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 820, height: 1_180),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad 10.2-inch in landscape.
    public static let iPad10_2 = iPad10_2(.landscape)

    /// Layout of the iPad 10.2-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPad10_2(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 810, height: 1_080),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad 9.7-inch in landscape.
    @available(*, deprecated, message: "iPad9_7 is not supported by iPadOS 17 or later.")
    public static let iPad9_7 = iPad9_7(.landscape)

    /// Layout of the iPad 9.7-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    @available(*, deprecated, message: "iPad9_7 is not supported by iPadOS 17 or later.")
    public static func iPad9_7(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 768, height: 1_024),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }
}

// MARK: - iPad Mini
extension LayoutConfiguration {

    /// Layout of the iPad mini 8.3-inch in landscape.
    public static let iPadMini8_3 = iPadMini8_3(.landscape)

    /// Layout of the iPad mini 8.3-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadMini8_3(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 744, height: 1_133),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }

    /// Layout of the iPad mini 7.9-inch in landscape.
    public static let iPadMini7_9 = iPadMini7_9(.landscape)

    /// Layout of the iPad mini 7.9-inch in the given orientation.
    ///
    /// - Parameter orientation: The device orientation. Its ratio scales the width,
    ///   so `.landscape(.medium)` renders at half the full landscape width.
    public static func iPadMini7_9(
        _ orientation: DeviceOrientation
    ) -> LayoutConfiguration {
        iPad(
            orientation: orientation,
            size: CGSize(width: 768, height: 1_024),
            displayScale: 2,
            deviceInterfaceSizeClass: .iPadOS
        )
    }
}

// MARK: - iPad Method
extension LayoutConfiguration {

    /// Builds the layout of an iPad.
    ///
    /// The width is multiplied by the ratio of `orientation`. The safe area is 24 points at the top
    /// and 20 at the bottom.
    fileprivate static func iPad(
        orientation: DeviceOrientation,
        size: CGSize,
        displayScale: CGFloat,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> LayoutConfiguration {
        var deviceSize: CGSize
        let deviceRatio: DeviceLayoutRatio

        switch orientation {
        case .landscape(let ratio):
            deviceRatio = ratio
            deviceSize = size.reflected()
        case .portrait(let ratio):
            deviceRatio = ratio
            deviceSize = size
        }

        deviceSize.width *= deviceRatio.rawValue

        return LayoutConfiguration(
            safeArea: UIEdgeInsets(top: 24, left: .zero, bottom: 20, right: .zero),
            size: deviceSize,
            traits: .iPadOS(
                displayScale: displayScale,
                size: deviceSize,
                deviceInterfaceSizeClass: deviceInterfaceSizeClass
            )
        )
    }
}

extension LayoutConfiguration {

    /// Layout of an Apple TV in Full HD: 1920×1080 points at 1× scale.
    public static let tv = tvOS(
        displayScale: 1,
        deviceInterfaceSizeClass: .tvOS
    )

    /// Layout of an Apple TV 4K: 1920×1080 points at 2× scale.
    public static let tv4K = tvOS(
        displayScale: 2,
        deviceInterfaceSizeClass: .tvOS
    )

    /// Builds the layout of an Apple TV: 1920×1080 points with a safe area of 60 points at the top
    /// and bottom and 80 at the sides.
    private static func tvOS(
        displayScale: CGFloat,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> LayoutConfiguration {
        let size = CGSize(width: 1920, height: 1080)

        return LayoutConfiguration(
            safeArea: .init(top: 60, left: 80, bottom: 60, right: 80),
            size: size,
            traits: .tvOS(
                displayScale: displayScale,
                size: size,
                deviceInterfaceSizeClass: deviceInterfaceSizeClass
            )
        )
    }
}
#endif
#endif
