// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
import Foundation

extension Snapshot {

    /// Stores the images of this strategy in a specific format.
    ///
    /// It takes precedence over ``SnapshotEnvironmentValues/imageFormat``, so a single assertion
    /// can be recorded in a format other than the rest of the test.
    ///
    /// ```swift
    /// try await assert(of: view, as: .image.imageFormat(.displayP3))
    /// ```
    ///
    /// - Parameter format: The format the images are stored in.
    public func imageFormat<Input>(
        _ format: ImageFormat
    ) -> Self where Executor == Sync<Input, ImageBytes> {
        map { executor in
            executor.map { ImageBytes(rawValue: $0.rawValue, format: format) }
        }
    }

    /// Stores the images of this strategy in a specific format.
    ///
    /// It takes precedence over ``SnapshotEnvironmentValues/imageFormat``, so a single assertion
    /// can be recorded in a format other than the rest of the test.
    ///
    /// ```swift
    /// try await assert(of: view, as: .image.imageFormat(.displayP3))
    /// ```
    ///
    /// - Parameter format: The format the images are stored in.
    public func imageFormat<Input: Sendable>(
        _ format: ImageFormat
    ) -> Self where Executor == Async<Input, ImageBytes> {
        map { executor in
            Async(Input.self) { input in
                // The image is drawn while the executor runs, so the format is also set in the
                // environment for the renderer to know the range it has to draw in.
                let output = try await withTestingEnvironment {
                    $0.imageFormat = format
                } operation: {
                    try await executor(input)
                }

                return ImageBytes(rawValue: output.rawValue, format: format)
            }
        }
    }
}
#endif
