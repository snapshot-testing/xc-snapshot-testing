// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(macOS) || os(visionOS)
import WebKit

extension WKWebView {

    func waitLoadingState(tolerance: TimeInterval) async throws {
        repeat {
            try await Task.sleep(nanoseconds: tolerance.nanoseconds)
        } while isLoading
    }
}
#endif
