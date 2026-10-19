# Platform support and validation matrix

Decision for [#5](https://github.com/KonohaDerek/suizai/issues/5), recorded 2026-10-11. These are engineering targets, not a claim that a shipping app has passed them. Device checks remain pending; this iteration covers code, CI and downloadable test builds.

## Baselines

| Platform | Minimum runtime | Current validation target | Build baseline | Rationale |
|---|---|---|---|---|
| Android | Android 8.0 / API 26 | Android 17 / API 37, plus Android 16 / API 36 | PoC keeps compile/target SDK 36, JDK 17, AGP 9.4.0, Gradle 9.6.0 | Preserve the existing PoC minimum and passing CI configuration; test newer OS behavior separately before changing the target SDK. |
| iOS / iPadOS | 17.0 | 27.0.1 | Native SwiftUI app and File Provider extension; local Xcode 26.6 / iOS SDK 26.5 | Limit the initial native implementation and regression surface; keep app and extension deployment targets equal. The installed SDK does not validate iOS 27. |

Android's [SDK setup guide](https://developer.android.com/about/versions/17/setup-sdk) identifies Android 17 as API 37. Apple's [security releases](https://support.apple.com/en-us/100100) list iOS/iPadOS 27.0.1 as current on the decision date. Recheck both sources before a beta/release; a newer version is a new test lane, not automatic support. Upgrade build SDKs and check store requirements before public distribution.

## Required test lanes

All device results below are **pending**. A proposed device is not an available or tested device. Record exact model, OS build, app commit/APK checksum, client version, steps and results in each issue's report.

| Lane | Representative environment | Required coverage | Evidence owner |
|---|---|---|---|
| Android minimum | AOSP emulator API 26 | Provider discovery, projections, CRUD, stable IDs, cancellation and notifications | #1 |
| Android regression | AOSP emulator API 33/36 | Same conformance suite, permission and URI grant boundaries | #1 |
| Android reference | Dedicated Pixel/reference device on Android 16 and current Android 17 | System picker, SAF editor, restart/reboot, persistence and BOOK☆WALKER enumeration | #1, #2, #3 |
| Android OEM | Dedicated Samsung Galaxy device on Android 16 or 17; record One UI version | Same end-to-end storage flow; compare OEM volume enumeration and lifecycle | #2, #3, #4 |
| Android privileged research | Separate rootable reference device or disposable AOSP image | Only after normal-permission results; record adb/root/system-image requirements | #4 |
| iOS minimum | iPhone simulator and dedicated physical device on iOS 17.x | Store tests; physical Files domain add/remove, nested enumeration, materialization, mutation, app/extension termination | #8 |
| iOS current | Dedicated iPhone supporting iOS 27.0.1, e.g. iPhone 16 | Same Files integration and lifecycle checks; authentication/background constraints | #8 |
| iPadOS current | Dedicated iPad supporting iPadOS 27.0.1, e.g. iPad (10th generation) | Files integration now; tablet, keyboard and accessibility flows in beta | #8, #25 |

Local inventory on 2026-10-11: Android SDK platforms 33/34 and AVD definitions API 31/33; no connected Android device. Xcode reports SDK 26.5 and installed simulator definitions 17.4/18.3. Availability is not execution evidence, and these runtimes do not cover the current OS lanes. Minimum-version simulator availability must be verified in CI; do not replace missing API 26 / iOS 17 coverage with a newer runtime and mark the minimum tested.

## Release decisions

- A build or unit-test pass does not establish picker discovery, URI permissions, Files behavior, reboot persistence or OEM compatibility.
- Phase 0 uses disposable local fixtures. BOOK☆WALKER tests require a dedicated account/device and replaceable content supplied by the tester.
- Android's ordinary DocumentsProvider edition has no root requirement. Any virtual-volume/root experiment is separate and confers no compatibility promise.
- iOS has no SD-card or BOOK☆WALKER download-relocation support. Remote providers and OpenList remain roadmap work.
- #10 records the final go/no-go after #1–#8 evidence. #41 checks every public support claim against this matrix and actual reports before release.
