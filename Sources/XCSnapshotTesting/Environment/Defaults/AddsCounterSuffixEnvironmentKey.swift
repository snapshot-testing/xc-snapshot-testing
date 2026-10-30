// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

private struct AddsCounterSuffixEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue = true
}

extension SnapshotEnvironmentValues {

    /// Whether snapshot file names receive a counter suffix when no `named` parameter is provided.
    ///
    /// By default, an assertion without a name is recorded as `<function>.<counter>.<extension>`,
    /// where the counter follows the order of the assertions in the test function. Disabling this
    /// property records it as `<function>.<extension>` instead, which is convenient when a test
    /// function asserts a single snapshot.
    ///
    /// - Default: `true`
    ///
    /// ```swift
    /// try await withTestingEnvironment {
    ///     $0.addsCounterSuffix = false
    /// } operation: {
    ///     try await assert(of: view, as: .image) // testLayout.png
    /// }
    /// ```
    ///
    /// - Important: Assertions without a name that share the same test function resolve to the
    ///   same file when the suffix is disabled. Provide a `named` parameter to tell them apart.
    /// - Note: Snapshots that already provide a `named` parameter are not affected.
    public var addsCounterSuffix: Bool {
        get { self[AddsCounterSuffixEnvironmentKey.self] }
        set { self[AddsCounterSuffixEnvironmentKey.self] = newValue }
    }
}
