// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if canImport(XCTest)
@preconcurrency import XCTest
#endif

/// Values that a test framework integration overrides in the snapshot environment.
///
/// The Swift Testing traits fill it in. A property left `nil` keeps the default of the environment.
@_spi(Internals)
public struct TestingSystemEnvironment {

    /// Overrides the record mode.
    public var recordMode: RecordMode?

    /// Overrides the diff tool.
    public var diffTool: DiffTool?

    /// Overrides the maximum number of windows used at once to render UI snapshots.
    public var maxConcurrentTests: Int?

    /// Overrides the platform name in the path of the references.
    public var platform: String?

    /// Creates an environment with the given overrides.
    public init(
        recordMode: RecordMode? = nil,
        diffTool: DiffTool? = nil,
        maxConcurrentTests: Int? = nil,
        platform: String? = nil
    ) {
        self.recordMode = recordMode
        self.diffTool = diffTool
        self.maxConcurrentTests = maxConcurrentTests
        self.platform = platform
    }
}

/// What the Swift Testing integration provides to ``TestingSystem``.
///
/// The `SnapshotTesting` module makes ``TestingSystem`` conform to it, and ``TestingSystem``
/// finds the conformance at runtime with a cast, so this module does not import Swift Testing.
@_spi(Internals)
public protocol SwiftTestingSystem {

    /// The overrides set by the traits of the running test, or `nil` outside of a test.
    var environment: TestingSystemEnvironment? { get }

    /// Whether code is running inside a Swift Testing test.
    var isRunning: Bool { get }

    /// Whether the running test belongs to a suite that applies the `finalizeSnapshots` trait.
    var isTestCompletionAttached: Bool { get }

    /// Attaches `attachments` to the running test.
    func add(
        _ name: String,
        attachments: [SnapshotAttachment],
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    )

    /// Records an issue on the running test.
    func record(
        message: String,
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    )
}

/// Sends failures and attachments to the test framework that is running the test.
///
/// It uses Swift Testing when a Swift Testing test is running, and XCTest otherwise.
@_spi(Internals)
public final class TestingSystem: Sendable {

    /// The shared instance.
    public static let shared = TestingSystem()

    /// Whether code is running inside a Swift Testing test.
    public var isSwiftTestingRunning: Bool {
        (self as? SwiftTestingSystem)?.isRunning ?? false
    }

    /// Whether the running test belongs to a suite that applies the `finalizeSnapshots` trait.
    public var isSwiftTestingCompletionAttached: Bool {
        (self as? SwiftTestingSystem)?.isTestCompletionAttached ?? false
    }

    var environment: TestingSystemEnvironment? {
        if let swiftTestingFramework = self as? SwiftTestingSystem {
            return swiftTestingFramework.environment
        } else {
            return nil
        }
    }

    /// Attaches `attachments` to the running test.
    ///
    /// - Parameters:
    ///   - name: The name of the XCTest activity that groups the attachments. Swift Testing ignores it.
    ///   - attachments: The attachments to add.
    ///   - fileID: The `#fileID` of the assertion.
    ///   - filePath: The `#filePath` of the assertion.
    ///   - line: The line of the assertion.
    ///   - column: The column of the assertion.
    public func add(
        _ name: String,
        attachments: [SnapshotAttachment],
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    ) {
        if let swiftTestingSystem = self as? SwiftTestingSystem, swiftTestingSystem.isRunning {
            swiftTestingSystem.add(
                name,
                attachments: attachments,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        } else {
            #if canImport(XCTest) && (os(iOS) || os(tvOS) || os(macOS) || os(visionOS) || os(watchOS))
            performOnMainThread {
                XCTContext.runActivity(named: name) { activity in
                    for attachment in attachments {
                        activity.add(
                            XCTAttachment(
                                uniformTypeIdentifier: attachment.uniformTypeIdentifier,
                                name: attachment.name,
                                payload: attachment.payload
                            )
                        )
                    }
                }
            }
            #endif
        }
    }

    /// Reports a failure on the running test.
    ///
    /// - Parameters:
    ///   - message: The failure message.
    ///   - fileID: The `#fileID` of the assertion.
    ///   - filePath: The `#filePath` of the assertion.
    ///   - line: The line of the assertion.
    ///   - column: The column of the assertion.
    /// - Throws: ``TestingFailure`` when neither Swift Testing nor XCTest is available.
    public func record(
        message: String,
        fileID: StaticString,
        filePath: StaticString,
        line: UInt,
        column: UInt
    ) throws {
        if let swiftTestingSystem = self as? SwiftTestingSystem, swiftTestingSystem.isRunning {
            swiftTestingSystem.record(
                message: message,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
        } else {
            #if canImport(XCTest)
            XCTFail(message, file: filePath, line: line)
            #else
            throw TestingFailure(
                message: message,
                fileID: fileID,
                filePath: filePath,
                line: line,
                column: column
            )
            #endif
        }
    }
}

#if !canImport(XCTest)
/// The error thrown when an assertion fails on a platform that has no XCTest.
///
/// Where XCTest is available, failures are reported with `XCTFail` instead.
public struct TestingFailure: Error {

    /// The failure message.
    public let message: String

    /// The `#fileID` of the failing assertion.
    public let fileID: StaticString

    /// The `#filePath` of the failing assertion.
    public let filePath: StaticString

    /// The line of the failing assertion.
    public let line: UInt

    /// The column of the failing assertion.
    public let column: UInt
}
#endif
