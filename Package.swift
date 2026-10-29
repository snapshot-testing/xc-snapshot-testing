// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "xc-snapshot-testing",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "XCSnapshotTesting",
            targets: ["XCSnapshotTesting"]
        ),
        .library(
            name: "XCSnapshotTestingCustomDump",
            targets: ["XCSnapshotTestingCustomDump"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/o-nnerb/swift-async-stream", from: "2.1.4"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
    ],
    targets: [
        .target(
            name: "XCSnapshotTesting",
            dependencies: [
                .product(name: "SwiftAsyncStream", package: "swift-async-stream")
            ]
        ),
        .target(
            name: "XCSnapshotTestingCustomDump",
            dependencies: [
                "XCSnapshotTesting",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .testTarget(
            name: "XCSnapshotTestingTests",
            dependencies: ["XCSnapshotTesting"],
            exclude: [
                "__Fixtures__",
                "__Snapshots__",
            ]
        ),
        .testTarget(
            name: "XCSnapshotTestingCustomDumpTests",
            dependencies: [
                "XCSnapshotTestingCustomDump"
            ]
        ),
    ]
)
