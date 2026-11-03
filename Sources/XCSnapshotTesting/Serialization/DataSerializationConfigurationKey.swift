// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// A key for a value of ``DataSerializationConfiguration``, such as the scale of images.
///
/// The key gives the type of the value and its default.
public protocol DataSerializationConfigurationKey: Sendable {

    /// The type of the value.
    associatedtype Value: Sendable

    /// The value used when none was set.
    static var defaultValue: Value { get }
}
