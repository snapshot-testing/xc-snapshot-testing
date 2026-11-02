// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import SwiftAsyncStream

extension AsyncSignal {

    /// How long a snapshot waits for the layout it asked for before it goes on.
    static let layoutTimeout: TimeInterval = 5

    /// Waits for the signal, and arms it again for the next wait.
    ///
    /// The layout that raises the signal was requested right before waiting, but nothing guarantees
    /// that UIKit or AppKit will run it (a view that is not laid out because nothing changed, for
    /// instance). With no limit, the snapshot would wait forever when the assertion has no timeout.
    /// After `timeout` the wait ends and the snapshot is taken with the layout already in place.
    func waitForLayout(timeout: TimeInterval = AsyncSignal.layoutTimeout) async throws {
        let fallback = Task { [self] in
            try await Task.sleep(nanoseconds: timeout.nanoseconds)
            signal()
        }

        defer { fallback.cancel() }

        try await wait()
        lock()
    }
}
