// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
@MainActor
/// Lends the windows in which views are rendered, creating no more than a limit of them.
///
/// Once the limit is reached, a request waits for the lock of one of the existing windows.
final class WindowPool {

    // MARK: - Internal static properties

    static let shared = WindowPool(SDKApplication.sharedIfAvailable)

    // MARK: - Private properties

    private var leases: [WindowLease] = []
    private weak var application: SDKApplication?

    #if !os(macOS)
    private var activeWindowScenes: [UIWindowScene] {
        leases.compactMap(\.window.windowScene)
    }
    #endif

    // MARK: - Inits

    init(_ application: SDKApplication?) {
        self.application = application
    }

    // MARK: - Internal methods

    /// Returns a window, locked for the caller until it is given back with ``release(_:)``.
    ///
    /// A new window is created while there are fewer than `maxConcurrentTests` of them. After that,
    /// the call waits for the lock of the least busy of the first `maxConcurrentTests` windows and reuses it.
    func acquire(
        sessionRole: UISceneSession.Role,
        maxConcurrentTests: Int
    ) async throws -> SDKWindow {
        #if !os(macOS)
        let windowScene = try windowScene(for: sessionRole)
        #endif

        let limit = max(1, maxConcurrentTests)

        if leases.count >= limit {
            let lease = Self.leastBusy(of: leases.prefix(limit))
            await lease.lock()
            #if !os(macOS)
            lease.window.windowScene = windowScene
            #endif
            display(lease.window, visible: true)
            return lease.window
        }

        #if os(macOS)
        let window = SDKWindow()
        window.isReleasedWhenClosed = false
        #else
        let window = SDKWindow(windowScene: windowScene)
        #endif

        display(window, visible: true)

        let WindowLease = WindowLease(window: window)
        leases.append(WindowLease)
        await WindowLease.lock()
        return window
    }

    /// The window that frees up first: the one with the fewest snapshots using or waiting for it.
    ///
    /// Ties go to the earliest, so idle windows are reused in the order they were created.
    static func leastBusy(of leases: some Collection<WindowLease>) -> WindowLease {
        leases.min(by: { $0.load < $1.load })!
    }

    /// Hides `window` and unlocks it, so the next waiting task can use it.
    func release(_ window: SDKWindow) {
        defer { display(window, visible: false) }

        window.windowLease?.unlock()
    }

    // MARK: - Private methods

    #if !os(macOS)
    /// Finds a scene with the given role.
    ///
    /// It tries, in order: a scene of the application, a scene of a pooled window, a new scene
    /// session (iOS 17 and later) and the scene of a temporary window.
    ///
    /// - Throws: ``NoWindowAvailableError`` when none of them yields a scene.
    private func windowScene(for sessionRole: UISceneSession.Role) throws -> UIWindowScene {
        if let windowScene = application?.windowScenes(for: sessionRole).first {
            return windowScene
        }

        if let windowScene = activeWindowScenes.first(where: { $0.session.role == sessionRole }) {
            return windowScene
        }

        if #available(iOS 17, tvOS 17, *) {
            if let windowScene = activateNewSceneSession(sessionRole) {
                return windowScene
            }
        }

        if let windowScene = windowSceneThroughTemporaryWindow(sessionRole) {
            return windowScene
        }

        throw NoWindowAvailableError(sessionRole: sessionRole)
    }

    @available(iOS 17, tvOS 17, *)
    /// Asks the application to activate a scene session with the given role, and returns its scene.
    private func activateNewSceneSession(_ sessionRole: UISceneSession.Role) -> UIWindowScene? {
        guard let application = application else {
            return nil
        }

        application.activateSceneSession(
            for: UISceneSessionActivationRequest(role: sessionRole)
        )

        return application.windowScenes(for: sessionRole).first
    }

    /// Shows an empty window just long enough to read the scene the system attaches to it.
    private func windowSceneThroughTemporaryWindow(
        _ sessionRole: UISceneSession.Role
    ) -> UIWindowScene? {
        let window = SDKWindow()
        window.isHidden = false

        defer {
            window.isHidden = true
            window.windowScene = nil
        }

        return window.windowScene
    }
    #endif

    /// Shows or hides `window`. A window that is shown is resized to its screen.
    private func display(_ window: SDKWindow, visible: Bool) {
        #if os(macOS)
        if !visible {
            window.close()
        } else {
            window.setIsVisible(visible)
        }
        #else
        window.isHidden = !visible
        #endif

        guard visible else {
            return
        }

        #if os(macOS)
        guard let screen = window.screen else {
            return
        }

        let screenSize = screen.frame.size
        if window.frame.size != screenSize {
            window.setFrame(
                NSRect(origin: .zero, size: screenSize),
                display: true
            )
        }
        #elseif os(iOS) || os(tvOS)
        let screenSize = window.screen.bounds.size

        if window.bounds.size != screenSize {
            window.frame = .init(origin: .zero, size: screenSize)
        }
        #endif
    }
}

// MARK: - SnapshotWindowConfiguration

@MainActor
private var kApplicationWindowPool = 0

@MainActor
extension SDKApplication {

    var windowPool: WindowPool {
        if let windowPool = objc_getAssociatedObject(self, &kApplicationWindowPool) as? WindowPool {
            return windowPool
        }

        let windowPool = WindowPool(self)
        objc_setAssociatedObject(self, &kApplicationWindowPool, windowPool, .OBJC_ASSOCIATION_RETAIN)
        return windowPool
    }
}
#endif
