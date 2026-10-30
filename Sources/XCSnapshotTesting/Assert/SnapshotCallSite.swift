// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

/// The position of an assertion in its source file.
///
/// An assertion without a name is identified by where it is written, not by when it runs. A counter
/// that follows the order of arrival would give a snapshot a different file whenever a test runs
/// alone, runs after another one, or skips an earlier assertion.
struct SnapshotCallSite: Hashable, Sendable {

    let line: UInt
    let column: UInt

    /// The part of the file name that tells this assertion apart, such as `L12C9`.
    var suffix: String {
        "L\(line)C\(column)"
    }
}
