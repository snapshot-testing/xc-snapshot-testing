// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Compares two strings line by line, and describes the difference as a patch.
///
/// The lines are matched with the longest common subsequence. The attachment is a patch file
/// (`public.patch-file`). It does not go below the level of a line: a changed word shows as a changed line.
/// Use ``DiffAttachmentGenerator/lines`` to get one.
public struct StringDiffAttachmentGenerator: DiffAttachmentGenerator {

    /// Creates a new instance of `StringDiffAttachmentGenerator`.
    ///
    /// Use this initializer to construct a diff generator that produces unified
    /// patch-style attachments for line-by-line differences between two strings.
    public init() {}

    /// Compares the strings.
    ///
    /// - Parameters:
    ///   - reference: The stored string.
    ///   - diffable: The string produced by the current run.
    /// - Returns: The patch that turns the reference into the new string, or `nil` if they are equal.
    public func callAsFunction(
        from reference: StringBytes,
        with diffable: StringBytes
    ) -> DiffAttachment? {
        // Compared by bytes: `String` equality treats a composed and a decomposed accent as the same
        // text, but they are not the same file.
        guard !reference.rawValue.utf8.elementsEqual(diffable.rawValue.utf8) else {
            return nil
        }

        let hunks = Self.lines(of: reference.rawValue)
            .diffing(Self.lines(of: diffable.rawValue))
            .groupping()

        let failure =
            hunks.isEmpty
            ? Self.sameLinesMessage
            : hunks
                .flatMap { [$0.patchMarker] + $0.lines }
                .joined(separator: "\n")

        let attachment = SnapshotAttachment(
            data: Data(failure.utf8),
            uniformTypeIdentifier: "public.patch-file"
        )

        return DiffAttachment(
            message: failure,
            attachments: [attachment]
        )
    }
}

extension StringDiffAttachmentGenerator {

    fileprivate static let sameLinesMessage =
        "The texts have the same lines, but they are not the same: they differ in the line endings "
        + "(\\r\\n against \\n) or in characters that look alike, such as an accent written as one "
        + "character and as two."

    /// The lines of a text, whether they end in `\n` or `\r\n`.
    ///
    /// A `\r\n` is a single `Character`, so splitting on `"\n"` alone never splits a text with those
    /// line endings, and the whole text was compared as one line.
    fileprivate static func lines(of text: String) -> [String] {
        text.split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "\n" || $0 == "\r\n" }
        ).map(String.init)
    }
}

extension DiffAttachmentGenerator where Self == StringDiffAttachmentGenerator {
    /// A generator that compares text line by line.
    public static var lines: Self {
        StringDiffAttachmentGenerator()
    }
}
