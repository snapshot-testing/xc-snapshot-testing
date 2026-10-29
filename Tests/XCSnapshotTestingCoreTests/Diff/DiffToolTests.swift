import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("DiffTool")
struct DiffToolTests {

    @Test func defaultToolPrintsBothPathsAndHowToConfigureAnotherTool() {
        let output = DiffTool.default(currentFilePath: "file://old.png", failedFilePath: "file://new.png")

        #expect(output.hasPrefix("@−\n\"file://old.png\"\n@+\n\"file://new.png\""))
        #expect(output.contains("withTestingEnvironment(diffTool: .ksdiff)"))
    }

    @Test func ksdiffQuotesBothPaths() {
        #expect(DiffTool.ksdiff(currentFilePath: "a b", failedFilePath: "c") == "ksdiff \"a b\" \"c\"")
    }

    @Test func stringLiteralWithoutPlaceholdersAppendsThePaths() {
        let tool: DiffTool = "open -a Preview"

        #expect(tool(currentFilePath: "old", failedFilePath: "new") == "open -a Preview old new")
    }

    @Test func stringLiteralPlaceholdersAreReplaced() {
        let tool: DiffTool = "diff $1 $0"

        #expect(tool(currentFilePath: "old", failedFilePath: "new") == "diff new old")
    }

    @Test func customClosureReceivesTheCurrentAndFailedPaths() {
        let tool = DiffTool { "\($0)|\($1)" }

        #expect(tool(currentFilePath: "old", failedFilePath: "new") == "old|new")
    }
}
