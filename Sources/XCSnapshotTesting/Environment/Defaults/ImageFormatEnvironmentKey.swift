// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
private struct ImageFormatEnvironmentKey: SnapshotEnvironmentKey {
    static let defaultValue: ImageFormat? = nil
}

extension SnapshotEnvironmentValues {

    /// The format in which image snapshots are recorded.
    ///
    /// When `nil`, an image is stored the way the platform renders it, which depends on the
    /// machine: a device that draws in Display P3 records a different file than a simulator that
    /// draws in sRGB. Setting a format converts every recorded image to it, and draws wide gamut or
    /// 16-bit formats in the extended range so no color is clipped before the conversion.
    ///
    /// - Default: `nil`
    ///
    /// ```swift
    /// try await withTestingEnvironment {
    ///     $0.imageFormat = .displayP3
    /// } operation: {
    ///     try await assert(of: view, as: .image)
    /// }
    /// ```
    ///
    /// - Note: The format only decides how a snapshot is recorded. A reference already on disk is
    ///   compared in its own format, so changing this value does not make existing references fail.
    public var imageFormat: ImageFormat? {
        get { self[ImageFormatEnvironmentKey.self] }
        set { self[ImageFormatEnvironmentKey.self] = newValue }
    }
}
#endif
