#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import CoreGraphics
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@MainActor
@Suite("View controller rendering", .serialized)
struct ViewControllerRenderingTests {

    private typealias Strategy = AsyncSnapshot<ColorViewController, ImageBytes>

    @Test func aFixedLayoutRendersTheViewOfTheController() async throws {
        let rendered = try await render(
            Strategy.image(layout: .fixed(width: 100, height: 80)),
            ColorViewController(.blue)
        )

        #expect(rendered.size == CGSize(width: 100, height: 80))
        #expect(rendered.swatch(x: 50, y: 40) == .blue)
        #expect(rendered.swatch(x: 2, y: 2) == .blue)
        #expect(rendered.swatch(x: 97, y: 77) == .blue)
    }

    @Test func theControllerReceivesItsLifecycleCallbacksInOrder() async throws {
        let controller = ColorViewController(.red)

        _ = try await render(Strategy.image(layout: .fixed(width: 50, height: 50)), controller)

        let events = controller.events
        #expect(events.contains("viewDidLoad"))
        let will = try #require(events.firstIndex(of: "viewWillAppear"))
        let did = try #require(events.firstIndex(of: "viewDidAppear"))
        #expect(events.firstIndex(of: "viewDidLoad")! < will)
        #expect(will < did)
    }

    @Test func theSameControllerCanBeSnapshottedTwice() async throws {
        let controller = ColorViewController(.green)

        let first = try await render(Strategy.image(layout: .fixed(width: 30, height: 30)), controller)
        let second = try await render(Strategy.image(layout: .fixed(width: 40, height: 20)), controller)

        #expect(first.size == CGSize(width: 30, height: 30))
        #expect(second.size == CGSize(width: 40, height: 20))
        #expect(second.swatch(x: 20, y: 10) == .green)
    }

    @Test func theRecursiveDescriptionDescribesTheControllerView() async throws {
        let description = try await AsyncSnapshot<ColorViewController, StringBytes>.recursiveDescription
            .executor(ColorViewController(.red)).rawValue

        #if os(macOS)
        #expect(description.contains("ColorView"))
        #else
        #expect(description.contains("frame ="))
        #endif
        #expect(!description.contains("0x"))
    }
}
#endif
