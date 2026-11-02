// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// A diff attachment generator that compares two UTF-8 strings line-by-line and produces a patch-style text diff
/// as an `SnapshotAttachment`. Calculates differences between collections using the Longest Common
/// Subsequence (LCS) algorithm.
///
/// `StringDiffAttachmentGenerator` implements the `DiffAttachmentGenerator` protocol, generating
/// a unified diff between a reference and a diffable string, each represented as a `StringBytes` value.
/// If the contents are identical, it returns `nil`. Otherwise, it produces a patch-like message
/// and an attachment with UTI "public.patch-file" that can be used to present rich diffs in test failures.
///
/// Typical usage is through `DiffAttachmentGenerator.lines`, which instantiates this type.
///
/// - Warning: The generator operates on lines, splitting both reference and diffable values on newlines,
///   and therefore only highlights differences at the line level. It does not perform word- or character-level diffs.
///
/// - Note: This is particularly useful for snapshot and golden file tests where readable, actionable diffs
///   are important to developers.
public struct StringDiffAttachmentGenerator: DiffAttachmentGenerator {

    /// Creates a new instance of `StringDiffAttachmentGenerator`.
    ///
    /// Use this initializer to construct a diff generator that produces unified
    /// patch-style attachments for line-by-line differences between two strings.
    public init() {}

    /// Compares two UTF-8 string values line-by-line and generates a unified patch-style diff attachment if differences are found.
    ///
    /// This function splits both the `reference` and `diffable` string values into lines,
    /// computes their differences using the Longest Common Subsequence (LCS) algorithm,
    /// and constructs a patch-formatted message representing the changes. If the strings are identical,
    /// the function returns `nil`. Otherwise, it returns a `DiffAttachment` containing a summary message and
    /// a patch file attachment suitable for rich diff presentation.
    ///
    /// - Parameters:
    ///   - reference: The baseline value, typically representing the expected or golden UTF-8 string.
    ///   - diffable: The actual UTF-8 string to compare against the reference.
    /// - Returns: A `DiffAttachment` with a patch-style message and attachment, or `nil` if no differences exist.
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
    /// A line-diffing strategy for UTF-8 text.
    public static var lines: Self {
        StringDiffAttachmentGenerator()
    }
}
