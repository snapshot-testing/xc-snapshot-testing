// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if canImport(SwiftUI)
@preconcurrency import SwiftUI

#if os(macOS)
extension AsyncSnapshot where Input: SwiftUI.View & Sendable, Output == ImageBytes {

    /// Renders a SwiftUI `View` as an image, with the default settings. The view is sized to its natural size.
    public static var image: AsyncSnapshot<Input, Output> {
        .image()
    }

    /// Renders a SwiftUI `View` as an image.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    ///   - layout: How the content is sized: to a fixed size, or to its natural size.
    ///   - delay: Seconds to wait after the layout and before capturing, for animations or content that loads.
    ///   - prepare: Runs on the main actor after the layout, the delay and the web view loading, right before the capture. Use it to wait for something, such as `onAppear` having run.
    ///   - application: The application whose windows host the content. With `nil`, the shared application is used.
    public static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        layout: SnapshotLayout = .sizeThatFits,
        delay: Double = .zero,
        prepare: (@MainActor @Sendable () async throws -> Void)? = nil,
        application: NSApplication? = nil
    ) -> AsyncSnapshot<Input, Output> {
        let config = LayoutConfiguration.resolve(layout)

        return IdentitySyncSnapshot.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision
        )
        .withWindow(
            sessionRole: .windowApplication,
            application: application,
            operation: { windowConfiguration, executor in
                Async(Input.self) { @MainActor in
                    SnapshotUIController($0, with: config)
                }
                .connectToWindow(windowConfiguration)
                .layoutIfNeeded()
                .sleep(nanoseconds: delay.nanoseconds)
                .waitLoadingStateIfNeeded(tolerance: SnapshotEnvironment.current.webViewTolerance)
                .prepare(prepare)
                .snapshot(executor)
            }
        )
    }
}
#elseif os(iOS) || os(tvOS) || os(visionOS)
extension Snapshot where Input: SwiftUI.View & Sendable, Output == ImageBytes {

    /// Renders a SwiftUI `View` as an image, with the default settings. The view is sized to its natural size.
    public static var image: AsyncSnapshot<Input, Output> {
        .image()
    }

    /// Renders a SwiftUI `View` as an image.
    ///
    /// - Parameters:
    ///   - sessionRole: The role of the scene session the window belongs to.
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    ///   - layout: How the content is sized: for a device, to a fixed size, or to its natural size.
    ///   - traits: Traits to apply, over the ones of the environment.
    ///   - isOpaque: Whether the background is opaque. With `false`, transparent areas of the view stay transparent.
    ///   - delay: Seconds to wait after the layout and before capturing, for animations or content that loads.
    ///   - prepare: Runs on the main actor after the layout, the delay and the web view loading, right before the capture. Use it to wait for something, such as `onAppear` having run.
    ///   - application: The application whose windows host the content. With `nil`, the shared application is used.
    ///
    /// ```swift
    /// try await assert(
    ///     of: ProfileView(),
    ///     as: .image(precision: 0.98, layout: .device(.iPhone15Pro))
    /// )
    /// ```
    public static func image(
        sessionRole: UISceneSession.Role = .windowApplication,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        layout: SnapshotLayout = .sizeThatFits,
        traits: Traits = .init(),
        isOpaque: Bool = true,
        delay: Double = .zero,
        prepare: (@MainActor @Sendable () async throws -> Void)? = nil,
        application: UIKit.UIApplication? = nil
    ) -> AsyncSnapshot<Input, Output> {
        // Resolved when the snapshot runs, so it follows the environment of the test that runs it
        let resolveConfig = LayoutConfiguration.resolver(layout, traits: traits)

        return IdentitySyncSnapshot.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision
        )
        .withWindow(
            sessionRole: sessionRole,
            application: application,
            operation: { windowConfiguration, executor in
                let config = resolveConfig()
                return Async(Input.self) { @MainActor in
                    SnapshotUIController($0, with: config, isOpaque: isOpaque)
                }
                .connectToWindow(windowConfiguration)
                .layoutIfNeeded()
                .sleep(nanoseconds: delay.nanoseconds)
                #if !os(tvOS)
                .waitLoadingStateIfNeeded(tolerance: SnapshotEnvironment.current.webViewTolerance)
                #endif
                .prepare(prepare)
                .snapshot(executor)
            }
        )
    }
}
#elseif os(watchOS)
extension Snapshot where Input: SwiftUI.View & Sendable, Output == ImageBytes {

    /// Renders a SwiftUI `View` as an image, with the default settings. The view is sized to its natural size.
    public static var image: AsyncSnapshot<Input, Output> {
        .image()
    }

    /// Renders a SwiftUI `View` as an image.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - scale: The scale of the rendered image.
    ///   - layout: How the content is sized: to a fixed size, or to its natural size.
    public static func image(
        precision: Float = 1,
        scale: CGFloat = 1,
        layout: SnapshotLayout = .sizeThatFits
    ) -> AsyncSnapshot<Input, Output> {
        let config = LayoutConfiguration.resolve(layout)

        return IdentitySyncSnapshot<ImageBytes>.image(
            precision: precision
        ).map { executor in
            Async(Input.self) { @MainActor view in
                let renderer = ImageRenderer(content: view)
                renderer.scale = scale

                if let size = config.size {
                    renderer.proposedSize = .init(size)
                }

                return try await executor(
                    renderer.uiImage ?? UIImage()
                )
            }
        }
    }
}
#endif
#endif
