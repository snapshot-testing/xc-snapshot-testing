// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
@preconcurrency import AppKit
#endif

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
@MainActor
struct ViewOperationPayload {
    let previousRootViewController: SDKViewController?
    let window: SDKWindow
    let input: SnapshotUIController
}

/// Puts the window back the way it was found, once, whatever way the operation ended.
///
/// The operation that renders into the window may fail at any step between connecting the view and
/// taking the snapshot (`prepare` throws, the timeout cancels it, the executor fails). Left behind,
/// the controller stays as the root of a window that the next snapshot reuses, and the view under
/// test keeps the helper views that were added to it.
@MainActor
final class ViewOperationRestoration {

    private var payload: ViewOperationPayload?

    func register(_ payload: ViewOperationPayload) {
        self.payload = payload
    }

    func restore() {
        guard let payload else {
            return
        }

        self.payload = nil

        payload.window.removeRootViewController()

        #if os(macOS)
        payload.window.contentViewController = payload.previousRootViewController
        #else
        payload.window.rootViewController = payload.previousRootViewController
        #endif

        payload.input.detachChild()

        if !payload.window.isKeyWindow {
            #if os(macOS)
            payload.window.close()
            #else
            payload.window.isHidden = true
            #endif
        }
    }
}

extension Async where Output == SnapshotUIController {

    func connectToWindow(
        _ configuration: SnapshotWindowConfiguration<Input>
    ) -> Async<
        Input, ViewOperationPayload
    > {
        map { @MainActor in
            let payload = ViewOperationPayload(
                previousRootViewController: configuration.window.switchRoot($0),
                window: configuration.window,
                input: $0
            )

            configuration.restoration.register(payload)
            return payload
        }
    }
}

extension Async where Output == ViewOperationPayload {

    func waitLoadingStateIfNeeded(tolerance: TimeInterval) -> Async<Input, Output> {
        map {
            await $0.input.view.waitLoadingStateIfNeeded(tolerance: tolerance)
            return $0
        }
    }

    func layoutIfNeeded() -> Async<Input, Output> {
        map { @MainActor in
            $0.input.layoutIfNeeded()
            return $0
        }
    }

    func prepare(
        _ operation: (@MainActor @Sendable () async throws -> Void)?
    ) -> Async<Input, Output> {
        guard let operation else {
            return self
        }

        return map { @MainActor payload in
            try await operation()
            return payload
        }
    }

    func snapshot(
        _ executor: Sync<SDKImage, ImageBytes>
    ) -> Async<Input, ImageBytes> {
        map { @MainActor payload in
            try await executor(
                payload.input.snapshot()
            )
        }
    }

    func descriptor(
        _ executor: Sync<String, StringBytes>,
        method: SnapshotUIController.DescriptorMethod
    ) -> Async<Input, StringBytes> {
        map { @MainActor payload in
            try await executor(
                payload.input.descriptor(method)
            )
        }
    }
}
#endif
