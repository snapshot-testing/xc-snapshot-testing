// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS)
import Foundation

/// The thing to snapshot has no extent, so there is no image to make of it.
struct NothingToDrawError: Error, LocalizedError, CustomStringConvertible {

    let subject: String

    var description: String {
        "No image could be generated for this \(subject) as it has nothing to draw: it is empty or its size is zero."
    }

    var errorDescription: String? { description }
}
#endif
