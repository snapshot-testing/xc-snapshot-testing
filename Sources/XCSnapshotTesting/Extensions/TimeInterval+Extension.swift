// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

extension TimeInterval {

    /// Whether this interval is a limit to wait for.
    ///
    /// Zero, `.infinity` and anything that is not a positive number mean there is no limit, so the
    /// same value behaves the same way whether the snapshot is synchronous or asynchronous.
    var hasLimit: Bool {
        self > 0 && self.isFinite
    }

    /// The interval in whole nanoseconds, for the APIs that sleep or wait for an unsigned count.
    ///
    /// Converting with `UInt64(_:)` traps on a negative, `nan` or infinite interval and on one too long
    /// to fit, and drops the fraction of the seconds. Here a negative or `nan` interval is no time at
    /// all, a fraction is rounded up so a short interval never turns into none, and an interval that is
    /// too long to count waits as long as it can.
    var nanoseconds: UInt64 {
        guard self > 0 else {
            return 0
        }

        let nanoseconds = self * 1_000_000_000

        guard nanoseconds < Double(UInt64.max) else {
            return .max
        }

        return UInt64(nanoseconds.rounded(.up))
    }
}
