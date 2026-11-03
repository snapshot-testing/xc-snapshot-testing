// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

private struct RecordEnvironmentKey: SnapshotEnvironmentKey {

    static var defaultValue: RecordMode {
        TestingSystem.shared.environment?.recordMode ?? .missing
    }
}

extension SnapshotEnvironmentValues {

    /// The record mode of the snapshot tests.
    ///
    /// A Swift Testing trait can set it. Otherwise, it is `.missing`.
    public var recordMode: RecordMode {
        get { self[RecordEnvironmentKey.self] }
        set { self[RecordEnvironmentKey.self] = newValue }
    }
}
