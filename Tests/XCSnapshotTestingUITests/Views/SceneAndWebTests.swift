#if (os(iOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import CoreGraphics
import SceneKit
import SpriteKit
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

#if !os(tvOS)
import WebKit
#endif

/// SceneKit scenes are not `Sendable`, which the strategies require; the tests only use them on the main actor.
@MainActor
private final class TestSCNScene: SCNScene, @unchecked Sendable {}

@MainActor
private final class TestSKScene: SKScene, @unchecked Sendable {}

/// Smoke tests for the content that is rendered by another framework: a scene or a web page with one
/// known color must show up with the requested size and that color.
@MainActor
@Suite("Scenes and web content", .serialized)
struct SceneAndWebTests {

    /// SceneKit and SpriteKit return their snapshot at the scale of the display, so the image is the requested
    /// size multiplied by a whole factor, which depends on the machine that runs the test.
    private func expectRequestedSize(_ rendered: Rendered, _ requested: CGSize) {
        let factor = rendered.size.width / requested.width
        #expect(factor >= 1 && factor <= 3)
        #expect(abs(rendered.size.height - requested.height * factor) < 0.5)
    }

    // MARK: - SceneKit

    @Test func aSceneKitSceneIsRenderedAtTheRequestedSize() async throws {
        let scene = TestSCNScene()
        scene.background.contents = Swatch.red.color

        let rendered = try await render(
            AsyncSnapshot<TestSCNScene, ImageBytes>.image(size: CGSize(width: 80, height: 60)),
            scene
        )

        expectRequestedSize(rendered, CGSize(width: 80, height: 60))
        #expect(rendered.swatch(x: rendered.size.width / 2, y: rendered.size.height / 2) == .red)
    }

    // MARK: - SpriteKit

    @Test func aSpriteKitSceneIsRenderedAtTheRequestedSize() async throws {
        let scene = TestSKScene(size: CGSize(width: 60, height: 60))
        scene.backgroundColor = Swatch.red.color

        let circle = SKShapeNode(circleOfRadius: 15)
        circle.fillColor = Swatch.blue.color
        circle.strokeColor = Swatch.blue.color
        circle.position = CGPoint(x: 30, y: 30)
        scene.addChild(circle)

        let rendered = try await render(
            AsyncSnapshot<TestSKScene, ImageBytes>.image(size: CGSize(width: 60, height: 60)),
            scene
        )

        expectRequestedSize(rendered, CGSize(width: 60, height: 60))
        #expect(
            rendered.swatch(x: rendered.size.width / 2, y: rendered.size.height / 2) == .blue,
            "the shape is in the center"
        )
        #expect(rendered.swatch(x: 3, y: 3) == .red, "the background shows at the corner")
    }

    #if !os(tvOS)
    // MARK: - WebKit

    private static let redPage = """
        <html><head><meta name="viewport" content="width=device-width"></head>
        <body style="margin:0;background:#ff0000"></body></html>
        """

    @Test func aWebViewIsWaitedForAndRenderedAtTheRequestedSize() async throws {
        let webView = WKWebView(frame: .zero)
        webView.loadHTMLString(Self.redPage, baseURL: nil)

        let rendered = try await render(
            AsyncSnapshot<WKWebView, ImageBytes>.image(layout: .fixed(width: 100, height: 60)),
            webView
        )

        // The color of the page is not asserted: a web view that is rendered off screen is painted by another
        // process, and whether its content has reached the layer when the snapshot is taken is not deterministic.
        #expect(rendered.size == CGSize(width: 100, height: 60))
        #expect(rendered.pixel(x: 50, y: 30)[3] == 255, "the image is opaque")
    }

    @Test func aWebViewWhoseNavigationIsCancelledStillProducesAnImage() async throws {
        final class Cancelling: NSObject, WKNavigationDelegate {
            func webView(
                _ webView: WKWebView,
                decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
            ) {
                decisionHandler(.cancel)
            }
        }

        let delegate = Cancelling()
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = delegate
        webView.loadHTMLString(Self.redPage, baseURL: nil)

        let rendered = try await render(
            AsyncSnapshot<WKWebView, ImageBytes>.image(layout: .fixed(width: 40, height: 40)),
            webView
        )

        #expect(rendered.size == CGSize(width: 40, height: 40))
    }
    #endif
}
#endif
