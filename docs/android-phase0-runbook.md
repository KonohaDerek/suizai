# Android Phase 0 runbook

## Purpose

This build exposes a local mock directory as a system `DocumentsProvider`. It answers one question before remote backends are implemented: does the target app discover or accept a standard Storage Access Framework provider?

## Toolchain

- Android Studio compatible with Android Gradle Plugin 9.4.0
- Gradle 9.6.0
- JDK 17
- Android SDK 37 and Build Tools 36.0.0
- Android 8.0+ test device; Android 14+ preferred for the first run

The repository intentionally does not include a generated Gradle wrapper JAR. Open the project with Android Studio and use its configured Gradle 9.6 installation, or generate the wrapper with a trusted local Gradle installation.

## Test procedure

1. Open the repository root in Android Studio.
2. Sync and install the `app` debug build.
3. Launch **SUIZAI 隨載**.
4. Tap **Open system file picker**.
5. Open the navigation drawer and select **SUIZAI 隨載**.
6. Confirm `Books/README.txt` is visible and readable.
7. Use a SAF-aware editor to create, rename, modify and delete a test file.
8. Restart the device and confirm the provider and files remain visible.
9. Open BOOK☆WALKER settings and record every storage option shown.

## Record results

| Check | Result | Evidence/notes |
|---|---|---|
| SUIZAI appears in Android Files | Pending | |
| Read sample file | Pending | |
| Create file | Pending | |
| Write and reopen file | Pending | |
| Rename file | Pending | |
| Delete file | Pending | |
| Survives reboot | Pending | |
| BOOK☆WALKER lists SUIZAI | Pending | |

## Expected interpretation

- If BOOK☆WALKER lists SUIZAI, proceed with a WebDAV adapter behind the provider.
- If Android Files sees SUIZAI but BOOK☆WALKER does not, proceed to the virtual-disk and `StorageVolume` experiment.
- If standard SAF operations fail, fix provider correctness before testing privileged mounts.
