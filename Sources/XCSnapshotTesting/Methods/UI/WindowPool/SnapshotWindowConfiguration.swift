// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
@MainActor
/// The window leased for a snapshot, and the input being rendered in it.
struct SnapshotWindowConfiguration<Input> {
    let window: SDKWindow
    let input: Input
    let restoration = ViewOperationRestoration()
}
#endif
