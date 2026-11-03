// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if canImport(SwiftUI)
import SwiftUI

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
/// Receives the size changes that a ``SizeListener`` observes.
@MainActor
protocol SizeListenerDelegate: AnyObject {

    func viewDidUpdateSize(_ id: ObjectIdentifier, size: CGSize)
}

/// Observes the size of the content being snapshotted, and tells its delegate when it changes.
@MainActor
class SizeListener {

    var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }

    weak var delegate: SizeListenerDelegate?

    private(set) var size: CGSize = .zero
    fileprivate weak var owningView: SDKView?

    init() {}

    fileprivate func updateSize(_ size: CGSize) {
        guard self.size != size else {
            return
        }

        self.size = size
        delegate?.viewDidUpdateSize(id, size: size)
    }

    func dispose() {
        owningView?.removeFromSuperview()
    }
}

// MARK: - UIView Extensions

/// An invisible view that reports its size to a ``SizeListener`` each time it lays out.
///
/// On macOS it reports the size of its superview instead of its own.
@MainActor
class UIViewSizeListener: SDKView {

    let listener: SizeListener

    init(listener: SizeListener) {
        self.listener = listener
        super.init(frame: .zero)
        listener.owningView = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    #if os(macOS)
    override func layout() {
        super.layout()
        guard window != nil, let superview else {
            return
        }

        listener.updateSize(superview.bounds.size)
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        listener.updateSize(bounds.size)
    }
    #endif
}

@MainActor
extension SDKView {

    /// Adds an invisible view, pinned to the safe area, that reports the size of that area to `listener`.
    func addSizeListener(_ listener: SizeListener) {
        let view = UIViewSizeListener(listener: listener)
        view.translatesAutoresizingMaskIntoConstraints = false
        #if os(macOS)
        addSubview(view, positioned: .below, relativeTo: subviews.first)
        #else
        insertSubview(view, at: .zero)
        #endif
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
        ])
    }
}

// MARK: - SwiftUI Extensions

/// Reports the size of a SwiftUI view to a ``SizeListener``, through a `GeometryReader` in its background.
private struct ViewSizeListener: ViewModifier {

    let listener: SizeListener

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy -> Color in
                    let size = proxy.size

                    Task { @MainActor in
                        listener.updateSize(size)
                    }

                    return Color.black.opacity(.zero)
                }
            )
    }
}

extension View {

    func sizeListener(_ listener: SizeListener) -> some View {
        modifier(ViewSizeListener(listener: listener))
    }
}
#endif
#endif
