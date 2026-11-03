// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
/// A trait that ``Traits`` can store: its default value, and how to apply a value to UIKit.
protocol TraitKey: Sendable, Hashable {

    associatedtype Value: Hashable & Sendable

    static var defaultValue: Value { get }

    /// Applies `value` through the trait overrides of a view controller, on iOS 17 and later.
    @available(iOS 17, tvOS 17, *)
    @MainActor
    static func apply(_ value: Value, to traitsOverrides: inout UITraitOverrides)

    /// Applies `value` to a trait collection, for the versions that have no trait overrides.
    @MainActor
    static func apply(_ value: Value, to traitCollection: inout UITraitCollection)
}

/// The traits that a UI snapshot is rendered with, such as the content size category or the user interface style.
///
/// ```swift
/// try await assert(
///     of: view,
///     as: .image(traits: Traits(preferredContentSizeCategory: .extraLarge))
/// )
/// ```
///
/// Traits set in the environment apply to every snapshot, and the ones passed to a strategy win over them.
public struct Traits: Sendable, Hashable {

    private var traits = [ObjectIdentifier: Storage]()

    /// Creates a default `Traits` instance with no specific characteristics set.
    public init() {}

    /// Creates a `Traits` instance from several instances, merged in order.
    ///
    /// When two of them set the same trait, the later one wins.
    public init(traitsFrom traitCollection: [Traits]) {
        self.init(
            traitCollection.lazy.map(\.traits).reduce([:]) {
                $0.merging($1, uniquingKeysWith: { $1 })
            }
        )
    }

    private init(_ traits: [ObjectIdentifier: Storage]) {
        self.traits = traits
    }

    subscript<Key: TraitKey>(_ key: Key.Type) -> Key.Value {
        get {
            let id = ObjectIdentifier(key)

            guard let storage = traits[id] else {
                return key.defaultValue
            }

            return storage.value as! Key.Value
        }
        set {
            let id = ObjectIdentifier(key)
            traits[id, default: .init(key)].value = newValue
        }
    }

    /// Combines this traits instance with another, returning a new instance that merges the properties of both.
    public func merging(_ traits: Traits) -> Traits {
        .init(traitsFrom: [self, traits])
    }

    /// Returns a `UITraitCollection` representation of these traits.
    public func callAsFunction() -> UITraitCollection {
        performOnMainThread {
            traits.reduce(into: UITraitCollection()) {
                $1.value.apply(to: &$0)
            }
        }
    }

    /// Applies the traits to `viewController`.
    ///
    /// On iOS 17 and later they are set as trait overrides. Before that, they are collected into one
    /// trait collection and set as the override of each child view controller.
    @MainActor
    func commit(in viewController: UIViewController) {
        #if !os(visionOS)
        var pendingTraitCollection: UITraitCollection?
        #endif

        for (_, trait) in traits {
            #if os(visionOS)
            trait.apply(to: &viewController.traitOverrides)
            #else
            if #available(iOS 17, tvOS 17, *) {
                trait.apply(to: &viewController.traitOverrides)
            } else {
                var traitCollection = pendingTraitCollection ?? UITraitCollection()
                trait.apply(to: &traitCollection)
                pendingTraitCollection = traitCollection
            }
            #endif
        }

        #if !os(visionOS)
        guard let pendingTraitCollection else {
            return
        }

        for childViewController in viewController.children {
            viewController.setOverrideTraitCollection(
                pendingTraitCollection,
                forChild: childViewController
            )
        }
        #endif
    }
}

/// A type-erased trait value, with the closures that apply, compare and hash it.
private struct Storage: Sendable, Hashable {

    var value: any Hashable & Sendable

    private let mutating: @MainActor (Self, inout Any) -> Void
    private let asserting: @Sendable (Self, Self) -> Bool
    private let hashing: @Sendable (Self, inout Hasher) -> Void

    init<Key: TraitKey>(_ key: Key.Type) {
        value = Key.defaultValue
        mutating = {
            #if os(visionOS)
            if var traitsOverrides = $1 as? UITraitOverrides {
                key.apply($0.value as! Key.Value, to: &traitsOverrides)
                $1 = traitsOverrides
            } else {
                var traitCollection = $1 as! UITraitCollection
                key.apply($0.value as! Key.Value, to: &traitCollection)
                $1 = traitCollection
            }
            #else
            if #available(iOS 17, tvOS 17, *), var traitsOverrides = $1 as? UITraitOverrides {
                key.apply($0.value as! Key.Value, to: &traitsOverrides)
                $1 = traitsOverrides
            } else {
                var traitCollection = $1 as! UITraitCollection
                key.apply($0.value as! Key.Value, to: &traitCollection)
                $1 = traitCollection
            }
            #endif
        }
        asserting = {
            if let lhs = $0.value as? Key.Value, let rhs = $1.value as? Key.Value {
                return lhs == rhs
            } else {
                return false
            }
        }
        hashing = {
            let value = $0.value as! Key.Value
            value.hash(into: &$1)
        }
    }

    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.asserting(lhs, rhs)
    }

    func hash(into hasher: inout Hasher) {
        hashing(self, &hasher)
    }

    @available(iOS 17, tvOS 17, *)
    @MainActor
    func apply(to traitsOverrides: inout UITraitOverrides) {
        var reference = traitsOverrides as Any
        mutating(self, &reference)
        traitsOverrides = reference as! UITraitOverrides
    }

    @MainActor
    func apply(to traitCollection: inout UITraitCollection) {
        var reference = traitCollection as Any
        mutating(self, &reference)
        traitCollection = reference as! UITraitCollection
    }
}

extension Traits {

    /// Prints a warning when `object`, which was already snapshotted with these traits, is now used with `otherTraits`.
    ///
    /// Reusing an instance with other traits can leak state between runs. When the check is disabled in
    /// the environment, only a short notice is printed.
    func inconsistentTraitsChecker<Object>(_ object: Object, to otherTraits: Traits) {
        if self != otherTraits {
            guard !SnapshotEnvironment.current.disableInconsistentTraitsChecker else {
                print("[DISABLED] ⚠️ Inconsistent Traits Detected - Snapshot Integrity Risk")
                return
            }

            print(
                """
                ⚠️ Inconsistent Traits Detected - Snapshot Integrity Risk

                The same instance of \(type(of: object)) is being reused with a different \(Traits.self) \
                configuration.

                This may cause:
                - Unreliable snapshot comparisons
                - State contamination between test runs
                - Non-deterministic test failures

                🛠️ Recommended approach for reliable snapshot testing:

                  try await assert(
                    of: await \(type(of: object))(), // Always use a clean instance
                    as: ...
                  )

                ℹ️ Tip: Create fresh input instances for each test scenario to ensure consistent results.
                """
            )
        }
    }
}

extension Traits {

    /// The traits of an iPhone: its idiom, its scale, and the size classes for `size`.
    static func iOS(
        displayScale: CGFloat,
        size: CGSize,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> Traits {
        iOS(
            userInterfaceIdiom: .phone,
            displayScale: displayScale,
            size: size,
            deviceInterfaceSizeClass: deviceInterfaceSizeClass
        )
    }

    /// The traits of an iPad: its idiom, its scale, and the size classes for `size`.
    static func iPadOS(
        displayScale: CGFloat,
        size: CGSize,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> Traits {
        iOS(
            userInterfaceIdiom: .pad,
            displayScale: displayScale,
            size: size,
            deviceInterfaceSizeClass: deviceInterfaceSizeClass
        )
    }

    /// The traits of an Apple TV: its idiom, its scale, and the size classes for `size`.
    static func tvOS(
        displayScale: CGFloat,
        size: CGSize,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> Traits {
        iOS(
            userInterfaceIdiom: .tv,
            displayScale: displayScale,
            size: size,
            deviceInterfaceSizeClass: deviceInterfaceSizeClass
        )
    }

    /// The traits of an Apple Vision Pro: its idiom, its scale, and the size classes for `size`.
    @available(iOS 17, tvOS 17, *)
    static func visionOS(
        displayScale: CGFloat,
        size: CGSize,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> Traits {
        iOS(
            userInterfaceIdiom: .vision,
            displayScale: displayScale,
            size: size,
            deviceInterfaceSizeClass: deviceInterfaceSizeClass
        )
    }

    /// Builds the traits from an idiom, a scale and the size classes resolved for `size`.
    ///
    /// On tvOS the idiom is always `.tv`.
    private static func iOS(
        userInterfaceIdiom: UIUserInterfaceIdiom = .phone,
        displayScale: CGFloat,
        size: CGSize,
        deviceInterfaceSizeClass: DeviceDynamicInterfaceSizeClass
    ) -> Traits {
        var traits = Traits(
            deviceInterfaceSizeClass: deviceInterfaceSizeClass(size)
        )

        #if os(tvOS)
        traits.userInterfaceIdiom = .tv
        #else
        traits.userInterfaceIdiom = userInterfaceIdiom
        #endif
        traits.displayScale = displayScale

        return traits
    }
}
#endif
