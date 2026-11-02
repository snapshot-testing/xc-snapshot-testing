// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("Snapshot methods")
struct SnapshotMethodsTests {

    private struct User: Encodable, Sendable {
        let id: Int
        let name: String
    }

    private enum Direction: String, CaseIterable, Sendable {
        case up, down, left, right

        var rotatedLeft: Direction {
            switch self {
            case .up: .left
            case .down: .right
            case .left: .down
            case .right: .up
            }
        }
    }

    // MARK: - Any

    @Test func descriptionUsesStringDescribing() throws {
        let snapshot = SyncSnapshot<[Int], StringBytes>.description

        #expect(try SnapshotRunner.run(snapshot, [1, 2]) == "[1, 2]")
        #expect(snapshot.pathExtension == "txt")
    }

    @Test func jsonOfAnyValueIsPrettyPrintedAndSorted() throws {
        let snapshot = SyncSnapshot<Any, StringBytes>.json
        let value: [String: Any] = ["b": [1, 2], "a": "x"]

        #expect(
            try SnapshotRunner.run(snapshot, value)
                == """
                {
                  "a" : "x",
                  "b" : [
                    1,
                    2
                  ]
                }
                """
        )
        #expect(snapshot.pathExtension == "json")
    }

    @Test func jsonOfAnyValueAllowsFragments() throws {
        #expect(try SnapshotRunner.run(SyncSnapshot<Any, StringBytes>.json, 42) == "42")
    }

    // MARK: - Encodable

    @Test func jsonOfAnythingThatIsNotJSONFailsInsteadOfCrashing() {
        // Regression: JSONSerialization raised an Objective-C exception for these, which aborted the process.
        let notJSON: [Any] = [
            Date(),
            Double.nan,
            Double.infinity,
            ["key": Date()],
            [1: "a"],
            [User(id: 1, name: "A")],
            NSObject(),
        ]

        for value in notJSON {
            #expect(throws: InvalidJSONObjectError.self, "\(value)") {
                try SnapshotRunner.run(SyncSnapshot<Any, StringBytes>.json, value)
            }
        }
    }

    @Test func jsonOfAnyValueStillAcceptsEveryKindOfJSON() throws {
        let valid: [Any] = ["text", 1, 2.5, true, NSNull(), [1, 2], ["a": ["b": 1]]]

        for value in valid {
            #expect(throws: Never.self, "\(value)") {
                try SnapshotRunner.run(SyncSnapshot<Any, StringBytes>.json, value)
            }
        }
    }

    @Test func theErrorForAnInvalidJSONObjectNamesTheType() {
        let error = InvalidJSONObjectError(type: Date.self)

        #expect(error.errorDescription?.contains("Date") == true)
    }

    @Test func encodableJSONIsPrettyPrintedAndSorted() throws {
        let snapshot = SyncSnapshot<User, StringBytes>.json

        #expect(
            try SnapshotRunner.run(snapshot, User(id: 1, name: "Blobby"))
                == """
                {
                  "id" : 1,
                  "name" : "Blobby"
                }
                """
        )
        #expect(snapshot.pathExtension == "json")
    }

    @Test func encodableJSONAcceptsACustomEncoder() throws {
        let snapshot = SyncSnapshot<User, StringBytes>.json(JSONEncoder())

        let output = try SnapshotRunner.run(snapshot, User(id: 1, name: "A"))

        #expect(output.contains("\"id\":1"))
        #expect(!output.contains("\n"))
    }

    @Test func encodablePropertyListIsXML() throws {
        let snapshot = SyncSnapshot<User, StringBytes>.plist

        let output = try SnapshotRunner.run(snapshot, User(id: 7, name: "Blobby"))

        #expect(output.contains("<key>name</key>"))
        #expect(output.contains("<string>Blobby</string>"))
        #expect(output.contains("<integer>7</integer>"))
        #expect(snapshot.pathExtension == "plist")
    }

    @Test func encodablePropertyListAcceptsACustomEncoder() throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary

        let snapshot = SyncSnapshot<User, StringBytes>.plist(encoder)

        #expect(snapshot.pathExtension == "plist")
        #expect(throws: Never.self) { try SnapshotRunner.run(snapshot, User(id: 1, name: "A")) }
    }

    // MARK: - CaseIterable

    @Test func functionsOverCaseIterableTypesProduceACSVOfEveryCase() throws {
        let witness = SyncSnapshot<Direction, StringBytes>.description
        let snapshot = SyncSnapshot<Direction, StringBytes>.func(into: witness)
        let rotateLeft: @Sendable (Direction) -> Direction = { $0.rotatedLeft }

        let output = try SnapshotRunner.run(snapshot, rotateLeft)

        #expect(
            output
                == """
                "up","left"
                "down","right"
                "left","down"
                "right","up"
                """
        )
        #expect(snapshot.pathExtension == "csv")
    }

    @Test func aFailingCaseOfACaseIterableFunctionFailsTheSnapshot() {
        struct Boom: Error {}

        let witness = SyncSnapshot<Direction, StringBytes>.description.pullback {
            (direction: Direction) throws -> Direction in
            if direction == .left { throw Boom() }
            return direction
        }

        let snapshot = SyncSnapshot<Direction, StringBytes>.func(into: witness)
        let identity: @Sendable (Direction) -> Direction = { $0 }

        // The case that fails must not just disappear from the CSV.
        #expect(throws: Boom.self) { try SnapshotRunner.run(snapshot, identity) }
    }

    // MARK: - URLRequest

    private func request(
        _ url: String,
        method: String? = nil,
        headers: [String: String] = [:],
        body: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        for (key, value) in headers { request.addValue(value, forHTTPHeaderField: key) }
        request.httpBody = body.map { Data($0.utf8) }
        return request
    }

    @Test func rawRequestSortsHeadersAndQueryItems() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.raw,
            request(
                "https://example.com/path?b=2&a=1",
                headers: ["Content-Type": "text/plain", "Accept": "text/html"]
            )
        )

        #expect(output == "GET https://example.com/path?a=1&b=2\nAccept: text/html\nContent-Type: text/plain")
    }

    @Test func rawRequestIncludesTheMethodAndBody() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.raw,
            request("https://example.com", method: "POST", body: "a=1")
        )

        #expect(output == "POST https://example.com\n\na=1")
    }

    @Test func prettyRawRequestFormatsJSONBodies() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.raw(pretty: true),
            request("https://example.com", method: "POST", body: #"{"b":1,"a":2}"#)
        )

        #expect(output == "POST https://example.com\n\n{\n  \"a\" : 2,\n  \"b\" : 1\n}")
    }

    @Test func prettyRawRequestKeepsBodiesThatAreNotJSON() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.raw(pretty: true),
            request("https://example.com", method: "POST", body: "not json")
        )

        #expect(output == "POST https://example.com\n\nnot json")
    }

    @Test func aRequestWithoutURLIsWrittenInsteadOfCrashing() throws {
        // Regression: the URL was force unwrapped.
        var withoutURL = request("https://example.com", method: "GET")
        withoutURL.url = nil

        #expect(
            try SnapshotRunner.run(SyncSnapshot<URLRequest, StringBytes>.curl, withoutURL)
                == "curl \\\n\t\"(null)\""
        )
        #expect(try SnapshotRunner.run(SyncSnapshot<URLRequest, StringBytes>.raw, withoutURL) == "GET (null)")
    }

    @Test func aURLThatCannotBeTakenApartIsWrittenAsItIs() throws {
        // A URL that is not an ordinary hierarchical one
        let odd = try #require(URL(string: "mailto:someone@example.com"))
        var odder = request("https://example.com", method: "GET")
        odder.url = odd

        let output = try SnapshotRunner.run(SyncSnapshot<URLRequest, StringBytes>.curl, odder)

        #expect(output.hasSuffix("\"mailto:someone@example.com\""))
    }

    @Test func curlOmitsTheMethodForGET() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.curl,
            request("https://example.com/path?b=2&a=1", method: "GET")
        )

        #expect(output == "curl \\\n\t\"https://example.com/path?a=1&b=2\"")
    }

    @Test func curlUsesHeadForHEADRequests() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.curl,
            request("https://example.com", method: "HEAD")
        )

        #expect(output == "curl \\\n\t--head \\\n\t\"https://example.com\"")
    }

    @Test func curlIncludesHeadersBodyAndCookiesInOrder() throws {
        let output = try SnapshotRunner.run(
            SyncSnapshot<URLRequest, StringBytes>.curl,
            request(
                "https://example.com",
                method: "POST",
                headers: ["Cookie": "session=\"abc\"", "X-Token": "say \"hi\"", "Accept": "*/*"],
                body: #"{"key":"value"}"#
            )
        )

        #expect(
            output
                == [
                    "curl",
                    "--request POST",
                    "--header \"Accept: */*\"",
                    "--header \"X-Token: say \\\"hi\\\"\"",
                    "--data \"{\\\"key\\\":\\\"value\\\"}\"",
                    "--cookie \"session=\\\"abc\\\"\"",
                    "\"https://example.com\"",
                ].joined(separator: " \\\n\t")
        )
    }
}
