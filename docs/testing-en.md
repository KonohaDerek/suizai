# SUIZAI Android device testing guide

## Installation and language

1. Sign into GitHub with access to this private repository. Download `suizai-<version>.apk`, `SHA256SUMS` and this guide from the Release. Manual testing does not require `androidTest.apk`.
2. Compare `shasum -a 256 suizai-<version>.apk` with `SHA256SUMS`. Release and Packages contain the same application APK.
3. Install on an Android 8.0+ test device and allow the installation source when prompted. Each CI build uses a different debug signing key; replacing an older build may require uninstalling it, which deletes the app's local data and test files. Preserve needed test records first.
4. Open the app. First launch defaults to **台灣正體中文** (Taiwan Traditional Chinese). Use **語言 / Language** to select **English** or **日本語**, close and reopen the app, and confirm your choice is retained. This does not change the phone or BOOK☆WALKER language.
5. Changing language does not rewrite existing files or change document IDs. Newly created test files use the app language at creation; existing files retain their original content.

## System file picker (issue #1)

1. Tap **Open system file picker**, then open the upper-left menu to expand the **storage locations**. The Recents screen alone does not list every storage provider.
2. Select **SUIZAI 隨載** and check that `Books/README.txt` is visible and readable.
3. In a text editor that supports the system picker, create a disposable text file in SUIZAI; write, close, reopen, rename and delete it.
4. Reboot the phone and confirm that SUIZAI and retained test files remain accessible.
5. If SUIZAI is still missing after opening the location list, record “not listed in system picker” with the full location list and device details. The app's self-check does not prove this check passed.

Earlier PoC builds used path-based document IDs. Their saved file grants are not migrated to this UUID-based build; reselect files in the system picker.

## App-specific storage (issue #3)

1. Tap **Create test folders**. Each writable app-specific location gets a fresh `suizai-external-probe/run-…` folder containing `SUIZAI-test.txt`.
2. The screen shows storage state, app-storage path, test-folder path and self-check result. Long-press the text to copy a path.
3. The self-check creates, writes, renames, reopens and deletes the app's own temporary file. Passing means SUIZAI can operate in its own folder; **it does not prove BOOK☆WALKER has access**.
4. Select each of the three languages and create a fresh folder. Check that the new `SUIZAI-test.txt` matches the language selected at creation; earlier folders and files must stay unchanged. Remove unwanted test data manually after recording results.

## BOOK☆WALKER compatibility (issues #2 and #3)

1. Use a dedicated test account/device and disposable content. Inspect BOOK☆WALKER storage settings and record the displayed names and paths.
2. Record whether the screen offers only storage roots, or also a subdirectory choice/system picker. An existing SD-card root is not a new SUIZAI virtual disk.
3. Only if the app offers a way to select the test folder or operate on text files, try reading `SUIZAI-test.txt` and creating, writing, reopening, renaming and deleting a separate disposable text file.
4. If the location or operation is unavailable, record “not listed / operation unavailable” and the screen shown. Do not relocate existing downloaded books or copy DRM content for this test.

## Report template

Report system-picker results in [#1](https://github.com/KonohaDerek/suizai/issues/1); report app-specific directory/BOOK☆WALKER results in [#3](https://github.com/KonohaDerek/suizai/issues/3).

| Field | Record |
|---|---|
| Device | Manufacturer, model, Android version, system build |
| Software | Release version, APK SHA-256, BOOK☆WALKER/text-editor versions |
| Language | 台灣正體中文 / English / 日本語; retained after app relaunch? |
| System picker | Is SUIZAI in the location list? Each file operation and reboot result |
| Storage directory | Path, storage state and self-check result |
| BOOK☆WALKER | Is the test location listed/selectable? Available operations and results |
| Evidence | Steps, errors and screenshots with phone/network identifiers hidden |

This test build checks compatibility using local mock files. Remote storage, OAuth, cache encryption, root mounting and interrupted-upload recovery are not implemented. Passing CI does not establish device or BOOK☆WALKER compatibility.

To run the automated device suite yourself, optionally install the matching Release's `androidTest.apk` and run `adb shell am instrument -w tw.suizai.app.test/androidx.test.runner.AndroidJUnitRunner`. Manual testers can skip this step.
