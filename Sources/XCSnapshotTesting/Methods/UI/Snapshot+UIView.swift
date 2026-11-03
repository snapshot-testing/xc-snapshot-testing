// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
extension AsyncSnapshot where Input: UIKit.UIView, Output == ImageBytes {

    /// Renders a `UIView` as an image, with the default settings. The view is sized to its natural size.
    public static var image: AsyncSnapshot<Input, Output> {
        .image()
    }

    /// Renders a `UIView` as an image. The view is shown in a window of its own.
    ///
    /// - Parameters:
    ///   - sessionRole: The role of the scene session the window belongs to.
    ///   - precision: The share of pixels, from 0 to 1, that must be the same. `1` requires every pixel to match.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same. `1` requires an exact match.
    ///   - layout: How the content is sized: for a device, to a fixed size, or to its natural size.
    ///   - traits: Traits to apply, over the ones of the environment.
    ///   - delay: Seconds to wait after the layout and before capturing, for animations or content that loads.
    ///   - prepare: Runs on the main actor after the layout, the delay and the web view loading, right before the capture. Use it to wait for something, such as `onAppear` having run.
    ///   - application: The application whose windows host the content. With `nil`, the shared application is used.
    ///
    /// ```swift
    /// try await assert(
    ///     of: view,
    ///     as: .image(precision: 0.98, layout: .device(.iPhone15Pro))
    /// )
    /// ```
    public static func image(
        sessionRole: UISceneSession.Role = .windowApplication,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        layout: SnapshotLayout = .sizeThatFits,
        traits: Traits = .init(),
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
                    SnapshotUIController($0, with: config)
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
        .inconsistentTraitsChecker { resolveConfig().traits }
        .withLock()
    }
}

extension AsyncSnapshot where Input: UIKit.UIView, Output == StringBytes {

    /// Describes the view hierarchy as text, with `recursiveDescription`.
    ///
    /// ```swift
    /// try await assert(of: view, as: .recursiveDescription)
    /// ```
    ///
    /// Records, for example:
    ///
    /// ```
    /// <UIView; frame = (0 0; 100 100); opaque = NO; layer = <CALayer>>
    /// ```
    public static var recursiveDescription: AsyncSnapshot<Input, Output> {
        Snapshot.recursiveDescription()
    }

    /// Describes the view hierarchy as text. The text comes from `recursiveDescription`.
    ///
    /// - Parameters:
    ///   - sessionRole: The role of the scene session the window belongs to.
    ///   - layout: How the content is sized: for a device, to a fixed size, or to its natural size.
    ///   - traits: Traits to apply, over the ones of the environment.
    ///   - delay: Seconds to wait after the layout and before capturing, for animations or content that loads.
    ///   - application: The application whose windows host the content. With `nil`, the shared application is used.
    public static func recursiveDescription(
        sessionRole: UISceneSession.Role = .windowApplication,
        layout: SnapshotLayout = .sizeThatFits,
        traits: Traits = .init(),
        delay: Double = .zero,
        application: UIKit.UIApplication? = nil
    ) -> AsyncSnapshot<Input, Output> {
        // Resolved when the snapshot runs, so it follows the environment of the test that runs it
        let resolveConfig = LayoutConfiguration.resolver(layout, traits: traits)

        return IdentitySyncSnapshot.lines
            .withWindow(
                sessionRole: sessionRole,
                application: application,
                operation: { windowConfiguration, executor in
                    let config = resolveConfig()
                    return Async(Input.self) { @MainActor in
                        SnapshotUIController($0, with: config)
                    }
                    .connectToWindow(windowConfiguration)
                    .layoutIfNeeded()
                    .sleep(nanoseconds: delay.nanoseconds)
                    #if !os(tvOS)
                    .waitLoadingStateIfNeeded(tolerance: SnapshotEnvironment.current.webViewTolerance)
                    #endif
                    .descriptor(executor, method: .recursiveDescription)
                }
            )
            .withLock()
    }
}
#endif
