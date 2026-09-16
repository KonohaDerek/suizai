# Android compatibility PoC

## Objective

Determine the least-privileged integration that lets BOOK☆WALKER store and reopen downloaded content backed by SUIZAI.

Do not build the production provider matrix before this experiment answers the compatibility question.

## Test matrix

| Stage | Storage surface | Privilege | Success condition |
|---|---|---:|---|
| A | Minimal DocumentsProvider | None | SUIZAI appears in the system picker and a test client can read/write |
| B | App-specific external directory | None | Determine whether BOOK☆WALKER enumerates the surface |
| C | AOSP virtual disk on emulator/test device | adb/test environment | BOOK☆WALKER recognizes a removable StorageVolume |
| D | FUSE/bind-mounted directory | Root/Magisk | Target app can read, write, rename and reopen data |
| E | Registered virtual portable volume | System-level research | Volume survives reboot and reports correct state |

## Test devices

- Android Emulator or AOSP reference image
- Rootable Pixel/reference device
- At least one Samsung device because OEM storage behavior may differ
- Current supported Android release plus the oldest planned target

## Observations to record

- Which volumes and paths BOOK☆WALKER displays.
- Whether it uses `StorageManager.storageVolumes`, `getExternalFilesDirs`, SAF or custom checks.
- Requirements for removable flag, UUID, filesystem type and free space.
- Behavior across reboot, network loss and cache eviction.
- Sequence of filesystem operations during a book download.
- Whether DRM data is tied to inode, absolute path, device storage ID or app-private metadata.

## Safety constraints

- Use a dedicated test account and test device.
- Do not move irreplaceable DRM content during early tests.
- Never report a remote write as complete before durable confirmation.
- Root/Magisk support must be a separate distribution and threat model.

## Go/no-go decision

- **Go, standard edition:** BOOK☆WALKER accepts DocumentsProvider or another public API.
- **Go, advanced edition:** compatibility works reliably through an opt-in privileged component.
- **Re-scope:** compatibility depends on fragile framework modification or breaks DRM integrity.
