// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("Difference")
struct DifferenceTests {

    /// Renders a diff compactly: `= common`, `- only in the first`, `+ only in the second`.
    private func describe(_ differences: [Difference<String>]) -> [String] {
        differences.map {
            let prefix =
                switch $0.origin {
                case .common: "="
                case .first: "-"
                case .second: "+"
                }

            return "\(prefix) \($0.elements.joined(separator: ","))"
        }
    }

    @Test func identicalCollectionsProduceASingleCommonBlock() {
        #expect(describe(["a", "b"].diffing(["a", "b"])) == ["= a,b"])
    }

    @Test func emptyCollectionsProduceNoDifferences() {
        #expect(describe([String]().diffing([])).isEmpty)
    }

    @Test func disjointCollectionsProduceOneBlockPerSide() {
        #expect(describe(["a"].diffing(["b"])) == ["- a", "+ b"])
    }

    @Test func onlyTheNonEmptySideIsReported() {
        #expect(describe(["a"].diffing([])) == ["- a"])
        #expect(describe([].diffing(["b"])) == ["+ b"])
    }

    @Test func insertionIsReportedAsAddition() {
        #expect(describe(["a", "c"].diffing(["a", "b", "c"])) == ["= a", "+ b", "= c"])
    }

    @Test func deletionIsReportedAsRemoval() {
        #expect(describe(["a", "b", "c"].diffing(["a", "c"])) == ["= a", "- b", "= c"])
    }

    @Test func replacementIsReportedAsRemovalFollowedByAddition() {
        #expect(describe(["a", "b", "c"].diffing(["a", "X", "c"])) == ["= a", "- b", "+ X", "= c"])
    }

    @Test func theLongestCommonSubsequenceAnchorsTheDiff() {
        let differences = ["x", "a", "b", "c", "y"].diffing(["a", "b", "c", "z"])

        #expect(describe(differences) == ["- x", "= a,b,c", "- y", "+ z"])
    }

    @Test func anInsertedElementBetweenMatchesBreaksTheCommonRun() {
        // Regression: a run of matches used to survive an element that has no match, which reported
        // `a` as added and `a,c` as common, losing the inserted `b`.
        #expect(describe(["a", "c"].diffing(["a", "b", "c"])) == ["= a", "+ b", "= c"])
        #expect(describe(["a", "d"].diffing(["a", "b", "c", "d"])) == ["= a", "+ b,c", "= d"])
    }

    @Test(arguments: [
        (["a", "b", "c"], ["a", "b", "c"]),
        ([], ["a"]),
        (["a"], []),
        (["a", "c"], ["a", "b", "c"]),
        (["a", "b", "c", "d"], ["a", "d"]),
        (["x", "a", "b", "y"], ["a", "b"]),
        (["a", "b", "a", "b", "c"], ["b", "a", "b", "c", "a"]),
        (["1", "2", "3", "4", "5", "6"], ["1", "3", "4", "x", "6", "7"]),
        (["same", "same", "same"], ["same", "other", "same"]),
    ])
    func differencesRebuildBothCollections(first: [String], second: [String]) {
        let differences = first.diffing(second)

        #expect(differences.filter { $0.origin != .second }.flatMap(\.elements) == first)
        #expect(differences.filter { $0.origin != .first }.flatMap(\.elements) == second)
    }

    @Test func differencesAccountForEveryElement() {
        let first = ["1", "2", "3", "4", "5", "6"]
        let second = ["1", "3", "4", "x", "6", "7"]

        let differences = first.diffing(second)

        let rebuiltFirst = differences.filter { $0.origin != .second }.flatMap(\.elements)
        let rebuiltSecond = differences.filter { $0.origin != .first }.flatMap(\.elements)

        #expect(rebuiltFirst == first)
        #expect(rebuiltSecond == second)
    }

    // MARK: - Size and performance

    /// The number of elements in the longest common subsequence, by dynamic programming.
    private func longestCommonSubsequence(_ first: [Int], _ second: [Int]) -> Int {
        var row = [Int](repeating: 0, count: second.count + 1)

        for a in first {
            var diagonal = 0

            for (index, b) in second.enumerated() {
                let above = row[index + 1]
                row[index + 1] = a == b ? diagonal + 1 : max(row[index + 1], row[index])
                diagonal = above
            }
        }

        return row[second.count]
    }

    private struct Generator {
        var state: UInt64

        mutating func next(below limit: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(limit))
        }
    }

    @Test func theDiffIsTheShortestOne() {
        var generator = Generator(state: 42)

        for _ in 0..<300 {
            let alphabet = 1 + generator.next(below: 5)
            let first = (0..<generator.next(below: 25)).map { _ in generator.next(below: alphabet) }
            let second = (0..<generator.next(below: 25)).map { _ in generator.next(below: alphabet) }

            let differences = first.diffing(second)

            let removed = differences.filter { $0.origin == .first }.flatMap(\.elements).count
            let added = differences.filter { $0.origin == .second }.flatMap(\.elements).count
            let common = longestCommonSubsequence(first, second)

            #expect(differences.filter { $0.origin != .second }.flatMap(\.elements) == first, "\(first) -> \(second)")
            #expect(differences.filter { $0.origin != .first }.flatMap(\.elements) == second, "\(first) -> \(second)")
            #expect(removed == first.count - common, "\(first) -> \(second)")
            #expect(added == second.count - common, "\(first) -> \(second)")
        }
    }

    @Test func aChangeBetweenMatchesNeverLeavesTwoRunsOfTheSameKindNextToEachOther() {
        var generator = Generator(state: 7)

        for _ in 0..<200 {
            let first = (0..<generator.next(below: 20)).map { _ in generator.next(below: 3) }
            let second = (0..<generator.next(below: 20)).map { _ in generator.next(below: 3) }

            let origins = first.diffing(second).map(\.origin)

            for (left, right) in zip(origins, origins.dropFirst()) {
                #expect(left != right, "\(first) -> \(second)")
            }
        }
    }

    @Test func manyRepeatedLinesDoNotTakeMinutes() {
        // Regression: 4000 identical lines with a change every seventh took 183 seconds.
        let first = [String](repeating: "}", count: 4_000)
        var second = first
        for index in stride(from: 0, to: second.count, by: 7) {
            second[index] = "x\(index)"
        }

        let start = Date()
        let differences = first.diffing(second)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 30, "took \(elapsed)")
        #expect(differences.filter { $0.origin != .second }.flatMap(\.elements) == first)
        #expect(differences.filter { $0.origin != .first }.flatMap(\.elements) == second)
    }

    @Test func aLargeFileWithAFewChangesIsFast() {
        let first = (0..<50_000).map { "line \($0)" }
        var second = first
        second[100] = "changed"
        second.remove(at: 25_000)
        second.insert("new", at: 40_000)

        let start = Date()
        let differences = first.diffing(second)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 30, "took \(elapsed)")
        #expect(differences.filter { $0.origin == .first }.flatMap(\.elements) == ["line 100", "line 25000"])
        #expect(differences.filter { $0.origin == .second }.flatMap(\.elements) == ["changed", "new"])
    }

    @Test func collectionsTooDifferentToSearchAreReportedAsReplaced() {
        // More edits than the search allows: the answer is coarse, but it still accounts for everything.
        let first = (0..<3_000).map { "a\($0)" }
        let second = (0..<3_000).map { "b\($0)" }

        let differences = first.diffing(second)

        #expect(differences.map(\.origin) == [.first, .second])
        #expect(differences.filter { $0.origin == .first }.flatMap(\.elements) == first)
        #expect(differences.filter { $0.origin == .second }.flatMap(\.elements) == second)
    }

    @Test func aTextWithManyChangesStillProducesAReadablePatch() {
        let first = (0..<5_000).map { "line \($0)" }
        let second = (0..<5_000).map { $0.isMultiple(of: 3) ? "other \($0)" : "line \($0)" }

        let hunks = first.diffing(second).groupping()

        #expect(!hunks.isEmpty)
        #expect(hunks.allSatisfy { $0.lines.contains { $0.hasPrefix("−") || $0.hasPrefix("+") } })
    }
}
