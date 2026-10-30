// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreGraphics
import Testing
import UIKit

@_spi(Internals) @testable import XCSnapshotTesting

/// Pins the view to the safe area, so the safe area configured by a device layout can be measured.
@MainActor
private final class SafeAreaViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Swatch.red.color

        let content = UIView()
        content.backgroundColor = Swatch.green.color
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])
    }
}

/// Remembers the trait collection the view ended up with once it was laid out inside the snapshot.
@MainActor
private final class TraitRecorder: UIView {

    private(set) var recorded: UITraitCollection?

    override var intrinsicContentSize: CGSize { CGSize(width: 40, height: 40) }

    override func layoutSubviews() {
        super.layoutSubviews()
        recorded = traitCollection
    }
}

/// Remembers the trait collection it received once it was laid out as a child of another controller.
@MainActor
private final class TraitRecordingViewController: UIViewController {

    private(set) var recorded: UITraitCollection?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        recorded = traitCollection
    }
}

/// Changes color with the interface style, so the style shows up in the pixels.
@MainActor
private final class DynamicColorView: UIView {

    override var intrinsicContentSize: CGSize { CGSize(width: 40, height: 40) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor {
            $0.userInterfaceStyle == .dark ? Swatch.blue.color : Swatch.red.color
        }
    }

    required init?(coder: NSCoder) { nil }
}

@MainActor
@Suite("Device layouts", .serialized)
struct DeviceLayoutTests {

    private typealias Strategy = AsyncSnapshot<ColorViewController, ImageBytes>

    @Test func aDeviceLayoutRendersAtTheScreenSizeOfTheDevice() async throws {
        let device = LayoutConfiguration.iPhoneSE

        let rendered = try await render(Strategy.image(layout: .device(device)), ColorViewController(.red))

        #expect(rendered.size == device.size)
        #expect(rendered.swatch(x: rendered.size.width / 2, y: rendered.size.height / 2) == .red)
    }

    /// A device layout larger than the screen of the machine running the test is scaled down to fit it, so
    /// the size of the image depends on the simulator. What stays true is the aspect ratio of the device.
    private func expectScaledLikeTheDevice(_ rendered: Rendered, _ device: CGSize) {
        #expect(rendered.size.width <= device.width + 0.5)
        #expect(rendered.size.height <= device.height + 0.5)
        #expect(abs(rendered.size.width / rendered.size.height - device.width / device.height) < 0.01)
    }

    @Test func landscapeSwapsTheDimensions() async throws {
        let portrait = try #require(LayoutConfiguration.iPhoneSE.size)

        let rendered = try await render(
            Strategy.image(layout: .device(.iPhoneSE(.landscape))),
            ColorViewController(.red)
        )

        #expect(rendered.size.width > rendered.size.height)
        expectScaledLikeTheDevice(rendered, CGSize(width: portrait.height, height: portrait.width))
    }

    @Test func tabletsHaveTheirOwnProportions() async throws {
        let device = try #require(LayoutConfiguration.iPadMini8_3.size)

        let rendered = try await render(
            Strategy.image(layout: .device(.iPadMini8_3)),
            ColorViewController(.blue)
        )

        expectScaledLikeTheDevice(rendered, device)
        #expect(rendered.swatch(x: rendered.size.width / 2, y: rendered.size.height / 2) == .blue)
    }

    @Test func theSafeAreaOfTheDeviceInsetsTheContent() async throws {
        let device = LayoutConfiguration.iPhoneXS
        let inset = device.safeArea
        #expect(inset.top > 0 && inset.bottom > 0, "this device has a notch and a home indicator")

        let rendered = try await render(
            AsyncSnapshot<SafeAreaViewController, ImageBytes>.image(layout: .device(device)),
            SafeAreaViewController()
        )

        // The safe area of the machine running the test can add to the one of the device layout, and the
        // rendering rounds to pixels, so the content is only required to stay out of the configured insets by
        // more than half of them, and the bands outside it to be red.
        let middle = rendered.size.width / 2
        let rows = Array(0..<Int(rendered.size.height))
        let green = rows.filter { rendered.swatch(x: middle, y: CGFloat($0)) == .green }
        let scale = rendered.size.height / (device.size?.height ?? rendered.size.height)

        let firstGreen = try #require(green.first, "size \(rendered.size)")
        let lastGreen = try #require(green.last)
        let context = "size \(rendered.size), green rows \(firstGreen)...\(lastGreen), insets \(inset)"
        #expect(CGFloat(firstGreen) >= inset.top * scale / 2, "the content starts below the top inset: \(context)")
        #expect(
            CGFloat(lastGreen) <= rendered.size.height - inset.bottom * scale / 2,
            "the content ends above the bottom inset: \(context)"
        )
        #expect(rendered.swatch(x: middle, y: 2) == .red, "the top inset is outside the content: \(context)")
        #expect(
            rendered.swatch(x: middle, y: rendered.size.height - 2) == .red,
            "the bottom inset is outside the content: \(context)"
        )
    }

    @Test func aFixedLayoutHasNoSafeArea() async throws {
        let rendered = try await render(
            AsyncSnapshot<SafeAreaViewController, ImageBytes>.image(layout: .fixed(width: 100, height: 100)),
            SafeAreaViewController()
        )

        #expect(rendered.swatch(x: 50, y: 2) == .green, "without a safe area the content fills the view")
        #expect(rendered.swatch(x: 2, y: 50) == .green)
    }
}

@MainActor
@Suite("Traits", .serialized)
struct TraitsTests {

    private func recordedTraits(_ traits: Traits) async throws -> UITraitCollection {
        let view = TraitRecorder()

        _ = try await render(
            AsyncSnapshot<TraitRecorder, ImageBytes>.image(layout: .sizeThatFits, traits: traits),
            view
        )

        return try #require(view.recorded)
    }

    // MARK: - Applied to a render

    @Test func theUserInterfaceStyleReachesTheView() async throws {
        #expect(try await recordedTraits(Traits(userInterfaceStyle: .dark)).userInterfaceStyle == .dark)
        #expect(try await recordedTraits(Traits(userInterfaceStyle: .light)).userInterfaceStyle == .light)
    }

    @Test func theInterfaceStyleChangesTheRenderedColors() async throws {
        let light = try await render(
            AsyncSnapshot<DynamicColorView, ImageBytes>.image(
                layout: .sizeThatFits,
                traits: Traits(userInterfaceStyle: .light)
            ),
            DynamicColorView()
        )
        let dark = try await render(
            AsyncSnapshot<DynamicColorView, ImageBytes>.image(
                layout: .sizeThatFits,
                traits: Traits(userInterfaceStyle: .dark)
            ),
            DynamicColorView()
        )

        #expect(light.swatch(x: 20, y: 20) == .red)
        #expect(dark.swatch(x: 20, y: 20) == .blue)
    }

    @Test func theLayoutDirectionReachesTheView() async throws {
        #expect(try await recordedTraits(Traits(layoutDirection: .rightToLeft)).layoutDirection == .rightToLeft)
    }

    @Test func theContentSizeCategoryReachesTheView() async throws {
        let traits = Traits(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)

        #expect(try await recordedTraits(traits).preferredContentSizeCategory == .accessibilityExtraExtraExtraLarge)
    }

    @Test func accessibilityTraitsReachTheView() async throws {
        #expect(try await recordedTraits(Traits(legibilityWeight: .bold)).legibilityWeight == .bold)
        #expect(try await recordedTraits(Traits(accessibilityContrast: .high)).accessibilityContrast == .high)
    }

    @Test func theDisplayScaleReachesTheView() async throws {
        #expect(try await recordedTraits(Traits(displayScale: 2)).displayScale == 2)
    }

    @Test func mergedTraitsApplyTogether() async throws {
        let traits = Traits(userInterfaceStyle: .dark).merging(Traits(layoutDirection: .rightToLeft))

        let recorded = try await recordedTraits(traits)

        #expect(recorded.userInterfaceStyle == .dark)
        #expect(recorded.layoutDirection == .rightToLeft)
    }

    // MARK: - As a trait collection

    @Test func traitsConvertToATraitCollection() {
        let collection = Traits(userInterfaceStyle: .dark).merging(Traits(displayScale: 3))()

        #expect(collection.userInterfaceStyle == .dark)
        #expect(collection.displayScale == 3)
    }

    @Test func everyTraitIsConvertedToItsTraitCollectionValue() {
        #expect(Traits(userInterfaceIdiom: .pad)().userInterfaceIdiom == .pad)
        #expect(Traits(layoutDirection: .rightToLeft)().layoutDirection == .rightToLeft)
        #expect(Traits(legibilityWeight: .bold)().legibilityWeight == .bold)
        #expect(Traits(accessibilityContrast: .high)().accessibilityContrast == .high)
        #expect(Traits(displayGamut: .P3)().displayGamut == .P3)
        #expect(Traits(forceTouchCapability: .available)().forceTouchCapability == .available)
        #expect(Traits(userInterfaceLevel: .elevated)().userInterfaceLevel == .elevated)
        #expect(Traits(preferredContentSizeCategory: .large)().preferredContentSizeCategory == .large)
        #expect(Traits(activeAppearance: .inactive)().activeAppearance == .inactive)
    }

    @Test func traitsAreEquatableAndLaterOnesWinWhenMerged() {
        #expect(Traits() == Traits())
        #expect(Traits(userInterfaceStyle: .dark) != Traits())
        #expect(Traits(userInterfaceStyle: .dark).hashValue == Traits(userInterfaceStyle: .dark).hashValue)

        let merged = Traits(userInterfaceStyle: .dark).merging(Traits(userInterfaceStyle: .light))
        #expect(merged.userInterfaceStyle == .light)
    }

    @Test func untouchedTraitsKeepTheirDefaultValue() {
        let traits = Traits()

        #expect(traits.userInterfaceStyle == .unspecified)
        #expect(traits.layoutDirection == .unspecified)
        #expect(traits.displayScale == 1)
    }

    @Test func traitsReachControllersEmbeddedInATabBarController() async throws {
        let child = TraitRecordingViewController()
        let tabs = UITabBarController()
        tabs.viewControllers = [child]

        _ = try await render(
            AsyncSnapshot<UITabBarController, ImageBytes>.image(
                layout: .fixed(width: 200, height: 300),
                traits: Traits(userInterfaceStyle: .dark)
            ),
            tabs
        )

        #expect(child.recorded?.userInterfaceStyle == .dark)
    }

    @Test func theHierarchyDescribesTheViewControllerTree() async throws {
        let description = try await AsyncSnapshot<ColorViewController, StringBytes>.hierarchy
            .executor(ColorViewController(.red)).rawValue

        #expect(description.contains("ColorViewController"))
        #expect(!description.contains("0x"))
    }
}
#endif
