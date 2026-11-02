// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

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

    @Test func stringLiteralWithoutPlaceholdersQuotesPathsThatNeedIt() {
        let tool: DiffTool = "open -a Preview"

        #expect(
            tool(currentFilePath: "/My Dir/old.png", failedFilePath: "/tmp/it's $HOME/new.png")
                == "open -a Preview '/My Dir/old.png' '/tmp/it'\\''s $HOME/new.png'"
        )
    }

    @Test func stringLiteralWithoutPlaceholdersLeavesPlainPathsAlone() {
        let tool: DiffTool = "open -a Preview"

        #expect(
            tool(currentFilePath: "/tmp/a-b_c.d/old.png", failedFilePath: "/tmp/new.png")
                == "open -a Preview /tmp/a-b_c.d/old.png /tmp/new.png"
        )
    }

    @Test func aPlaceholderWrittenInAPathIsNotReplacedAgain() {
        let tool: DiffTool = "diff $0 $1"

        // Replacing $0 and then $1 would turn the `$1` of the first path into the second one.
        #expect(tool(currentFilePath: "/tmp/$1/old", failedFilePath: "/tmp/new") == "diff /tmp/$1/old /tmp/new")
    }

    @Test func placeholdersCanRepeatAndSitNextToText() {
        let tool: DiffTool = "cmp $0 $1 && echo $0$1 $2"

        #expect(tool(currentFilePath: "a", failedFilePath: "b") == "cmp a b && echo ab $2")
    }

    @Test func customClosureReceivesTheCurrentAndFailedPaths() {
        let tool = DiffTool { "\($0)|\($1)" }

        #expect(tool(currentFilePath: "old", failedFilePath: "new") == "old|new")
    }
}
