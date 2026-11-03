// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(visionOS) || os(macOS) || os(visionOS)
private struct WebViewToleranceEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue: TimeInterval = 2.5
}

extension SnapshotEnvironmentValues {

    /// How long to wait, in seconds, for a web view to finish loading before the snapshot is taken.
    ///
    /// The default is 2.5. Available on iOS, macOS and visionOS.
    ///
    /// ```swift
    /// withTestingEnvironment {
    ///     $0.webViewTolerance = 5
    /// } operation: {
    ///     // ...
    /// }
    /// ```
    public var webViewTolerance: TimeInterval {
        get { self[WebViewToleranceEnvironmentKey.self] }
        set { self[WebViewToleranceEnvironmentKey.self] = newValue }
    }
}
#endif
