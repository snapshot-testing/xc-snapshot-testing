// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if (os(iOS) || os(tvOS) || os(visionOS) || os(macOS)) && !targetEnvironment(macCatalyst)
import Foundation
import Testing

@_spi(Internals) @testable import XCSnapshotTesting

@MainActor
@Suite("Descriptors")
struct DescriptorTests {

    @Test func aSelectorThatTheObjectDoesNotHaveIsAnErrorAndNotACrash() {
        // Sending an unknown message raises an Objective-C exception, which Swift cannot catch.
        #expect(throws: DescriptorUnavailableError.self) {
            try SnapshotUIController.DescriptorMethod.description(of: NSObject(), selector: "thisSelectorDoesNotExist")
        }
    }

    @Test func aSelectorThatDoesNotReturnAStringIsAnErrorAndNotACrash() {
        // Regression: the result was force cast to `String`.
        #expect(throws: DescriptorUnavailableError.self) {
            try SnapshotUIController.DescriptorMethod.description(of: NSObject(), selector: "class")
        }
    }

    @Test func aSelectorThatReturnsAStringGivesItBack() throws {
        let object = NSString(string: "described")

        #expect(
            try SnapshotUIController.DescriptorMethod.description(of: object, selector: "description") == "described"
        )
    }

    @Test func theErrorNamesTheSelectorAndTheType() {
        let error = DescriptorUnavailableError(selector: "_printHierarchy", type: NSObject.self)

        #expect(error.errorDescription?.contains("_printHierarchy") == true)
        #expect(error.errorDescription?.contains("NSObject") == true)
    }
}
#endif
