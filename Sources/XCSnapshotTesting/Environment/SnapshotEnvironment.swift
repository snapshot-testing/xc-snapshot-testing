// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Read-only access to the environment of the running test.
///
/// Each configuration value is a property, found through ``SnapshotEnvironmentValues``.
///
/// ```swift
/// let recordMode = SnapshotEnvironment.current.recordMode
/// ```
@dynamicMemberLookup
public struct SnapshotEnvironment: Sendable {

    /// The environment of the running test.
    public static let current = SnapshotEnvironment()

    fileprivate init() {}

    /// The value at `keyPath` in the environment.
    ///
    /// - Parameter keyPath: A property of ``SnapshotEnvironmentValues``.
    public subscript<Value>(dynamicMember keyPath: KeyPath<SnapshotEnvironmentValues, Value>) -> Value {
        (SnapshotEnvironmentValues.current ?? SnapshotEnvironmentValues())[keyPath: keyPath]
    }

    /// The value stored for `key`, or its default value if none was set.
    ///
    /// - Parameter key: The type of the key.
    public subscript<Key: SnapshotEnvironmentKey>(_ key: Key.Type) -> Key.Value {
        (SnapshotEnvironmentValues.current ?? SnapshotEnvironmentValues())[key]
    }
}
