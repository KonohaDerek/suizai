# Android app-specific external storage probe

This Phase 0 probe tests whether BOOK☆WALKER can discover or use an ordinary app-specific external-files directory. It uses normal app permissions only. It does not create a removable volume, bypass Android storage isolation, or test real DRM files.

## Prepare

1. Install the debug APK on a test device and open **SUIZAI 隨載**.
2. Tap **Create test folders**. For each `getExternalFilesDirs(null)` location, the screen shows its Android availability state and path. A mounted location gets a fresh `suizai-external-probe/run-…` directory with `SUIZAI-test.txt`.
3. Long-press the displayed text to copy the test-folder path. The app checks create, write, reopen, rename, and delete of a temporary file in its own folder, then leaves the disposable text file for inspection. A successful app file check says nothing about BOOK☆WALKER access.
4. Repeated taps create new run folders. Existing folders and any files you add to them are left untouched. Remove old test folders manually only after recording results.

## Check BOOK☆WALKER manually

1. In BOOK☆WALKER, inspect the available storage locations and record their displayed names and paths, if shown.
2. Check whether the new SUIZAI test-folder path is listed or can be selected. Record the exact screen and error if it cannot.
3. Only if BOOK☆WALKER offers a way to open that folder, try reading `SUIZAI-test.txt` and creating, renaming, reopening, and deleting a separate disposable text file there. Do not move or copy real downloaded books or DRM content for this test.
4. Repeat on each reported location and record the Android version, device model, volume state, and BOOK☆WALKER version.

| Location / path | Listed by BOOK☆WALKER? | Read | Create/write/reopen/rename/delete | Evidence |
|---|---|---|---|---|
| Pending | Pending | Pending | Pending | |

On recent Android versions, `Android/data/<app package>/files` is app-specific space and other apps may be blocked from browsing it. A negative result is useful evidence for the storage integration decision. This runbook records a manual compatibility check; no BOOK☆WALKER result has been observed yet.
