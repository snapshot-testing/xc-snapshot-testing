// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

private struct AddsCounterSuffixEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue = true
}

extension SnapshotEnvironmentValues {

    /// Whether the file name of a snapshot without a `named` argument gets a suffix with the position
    /// of the assertion.
    ///
    /// With the suffix, the file is `<function>.L<line>C<column>.<extension>`. The position is the one
    /// of the assertion in the test file, so it does not depend on the order in which the tests or the
    /// assertions run. Without it, the file is `<function>.<extension>`, which reads better when a test
    /// makes a single assertion. The default is `true`.
    ///
    /// ```swift
    /// try await withTestingEnvironment {
    ///     $0.addsCounterSuffix = false
    /// } operation: {
    ///     try await assert(of: view, as: .image)  // testLayout.png
    /// }
    /// ```
    ///
    /// - Note: Moving an assertion to another line or column changes its file name. Pass a `named`
    ///   argument for snapshots that have to survive edits above them.
    /// - Important: Without the suffix, two unnamed assertions in the same test use the same file.
    ///   Pass a `named` argument to tell them apart.
    public var addsCounterSuffix: Bool {
        get { self[AddsCounterSuffixEnvironmentKey.self] }
        set { self[AddsCounterSuffixEnvironmentKey.self] = newValue }
    }
}
