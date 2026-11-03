// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

private struct IncludeMajorPlatformVersionInPathEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue = false
}

extension SnapshotEnvironmentValues {

    /// Whether the major version of the platform is part of the path of the references.
    ///
    /// When `true`, references are stored in a folder such as `v18`, inside the folder of the
    /// platform, so each major version of the system has its own. The default is `false`.
    ///
    /// On macOS 10, the version has two parts, such as `v10.15`.
    ///
    /// ```swift
    /// withTestingEnvironment {
    ///     $0.includeMajorPlatformVersionInPath = true
    /// } operation: {
    ///     // ...
    /// }
    /// ```
    public var includeMajorPlatformVersionInPath: Bool {
        get { self[IncludeMajorPlatformVersionInPathEnvironmentKey.self] }
        set { self[IncludeMajorPlatformVersionInPathEnvironmentKey.self] = newValue }
    }

    var platformVersion: String? {
        guard includeMajorPlatformVersionInPath, !platform.isEmpty else {
            return nil
        }

        let majorVersion: String?
        #if os(macOS)
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 10 {
            let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
            majorVersion = "\(systemVersion.majorVersion).\(systemVersion.minorVersion)"
        } else {
            majorVersion = String(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        }
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        majorVersion = performOnMainThread {
            UIDevice.current.systemVersion.split(separator: ".").first.map(String.init)
        }
        #elseif os(watchOS)
        majorVersion = performOnMainThread {
            WKInterfaceDevice.current().systemVersion.split(separator: ".").first.map(String.init)
        }
        #else
        majorVersion = String(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        #endif

        return majorVersion.map { "v\($0)" }
    }
}
