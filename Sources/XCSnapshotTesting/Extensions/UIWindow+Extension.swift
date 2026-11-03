// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
@MainActor
extension SDKWindow {

    @discardableResult
    /// Dismisses what the root view controller presented, detaches it from the window, and returns it.
    ///
    /// - Returns: The controller that was the root, or `nil` if there was none.
    func removeRootViewController() -> SDKViewController? {
        #if os(macOS)
        if let contentViewController {
            for presentedViewController in contentViewController.presentedViewControllers ?? [] {
                contentViewController.dismiss(presentedViewController)
            }

            contentViewController.view.removeFromSuperview()
            self.contentViewController = nil
            return contentViewController
        }
        #else
        if let rootViewController {
            // Allow the view controller to be deallocated
            rootViewController.dismiss(animated: false) {
                // Remove the root view in case its still showing
                rootViewController.view.removeFromSuperview()
            }

            self.rootViewController = nil

            for subview in subviews {
                subview.removeFromSuperview()
            }

            return rootViewController
        }
        #endif
        return nil
    }

    @discardableResult
    /// Makes `viewController` the root of the window. On UIKit, it also lays the window out.
    ///
    /// - Returns: The controller that was the root before, or `nil` if there was none.
    func switchRoot(
        _ viewController: SDKViewController
    ) -> SDKViewController? {
        #if os(macOS)
        let previousRootViewController = removeRootViewController()
        contentViewController = viewController
        #else
        let previousRootViewController = removeRootViewController()
        rootViewController = viewController

        #if !os(tvOS) && !os(visionOS)
        viewController.setNeedsStatusBarAppearanceUpdate()
        #endif
        setNeedsLayout()
        layoutIfNeeded()
        safeAreaInsetsDidChange()
        #endif
        return previousRootViewController
    }
}
#endif
