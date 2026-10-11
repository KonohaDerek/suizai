# iOS Phase 0 mock File Provider

This spike uses a native SwiftUI app and replicated File Provider extension with an App Group mock catalog. It has no remote account, credentials, network access, Rust bridge, or production sync guarantee. The proposed minimum is iOS 17.0; this is a build baseline, not a validated device support matrix.

## Build and code checks

From the repository root:

```sh
swift test --package-path ios
xcodebuild -project ios/SuizaiPhase0.xcodeproj -target SuizaiPhase0 -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The Swift package exercises the same `MockStore.swift` compiled into both the app and extension. It verifies nested fixtures, stable IDs after reopening the store, materialization, and create/move/write/delete. The Xcode target build compiles the app and embedded extension without launching a simulator. For a device build, select a development team and register the App Group `group.dev.suizai.phase0` for both bundle IDs; the checked-in bundle IDs are placeholders for this spike.

## Device gate still required

On a signed iOS 17+ physical device, install the app, tap **Add Mock Domain**, and check that **SUIZAI Mock** appears under Files > Browse > Locations. Browse `Books/Notes/Welcome.txt`, open and read it, create and rename a text file and directory, move an item, and delete it. Force quit the main app before browsing again; the extension must still enumerate and materialize from the App Group. Tap **Remove Mock Domain** and verify the location disappears. Test app/extension restart, simultaneous writes, and low-memory extension termination separately. Record the device, OS version, result, and any Console errors. These gates have not been executed by the code build.

## Constraints observed in the design

- The extension reads its own App Group catalog and content, so File Provider requests do not require the main app process. A cross-process file lock serializes catalog writes.
- Domain registration and removal use `NSFileProviderManager`; the system owns extension launch and termination. The main app does not run a background service.
- The mock stores no credentials. A real provider needs Keychain access group credentials, refresh and user-actionable authentication errors. Those are outside this spike.
- File content is copied into a temporary URL for materialization; this mock keeps permanent copies in App Group storage. Real cache protection, backup exclusion, coordinated eviction, write-back recovery, and conflict handling remain future work.
- Change enumeration currently re-sends the small catalog. This is sufficient only for a local mock with user-initiated mutations; a real provider needs durable anchors and tombstones for remote edits and deletions.
- File Provider extension execution time, memory, and system scheduling are constrained. No long-running background transfer or retry behavior is claimed here.
