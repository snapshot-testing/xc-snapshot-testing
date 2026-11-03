// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import SwiftAsyncStream

#if os(macOS)
@preconcurrency import AppKit
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
@MainActor
/// A pooled window, and the lock that lets one task at a time use it.
class WindowLease {

    private let _lock = AsyncLock()

    /// The number of tasks waiting for the lock.
    private(set) var pendingTasks: Int = .zero
    private(set) var isHeld = false

    /// How many snapshots are using or waiting for the window, to tell which one is the least busy.
    var load: Int {
        pendingTasks + (isHeld ? 1 : 0)
    }

    let window: SDKWindow

    init(window: SDKWindow) {
        self.window = window
        window.windowLease = self
    }

    func lock() async {
        pendingTasks += 1
        await _lock.lock()
        pendingTasks -= 1
        isHeld = true
    }

    func unlock() {
        isHeld = false
        _lock.unlock()
    }
}

@MainActor
private var kWindowLeaseKey = 0

@MainActor
extension SDKWindow {

    fileprivate(set) var windowLease: WindowLease? {
        get {
            objc_getAssociatedObject(self, &kWindowLeaseKey) as? WindowLease
        }
        set {
            precondition(windowLease == nil)

            objc_setAssociatedObject(
                self,
                &kWindowLeaseKey,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN
            )
        }
    }
}
#endif
