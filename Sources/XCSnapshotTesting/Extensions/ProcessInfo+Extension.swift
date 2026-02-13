import Foundation

extension ProcessInfo {

    static var artifactsDirectory: URL {
        let env = ProcessInfo.processInfo.environment

        return URL(
            fileURLWithPath: env["SNAPSHOT_ARTIFACTS"] ?? NSTemporaryDirectory(),
            isDirectory: true
        )
    }
}
