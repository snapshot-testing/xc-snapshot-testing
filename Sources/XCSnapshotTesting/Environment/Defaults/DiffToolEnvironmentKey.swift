// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

private struct DiffToolEnvironmentKey: SnapshotEnvironmentKey {

    static var defaultValue: DiffTool {
        TestingSystem.shared.environment?.diffTool ?? .default
    }
}

extension SnapshotEnvironmentValues {

    /// The diff tool used to compare files when a snapshot does not match.
    ///
    /// The default is `.default`, which prints a message with instructions in the console. `.ksdiff`
    /// prints the command that opens Kaleidoscope.
    ///
    /// ```swift
    /// withTestingEnvironment {
    ///     $0.diffTool = .ksdiff
    /// } operation: {
    ///     // ...
    /// }
    /// ```
    ///
    /// - SeeAlso: ``DiffTool``
    public var diffTool: DiffTool {
        get { self[DiffToolEnvironmentKey.self] }
        set { self[DiffToolEnvironmentKey.self] = newValue }
    }
}
