// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(macOS) || os(iOS) || os(tvOS) || os(visionOS)
import Foundation

/// The formatter that writes the points of the `elementsDescription` snapshots of paths.
///
/// Its locale is fixed: with the locale of the machine, the digits and the separators of the same
/// path would read differently on another one, and a reference recorded on a machine would fail on
/// the next.
let defaultNumberFormatter: NumberFormatter = {
    let numberFormatter = NumberFormatter()
    numberFormatter.locale = Locale(identifier: "en_US_POSIX")
    numberFormatter.decimalSeparator = "."
    numberFormatter.minimumFractionDigits = 1
    numberFormatter.maximumFractionDigits = 3
    return numberFormatter
}()
#endif
