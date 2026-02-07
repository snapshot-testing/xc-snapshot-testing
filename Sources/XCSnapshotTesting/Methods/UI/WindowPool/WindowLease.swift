#if os(macOS)
@preconcurrency import AppKit
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

import SwiftAsyncStream

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
@MainActor
class WindowLease {

    private let _lock = AsyncLock()
    private(set) var pendingTasks: Int = .zero

    let window: SDKWindow

    init(window: SDKWindow) {
        self.window = window
        window.windowLease = self
    }

    func lock() async {
        pendingTasks += 1
        await _lock.lock()
        pendingTasks -= 1
    }

    func unlock() {
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
