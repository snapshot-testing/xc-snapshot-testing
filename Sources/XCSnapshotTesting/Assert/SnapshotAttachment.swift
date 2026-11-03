// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A file attached to a test result: its type, an optional name, and its content.
public struct SnapshotAttachment: Sendable {

    /// The uniform type identifier of the content. It is `public.data` when none was given.
    public let uniformTypeIdentifier: String

    /// A name to show with the attachment.
    public var name: String?

    /// The content of the file.
    public let payload: Data?

    /// Creates an attachment.
    ///
    /// - Parameters:
    ///   - identifier: The uniform type identifier of the content. With `nil`, it is `public.data`.
    ///   - name: A name to show with the attachment.
    ///   - payload: The content of the file.
    public init(uniformTypeIdentifier identifier: String?, name: String?, payload: Data?) {
        self.uniformTypeIdentifier = identifier ?? "public.data"
        self.name = name
        self.payload = payload
    }

    /// Creates an attachment from data, with the type `public.data`.
    ///
    /// - Parameter payload: The content of the file.
    public init(data payload: Data) {
        self.init(
            data: payload,
            uniformTypeIdentifier: "public.data"
        )
    }

    /// Creates an attachment from data of a given type.
    ///
    /// - Parameters:
    ///   - payload: The content of the file.
    ///   - identifier: The uniform type identifier of the content.
    public init(data payload: Data, uniformTypeIdentifier identifier: String) {
        self.init(
            uniformTypeIdentifier: identifier,
            name: "",
            payload: payload
        )
    }

    /// Creates a plain text attachment.
    ///
    /// - Parameter string: The text. It is stored as UTF-8, with the type `public.plain-text`.
    public init(string: String) {
        self.init(
            data: Data(string.utf8),
            uniformTypeIdentifier: "public.plain-text"
        )
    }

    #if os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
    /// Creates an attachment from an image, stored as PNG.
    ///
    /// - Parameter image: The image. The initializer returns `nil` if it cannot be encoded.
    public init?(image: UIImage) {
        guard let payload = image.pngData() else {
            return nil
        }

        self.init(
            uniformTypeIdentifier: "public.png",
            name: "",
            payload: payload
        )
    }
    #elseif os(macOS)
    /// Creates an attachment from an image, stored as PNG.
    ///
    /// - Parameter image: The image. The initializer returns `nil` if it cannot be encoded.
    public init?(image: NSImage) {
        guard let payload = image.pngData() else {
            return nil
        }

        self.init(
            uniformTypeIdentifier: "public.png",
            name: "",
            payload: payload
        )
    }
    #endif
}
