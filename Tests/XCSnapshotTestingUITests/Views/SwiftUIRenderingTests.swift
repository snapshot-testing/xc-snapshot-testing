#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Observation
import SwiftUI
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@MainActor
@Observable
private final class ColorModel {
    var color = Color(red: 1, green: 0, blue: 0)
}

@MainActor
private struct ModelView: SwiftUI.View {
    let model: ColorModel

    var body: some SwiftUI.View {
        model.color.frame(width: 20, height: 20)
    }
}

@MainActor
private struct DotView: SwiftUI.View {
    var body: some SwiftUI.View {
        Circle().fill(Color(red: 1, green: 0, blue: 0)).frame(width: 40, height: 40).padding(20)
    }
}

@MainActor
@Suite("SwiftUI rendering", .serialized)
struct SwiftUIRenderingTests {

    private typealias Strategy = AsyncSnapshot<TwoBlocksView, ImageBytes>

    @Test func sizeThatFitsMeasuresTheContent() async throws {
        let rendered = try await render(Strategy.image(layout: .sizeThatFits), TwoBlocksView())

        #expect(rendered.size == CGSize(width: 80, height: 20))
        #expect(rendered.swatch(x: 15, y: 10) == .red)
        #expect(rendered.swatch(x: 55, y: 10) == .blue)
    }

    @Test func aFixedLayoutDefinesTheImageSize() async throws {
        let rendered = try await render(Strategy.image(layout: .fixed(width: 200, height: 100)), TwoBlocksView())

        #expect(rendered.size == CGSize(width: 200, height: 100))
    }

    @Test func prepareCanChangeTheObservedState() async throws {
        let model = ColorModel()

        let rendered = try await render(
            AsyncSnapshot<ModelView, ImageBytes>.image(
                layout: .sizeThatFits,
                prepare: {
                    try await Task.sleep(nanoseconds: 20_000_000)
                    model.color = Color(red: 0, green: 0, blue: 1)
                }
            ),
            ModelView(model: model)
        )

        #expect(rendered.swatch(x: 10, y: 10) == .blue)
    }

    #if !os(macOS)
    @Test func theBackgroundIsOpaqueByDefault() async throws {
        let rendered = try await render(AsyncSnapshot<DotView, ImageBytes>.image(layout: .sizeThatFits), DotView())

        #expect(rendered.size == CGSize(width: 80, height: 80))
        #expect(rendered.swatch(x: 40, y: 40) == .red)
        #expect(rendered.swatch(x: 2, y: 2) != .clear)
    }

    @Test func aTransparentBackgroundIsKeptWhenNotOpaque() async throws {
        let rendered = try await render(
            AsyncSnapshot<DotView, ImageBytes>.image(layout: .sizeThatFits, isOpaque: false),
            DotView()
        )

        #expect(rendered.swatch(x: 40, y: 40) == .red)
        #expect(rendered.swatch(x: 2, y: 2) == .clear)
    }
    #endif
}
#endif
