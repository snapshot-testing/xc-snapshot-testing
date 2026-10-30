// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import CoreGraphics
import Foundation
@preconcurrency import XCTest

@_spi(Internals) @testable import XCSnapshotTesting

/// The strategies without arguments, and the failure for views that have no size.
@MainActor
final class DefaultStrategiesTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testTheDefaultViewStrategySizesTheViewToFit() async throws {
        let view = ColorView(.green, intrinsicSize: CGSize(width: 30, height: 20))

        let rendered = try await render(AsyncSnapshot<ColorView, ImageBytes>.image, view)

        XCTAssertEqual(rendered.size, CGSize(width: 30, height: 20))
        XCTAssertEqual(rendered.swatch(x: 15, y: 10), .green)
    }

    func testTheDefaultSwiftUIStrategySizesTheViewToFit() async throws {
        let rendered = try await render(AsyncSnapshot<TwoBlocksView, ImageBytes>.image, TwoBlocksView())

        XCTAssertEqual(rendered.size, CGSize(width: 80, height: 20))
    }

    func testTheDefaultViewControllerStrategyRenders() async throws {
        let rendered = try await render(
            AsyncSnapshot<ColorViewController, ImageBytes>.image(layout: .fixed(width: 20, height: 20)),
            ColorViewController(.red)
        )

        XCTAssertEqual(rendered.swatch(x: 10, y: 10), .red)
    }

    #if os(macOS)
    /// A view that reports no size has nothing to draw, and says so instead of failing without a reason.
    func testAViewWithoutSizeReportsWhyNothingWasRendered() async throws {
        do {
            _ = try await render(AsyncSnapshot<ColorView, ImageBytes>.image, ColorView(.blue))
            XCTFail("Expected the render to throw")
        } catch {
            XCTAssertTrue("\(error)".contains("its size was zero"), "\(error)")
            XCTAssertTrue(error.localizedDescription.contains("explicit size"))
        }
    }
    #else
    /// A view that reports no size has nothing to draw, so the comparison fails and attaches an explanation.
    func testAViewWithoutSizeFailsTheComparison() async throws {
        let sized = ColorView(.red, intrinsicSize: CGSize(width: 20, height: 20))
        let unsized = ColorView(.blue)

        _ = try await XCSnapshotTesting.verify(
            of: sized,
            as: .image,
            named: "view",
            record: .missing,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )

        let failure = try await XCSnapshotTesting.verify(
            of: unsized,
            as: .image,
            named: "view",
            record: .never,
            snapshotDirectory: directory.path,
            testName: "snapshot"
        )

        XCTAssertTrue(try XCTUnwrap(failure).contains("does not match reference."), "\(failure ?? "nil")")
    }
    #endif
}
#endif
