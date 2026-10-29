import Foundation

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UniformTypeIdentifiers
#endif

extension String {

    func sanitizingPointersReferences() -> String {
        replacingOccurrences(
            of: ":?\\s*0x[\\da-f]+(\\s*)",
            with: "$1",
            options: .regularExpression
        )
    }

    func sanitizingPathComponent() -> String {
        // see for ressoning on charachrer sets https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return
            self
            // Only applies to functions without parameters
            .replacingOccurrences(of: "()", with: "")
            .components(separatedBy: invalidCharacters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "")
    }

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    func uniformTypeIdentifier() -> String? {
        UTType(filenameExtension: self)?.identifier
    }
    #endif
}
