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

    /// A web view that counts how many times it is asked whether it is loading, and answers as told.
    ///
    /// The tests count the checks instead of timing them: a loaded CI simulator can take seconds
    /// to wake a short sleep, and the number of checks does not depend on that.
    private final class ScriptedWebView: WKWebView {

        var stillLoading = true
        private(set) var checks = 0

        override var isLoading: Bool {
            checks += 1
            return stillLoading
        }
    }

    @Test func aPageThatNeverFinishesLoadingDoesNotHoldTheSnapshotForever() async throws {
        // Regression: the wait repeated for as long as the view was loading.
        let webView = ScriptedWebView(frame: .zero)

        try await webView.waitLoadingState(tolerance: 0.01, maximumWait: 0.1)

        #expect(
            (10...11).contains(webView.checks),
            "the wait gives up after the maximum, in steps of the tolerance (the sum of the steps may fall just short of it)"
        )
    }

    @Test func aToleranceOfZeroStillWaitsBetweenChecks() async throws {
        let webView = ScriptedWebView(frame: .zero)
        let start = Date()

        try await webView.waitLoadingState(tolerance: 0, maximumWait: 0.1)

        #expect((10...11).contains(webView.checks), "the step is at least 10 ms, not a busy loop")
        #expect(Date().timeIntervalSince(start) >= 0.09, "and the pauses really happen")
    }

    @Test func aPageThatIsNotLoadingEndsTheWaitAfterOneCheck() async throws {
        let webView = ScriptedWebView(frame: .zero)
        webView.stillLoading = false

        try await webView.waitLoadingState(tolerance: 0.05, maximumWait: 30)

        #expect(webView.checks == 1)
    }
}
#endif
