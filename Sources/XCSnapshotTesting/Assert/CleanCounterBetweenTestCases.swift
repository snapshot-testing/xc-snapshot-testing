// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if canImport(XCTest)
import XCTest

/// An XCTest observer that posts ``XCTestBundleDidFinishNotification`` when the test bundle finishes.
final class CleanCounterBetweenTestCases: NSObject, XCTestObservation {

    @MainActor
    private static var registered = false

    fileprivate static func registerIfNeeded() {
        performOnMainThread {
            guard !registered else { return }
            registered = true
            XCTestObservationCenter.shared.addTestObserver(CleanCounterBetweenTestCases())
        }
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        NotificationCenter.default.post(
            name: XCTestBundleDidFinishNotification,
            object: nil
        )
    }
}

extension XCTestCase {

    static func registerObserverIfNeeded() {
        CleanCounterBetweenTestCases.registerIfNeeded()
    }
}
#endif

/// Posted when the XCTest bundle finishes running.
///
/// The inline engine writes the pending inline snapshots to the test sources when it is posted.
@_spi(Internals)
public let XCTestBundleDidFinishNotification = Notification.Name(
    "XCTestBundleDidFinishNotification"
)

/// Posted when a suite that applies the `finalizeSnapshots` trait finishes.
///
/// The `userInfo` holds the name of the test file under ``kTestFileName``. The inline engine
/// writes the pending inline snapshots of that file when it is posted.
@_spi(Internals)
public let SwiftTestingDidFinishNotification = Notification.Name(
    "SwiftTestingDidFinishNotification"
)

/// The `userInfo` key that holds the name of the test file in ``SwiftTestingDidFinishNotification``.
@_spi(Internals)
public let kTestFileName = "kTestFileName"
