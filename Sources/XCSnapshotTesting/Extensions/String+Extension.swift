// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UniformTypeIdentifiers
#endif

extension String {

    /// The text without the lines that mention `text`.
    ///
    /// The description of a view lists the views that are added to it only to measure it. They are
    /// not part of what is being tested, and a reference would break if one were renamed.
    func removingLines(mentioning text: String) -> String {
        split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.contains(text) }
            .joined(separator: "\n")
    }

    func sanitizingPointersReferences() -> String {
        replacingOccurrences(
            of: ":?\\s*0x[\\da-f]+(\\s*)",
            with: "$1",
            options: .regularExpression
        )
    }

    /// Removes what cannot be part of a file name: the characters that file systems reject, and the `()` of a function name.
    func sanitizingPathComponent() -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|%")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        var sanitized = ""

        for scalar in unicodeScalars {
            guard invalidCharacters.contains(scalar) else {
                sanitized.unicodeScalars.append(scalar)
                continue
            }

            for byte in String(scalar).utf8 {
                sanitized += "%" + String(byte, radix: 16, uppercase: true).leftPadded(to: 2, with: "0")
            }
        }

        if sanitized == "." || sanitized == ".." {
            return sanitized.replacingOccurrences(of: ".", with: "%2E")
        }

        return sanitized
    }

    private func leftPadded(to length: Int, with character: Character) -> String {
        String(repeating: character, count: Swift.max(0, length - count)) + self
    }

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    func uniformTypeIdentifier() -> String? {
        UTType(filenameExtension: self)?.identifier
    }
    #endif
}
