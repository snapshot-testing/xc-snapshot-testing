import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@Suite("Extensions")
struct ExtensionTests {

    // MARK: - String

    @Test func pointerReferencesAreRemoved() {
        #expect(
            "<UIView: 0x7f8b1c004a00; frame = (0 0; 10 10)>".sanitizingPointersReferences()
                == "<UIView; frame = (0 0; 10 10)>"
        )
        #expect("Object:0xabc123 end".sanitizingPointersReferences() == "Object end")
        #expect("no pointers here".sanitizingPointersReferences() == "no pointers here")
    }

    @Test func pathComponentsDropInvalidCharactersAndEmptyParentheses() {
        #expect("testExample()".sanitizingPathComponent() == "testExample")
        #expect("a/b\\c:d*e?f\"g<h>i|j".sanitizingPathComponent() == "abcdefghij")
        #expect("line\nbreak".sanitizingPathComponent() == "linebreak")
        #expect("keeps spaces".sanitizingPathComponent() == "keeps spaces")
    }

    #if canImport(Darwin)
    @Test func uniformTypeIdentifierIsResolvedFromTheExtension() {
        #expect("png".uniformTypeIdentifier() == "public.png")
        #expect("txt".uniformTypeIdentifier() == "public.plain-text")
        #expect("definitely-not-an-extension".uniformTypeIdentifier()?.hasPrefix("dyn.") ?? true)
    }

    // MARK: - CGSize and CGRect

    @Test func scaleIsOneWhenTheContentFits() {
        #expect(CGSize(width: 100, height: 100).scaleThatFits(CGSize(width: 50, height: 100)) == 1)
    }

    @Test func scaleFollowsTheTightestDimension() {
        let container = CGSize(width: 100, height: 100)

        #expect(container.scaleThatFits(CGSize(width: 200, height: 100)) == 0.5)
        #expect(container.scaleThatFits(CGSize(width: 100, height: 400)) == 0.25)
        #expect(container.scaleThatFits(CGSize(width: 400, height: 400)) == 0.25)
    }

    @Test func scaleToFitShrinksTheSizeKeepingItsAspectRatio() {
        let result = CGSize(width: 100, height: 100).scaleToFit(CGSize(width: 400, height: 200))

        #expect(result == CGSize(width: 100, height: 50))
    }

    @Test func rectScalingKeepsTheCenter() {
        let rect = CGRect(x: 10, y: 20, width: 100, height: 40)

        let scaled = rect.scale(by: 2)

        #expect(scaled.size == CGSize(width: 200, height: 80))
        #expect(scaled.midX == rect.midX)
        #expect(scaled.midY == rect.midY)
        #expect(rect.scale(by: 1) == rect)
    }
    #endif

    // MARK: - ProcessInfo

    @Test func artifactsDirectoryDefaultsToTheTemporaryDirectory() {
        let directory = ProcessInfo.artifactsDirectory

        if let configured = ProcessInfo.processInfo.environment["SNAPSHOT_ARTIFACTS"] {
            #expect(directory.path == URL(fileURLWithPath: configured, isDirectory: true).path)
        } else {
            #expect(
                directory.standardizedFileURL.path
                    == URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
            )
        }
        #expect(directory.hasDirectoryPath)
    }

    // MARK: - Task.timeout

    @Test func timeoutReturnsTheResultOfFastOperations() async throws {
        let value = try await Task.timeout(2) { 42 }

        #expect(value == 42)
    }

    @Test func timeoutRethrowsErrorsOfTheOperation() async {
        struct Failure: Error {}

        await #expect(throws: Failure.self) {
            try await Task<Int, Error>.timeout(2) { throw Failure() }
        }
    }

    @Test func timeoutThrowsWhenTheOperationIsTooSlow() async {
        await #expect(throws: TaskTimeout.self) {
            try await Task<Int, Error>.timeout(1) {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                return 1
            }
        }
    }

    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set() { lock.withLock { value = true } }
    }

    @Test func timeoutCancelsTheOperationThatTookTooLong() async throws {
        // Regression: the slow operation used to keep running after the timeout, and resumed the
        // continuation a second time when it finally finished.
        let observedCancellation = Flag()

        await #expect(throws: TaskTimeout.self) {
            try await Task<Int, Error>.timeout(1) {
                do {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                } catch {
                    observedCancellation.set()
                    throw error
                }
                return 1
            }
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(observedCancellation.isSet)
    }
}
