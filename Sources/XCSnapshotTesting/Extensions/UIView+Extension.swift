// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import SwiftAsyncStream

#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

#if os(macOS) || os(iOS) || os(visionOS)
import WebKit
#endif

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)

@MainActor
extension SDKView {

    /// Draws the view into an image of the size of its bounds.
    func asImage() -> SDKImage {
        #if os(macOS)
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return SDKImage()
        }

        cacheDisplay(in: bounds, to: rep)

        let image = SDKImage(size: bounds.size)
        image.addRepresentation(rep)

        return image
        #else
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
        #endif
    }

    /// Wraps the view in a controller that uses it as its own view.
    func withController() -> SDKViewController {
        UIViewHostingController(self)
    }

    /// Waits for the web views in the hierarchy to finish loading, within `tolerance`.
    ///
    /// Does nothing on platforms without web views.
    func waitLoadingStateIfNeeded(tolerance: TimeInterval) async {
        #if os(iOS) || os(macOS) || os(visionOS)
        if let webView = self as? WKWebView {
            try? await webView.waitLoadingState(tolerance: tolerance)
            return
        }

        for subview in subviews {
            await subview.waitLoadingStateIfNeeded(tolerance: tolerance)
        }
        #endif
    }

    /// Marks the view and its subviews as needing layout.
    ///
    /// Does nothing for a view that is not in a window. The contents of table and collection views
    /// are left alone, because they manage the layout of their cells.
    func recursiveNeedsLayout() {
        guard window != nil else {
            return
        }

        invalidateIntrinsicContentSize()
        #if os(macOS)
        needsUpdateConstraints = true
        needsLayout = true
        #else
        setNeedsUpdateConstraints()
        setNeedsLayout()
        #endif

        switch self {
        #if os(macOS)
        #else
        case is UITableView, is UICollectionView:
            break
        #endif
        default:
            for view in subviews {
                view.recursiveNeedsLayout()
            }
        }
    }
}

@MainActor
/// A controller whose view is a given view, used to host a bare view as a child controller.
private class UIViewHostingController: SDKViewController {

    private let contentView: SDKView

    init(_ contentView: SDKView) {
        self.contentView = contentView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = contentView
    }
}

@MainActor
private var kUIViewLock = 0

@MainActor
extension SDKView {

    private var lock: AsyncLock {
        if let lock = objc_getAssociatedObject(self, &kUIViewLock) as? AsyncLock {
            return lock
        }

        let lock = AsyncLock()
        objc_setAssociatedObject(self, &kUIViewLock, lock, .OBJC_ASSOCIATION_RETAIN)
        return lock
    }

    fileprivate func withLock<Value: Sendable>(
        _ body: @Sendable () async throws -> Value
    ) async throws -> Value {
        try await lock.withLock(body)
    }
}

extension Snapshot {

    /// Makes the snapshot wait for the lock of its input before it runs, so two snapshots of the same view never render at once.
    func withLock<Input: SDKView, Output: BytesRepresentable>() -> AsyncSnapshot<Input, Output>
    where Executor == Async<Input, Output> {
        map { executor in
            Async(Input.self) { view in
                try await view.withLock {
                    try await executor(view)
                }
            }
        }
    }
}
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
@MainActor
private var kUIViewTraits = 0

extension SDKView {

    private var traits: Traits? {
        get { objc_getAssociatedObject(self, &kUIViewTraits) as? Traits }
        set {
            objc_setAssociatedObject(
                self,
                &kUIViewTraits,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    /// Remembers `traits`, and warns if the view was last used with different ones.
    func inconsistentTraitsChecker(for traits: Traits) {
        defer { self.traits = traits }
        self.traits?.inconsistentTraitsChecker(self, to: traits)
    }
}

extension Snapshot {

    /// Makes the snapshot check the traits of its input view before it runs.
    func inconsistentTraitsChecker<Input: SDKView, Output: BytesRepresentable>(
        _ traits: @escaping @Sendable () -> Traits
    ) -> AsyncSnapshot<Input, Output> where Executor == Async<Input, Output> {
        map { executor in
            Async(Input.self) { @MainActor in
                $0.inconsistentTraitsChecker(for: traits())
                return try await executor($0)
            }
        }
    }
}
#endif
