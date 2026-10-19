# SUIZAI 隨載

> Every file, ready anywhere. 你的檔案，隨在隨載。

SUIZAI is a proposed privacy-first mobile storage virtualization layer for iOS and Android. Its goal is to connect cloud drives, NAS devices, and object storage directly from the phone and make remote files available to other apps with on-demand caching. Remote accounts, caching and production security controls are not implemented yet.

## Product thesis

Existing mobile file managers are good at browsing remote files. SUIZAI focuses on making remote storage behave like local storage:

- Connect directly to SMB, WebDAV, S3, SFTP and major cloud providers.
- Browse every account in one app without deploying a server.
- Expose storage through Android DocumentsProvider and Apple File Provider.
- Download files on demand with bounded local cache and offline pinning.
- Research an Android compatibility layer for apps that only recognize StorageVolume paths.
- Add OpenList as an optional provider in v2, never as a v1 dependency.

## Planned platform scope

| Capability | Android | iOS |
|---|---:|---:|
| Unified storage browser | Planned | Planned |
| System file picker integration | DocumentsProvider PoC | File Provider spike |
| Files on demand and offline pinning | Planned | Planned |
| Virtual SD compatibility research | PoC, privileged/root path | Not supported by iOS |
| BOOK☆WALKER storage experiment | Primary PoC | Not promised |

## Repository status

Phase 0 specifications and prototype work are tracked in [GitHub Projects](https://github.com/users/KonohaDerek/projects/4). The Android local mock is under review in [PR #43](https://github.com/KonohaDerek/suizai/pull/43). A CI build or downloadable test APK does not establish device compatibility. Use only disposable, non-sensitive test files; do not enter real provider credentials. Phase 1 begins after the evidence-based decision in [#10](https://github.com/KonohaDerek/suizai/issues/10).

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
- [Platform support and validation matrix](docs/platform-support.md)
- [Issue delivery workflow and dependencies](docs/issue-workflow.md)

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
