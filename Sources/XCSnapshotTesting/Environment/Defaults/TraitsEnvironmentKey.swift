// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

private struct TraitsEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue = Traits()
}

extension SnapshotEnvironmentValues {

    /// The traits applied to every UI snapshot, before the ones passed to the strategy.
    ///
    /// ```swift
    /// withTestingEnvironment {
    ///     $0.traits = Traits(preferredContentSizeCategory: .extraLarge)
    /// } operation: {
    ///     // ...
    /// }
    /// ```
    ///
    /// - SeeAlso: ``Traits``
    public var traits: Traits {
        get { self[TraitsEnvironmentKey.self] }
        set { self[TraitsEnvironmentKey.self] = newValue }
    }
}
#endif
