// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
extension Snapshot where Input: UIKit.UIApplication, Output == ImageBytes {

    /// Renders the key window of a `UIApplication` as an image, with the default settings.
    public static var image: AsyncSnapshot<Input, Output> {
        .image()
    }

    /// Renders the key window of a `UIApplication` as an image.
    ///
    /// Use it to check the screen after interacting with the app, for instance in a UI test.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    ///   - delay: Seconds to wait before capturing, for animations or content that loads.
    ///   - sessionRole: The role of the scene session whose key window is captured.
    ///
    /// ```swift
    /// app.buttons["Submit"].tap()
    /// try await assert(of: UIApplication.shared, as: .image(delay: 2))
    /// ```
    public static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        delay: Double = .zero,
        sessionRole: UISceneSession.Role = .windowApplication
    ) -> AsyncSnapshot<Input, Output> {
        IdentitySyncSnapshot.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision
        )
        .withApplication(sessionRole: sessionRole) { window, executor in
            Async(Input.self) { _ in window }
                .sleep(nanoseconds: delay.nanoseconds)
                .map { @MainActor window in
                    let renderer = UIGraphicsImageRenderer(
                        bounds: window.bounds,
                        format: .init(for: window.traitCollection)
                    )

                    let image = try await executor(
                        renderer.image {
                            window.layer.render(in: $0.cgContext)
                        }
                    )

                    return image
                }
        }
        .withLock()
    }
}
#endif
