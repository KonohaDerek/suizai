# System architecture

## Proposed stack

- Shared storage core: Rust
- Android app and service: Kotlin + Jetpack Compose
- iOS app and extension: Swift + SwiftUI
- Metadata: SQLite
- Secrets: Android Keystore / iOS Keychain
- Platform integration: DocumentsProvider / File Provider Extension

Kotlin Multiplatform may be evaluated for non-filesystem application logic, but the system integrations remain native. Rust is proposed for provider I/O, cache coordination and reusable filesystem semantics.

## Component boundaries

```text
Android UI/service                 iOS UI/extension
        │                                 │
        └──────── Native bridge ──────────┘
                          │
                    Rust core
        ┌─────────────────┼──────────────────┐
        │                 │                  │
 Provider registry   Metadata index     Cache engine
        │                                    │
 SMB / WebDAV / S3 / SFTP / cloud APIs   Chunk store
```

## Major modules

### Account manager

- Creates provider instances.
- Stores secrets only in platform secure storage.
- Handles OAuth refresh and account revocation.
- Exposes connection health without exposing credentials.

### Provider registry

- Resolves a mount point to a provider instance.
- Advertises capabilities such as random read, atomic move and server-side copy.
- Normalizes identifiers without assuming POSIX paths.

### Metadata index

- Stable document IDs for platform integrations.
- Directory listings, versions, ETags, modification timestamps and sync state.
- Does not treat stale cached metadata as confirmed remote state.

### Cache engine

- Configurable size budget.
- Whole-file cache initially; chunk cache after correctness is established.
- LRU eviction for unpinned clean data.
- Offline pins protected from automatic eviction.
- Dirty data cannot be evicted until committed or explicitly recovered.

### Sync/write-back coordinator

- Durable upload journal.
- Idempotent retry where provider semantics permit it.
- Conflict copies rather than silent overwrite when versions diverge.
- Explicit states: local-only, uploading, synced, conflict, failed.

## Data path

```text
Client requests file
        ↓
Metadata lookup
        ↓
Cache hit? ── yes ─→ local read
        │
        no
        ↓
Provider range/whole-file read
        ↓
Verified local cache
        ↓
Return descriptor/stream
```

## Provider delivery order

1. Local test provider
2. WebDAV
3. SMB3
4. S3-compatible storage
5. Google Drive
6. Microsoft OneDrive
7. SFTP
8. Dropbox
9. OpenList provider in v2

WebDAV is the first remote implementation because it validates hierarchical file behavior with lower OAuth complexity. SMB follows because home NAS access is a core use case.
