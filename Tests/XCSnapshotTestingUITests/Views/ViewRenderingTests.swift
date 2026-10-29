#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import CoreGraphics
import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

/// Renders views made of solid colors through the real strategies (window, layout, snapshot) and
/// checks size and color at known points. Nothing here depends on fonts or system controls.
@MainActor
@Suite("View rendering", .serialized)
struct ViewRenderingTests {

    private typealias Strategy = AsyncSnapshot<ColorView, ImageBytes>
    private typealias SplitStrategy = AsyncSnapshot<SplitView, ImageBytes>

    @Test func aFixedLayoutRendersAtTheRequestedSize() async throws {
        let rendered = try await render(Strategy.image(layout: .fixed(width: 120, height: 60)), ColorView(.red))

        #expect(rendered.size == CGSize(width: 120, height: 60))
        for point in [(1, 1), (118, 1), (1, 58), (118, 58), (60, 30)] {
            #expect(rendered.swatch(x: CGFloat(point.0), y: CGFloat(point.1)) == .red, "at \(point)")
        }
    }

    @Test func sizeThatFitsUsesTheIntrinsicContentSize() async throws {
        let view = ColorView(.green, intrinsicSize: CGSize(width: 80, height: 40))

        let rendered = try await render(Strategy.image(layout: .sizeThatFits), view)

        #expect(rendered.size == CGSize(width: 80, height: 40))
        #expect(rendered.swatch(x: 40, y: 20) == .green)
    }

    @Test func subviewsAreLaidOutHorizontally() async throws {
        let view = SplitView(.blue, .green, axis: .horizontal)

        let rendered = try await render(SplitStrategy.image(layout: .sizeThatFits), view)

        #expect(rendered.size == CGSize(width: 100, height: 50))
        #expect(rendered.swatch(x: 25, y: 25) == .blue)
        #expect(rendered.swatch(x: 75, y: 25) == .green)
    }

    @Test func subviewsAreLaidOutVertically() async throws {
        let view = SplitView(.blue, .green, axis: .vertical)

        let rendered = try await render(SplitStrategy.image(layout: .sizeThatFits), view)

        #expect(rendered.swatch(x: 50, y: 10) == .blue, "the first view is at the top")
        #expect(rendered.swatch(x: 50, y: 40) == .green)
    }

    @Test func theDelayDoesNotChangeTheResult() async throws {
        let view = ColorView(.red, intrinsicSize: CGSize(width: 20, height: 20))

        let rendered = try await render(Strategy.image(layout: .sizeThatFits, delay: 0.05), view)

        #expect(rendered.size == CGSize(width: 20, height: 20))
        #expect(rendered.swatch(x: 10, y: 10) == .red)
    }

    @Test func prepareRunsBeforeTheSnapshotIsTaken() async throws {
        let view = ColorView(.red, intrinsicSize: CGSize(width: 20, height: 20))

        let rendered = try await render(
            Strategy.image(
                layout: .sizeThatFits,
                prepare: {
                    try await Task.sleep(nanoseconds: 20_000_000)
                    view.paint(.blue)
                }
            ),
            view
        )

        #expect(rendered.swatch(x: 10, y: 10) == .blue, "the state set by prepare is captured")
    }

    @Test func consecutiveSnapshotsDoNotLeakIntoEachOther() async throws {
        let first = try await render(
            Strategy.image(layout: .fixed(width: 40, height: 40)),
            ColorView(.red)
        )
        let second = try await render(
            Strategy.image(layout: .fixed(width: 60, height: 30)),
            ColorView(.green)
        )

        #expect(first.size == CGSize(width: 40, height: 40))
        #expect(second.size == CGSize(width: 60, height: 30))
        #expect(first.swatch(x: 20, y: 20) == .red)
        #expect(second.swatch(x: 30, y: 15) == .green)
    }

    // MARK: - Descriptions

    @Test func theRecursiveDescriptionListsTheViewHierarchyWithoutPointers() async throws {
        let view = SplitView(.blue, .green)

        let description = try await AsyncSnapshot<SplitView, StringBytes>.recursiveDescription
            .executor(view).rawValue

        #expect(description.contains("SplitView"))
        #expect(description.contains("ColorView"))
        #expect(!description.contains("0x"), "pointer references are removed so the text is stable")
    }
}
#endif
