// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

private struct AddsCounterSuffixEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue = true
}

extension SnapshotEnvironmentValues {

    /// Whether snapshot file names receive a position suffix when no `named` parameter is provided.
    ///
    /// By default, an assertion without a name is recorded as `<function>.L<line>C<column>.<extension>`,
    /// where the suffix is the position of the assertion in the test file, so it does not depend on
    /// the order in which the tests or the assertions run. Disabling this
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
    /// - Note: Moving an assertion to another line or column changes its file name. Provide a
    ///   `named` parameter for snapshots that have to survive edits above them.
    public var addsCounterSuffix: Bool {
        get { self[AddsCounterSuffixEnvironmentKey.self] }
        set { self[AddsCounterSuffixEnvironmentKey.self] = newValue }
    }
}
