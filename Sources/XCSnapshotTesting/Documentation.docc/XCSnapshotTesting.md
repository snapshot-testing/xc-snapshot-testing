# ``XCSnapshotTesting``

Compare values with reference snapshots stored next to your tests.

## Overview

``assert(of:as:serialization:named:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)``
runs a value through a ``Snapshot`` strategy and compares the result with the reference saved on
disk. The first run has no reference, so the snapshot is recorded and the assertion fails. Run the
test again to compare against it.

```swift
import XCSnapshotTesting
import XCTest

final class ProfileTests: XCTestCase {
    func testProfileView() async throws {
        try await assert(of: ProfileView(), as: .image)
    }
}
```

References live in a `__Snapshots__` directory beside the test file, in a folder named after the
platform and the test file: `__Snapshots__/iOS/ProfileTests/testProfileView.1.png`. Use ``RecordMode``
to choose when references are written, and ``DiffTool`` to choose what a failure prints to compare
the files.

To use it from Swift Testing, with traits such as `.record(_:)` and `.diffTool(_:)`, add the
`SnapshotTesting` library from the `swift-snapshot-testing` package.

## Topics

### Asserting

- ``assert(of:as:serialization:named:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)``
- ``assert(of:as:serialization:named:record:snapshotDirectory:timeout:isolation:fileID:file:testName:line:column:)``
- ``verify(of:as:serialization:named:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)``
- ``verify(of:as:serialization:named:record:snapshotDirectory:timeout:isolation:fileID:file:testName:line:column:)``
- ``assert(of:as:serialization:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)-97yat``
- ``assert(of:as:serialization:record:snapshotDirectory:timeout:fileID:file:testName:line:column:)-8jkj5``
- ``assert(of:as:serialization:record:snapshotDirectory:timeout:isolation:fileID:file:testName:line:column:)-928gi``
- ``assert(of:as:serialization:record:snapshotDirectory:timeout:isolation:fileID:file:testName:line:column:)-1hd5i``
- ``RecordMode``
- ``TaskTimeout``

### Defining a snapshot strategy

- ``Snapshot``
- ``SnapshotExecutor``
- ``Sync``
- ``Async``
- ``SyncSnapshot``
- ``AsyncSnapshot``
- ``IdentitySyncSnapshot``
- ``IdentityAsyncSnapshot``
- ``SyncContinuation``

### Serializing snapshots

- ``BytesRepresentable``
- ``BytesContainer``
- ``BytesSerializationError``
- ``DataSerialization``
- ``DataSerializationConfiguration``
- ``DataSerializationConfigurationKey``
- ``DataBytes``
- ``StringBytes``
- ``ImageBytes``
- ``ImageFormat``

### Reporting differences

- ``DiffAttachmentGenerator``
- ``DiffAttachment``
- ``DataDiffAttachmentGenerator``
- ``StringDiffAttachmentGenerator``
- ``ImageDiffAttachmentGenerator``
- ``DiffTool``
- ``SnapshotAttachment``

### Configuring the environment

- ``SnapshotEnvironment``
- ``SnapshotEnvironmentValues``
- ``SnapshotEnvironmentKey``
- ``withTestingEnvironment(_:operation:file:line:)-7a0j4``
- ``withTestingEnvironment(_:operation:file:line:)-6chs6``
- ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:operation:file:line:)-9dns4``
- ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:operation:file:line:)-8wyqi``
- ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:environment:operation:file:line:)-3trzi``
- ``withTestingEnvironment(record:diffTool:maxConcurrentTests:platform:environment:operation:file:line:)-9j11c``

### Rendering views

- ``SnapshotLayout``
- ``LayoutConfiguration``
- ``DeviceOrientation``
- ``DeviceLayoutRatio``
- ``Traits``
- ``InterfaceSizeClass``
- ``DeviceInterfaceSizeClass``
- ``DeviceDynamicInterfaceSizeClass``
