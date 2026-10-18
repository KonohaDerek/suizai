# Android Phase 0 實機驗證

完整操作與回報格式：[台灣正體中文](testing-zh-TW.md) · [English](testing-en.md) · [日本語](testing-ja.md)。App 首次啟動預設台灣正體中文，可在 App 內切換並記住語言。

此測試版透過 Android DocumentsProvider 提供本機模擬檔案。驗證時請先展開系統檔案選擇器左上角的儲存位置清單，再尋找 SUIZAI。App 的檔案自我檢查、系統選擇器與 BOOK☆WALKER 相容性是分別需要紀錄的結果。

## 自行建置

- JDK 17
- Android Gradle Plugin 9.4.0 / Gradle 9.6.0
- Android SDK Platform 36 / Build Tools 36.0.0
- Android 8.0 以上測試裝置

在相容的 Android Studio 開啟儲存庫，或使用上述 Gradle 執行 `testDebugUnitTest assembleDebug assembleDebugAndroidTest`。儲存庫未附上產生的 Gradle wrapper JAR；如需 wrapper，請以可信任的本機 Gradle 產生。

CI 的模擬器結果不會取代實機驗收。先將結果記錄到 #1、#2、#3，再由 #10 整理 Phase 0 決策；列出儲存位置本身不代表可直接進入遠端儲存或進階掛載實作。
