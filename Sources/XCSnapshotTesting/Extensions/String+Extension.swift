// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UniformTypeIdentifiers
#endif

extension String {

    func sanitizingPointersReferences() -> String {
        replacingOccurrences(
            of: ":?\\s*0x[\\da-f]+(\\s*)",
            with: "$1",
            options: .regularExpression
        )
    }

    /// The text as one component of a path.
    ///
    /// The characters that a file name can't hold (see https://superuser.com/a/358861), the control
    /// characters and `%` are written as `%` and the hexadecimal bytes of the character, so two
    /// different texts never end up in the same file: removing them would make `a:b`, `a/b` and `ab`
    /// share a snapshot. A component that is `.` or `..` would leave the folder it is appended to, so
    /// its dots are written that way too.
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
