// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// A key for a value of the snapshot environment.
///
/// Conform a type to it to add a value to ``SnapshotEnvironmentValues``. The key gives the type of
/// the value and its default.
///
/// ```swift
/// struct MyEnvironmentKey: SnapshotEnvironmentKey {
///     static let defaultValue = 42
/// }
/// ```
public protocol SnapshotEnvironmentKey {
    /// The type of the value.
    associatedtype Value: Sendable

    /// The value used when none was set.
    static var defaultValue: Value { get }
}
