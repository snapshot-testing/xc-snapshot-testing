import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@Suite("Environment")
struct EnvironmentTests {

    private struct GreetingKey: SnapshotEnvironmentKey {
        static let defaultValue = "hello"
    }

    // MARK: - Defaults

    @Test func defaultsDoNotDependOnTheTestRunner() {
        let environment = SnapshotEnvironment.current

        #expect(environment.recordMode == .missing)
        #expect(environment.maxConcurrentTests == 3)
        #expect(environment.addsCounterSuffix)
        #expect(!environment.includeMajorPlatformVersionInPath)
        #expect(environment.platformVersion == nil)
        #expect(!environment.platform.isEmpty)
        #expect(environment.diffTool(currentFilePath: "a", failedFilePath: "b").hasPrefix("@−"))
    }

    @Test func keysFallBackToTheirDefaultValue() {
        #expect(SnapshotEnvironment.current[GreetingKey.self] == "hello")
        #expect(SnapshotEnvironmentValues()[GreetingKey.self] == "hello")
    }

    // MARK: - Overrides

    @Test func theMutatingClosureOverridesValuesOnlyInsideTheOperation() async {
        await withTestingEnvironment {
            $0[GreetingKey.self] = "hi"
            $0.addsCounterSuffix = false
        } operation: {
            #expect(SnapshotEnvironment.current[GreetingKey.self] == "hi")
            #expect(!SnapshotEnvironment.current.addsCounterSuffix)
        }

        #expect(SnapshotEnvironment.current[GreetingKey.self] == "hello")
        #expect(SnapshotEnvironment.current.addsCounterSuffix)
    }

    @Test func parametersOverrideTheCommonValues() async {
        await withTestingEnvironment(
            record: .all,
            diffTool: "ksdiff",
            maxConcurrentTests: 1,
            platform: "custom"
        ) {
            let environment = SnapshotEnvironment.current

            #expect(environment.recordMode == .all)
            #expect(environment.maxConcurrentTests == 1)
            #expect(environment.platform == "custom")
            #expect(environment.diffTool(currentFilePath: "a", failedFilePath: "b") == "ksdiff a b")
        }
    }

    @Test func parametersLeftOutKeepTheirValue() async {
        await withTestingEnvironment(record: .never) {
            await withTestingEnvironment(platform: "inner") {
                #expect(SnapshotEnvironment.current.recordMode == .never)
                #expect(SnapshotEnvironment.current.platform == "inner")
            }
        }
    }

    @Test func parametersAndAClosureCanBeCombined() async {
        await withTestingEnvironment(
            record: .failed,
            environment: { $0[GreetingKey.self] = "combined" },
            operation: {
                #expect(SnapshotEnvironment.current.recordMode == .failed)
                #expect(SnapshotEnvironment.current[GreetingKey.self] == "combined")
            }
        )
    }

    @Test func nestedEnvironmentsRestoreTheOuterValues() async {
        await withTestingEnvironment(record: .all) {
            await withTestingEnvironment(record: .never) {
                #expect(SnapshotEnvironment.current.recordMode == .never)
            }

            #expect(SnapshotEnvironment.current.recordMode == .all)
        }
    }

    @Test func synchronousOperationsSeeTheOverrides() {
        let result = withTestingEnvironment(record: .failed) {
            SnapshotEnvironment.current.recordMode
        }

        #expect(result == .failed)
        #expect(SnapshotEnvironment.current.recordMode == .missing)
    }

    @Test func synchronousClosureVariantOverridesValues() {
        let greeting = withTestingEnvironment {
            $0[GreetingKey.self] = "sync"
        } operation: {
            SnapshotEnvironment.current[GreetingKey.self]
        }

        #expect(greeting == "sync")
    }

    @Test func synchronousParametersAndAClosureCanBeCombined() {
        let result = withTestingEnvironment(
            record: .failed,
            diffTool: "ksdiff",
            maxConcurrentTests: 2,
            platform: "sync-platform",
            environment: { $0[GreetingKey.self] = "sync-combined" },
            operation: {
                let environment = SnapshotEnvironment.current
                return (
                    environment.recordMode,
                    environment.maxConcurrentTests,
                    environment.platform,
                    environment[GreetingKey.self]
                )
            }
        )

        #expect(result.0 == .failed)
        #expect(result.1 == 2)
        #expect(result.2 == "sync-platform")
        #expect(result.3 == "sync-combined")
    }

    @Test func synchronousParameterVariantsPropagateErrors() {
        struct Failure: Error {}

        #expect(throws: Failure.self) {
            try withTestingEnvironment(record: .all) {
                throw Failure()
            }
        }
    }

    // MARK: - Platform version

    @Test func theMajorPlatformVersionCanBeIncludedInThePath() async throws {
        let version = await withTestingEnvironment {
            $0.includeMajorPlatformVersionInPath = true
        } operation: {
            SnapshotEnvironment.current.platformVersion
        }

        let value = try #require(version)
        #expect(value.hasPrefix("v"))
        #expect(Int(value.dropFirst()) != nil)
    }
}
