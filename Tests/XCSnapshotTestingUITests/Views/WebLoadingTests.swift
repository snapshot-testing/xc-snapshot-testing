// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if (os(iOS) || os(visionOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import Foundation
import Testing
import WebKit

@_spi(Internals) @testable import XCSnapshotTesting

@MainActor
@Suite("Web loading")
struct WebLoadingTests {

    /// A web view whose page never finishes loading, as a stalled request or a long poll would.
    private final class NeverLoadedWebView: WKWebView {
        override var isLoading: Bool { true }
    }

    @Test func aPageThatNeverFinishesLoadingDoesNotHoldTheSnapshotForever() async throws {
        // Regression: the wait repeated for as long as the view was loading.
        let webView = NeverLoadedWebView(frame: .zero)
        let start = Date()

        try await webView.waitLoadingState(tolerance: 0.01, maximumWait: 0.1)

        #expect(Date().timeIntervalSince(start) < 5)
    }

    @Test func aToleranceOfZeroStillWaitsBetweenChecks() async throws {
        let webView = NeverLoadedWebView(frame: .zero)
        let start = Date()

        try await webView.waitLoadingState(tolerance: 0, maximumWait: 0.1)

        #expect(Date().timeIntervalSince(start) >= 0.09, "the checks are spaced, not a busy loop")
    }

    @Test func aPageThatIsNotLoadingEndsTheWaitAfterOneCheck() async throws {
        let webView = WKWebView(frame: .zero)
        let start = Date()

        try await webView.waitLoadingState(tolerance: 0.05, maximumWait: 30)

        #expect(Date().timeIntervalSince(start) < 5)
    }
}
#endif
