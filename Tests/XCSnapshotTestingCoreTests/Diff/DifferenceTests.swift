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
}
