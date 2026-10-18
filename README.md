# SUIZAI 隨載

> Every file, ready anywhere. 你的檔案，隨在隨載。

SUIZAI is a privacy-first mobile storage virtualization layer for iOS and Android. It connects cloud drives, NAS devices, and object storage directly from the phone, presents them through one consistent interface, and makes remote files available to other apps with on-demand caching.

## Product thesis

Existing mobile file managers are good at browsing remote files. SUIZAI focuses on making remote storage behave like local storage:

- Connect directly to SMB, WebDAV, S3, SFTP and major cloud providers.
- Browse every account in one app without deploying a server.
- Expose storage through Android DocumentsProvider and Apple File Provider.
- Download files on demand with bounded local cache and offline pinning.
- Research an Android compatibility layer for apps that only recognize StorageVolume paths.
- Add OpenList as an optional provider in v2, never as a v1 dependency.

## Platform scope

| Capability | Android | iOS |
|---|---:|---:|
| Unified storage browser | Yes | Yes |
| System file picker integration | DocumentsProvider | File Provider Extension |
| Files on demand and offline pinning | Yes | Yes |
| Virtual SD compatibility research | PoC, privileged/root path | Not supported by iOS |
| BOOK☆WALKER storage experiment | Primary PoC | Not promised |

## Repository status

Phase 0 implementation is in progress. The Android app currently exposes a local mock directory through `DocumentsProvider` so the system file picker and BOOK☆WALKER discovery behavior can be tested before remote backends are introduced.

## Documentation

- [Product vision](docs/product-vision.md)
- [Market and competition](docs/market-analysis.md)
- [System architecture](docs/architecture.md)
- [Storage provider contract](docs/storage-provider-contract.md)
- [Android compatibility PoC](docs/android-poc.md)
- [Android Phase 0 runbook](docs/android-phase0-runbook.md)
- [iOS File Provider plan](docs/ios-file-provider.md)
- [Security model](docs/security-model.md)
- [Roadmap](docs/roadmap.md)

## Android Phase 0 實機測試

測試版首次啟動預設台灣正體中文，可切換 English 或日本語並保留選擇。App 操作說明、新建立的測試檔與驗證指南均提供三語；既有檔案保留原文。

- [台灣正體中文測試指南](docs/testing-zh-TW.md)
- [English testing guide](docs/testing-en.md)
- [日本語テストガイド](docs/testing-ja.md)

從 [Releases](https://github.com/KonohaDerek/suizai/releases) 下載測試 APK 與指南，或依 [建置說明](docs/android-phase0-runbook.md) 自行建置。請分別記錄系統檔案選擇器與 BOOK☆WALKER 的驗證結果。

## Working name

**SUIZAI / 隨載** combines Taiwanese 「隨在」—wherever or as you please—with 「載」—load on demand. The name is a working product mark pending formal trademark and store-name clearance.

## License

No open-source license has been selected. All rights are reserved until the licensing strategy is decided.
