// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

/// Builds the text that a failed snapshot prints to help compare the reference with the new output.
///
/// The text can be a message for people, or a command that opens both files in a diff tool. The
/// library shows it in the failure and never runs it. The tool receives the absolute paths of the
/// reference and of the new output.
///
/// Use a preset, `.default` or `.ksdiff`, or create one from a closure or a string literal:
///
/// ```swift
/// let customTool: DiffTool = { reference, failed in
///     "diff \"\(reference)\" \"\(failed)\""
/// }
///
/// let literalTool: DiffTool = "open -a Kaleidoscope"
/// ```
///
/// Set the tool for a scope with ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:operation:file:line:)-(_,_,_,_,()->R,_,_)``,
/// or for a test or suite with the `.diffTool(_:)` trait of Swift Testing.
public struct DiffTool: Sendable, ExpressibleByStringLiteral {

    /// A command that opens the two files in [Kaleidoscope](http://kaleidoscope.app).
    ///
    /// ```bash
    /// ksdiff "/path/reference-file.png" "/path/failed-file.png"
    /// ```
    ///
    /// - Important: Kaleidoscope and its `ksdiff` command line tool must be installed.
    public static let ksdiff = Self {
        "ksdiff \"\($0)\" \"\($1)\""
    }

    /// A message with the two paths and instructions to set up a diff tool.
    ///
    /// It needs no tool, so it also works on CI.
    ///
    /// ```plaintext
    /// @−
    /// "/path/to/reference.png"
    /// @+
    /// "/path/to/failed.png"
    ///
    /// To configure output for a custom diff tool, use 'withTestingEnvironment'. For example:
    ///
    ///     withTestingEnvironment(diffTool: .ksdiff) {
    ///       // ...
    ///     }
    /// ```
    public static let `default` = Self {
        """
        @−
        "\($0)"
        @+
        "\($1)"

        To configure output for a custom diff tool, use 'withTestingEnvironment'. For example:

            withTestingEnvironment(diffTool: .ksdiff) {
              // ...
            }
        """
    }

    private var tool: @Sendable (_ currentFilePath: String, _ failedFilePath: String) -> String

    /// Creates a tool from a closure.
    ///
    /// - Parameter tool: Receives the absolute path of the reference file and of the new output, and returns the text to show.
    public init(
        _ tool: @escaping @Sendable (_ currentFilePath: String, _ failedFilePath: String) -> String
    ) {
        self.tool = tool
    }

    /// Creates a tool from a command.
    ///
    /// `$0` is replaced by the path of the reference and `$1` by the path of the new output. If the
    /// text has neither, both paths are added at the end, separated by spaces.
    ///
    /// ```swift
    /// let tool: DiffTool = "open -a Kaleidoscope $0 $1"
    /// ```
    ///
    /// - Parameter value: The command.
    public init(stringLiteral value: StringLiteralType) {
        self.tool = { current, failed in
            guard value.contains("$0") || value.contains("$1") else {
                return "\(value) \(current.quotedForShell) \(failed.quotedForShell)"
            }

            // A single pass over the placeholders: replacing `$0` first and `$1` after would also
            // replace a `$1` that happens to be written in the first path.
            var output = ""
            var index = value.startIndex

            while index < value.endIndex {
                let next = value.index(after: index)

                if value[index] == "$", next < value.endIndex, value[next] == "0" || value[next] == "1" {
                    output += value[next] == "0" ? current : failed
                    index = value.index(after: next)
                } else {
                    output.append(value[index])
                    index = next
                }
            }

            return output
        }
    }

    /// Builds the text for a failed comparison.
    ///
    /// - Parameters:
    ///   - currentFilePath: The absolute path of the reference file.
    ///   - failedFilePath: The absolute path of the new output.
    /// - Returns: The text to show. The library does not run it.
    public func callAsFunction(currentFilePath: String, failedFilePath: String) -> String {
        self.tool(currentFilePath, failedFilePath)
    }
}

extension String {

    /// The string as one argument of a shell command: unchanged when it holds only characters that
    /// have no meaning to the shell, and otherwise in single quotes.
    fileprivate var quotedForShell: String {
        let safe = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_@%+=:,./-"
        )

        if !isEmpty, unicodeScalars.allSatisfy(safe.contains) {
            return self
        }

        return "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
