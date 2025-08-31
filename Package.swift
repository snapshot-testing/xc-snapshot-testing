// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "xc-snapshot-testing",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
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
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    ],
    targets: [
        .target(
            name: "XCSnapshotTesting"
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
