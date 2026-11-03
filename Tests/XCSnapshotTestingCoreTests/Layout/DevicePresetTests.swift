// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(visionOS)
import CoreGraphics
import Testing
import UIKit

@_spi(Internals) @testable import XCSnapshotTesting

/// The device presets only set values, so they are checked without rendering anything. Each one is
/// built in every orientation it supports, which also runs the shared builders behind them.
@Suite("Device presets")
struct DevicePresetTests {

    struct Preset: Sendable, CustomTestStringConvertible {
        let name: String
        let defaultOrientation: DeviceOrientation
        let preset: LayoutConfiguration
        let make: @Sendable (DeviceOrientation) -> LayoutConfiguration

        var testDescription: String { name }
    }

    static let presets: [Preset] = [
        Preset(name: "iPhoneDuo", defaultOrientation: .portrait, preset: .iPhoneDuo, make: { .iPhoneDuo($0) }),
        Preset(
            name: "iPhoneDuoUnfolded",
            defaultOrientation: .landscape,
            preset: .iPhoneDuoUnfolded,
            make: { .iPhoneDuoUnfolded($0) }
        ),
        Preset(
            name: "iPhone18ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone18ProMax,
            make: { .iPhone18ProMax($0) }
        ),
        Preset(name: "iPhone18Pro", defaultOrientation: .portrait, preset: .iPhone18Pro, make: { .iPhone18Pro($0) }),
        Preset(name: "iPhone17e", defaultOrientation: .portrait, preset: .iPhone17e, make: { .iPhone17e($0) }),
        Preset(
            name: "iPhone17ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone17ProMax,
            make: { .iPhone17ProMax($0) }
        ),
        Preset(name: "iPhone17Pro", defaultOrientation: .portrait, preset: .iPhone17Pro, make: { .iPhone17Pro($0) }),
        Preset(name: "iPhone17", defaultOrientation: .portrait, preset: .iPhone17, make: { .iPhone17($0) }),
        Preset(name: "iPhoneAir", defaultOrientation: .portrait, preset: .iPhoneAir, make: { .iPhoneAir($0) }),
        Preset(
            name: "iPhone16ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone16ProMax,
            make: { .iPhone16ProMax($0) }
        ),
        Preset(name: "iPhone16Pro", defaultOrientation: .portrait, preset: .iPhone16Pro, make: { .iPhone16Pro($0) }),
        Preset(name: "iPhone16Plus", defaultOrientation: .portrait, preset: .iPhone16Plus, make: { .iPhone16Plus($0) }),
        Preset(name: "iPhone16", defaultOrientation: .portrait, preset: .iPhone16, make: { .iPhone16($0) }),
        Preset(name: "iPhone16e", defaultOrientation: .portrait, preset: .iPhone16e, make: { .iPhone16e($0) }),
        Preset(
            name: "iPhone15ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone15ProMax,
            make: { .iPhone15ProMax($0) }
        ),
        Preset(name: "iPhone15Pro", defaultOrientation: .portrait, preset: .iPhone15Pro, make: { .iPhone15Pro($0) }),
        Preset(name: "iPhone15Plus", defaultOrientation: .portrait, preset: .iPhone15Plus, make: { .iPhone15Plus($0) }),
        Preset(name: "iPhone15", defaultOrientation: .portrait, preset: .iPhone15, make: { .iPhone15($0) }),
        Preset(
            name: "iPhone14ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone14ProMax,
            make: { .iPhone14ProMax($0) }
        ),
        Preset(name: "iPhone14Pro", defaultOrientation: .portrait, preset: .iPhone14Pro, make: { .iPhone14Pro($0) }),
        Preset(name: "iPhone14Plus", defaultOrientation: .portrait, preset: .iPhone14Plus, make: { .iPhone14Plus($0) }),
        Preset(name: "iPhone14", defaultOrientation: .portrait, preset: .iPhone14, make: { .iPhone14($0) }),
        Preset(
            name: "iPhone13ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone13ProMax,
            make: { .iPhone13ProMax($0) }
        ),
        Preset(name: "iPhone13Pro", defaultOrientation: .portrait, preset: .iPhone13Pro, make: { .iPhone13Pro($0) }),
        Preset(name: "iPhone13", defaultOrientation: .portrait, preset: .iPhone13, make: { .iPhone13($0) }),
        Preset(name: "iPhone13Mini", defaultOrientation: .portrait, preset: .iPhone13Mini, make: { .iPhone13Mini($0) }),
        Preset(
            name: "iPhone12ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone12ProMax,
            make: { .iPhone12ProMax($0) }
        ),
        Preset(name: "iPhone12Pro", defaultOrientation: .portrait, preset: .iPhone12Pro, make: { .iPhone12Pro($0) }),
        Preset(name: "iPhone12", defaultOrientation: .portrait, preset: .iPhone12, make: { .iPhone12($0) }),
        Preset(name: "iPhone12Mini", defaultOrientation: .portrait, preset: .iPhone12Mini, make: { .iPhone12Mini($0) }),
        Preset(
            name: "iPhone11ProMax",
            defaultOrientation: .portrait,
            preset: .iPhone11ProMax,
            make: { .iPhone11ProMax($0) }
        ),
        Preset(name: "iPhone11Pro", defaultOrientation: .portrait, preset: .iPhone11Pro, make: { .iPhone11Pro($0) }),
        Preset(name: "iPhone11", defaultOrientation: .portrait, preset: .iPhone11, make: { .iPhone11($0) }),
        Preset(name: "iPhoneXR", defaultOrientation: .portrait, preset: .iPhoneXR, make: { .iPhoneXR($0) }),
        Preset(name: "iPhoneXSMax", defaultOrientation: .portrait, preset: .iPhoneXSMax, make: { .iPhoneXSMax($0) }),
        Preset(name: "iPhoneXS", defaultOrientation: .portrait, preset: .iPhoneXS, make: { .iPhoneXS($0) }),
        Preset(name: "iPhoneX", defaultOrientation: .portrait, preset: .iPhoneX, make: { .iPhoneX($0) }),
        Preset(name: "iPhone8", defaultOrientation: .portrait, preset: .iPhone8, make: { .iPhone8($0) }),
        Preset(name: "iPhone8Plus", defaultOrientation: .portrait, preset: .iPhone8Plus, make: { .iPhone8Plus($0) }),
        Preset(name: "iPhoneSE", defaultOrientation: .portrait, preset: .iPhoneSE, make: { .iPhoneSE($0) }),
        Preset(name: "iPadPro12_9", defaultOrientation: .landscape, preset: .iPadPro12_9, make: { .iPadPro12_9($0) }),
        Preset(name: "iPadPro11", defaultOrientation: .landscape, preset: .iPadPro11, make: { .iPadPro11($0) }),
        Preset(name: "iPadPro10_5", defaultOrientation: .landscape, preset: .iPadPro10_5, make: { .iPadPro10_5($0) }),
        Preset(name: "iPadPro9_7", defaultOrientation: .landscape, preset: .iPadPro9_7, make: { .iPadPro9_7($0) }),
        Preset(name: "iPadPro13", defaultOrientation: .landscape, preset: .iPadPro13, make: { .iPadPro13($0) }),
        Preset(name: "iPadPro11v2", defaultOrientation: .landscape, preset: .iPadPro11v2, make: { .iPadPro11v2($0) }),
        Preset(name: "iPadAir13", defaultOrientation: .landscape, preset: .iPadAir13, make: { .iPadAir13($0) }),
        Preset(name: "iPadAir11", defaultOrientation: .landscape, preset: .iPadAir11, make: { .iPadAir11($0) }),
        Preset(name: "iPadAir10_9", defaultOrientation: .landscape, preset: .iPadAir10_9, make: { .iPadAir10_9($0) }),
        Preset(name: "iPadAir10_5", defaultOrientation: .landscape, preset: .iPadAir10_5, make: { .iPadAir10_5($0) }),
        Preset(name: "iPadAir9_7", defaultOrientation: .landscape, preset: .iPadAir9_7, make: { .iPadAir9_7($0) }),
        Preset(name: "iPad11", defaultOrientation: .landscape, preset: .iPad11, make: { .iPad11($0) }),
        Preset(name: "iPad10_2", defaultOrientation: .landscape, preset: .iPad10_2, make: { .iPad10_2($0) }),
        Preset(name: "iPad9_7", defaultOrientation: .landscape, preset: .iPad9_7, make: { .iPad9_7($0) }),
        Preset(name: "iPadMini8_3", defaultOrientation: .landscape, preset: .iPadMini8_3, make: { .iPadMini8_3($0) }),
        Preset(name: "iPadMini7_9", defaultOrientation: .landscape, preset: .iPadMini7_9, make: { .iPadMini7_9($0) }),
    ]

    @Test(arguments: presets)
    func thePresetIsThePortraitOrLandscapeLayoutByDefault(_ preset: Preset) throws {
        let expected = preset.make(preset.defaultOrientation)

        #expect(preset.preset.size == expected.size)
        #expect(preset.preset.safeArea == expected.safeArea)
    }

    @Test(arguments: presets)
    func landscapeIsThePortraitSizeReflected(_ preset: Preset) throws {
        let portrait = try #require(preset.make(.portrait).size)
        let landscape = try #require(preset.make(.landscape).size)

        #expect(portrait.width > 0 && portrait.height > 0)
        #expect(portrait.width < portrait.height)
        #expect(landscape == CGSize(width: portrait.height, height: portrait.width))
    }

    @Test(arguments: presets)
    func everyPresetHasASafeAreaThatFitsInsideItsScreen(_ preset: Preset) throws {
        for orientation in [DeviceOrientation.portrait, .landscape] {
            let layout = preset.make(orientation)
            let size = try #require(layout.size)

            #expect(layout.safeArea.top >= 0 && layout.safeArea.bottom >= 0)
            #expect(layout.safeArea.left >= 0 && layout.safeArea.right >= 0)
            #expect(layout.safeArea.top + layout.safeArea.bottom < size.height)
            #expect(layout.safeArea.left + layout.safeArea.right < size.width)
        }
    }

    @Test(arguments: presets.filter { $0.name.hasPrefix("iPad") })
    func theRatioOfAnIPadOrientationScalesTheWidth(_ preset: Preset) throws {
        let full = try #require(preset.make(.landscape(.extended)).size)
        let half = try #require(preset.make(.landscape(.medium)).size)
        let compact = try #require(preset.make(.portrait(.compact)).size)
        let portrait = try #require(preset.make(.portrait(.extended)).size)

        #expect(half.height == full.height)
        #expect(half.width == full.width * 0.5)
        #expect(compact.height == portrait.height)
        #expect(compact.width == portrait.width / 3)
    }
}

#if os(tvOS) || os(iOS) || os(visionOS)
extension DevicePresetTests {

    @Test func theAppleTVPresetsAreFullHDWithTheTelevisionSafeArea() throws {
        for layout in [LayoutConfiguration.tv, .tv4K] {
            #expect(layout.size == CGSize(width: 1920, height: 1080))
            #expect(layout.safeArea == UIEdgeInsets(top: 60, left: 80, bottom: 60, right: 80))
        }
    }

    @Test func theAppleTV4KPresetHasTheTraitsOfADoubleScaleDisplay() {
        #expect(LayoutConfiguration.tv.traits != LayoutConfiguration.tv4K.traits)
    }
}
#endif
#endif
