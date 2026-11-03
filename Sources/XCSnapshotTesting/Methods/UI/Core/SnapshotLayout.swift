// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
import CoreGraphics

/// How the content of a UI snapshot is sized.
public enum SnapshotLayout: Sendable {

    #if os(iOS) || os(tvOS) || os(visionOS)
    /// Renders the content with the safe area, size and traits of a device.
    ///
    /// ```swift
    /// let layout = SnapshotLayout.device(.iPhone15ProMax)
    /// ```
    ///
    /// - Parameter configuration: The layout of the device.
    case device(LayoutConfiguration)
    #endif

    /// Renders the content at a fixed size.
    ///
    /// ```swift
    /// let layout = SnapshotLayout.fixed(width: 375, height: 812)
    /// ```
    ///
    /// - Parameters:
    ///   - width: The width, in points.
    ///   - height: The height, in points.
    case fixed(width: CGFloat, height: CGFloat)

    /// Renders the content at its natural size.
    case sizeThatFits
}
#endif
