import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("DiffHunk")
struct DiffHunkTests {

    private static let space = "\u{2007}"

    private func hunks(_ first: [String], _ second: [String], context: Int = 4) -> [DiffHunk] {
        first.diffing(second).groupping(context: context)
    }

    @Test func patchMarkerUsesOneBasedStartsAndLengths() {
        let hunk = DiffHunk(firstStart: 0, firstLength: 3, secondStart: 4, secondLength: 5)

        #expect(hunk.patchMarker == "@@ −1,3 +5,5 @@")
    }

    @Test func addingHunksAccumulatesLengthsAndLinesKeepingTheFirstStart() {
        let sum =
            DiffHunk(firstStart: 2, firstLength: 1, secondStart: 3, secondLength: 1, lines: ["a"])
            + DiffHunk(firstStart: 9, firstLength: 2, secondStart: 9, secondLength: 0, lines: ["b", "c"])

        #expect(sum.firstStart == 2)
        #expect(sum.secondStart == 3)
        #expect(sum.firstLength == 3)
        #expect(sum.secondLength == 1)
        #expect(sum.lines == ["a", "b", "c"])
    }

    @Test func identicalCollectionsProduceNoChangedLines() {
        let result = hunks(["a", "b"], ["a", "b"])

        #expect(result.flatMap(\.lines).allSatisfy { $0.hasPrefix(Self.space) })
    }

    @Test func aSingleChangeProducesOneHunkWithContext() throws {
        let result = hunks(["a", "b", "c"], ["a", "X", "c"])

        let hunk = try #require(result.first)
        #expect(result.count == 1)
        #expect(hunk.patchMarker == "@@ −1,3 +1,3 @@")
        #expect(hunk.lines == ["\(Self.space)a", "−b", "+X", "\(Self.space)c"])
    }

    @Test func linesEndingWithASpaceAreMarkedWithANotSign() throws {
        let result = hunks(["a "], ["a"])

        let hunk = try #require(result.first)
        #expect(hunk.lines == ["−a ¬", "+a"])
    }

    @Test func aLongCommonBlockSplitsTheChangesIntoSeparateHunks() {
        let middle = (1...20).map { "line \($0)" }
        let first = ["old-top"] + middle + ["old-bottom"]
        let second = ["new-top"] + middle + ["new-bottom"]

        let result = hunks(first, second)

        #expect(result.count == 2)
        #expect(result[0].lines.first == "−old-top")
        #expect(result[0].lines.contains("\(Self.space)line 4"))
        #expect(!result[0].lines.contains("\(Self.space)line 5"))
        #expect(result[1].lines.contains("\(Self.space)line 17"))
        #expect(!result[1].lines.contains("\(Self.space)line 16"))
        #expect(result[1].lines.last == "+new-bottom")
    }

    @Test func hunkLengthsMatchTheirLines() {
        let first = (1...30).map { "line \($0)" }
        var second = first
        second[2] = "changed 3"
        second.remove(at: 14)
        second.append("added")

        for hunk in first.diffing(second).groupping() {
            let removed = hunk.lines.filter { $0.hasPrefix("−") }.count
            let added = hunk.lines.filter { $0.hasPrefix("+") }.count
            let context = hunk.lines.count - removed - added

            #expect(hunk.firstLength == context + removed)
            #expect(hunk.secondLength == context + added)
        }
    }
}
