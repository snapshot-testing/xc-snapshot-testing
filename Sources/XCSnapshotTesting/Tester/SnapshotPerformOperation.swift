// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

/// What a ``SnapshotEngine`` does with a serialized snapshot.
@_spi(Internals)
public enum SnapshotPerformOperation {

    /// Tells the engine about the snapshot without changing the reference.
    ///
    /// The file engine ignores it. The inline engine uses it to keep track of the assertion.
    case notify

    /// Stores the snapshot as the new reference.
    case write
}
