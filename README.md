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

This repository currently contains product and engineering specifications. Implementation begins only after the Android compatibility PoC establishes which storage surface BOOK☆WALKER accepts.

## Documentation

- [Product vision](docs/product-vision.md)
- [Market and competition](docs/market-analysis.md)
- [System architecture](docs/architecture.md)
- [Storage provider contract](docs/storage-provider-contract.md)
- [Android compatibility PoC](docs/android-poc.md)
- [iOS File Provider plan](docs/ios-file-provider.md)
- [Security model](docs/security-model.md)
- [Roadmap](docs/roadmap.md)

## Working name

**SUIZAI / 隨載** combines Taiwanese 「隨在」—wherever or as you please—with 「載」—load on demand. The name is a working product mark pending formal trademark and store-name clearance.

## License

No open-source license has been selected. All rights are reserved until the licensing strategy is decided.
