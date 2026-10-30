#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import CoreGraphics
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@_spi(Internals) @testable import XCSnapshotTesting

/// A view filled with one color, optionally reporting an intrinsic size.
@MainActor
final class ColorView: SDKView {

    private let intrinsicSize: CGSize?

    init(_ swatch: Swatch, intrinsicSize: CGSize? = nil) {
        self.intrinsicSize = intrinsicSize
        super.init(frame: .zero)
        #if os(macOS)
        wantsLayer = true
        layer?.backgroundColor = swatch.color.cgColor
        #else
        backgroundColor = swatch.color
        #endif
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize {
        intrinsicSize ?? CGSize(width: SDKView.noIntrinsicMetric, height: SDKView.noIntrinsicMetric)
    }

    func paint(_ swatch: Swatch) {
        #if os(macOS)
        layer?.backgroundColor = swatch.color.cgColor
        #else
        backgroundColor = swatch.color
        #endif
    }
}

/// Lays two colors side by side, or one above the other, filling its bounds.
@MainActor
final class SplitView: SDKView {

    enum Axis { case horizontal, vertical }

    private let first: ColorView
    private let second: ColorView
    private let axis: Axis
    private let size: CGSize

    init(_ first: Swatch, _ second: Swatch, axis: Axis = .horizontal, size: CGSize = CGSize(width: 100, height: 50)) {
        self.first = ColorView(first)
        self.second = ColorView(second)
        self.axis = axis
        self.size = size
        super.init(frame: .zero)
        addSubview(self.first)
        addSubview(self.second)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize { size }

    #if os(macOS)
    override var isFlipped: Bool { true }
    override func layout() {
        super.layout()
        arrange()
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        arrange()
    }
    #endif

    private func arrange() {
        switch axis {
        case .horizontal:
            first.frame = CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
            second.frame = CGRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: bounds.height)
        case .vertical:
            first.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height / 2)
            second.frame = CGRect(x: 0, y: bounds.height / 2, width: bounds.width, height: bounds.height / 2)
        }
    }
}

/// A view controller with a single colored view that remembers its lifecycle callbacks.
@MainActor
final class ColorViewController: SDKViewController {

    private(set) var events: [String] = []
    private let swatch: Swatch

    init(_ swatch: Swatch) {
        self.swatch = swatch
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    #if os(macOS)
    override func loadView() {
        view = ColorView(swatch)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        events.append("viewDidLoad")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        events.append("viewWillAppear")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        events.append("viewDidAppear")
    }
    #else
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = swatch.color
        events.append("viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        events.append("viewWillAppear")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        events.append("viewDidAppear")
    }
    #endif
}

/// A SwiftUI view made of two colored blocks side by side.
@MainActor
struct TwoBlocksView: SwiftUI.View {

    var body: some SwiftUI.View {
        HStack(spacing: 0) {
            Color(red: 1, green: 0, blue: 0).frame(width: 30, height: 20)
            Color(red: 0, green: 0, blue: 1).frame(width: 50, height: 20)
        }
    }
}
#endif
