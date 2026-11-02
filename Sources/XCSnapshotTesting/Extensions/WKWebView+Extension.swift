// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(macOS) || os(visionOS)
import WebKit

extension WKWebView {

    /// Waits for the web view to stop loading, checking again after each `tolerance`.
    ///
    /// A page that never finishes loading (a stalled request, a long poll) would hold the snapshot
    /// forever when the assertion has no timeout, so the wait ends after `maximumWait` and the view is
    /// captured as it is.
    func waitLoadingState(
        tolerance: TimeInterval,
        maximumWait: TimeInterval = WKWebView.maximumLoadingWait
    ) async throws {
        // A tolerance of zero would check again with no pause, and keep the main actor busy.
        let step = max(tolerance, 0.01)
        var waited: TimeInterval = 0

        repeat {
            try await Task.sleep(nanoseconds: step.nanoseconds)
            waited += step
        } while isLoading && waited < maximumWait
    }

    static let maximumLoadingWait: TimeInterval = 30
}
#endif
