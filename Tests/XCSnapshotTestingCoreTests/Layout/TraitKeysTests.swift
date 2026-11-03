// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(visionOS)
import Testing
import UIKit

@_spi(Internals) @testable import XCSnapshotTesting

/// Every trait is set through its own key, which reads it back from `Traits`, writes it into a trait
/// collection and, on iOS 17 and later, into the trait overrides of a view controller.
@MainActor
@Suite("Trait keys")
struct TraitKeysTests {

    /// Sets `value` with `make`, then reads it back from the traits, from the trait collection they
    /// produce and from the overrides they commit to a view controller.
    @available(iOS 17, tvOS 17, *)
    private func expectRoundTrip<Value: Equatable>(
        _ value: Value,
        make: (Value) -> Traits,
        stored: KeyPath<Traits, Value>,
        collection: KeyPath<UITraitCollection, Value>,
        overrides: KeyPath<UITraitOverrides, Value>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let traits = make(value)
        #expect(traits[keyPath: stored] == value, sourceLocation: sourceLocation)
        #expect(traits()[keyPath: collection] == value, sourceLocation: sourceLocation)

        let viewController = UIViewController()
        traits.commit(in: viewController)
        #expect(viewController.traitOverrides[keyPath: overrides] == value, sourceLocation: sourceLocation)
    }

    @Test func accessibilityContrast() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIAccessibilityContrast.high,
            make: { Traits(accessibilityContrast: $0) },
            stored: \.accessibilityContrast,
            collection: \.accessibilityContrast,
            overrides: \.accessibilityContrast
        )
    }

    @Test func preferredContentSizeCategory() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIContentSizeCategory.accessibilityExtraLarge,
            make: { Traits(preferredContentSizeCategory: $0) },
            stored: \.preferredContentSizeCategory,
            collection: \.preferredContentSizeCategory,
            overrides: \.preferredContentSizeCategory
        )
    }

    @Test func displayGamut() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIDisplayGamut.P3,
            make: { Traits(displayGamut: $0) },
            stored: \.displayGamut,
            collection: \.displayGamut,
            overrides: \.displayGamut
        )
    }

    @Test func displayScale() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            CGFloat(3),
            make: { Traits(displayScale: $0) },
            stored: \.displayScale,
            collection: \.displayScale,
            overrides: \.displayScale
        )
    }

    @Test func forceTouchCapability() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIForceTouchCapability.available,
            make: { Traits(forceTouchCapability: $0) },
            stored: \.forceTouchCapability,
            collection: \.forceTouchCapability,
            overrides: \.forceTouchCapability
        )
    }

    @Test func layoutDirection() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UITraitEnvironmentLayoutDirection.rightToLeft,
            make: { Traits(layoutDirection: $0) },
            stored: \.layoutDirection,
            collection: \.layoutDirection,
            overrides: \.layoutDirection
        )
    }

    @Test func legibilityWeight() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UILegibilityWeight.bold,
            make: { Traits(legibilityWeight: $0) },
            stored: \.legibilityWeight,
            collection: \.legibilityWeight,
            overrides: \.legibilityWeight
        )
    }

    @Test func activeAppearance() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIUserInterfaceActiveAppearance.inactive,
            make: { Traits(activeAppearance: $0) },
            stored: \.activeAppearance,
            collection: \.activeAppearance,
            overrides: \.activeAppearance
        )
    }

    @Test func userInterfaceStyle() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIUserInterfaceStyle.dark,
            make: { Traits(userInterfaceStyle: $0) },
            stored: \.userInterfaceStyle,
            collection: \.userInterfaceStyle,
            overrides: \.userInterfaceStyle
        )
    }

    @Test func typesettingLanguage() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            Locale.Language(identifier: "ar") as Locale.Language?,
            make: { Traits(typesettingLanguage: $0) },
            stored: \.typesettingLanguage,
            collection: \.typesettingLanguage,
            overrides: \.typesettingLanguage
        )
    }

    @Test func imageDynamicRange() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIImage.DynamicRange.high,
            make: { Traits(imageDynamicRange: $0) },
            stored: \.imageDynamicRange,
            collection: \.imageDynamicRange,
            overrides: \.imageDynamicRange
        )
    }

    @Test func sceneCaptureState() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UISceneCaptureState.active,
            make: { Traits(sceneCaptureState: $0) },
            stored: \.sceneCaptureState,
            collection: \.sceneCaptureState,
            overrides: \.sceneCaptureState
        )
    }

    @Test func toolbarItemPresentationSize() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UINSToolbarItemPresentationSize.small,
            make: { Traits(toolbarItemPresentationSize: $0) },
            stored: \.toolbarItemPresentationSize,
            collection: \.toolbarItemPresentationSize,
            overrides: \.toolbarItemPresentationSize
        )
    }

    @Test func listEnvironment() {
        guard #available(iOS 18, tvOS 18, visionOS 2, *) else { return }
        expectRoundTrip(
            UIListEnvironment.grouped,
            make: { Traits(listEnvironment: $0) },
            stored: \.listEnvironment,
            collection: \.listEnvironment,
            overrides: \.listEnvironment
        )
    }

    #if !os(tvOS)
    @Test func userInterfaceLevel() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        expectRoundTrip(
            UIUserInterfaceLevel.elevated,
            make: { Traits(userInterfaceLevel: $0) },
            stored: \.userInterfaceLevel,
            collection: \.userInterfaceLevel,
            overrides: \.userInterfaceLevel
        )
    }
    #endif

    @Test func userInterfaceIdiom() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        let traits = Traits(userInterfaceIdiom: .pad)

        #expect(traits.userInterfaceIdiom == .pad)
        #expect(traits()[keyPath: \.userInterfaceIdiom] == .pad)
    }

    @Test func mergedTraitsKeepTheLaterValueOfEachKey() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        let merged = Traits(userInterfaceStyle: .dark)
            .merging(Traits(userInterfaceStyle: .light))
            .merging(Traits(legibilityWeight: .bold))

        #expect(merged.userInterfaceStyle == .light)
        #expect(merged.legibilityWeight == .bold)
    }

    @Test func traitsWithTheSameValuesAreEqualAndHashTheSame() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        let first = Traits(userInterfaceStyle: .dark).merging(Traits(legibilityWeight: .bold))
        let second = Traits(legibilityWeight: .bold).merging(Traits(userInterfaceStyle: .dark))

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(first != Traits(userInterfaceStyle: .dark))
    }

    @Test func aTraitLeftUnsetKeepsItsDefault() {
        guard #available(iOS 17, tvOS 17, *) else { return }
        #expect(Traits().userInterfaceStyle == .unspecified)
        #expect(Traits().displayScale == 1)
    }
}
#endif
