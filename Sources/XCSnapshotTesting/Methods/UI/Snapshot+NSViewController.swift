// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS)
import AppKit
import Cocoa

extension AsyncSnapshot where Input: NSViewController & Sendable, Output == ImageBytes {

    /// Renders an `NSViewController` as an image, with the default settings. The view is sized to its natural size.
    public static var image: AsyncSnapshot<Input, Output> {
        .image()
    }

    /// Renders an `NSViewController` as an image. The controller is shown as the content of a window of its own.
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
        #if !os(macOS)
        .inconsistentTraitsChecker(config.traits)
        #endif
        .withLock()
    }
}

extension Snapshot where Input: NSViewController, Output == StringBytes {

    /// Describes the view hierarchy of the controller as text, with the private `_subtreeDescription` method.
    public static var recursiveDescription: AsyncSnapshot<Input, Output> {
        .recursiveDescription()
    }

    /// Describes the view hierarchy of the controller as text. The text comes from the private `_subtreeDescription` method.
    ///
    /// - Parameters:
    ///   - layout: How the content is sized: to a fixed size, or to its natural size.
    ///   - delay: Seconds to wait after the layout and before capturing, for animations or content that loads.
    ///   - application: The application whose windows host the content. With `nil`, the shared application is used.
    public static func recursiveDescription(
        layout: SnapshotLayout = .sizeThatFits,
        delay: Double = .zero,
        application: NSApplication? = nil
    ) -> AsyncSnapshot<Input, Output> {
        let config = LayoutConfiguration.resolve(layout)

        return IdentitySyncSnapshot.lines
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
                    .descriptor(executor, method: .subtreeDescription)
                }
            )
            #if !os(macOS)
        .inconsistentTraitsChecker(config.traits)
        #endif
        .withLock()
    }
}
#endif
