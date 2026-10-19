# Android Phase 0 實機驗證

完整操作與回報格式：[台灣正體中文](testing-zh-TW.md) · [English](testing-en.md) · [日本語](testing-ja.md)。App 首次啟動預設台灣正體中文，可在 App 內切換並記住語言。

此測試版透過 Android DocumentsProvider 提供本機模擬檔案。驗證時請先展開系統檔案選擇器左上角的儲存位置清單，再尋找 SUIZAI。App 的檔案自我檢查、系統選擇器與 BOOK☆WALKER 相容性是分別需要紀錄的結果。

## 自行建置

- JDK 17
- Android Gradle Plugin 9.4.0 / Gradle 9.6.0
- Android SDK Platform 36 / Build Tools 36.0.0
- Rust 1.85.1，目標 `aarch64-linux-android` 與 `x86_64-linux-android`
- Android NDK 27.2.12479018 / CMake 3.22.1
- Android 8.0 以上 `arm64-v8a` 測試裝置，或 `x86_64` 模擬器

先安裝固定版本與 Rust 目標，並讓建置環境可使用 `cargo`、`rustup` 與 `ANDROID_HOME`：

```sh
rustup toolchain install 1.85.1 --profile minimal
rustup target add --toolchain 1.85.1 aarch64-linux-android x86_64-linux-android
sdkmanager --install "platforms;android-36" "build-tools;36.0.0" "ndk;27.2.12479018" "cmake;3.22.1"
```

Gradle 會呼叫 `.github/scripts/build-android-core.sh` 產生兩個 ABI 的 Rust 靜態函式庫，再由 CMake 連結 JNI。共享函式庫採 16 KiB 頁面對齊；實際裝置相容性仍待驗證。

在相容的 Android Studio 開啟儲存庫，或使用上述 Gradle 執行 `testDebugUnitTest assembleDebug assembleDebugAndroidTest`。儲存庫未附上產生的 Gradle wrapper JAR；如需 wrapper，請以可信任的本機 Gradle 產生。

CI 的模擬器結果不會取代實機驗收。先將結果記錄到 #1、#2、#3，以及 Rust 橋接的 #6，再由 #10 整理 Phase 0 決策；列出儲存位置本身不代表可直接進入遠端儲存或進階掛載實作。
