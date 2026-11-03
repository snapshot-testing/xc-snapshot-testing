// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
import SpriteKit
#if os(macOS)
import Cocoa
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if os(macOS)
extension AsyncSnapshot where Input: SKScene & Sendable, Output == ImageBytes {
    /// A snapshot strategy for comparing SpriteKit scenes based on pixel equality.
    ///
    /// - Parameters:
    ///   - precision: The share of pixels, from 0 to 1, that must be the same.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same.
    ///     Values of 0.98 to 0.99 match what the human eye can tell apart.
    ///   - size: The size of the scene.
    ///   - delay: Seconds to wait before capturing, for animations or content that loads.
    ///   - application: The `NSApplication` instance to render the windows.
    public static func image(
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        size: CGSize,
        delay: Double = .zero,
        application: NSApplication? = nil
    ) -> AsyncSnapshot<Input, Output> {
        .skScene(
            sessionRole: .windowApplication,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            size: size,
            delay: delay,
            application: application
        )
    }
}
#elseif os(iOS) || os(tvOS) || os(visionOS)
extension AsyncSnapshot where Input: SKScene, Output == ImageBytes {
    /// A snapshot strategy for comparing SpriteKit scenes based on pixel equality.
    ///
    /// - Parameters:
    ///   - sessionRole: The role of the UI session (default is `.windowApplication`, appropriate for most UI testing scenarios).
    ///   - precision: The share of pixels, from 0 to 1, that must be the same.
    ///   - perceptualPrecision: How close in color a pixel must be, from 0 to 1, to count as the same.
    ///     Values of 0.98 to 0.99 match what the human eye can tell apart.
    ///   - size: The size of the scene.
    ///   - delay: Seconds to wait before capturing, for animations or content that loads.
    ///   - application: The `UIApplication` instance to render the windows.
    public static func image(
        sessionRole: UISceneSession.Role = .windowApplication,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        size: CGSize,
        delay: Double = .zero,
        application: UIKit.UIApplication? = nil
    ) -> AsyncSnapshot<Input, Output> {
        .skScene(
            sessionRole: sessionRole,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            size: size,
            delay: delay,
            application: application
        )
    }
}
#endif

extension AsyncSnapshot where Input: SKScene, Output == ImageBytes {

    /// Presents the scene in a `SKView` of the given size and snapshots that view as an image.
    fileprivate static func skScene(
        sessionRole: UISceneSession.Role,
        precision: Float,
        perceptualPrecision: Float,
        size: CGSize,
        delay: Double,
        application: SDKApplication?
    ) -> AsyncSnapshot<Input, Output> {
        #if os(macOS)
        let snapshot = AsyncSnapshot<SDKView, ImageBytes>.image(
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            layout: .fixed(width: size.width, height: size.height),
            delay: delay,
            application: application
        )
        #else
        let snapshot = AsyncSnapshot<SDKView, ImageBytes>.image(
            sessionRole: sessionRole,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            layout: .fixed(width: size.width, height: size.height),
            delay: delay,
            application: application
        )
        #endif
        return snapshot.pullback { @MainActor scene in
            let view = SKView(frame: .init(origin: .zero, size: size))
            view.presentScene(scene)
            return view
        }
    }
}
#endif
