# ``XCSnapshotTestingCustomDump``

Snapshot any value as a custom dump.

## Overview

Import the module to get the `.customDump` strategy, which turns a value into the text that
[CustomDump](https://github.com/pointfreeco/swift-custom-dump) prints for it:

```swift
import XCSnapshotTesting
import XCSnapshotTestingCustomDump

try assert(of: user, as: .customDump)
```
