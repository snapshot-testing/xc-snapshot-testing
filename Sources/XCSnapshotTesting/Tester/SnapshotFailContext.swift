// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Everything an engine needs to write the message of a failed assertion.
@_spi(Internals)
public struct SnapshotFailContext: Sendable {

    /// Why an assertion failed.
    public enum Reason: Sendable {

        /// There is no reference to compare against.
        case missing

        /// The output differs from the reference.
        case doesNotMatch

        /// The record mode is ``RecordMode/all``: the output replaced the reference without a comparison.
        case allRecordMode

        /// The executor did not finish within the time limit.
        case timeout
    }

    /// The test function that made the assertion.
    public let function: StaticString

    /// Why the assertion failed.
    public let reason: Reason

    /// The location of the reference.
    ///
    /// For a timeout it is the temporary directory, because no reference was resolved.
    public let url: URL

    /// The output of the diff tool for the reference and the new output.
    ///
    /// Only set when the new output was written to a temporary location.
    public let diff: String?

    /// The description of the difference, written by the attachment generator.
    public let additionalInformation: String?

    /// Whether the reference was written or replaced during the assertion.
    public let didWriteNewSnapshot: Bool

    init(
        function: StaticString,
        reason: Reason,
        url: URL,
        diff: String?,
        additionalInformation: String?,
        didWriteNewSnapshot: Bool
    ) {
        self.function = function
        self.reason = reason
        self.url = url
        self.diff = diff
        self.additionalInformation = additionalInformation
        self.didWriteNewSnapshot = didWriteNewSnapshot
    }
}
