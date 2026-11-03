// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// The outcome of a snapshot assertion that did not pass.
///
/// ``SnapshotTester`` returns it, and the caller reports ``message`` to the test framework.
@_spi(Internals)
public struct SnapshotFailure: Sendable {

    /// The message to report, written by the engine.
    public let message: String

    /// Why the assertion failed.
    public let reason: SnapshotFailContext.Reason

    init(
        message: String,
        context: SnapshotFailContext
    ) {
        self.message = message
        self.reason = context.reason
    }
}
