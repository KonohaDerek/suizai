# Storage provider contract

The core uses capabilities instead of pretending every backend is a POSIX filesystem.

```rust
#[async_trait]
pub trait StorageProvider {
    async fn root(&self) -> Result<Entry>;
    async fn list(&self, parent: &EntryId, page: PageRequest) -> Result<Page<Entry>>;
    async fn stat(&self, id: &EntryId) -> Result<Entry>;
    async fn read(&self, id: &EntryId, range: ByteRange) -> Result<ByteStream>;
    async fn create(&self, parent: &EntryId, name: &str, kind: EntryKind) -> Result<Entry>;
    async fn write(&self, target: WriteTarget, source: ByteStream, precondition: VersionMatch) -> Result<Entry>;
    async fn move_entry(&self, id: &EntryId, destination: &EntryId, name: &str) -> Result<Entry>;
    async fn delete(&self, id: &EntryId, precondition: VersionMatch) -> Result<()>;
    async fn quota(&self) -> Result<Option<Quota>>;
    fn capabilities(&self) -> Capabilities;
}
```

## Required model properties

- `EntryId` is opaque and stable within an account.
- Display paths are not primary keys.
- Every mutation accepts a version precondition where the provider supports one.
- Providers report whether range reads, atomic rename, server copy and resumable upload exist.
- Pagination and rate limits are first-class.
- The core never fabricates free-space values for providers without quota APIs.

## Error taxonomy

- Authentication expired
- Permission denied
- Not found
- Version conflict
- Rate limited
- Temporary network failure
- Unsupported operation
- Remote quota exceeded
- Local cache exhausted
- Integrity verification failed

Errors must remain actionable when mapped to Android and iOS platform APIs.
