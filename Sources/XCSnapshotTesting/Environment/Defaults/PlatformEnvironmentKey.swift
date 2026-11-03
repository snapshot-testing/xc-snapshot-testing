// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS)
import UIKit
#endif

/// The platform name that goes in the path of the references.
///
/// A trait can override it. Otherwise, it is the name of the running platform.
private struct PlatformEnvironmentKey: SnapshotEnvironmentKey {

    static var defaultValue: String {
        TestingSystem.shared.environment?.platform ?? operatingSystemName()
    }

    /// The name of the running platform, such as `iOS`, `iPadOS` or `macOS`.
    private static func operatingSystemName() -> String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        #if targetEnvironment(macCatalyst)
        return "macCatalyst"
        #else
        return performOnMainThread {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "iPadOS"
            } else {
                return "iOS"
            }
        }
        #endif
        #elseif os(tvOS)
        return "tvOS"
        #elseif os(watchOS)
        return "watchOS"
        #elseif os(visionOS)
        return "visionOS"
        #elseif os(Android)
        return "android"
        #elseif os(Windows)
        return "windows"
        #elseif os(Linux)
        return "linux"
        #elseif os(WASI)
        return "wasi"
        #else
        return "unknown"
        #endif
    }
}

extension SnapshotEnvironmentValues {

    /// The platform name in the path of the references, such as `iOS`.
    ///
    /// By default it is the name of the running platform. An empty string removes the platform from
    /// the path, so every platform shares the same references.
    ///
    /// ```swift
    /// withTestingEnvironment {
    ///     $0.platform = "iOS-Simulator"
    /// } operation: {
    ///     // ...
    /// }
    /// ```
    ///
    /// - SeeAlso: ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:operation:file:line:)-(_,_,_,_,()->R,_,_)``
    public var platform: String {
        get { self[PlatformEnvironmentKey.self] }
        set { self[PlatformEnvironmentKey.self] = newValue }
    }
}
