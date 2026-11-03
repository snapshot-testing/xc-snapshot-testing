// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

private struct MaxConcurrentTestsEnvironmentKey: SnapshotEnvironmentKey {

    static var defaultValue: Int {
        max(1, TestingSystem.shared.environment?.maxConcurrentTests ?? 3)
    }
}

extension SnapshotEnvironmentValues {

    /// The maximum number of windows that UI snapshots can use at the same time.
    ///
    /// Rendering a UI snapshot takes a `UIWindow` (`NSWindow` on macOS) from a pool of this size. A
    /// low limit keeps the system from being overloaded when many snapshot tests run in parallel.
    /// The default is 3, and the value must be at least 1.
    ///
    /// ```swift
    /// withTestingEnvironment {
    ///     $0.maxConcurrentTests = 5
    /// } operation: {
    ///     // ...
    /// }
    /// ```
    ///
    /// - SeeAlso: ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:operation:file:line:)-(_,_,_,_,()->R,_,_)``
    public var maxConcurrentTests: Int {
        get { self[MaxConcurrentTestsEnvironmentKey.self] }
        set {
            precondition(newValue >= 1)
            self[MaxConcurrentTestsEnvironmentKey.self] = newValue
        }
    }
}
