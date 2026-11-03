// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

// MARK: - Difference Structure
/// Represents a difference between two collections of elements.
struct Difference<Element> {
    /// Origin of elements in the comparison
    enum Origin {
        case first  // Element unique to the first collection
        case second  // Element unique to the second collection
        case common  // Element present in both collections
    }

    /// Elements involved in the difference
    let elements: [Element]
    /// Origin of elements (first collection, second collection, or common)
    let origin: Origin
}

extension Array where Element: Hashable {

    /// The most edits (removals plus additions) that are searched for before the collections are
    /// reported as entirely different.
    ///
    /// The search takes time proportional to the size of the collections times the number of edits,
    /// and memory proportional to the square of the edits. A diff with thousands of changes is not one
    /// anybody reads, so past this point a coarse answer is better than minutes of waiting.
    fileprivate static var maximumEdits: Int { 2_000 }

    // MARK: - Main Comparison Function
    /// Calculates differences between collections with the shortest edit script of Myers' algorithm.
    ///
    /// The result is made of runs of elements that are common to both collections, only in the first
    /// one, or only in the second one. Between two common runs, the removals come before the additions.
    ///
    /// - Parameter other: Collection to compare with
    /// - Returns: List of identified differences
    func diffing(_ other: [Element]) -> [Difference<Element>] {
        // 1. The start and the end that do not change are most of the work saved: they need no search.
        var prefixLength = 0
        while prefixLength < count, prefixLength < other.count, self[prefixLength] == other[prefixLength] {
            prefixLength += 1
        }

        var suffixLength = 0
        while suffixLength < count - prefixLength,
            suffixLength < other.count - prefixLength,
            self[count - 1 - suffixLength] == other[other.count - 1 - suffixLength]
        {
            suffixLength += 1
        }

        let first = Array(self[prefixLength..<(count - suffixLength)])
        let second = Array(other[prefixLength..<(other.count - suffixLength)])

        var differences = [Difference<Element>]()

        if prefixLength > 0 {
            differences.append(Difference(elements: Array(self[..<prefixLength]), origin: .common))
        }

        // 2. What is left in the middle
        differences += Self.differencesBetween(first, second)

        if suffixLength > 0 {
            differences.append(Difference(elements: Array(self[(count - suffixLength)...]), origin: .common))
        }

        return differences
    }

    private static func differencesBetween(
        _ first: [Element],
        _ second: [Element]
    ) -> [Difference<Element>] {
        guard !first.isEmpty, !second.isEmpty else {
            return [
                Difference(elements: first, origin: .first),
                Difference(elements: second, origin: .second),
            ].filter { !$0.elements.isEmpty }
        }

        guard let edits = shortestEdits(first, second) else {
            // Too different to search: everything of the first collection was removed and everything
            // of the second one was added.
            return [
                Difference(elements: first, origin: .first),
                Difference(elements: second, origin: .second),
            ]
        }

        // 3. Walks both collections, grouping what they have in common and what each one has alone
        var differences = [Difference<Element>]()
        var common = [Element]()
        var removed = [Element]()
        var added = [Element]()

        func flushCommon() {
            guard !common.isEmpty else { return }
            differences.append(Difference(elements: common, origin: .common))
            common = []
        }

        func flushChanges() {
            if !removed.isEmpty {
                differences.append(Difference(elements: removed, origin: .first))
                removed = []
            }

            if !added.isEmpty {
                differences.append(Difference(elements: added, origin: .second))
                added = []
            }
        }

        var firstIndex = 0
        var secondIndex = 0

        while firstIndex < first.count || secondIndex < second.count {
            if firstIndex < first.count, edits.removed[firstIndex] {
                flushCommon()
                removed.append(first[firstIndex])
                firstIndex += 1
            } else if secondIndex < second.count, edits.added[secondIndex] {
                flushCommon()
                added.append(second[secondIndex])
                secondIndex += 1
            } else {
                flushChanges()
                common.append(first[firstIndex])
                firstIndex += 1
                secondIndex += 1
            }
        }

        flushChanges()
        flushCommon()

        return differences
    }

    /// Which elements of the first collection are removed and which of the second one are added, in
    /// the fewest edits, or `nil` when more than ``maximumEdits`` would be needed.
    private static func shortestEdits(
        _ first: [Element],
        _ second: [Element]
    ) -> (removed: [Bool], added: [Bool])? {
        // Elements are compared as numbers, which is much cheaper than comparing strings of a text
        // over and over.
        var identifiers = [Element: Int]()
        func identifier(_ element: Element) -> Int {
            if let identifier = identifiers[element] {
                return identifier
            }

            identifiers[element] = identifiers.count
            return identifiers.count - 1
        }

        let a = first.map(identifier)
        let b = second.map(identifier)
        let n = a.count
        let m = b.count

        let limit = Swift.min(n + m, maximumEdits)
        let offset = limit + 1

        // `furthest[k + offset]` is the furthest x reached on the diagonal k = x - y
        var furthest = [Int](repeating: 0, count: 2 * limit + 3)
        // The diagonals -d...d after each number of edits d, to walk back from the end
        var trace = [[Int]]()
        var edits: Int?

        search: for d in 0...limit {
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int

                if k == -d || (k != d && furthest[offset + k - 1] < furthest[offset + k + 1]) {
                    x = furthest[offset + k + 1]
                } else {
                    x = furthest[offset + k - 1] + 1
                }

                var y = x - k

                while x < n, y < m, a[x] == b[y] {
                    x += 1
                    y += 1
                }

                furthest[offset + k] = x

                if x >= n, y >= m {
                    edits = d
                    break search
                }
            }

            trace.append([Int](furthest[(offset - d)...(offset + d)]))
        }

        guard let edits else {
            return nil
        }

        var removed = [Bool](repeating: false, count: n)
        var added = [Bool](repeating: false, count: m)

        var x = n
        var y = m

        for d in stride(from: edits, to: 0, by: -1) {
            let previous = trace[d - 1]
            let k = x - y

            // `previous` holds the diagonals -(d-1)...(d-1)
            func previousX(_ diagonal: Int) -> Int {
                previous[diagonal + d - 1]
            }

            let previousK =
                if k == -d || (k != d && previousX(k - 1) < previousX(k + 1)) {
                    k + 1
                } else {
                    k - 1
                }

            let startX = previousX(previousK)
            let startY = startX - previousK

            // Only the edits are recorded: the run of equal elements after each of them is what is
            // left over, and `startX` already is the end of the run before it.
            if previousK == k + 1 {
                added[startY] = true
            } else {
                removed[startX] = true
            }

            x = startX
            y = startY
        }

        return (removed, added)
    }
}

extension [Difference<String>] {

    /// Groups the differences into hunks, in the format of a unified diff.
    ///
    /// Unchanged runs longer than twice `context` are cut down to `context` lines on each side of the
    /// changes. Removed lines start with `−`, added lines with `+`, and unchanged lines with a figure
    /// space, to keep them aligned. Lines that end with a space get a `¬` at the end.
    ///
    /// - Parameter context: How many unchanged lines to keep around a change.
    func groupping(context: Int = 4) -> [DiffHunk] {
        let figureSpace = "\u{2007}"  // Figure space (for alignment)

        // Processes each difference and groups into hunks
        let (finalHunk, hunks) = reduce(into: (current: DiffHunk(), hunks: [DiffHunk]())) {
            state,
            diff in

            let count = diff.elements.count

            switch diff.origin {
            // Case: Common elements with large context
            case .common where count > context * 2:
                let prefixLines = diff.elements.prefix(context).map(addPrefix(figureSpace))
                let suffixLines = diff.elements.suffix(context).map(addPrefix(figureSpace))

                let newHunk =
                    state.current
                    + DiffHunk(
                        firstLength: context,
                        secondLength: context,
                        lines: prefixLines
                    )

                state.current = DiffHunk(
                    firstStart: state.current.firstStart + state.current.firstLength + count - context,
                    firstLength: context,
                    secondStart: state.current.secondStart + state.current.secondLength + count - context,
                    secondLength: context,
                    lines: suffixLines
                )

                // Adds previous hunk if it contains changes
                if newHunk.hasChanges {
                    state.hunks.append(newHunk)
                }

            // Case: Common elements with empty hunk
            case .common where state.current.lines.isEmpty:
                let suffixLines = diff.elements.suffix(context).map(addPrefix(figureSpace))
                state.current =
                    state.current
                    + DiffHunk(
                        firstStart: count - suffixLines.count,
                        firstLength: suffixLines.count,
                        secondStart: count - suffixLines.count,
                        secondLength: suffixLines.count,
                        lines: suffixLines
                    )

            // Case: Normal common elements
            case .common:
                let lines = diff.elements.map(addPrefix(figureSpace))
                state.current =
                    state.current
                    + DiffHunk(
                        firstLength: count,
                        secondLength: count,
                        lines: lines
                    )

            // Case: Removals (first collection elements)
            case .first:
                state.current =
                    state.current
                    + DiffHunk(
                        firstLength: count,
                        lines: diff.elements.map(addPrefix("−"))
                    )

            // Case: Additions (second collection elements)
            case .second:
                state.current =
                    state.current
                    + DiffHunk(
                        secondLength: count,
                        lines: diff.elements.map(addPrefix("+"))
                    )
            }
        }

        // Returns accumulated hunks + final hunk, unless it only holds the lines of context that follow
        // the last change: those already close the hunk before it
        return finalHunk.hasChanges ? hunks + [finalHunk] : hunks
    }
}

// MARK: - Contextual Change Grouping
/// Helper function to add line prefixes
private func addPrefix(_ prefix: String) -> (String) -> String {
    { "\(prefix)\($0)\($0.hasSuffix(" ") ? "¬" : "")" }
}
