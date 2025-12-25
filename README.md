[![Swift Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsnapshot-testing%2Fxc-snapshot-testing%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/snapshot-testing/xc-snapshot-testing)
[![Platform Compatibility](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsnapshot-testing%2Fxc-snapshot-testing%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/snapshot-testing/xc-snapshot-testing)
[![codecov](https://codecov.io/gh/snapshot-testing/xc-snapshot-testing/graph/badge.svg?token=YN43HSRRAU)](https://codecov.io/gh/snapshot-testing/xc-snapshot-testing)

# XCSnapshotTesting

XCSnapshotTesting is a comprehensive, cross-platform snapshot testing library for Swift that enables reliable UI and data structure testing across iOS, macOS, tvOS, watchOS, and visionOS. The library provides powerful tools for capturing, comparing, and verifying snapshots of your UI elements, data structures, and more, with support for both UIKit and SwiftUI.

## [Documentation](https://swiftpackageindex.com/snapshot-testing/xc-snapshot-testing/main/documentation/xcsnapshottesting)

Check out our comprehensive documentation to get all the necessary information to start using XCSnapshotTesting in your project.

## Installation

XCSnapshotTesting can be installed using Swift Package Manager. To include it in your project, add the following dependency to your Package.swift file:

```swift
dependencies: [
    .package(url: "https://github.com/snapshot-testing/xc-snapshot-testing", from: "1.0.0")
]
```

## Usage

XCSnapshotTesting provides a comprehensive framework for snapshot testing across different platforms. It supports both synchronous and asynchronous snapshot testing for various types of content including UI elements, data structures, and more.

### Basic Usage

The primary function for snapshot testing is `assert(of:as:named:)`. Here are the most common usage patterns:

#### UI Snapshot Testing

For UI elements like views or view controllers:

```swift
import XCSnapshotTesting
import XCTest

class MyViewControllerTests: XCTestCase {
    func testViewController() async throws {
        let vc = MyViewController()
        
        // Basic snapshot of a view
        try await assert(
            of: vc.view,
            as: .image
        )
        
        // With specific device layout
        try await assert(
            of: vc.view, 
            as: .image(layout: .device(.iPhone15Pro))
        )
        
        // With custom precision and name
        try await assert(
            of: vc.view,
            as: .image(
                precision: 0.95,
                layout: .device(.iPhone15Pro)
            ),
            named: "light-mode"
        )
    }
}
```

#### Data Structure Snapshot Testing

For data structures like JSON, arrays, dictionaries, etc.:

```swift
func testDataStructure() async throws {
    let data = ["name": "John", "age": 30]
    
    // Test as JSON
    try await assert(
        of: data,
        as: .json
    )
    
    // Test as pretty-printed JSON
    try await assert(
        of: data,
        as: .json(pretty: true)
    )
}
```

#### Multiple Snapshots in One Test

You can test multiple configurations in a single test:

```swift
func testMultipleConfigurations() async throws {
    let view = MyCustomView()
    
    // Test with multiple device layouts
    try await assert(
        of: view,
        as: [
            "iPhone": .image(layout: .device(.iPhone15Pro)),
            "iPad": .image(layout: .device(.iPadPro)),
            "Dark": .image(layout: .device(.iPhone15ProDark))
        ]
    )
}
```

### Recording Mode

By default, the library uses the environment's recording mode, but you can override it:

```swift
func testWithRecordingOverride() async throws {
    // Force recording a new snapshot
    try await assert(
        of: myView,
        as: .image,
        record: .always  // or .never to prevent recording
    )
}
```

### Advanced Configuration

You can customize various aspects of snapshot testing:

```swift
func testAdvancedConfiguration() async throws {
    let view = MyCustomView()
    
    try await assert(
        of: view,
        as: .image(
            precision: 0.98,           // Pixel tolerance
            perceptualPrecision: 0.95, // Color/tone tolerance
            layout: .device(.iPhone15Pro),
            delay: 0.1                 // Wait before capturing
        ),
        serialization: .init(          // Additional serialization options
            maxSize: CGSize(width: 1000, height: 1000)
        ),
        named: "custom-snapshot"
    )
}
```

### Testing Environment Configuration

You can configure the testing environment globally:

```swift
override func setUp() {
    super.setUp()
    
    // Configure global testing environment
    withTestingEnvironment(
        record: .never,  // Default to never record
        diffTool: .imageMagick,  // Use ImageMagick for diffs
        maxConcurrentTests: 4
    ) {
        // Tests run with these settings
    }
}
```

### Supported Platforms

XCSnapshotTesting supports:

- iOS (13.0+)
- macOS (10.15+)
- tvOS (13.0+)
- watchOS (6.0+)

### Available Snapshot Types

The library provides various built-in snapshot types:

- `.image` - For UI elements (views, view controllers, etc.)
- `.json` - For JSON-serializable data
- `.text` - For string content
- `.html` - For HTML content
- `.xml` - For XML content
- `.data` - For raw data

### Asynchronous vs Synchronous

The library provides both asynchronous and synchronous versions of the `assert` function:

- Use `assert(of:as:) async` for asynchronous operations
- Use `assert(of:as:)` for synchronous operations

### Custom Dump Snapshots

The package includes an additional module `XCSnapshotTestingCustomDump` that provides snapshot strategies based on the [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump) library. This allows for human-readable, structured snapshots of complex Swift types:

```swift
import XCSnapshotTesting
import XCSnapshotTestingCustomDump  // Import for custom dump functionality
import XCTest

func testCustomDump() throws {
    struct User {
        let id: Int
        let name: String
        let bio: String
    }
    
    let user = User(id: 1, name: "Blobby", bio: "Blobbed around the world.")
    
    // Test using custom dump representation
    try assert(
        of: user,
        as: .customDump
    )
}
```

### Testing Traits

The library provides a `Traits` system that allows you to customize the environment in which UI elements are rendered during snapshot testing. This is particularly useful for testing different accessibility settings, content size categories, and interface styles:

```swift
func testWithTraits() async throws {
    let view = MyCustomView()
    
    // Test with specific accessibility traits
    var traits = Traits()
    traits.preferredContentSizeCategory = .extraLarge
    traits.userInterfaceStyle = .dark
    
    try await assert(
        of: view,
        as: .image(
            layout: .device(.iPhone15Pro),
            traits: traits
        ),
        named: "accessibility-large-dark"
    )
}
```

This allows you to ensure your UI renders correctly across different accessibility settings, content sizes, and interface styles.

### Device Layouts

The library provides comprehensive device simulation capabilities. You can test your UI across various device sizes, orientations, and split-view configurations:

```swift
func testMultipleDeviceLayouts() async throws {
    let vc = MyViewController()
    
    // Test different iPhone layouts
    try await assert(
        of: vc,
        as: .image(layout: .device(.iPhone15Pro(.portrait)))
    )
    
    try await assert(
        of: vc,
        as: .image(layout: .device(.iPhone15Pro(.landscape)))
    )
    
    // Test iPad layouts including split-view
    try await assert(
        of: vc,
        as: .image(layout: .device(.iPadPro12_9(.landscape(.regular))))
    )
    
    try await assert(
        of: vc,
        as: .image(layout: .device(.iPadPro12_9(.landscape(.medium))))
    )
    
    try await assert(
        of: vc,
        as: .image(layout: .device(.iPadPro12_9(.landscape(.compact))))
    )
}
```

### Alternative Snapshot Methods

In addition to image snapshots, you can also capture recursive descriptions of your views:

```swift
func testRecursiveDescription() async throws {
    let vc = MyViewController()
    
    // Capture the view hierarchy as text
    try await assert(
        of: vc,
        as: .recursiveDescription(layout: .device(.iPhone15Pro))
    )
}
```

### SwiftUI Support

XCSnapshotTesting also supports SwiftUI views directly. You can test SwiftUI views just like UIKit/AppKit views:

```swift
import SwiftUI
import XCSnapshotTesting
import XCTest

@MainActor
func testSwiftUIView() async throws {
    struct MyView: SwiftUI.View {
        var body: some SwiftUI.View {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Checked").fixedSize()
            }
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 5.0).fill(Color.blue))
            .padding(10)
            .background(Color.yellow)
        }
    }
    
    let view = MyView()
    
    try await assert(
        of: view,
        as: .image  // This will render the SwiftUI view and take a snapshot
    )
    
    // Test with specific sizing
    try await assert(
        of: view,
        as: .image(layout: .sizeThatFits),
        named: "size-that-fits"
    )
}
```

## Versioning

We follow semantic versioning for this project. The version number is composed of three parts: MAJOR.MINOR.PATCH.

- MAJOR version: Increments when there are incompatible changes and breaking changes. These changes may require updates to existing code and could potentially break backward compatibility.

- MINOR version: Increments when new features or enhancements are added in a backward-compatible manner. It may include improvements, additions, or modifications to existing functionality.

- The PATCH version includes bug fixes, patches, and safe modifications that address issues, bugs, or vulnerabilities without disrupting existing functionality. It may also include new features, but they must be implemented carefully to avoid breaking changes or compatibility issues.

It is recommended to review the release notes for each version to understand the specific changes and updates made in that particular release.

## Contributing

If you find a bug or have an idea for a new feature, please open an issue or  submit a pull request. We welcome contributions from the community!
