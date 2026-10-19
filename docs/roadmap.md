# Roadmap

Track live progress in the [project board](https://github.com/users/KonohaDerek/projects/4), using the [issue workflow and dependencies](issue-workflow.md). Platform targets and unverified device lanes are recorded in the [support matrix](platform-support.md). Roadmap entries describe planned capabilities, not released features.

## Phase 0 — Feasibility

- Minimal Android DocumentsProvider.
- BOOK☆WALKER storage enumeration tests.
- AOSP virtual-disk and privileged-mount experiments.
- Minimal iOS File Provider spike using a local/mock backend.
- Decide whether the shared Rust core is viable inside both platform lifecycles.

Exit criterion: documented compatibility result and a go/no-go decision for Android legacy-app mode.

## Phase 1 — Standalone MVP

- Native Android and iOS account setup.
- WebDAV and SMB providers.
- Unified browser.
- DocumentsProvider and File Provider integration.
- Whole-file on-demand cache.
- Offline pinning.
- Secure credential storage.
- Upload journal, retry and conflict copies.

## Phase 1.5 — Public beta quality

- S3-compatible provider.
- Google Drive and OneDrive OAuth providers.
- Transfer queue and diagnostic UI.
- Cache budget controls and safe eviction.
- Accessibility, localization and tablet layouts.
- Reliability test suite with network fault injection.

## Phase 2 — Ecosystem expansion

- OpenList provider.
- SFTP and Dropbox.
- Optional connection synchronization without syncing credentials in plaintext.
- Share extension and deep links.
- Provider SDK documentation.

## Phase 3 — Advanced virtualization

- Android legacy-app compatibility edition if Phase 0 succeeds.
- Chunk cache and adaptive read-ahead.
- Desktop feasibility for macOS and Windows.
- Optional end-to-end encrypted overlay.

## Initial backlog

1. Record supported OS versions and test-device matrix.
2. Implement stable-ID local mock provider.
3. Build Android DocumentsProvider conformance tests.
4. Run BOOK☆WALKER compatibility experiment.
5. Build File Provider mock domain on iOS.
6. Define cache state machine and crash-recovery invariants.
7. Implement WebDAV provider contract tests.
8. Perform threat-model review before real credentials are accepted.

## Release gates

- No silent data loss under interrupted upload tests.
- No credential leakage in logs or backups.
- Cache limit remains enforceable while preserving dirty and pinned data.
- System provider remains functional after app/extension termination.
- Public claims match verified platform behavior.
