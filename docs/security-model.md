# Security model

## Phase 0 review disposition — 2026-10-11

The architecture and Android local mock at commit `bed3c3b0fcee3ae707d5c01878d89aa2647f2450` were independently reviewed for [#7](https://github.com/KonohaDerek/suizai/issues/7). Continue development with synthetic, non-sensitive local fixtures only. **Real accounts, provider credentials and production data remain blocked** until the applicable controls below are implemented and verified. Completing this design review does not satisfy the release security audit (#39).

The reviewed mock has no account-entry flow or `INTERNET` permission. Its provider requires `MANAGE_DOCUMENTS`/URI grants, checks canonical root containment and sets `allowBackup=false`. These are source-level observations, not device permission, backup/restore or termination-test results. Pending Android identity fixes and the new iOS spike require review of their final diffs; they do not inherit an approval from this snapshot.

## Trust model

SUIZAI is a client. By default, it connects the device directly to user-selected providers. A SUIZAI-operated relay is not required.

## Assets

- OAuth refresh tokens and provider credentials
- File content in local cache
- File and directory metadata
- Remote account permissions
- Pending writes and conflict copies
- Diagnostic logs

## Required controls (not implementation claims)

### Credentials

- Android Keystore protects encryption keys; encrypt token/credential records with those keys. iOS stores secrets in Keychain. Do not treat Android Keystore as a store for arbitrary token strings.
- Never store secrets in SQLite, preferences, logs, crash reports or exported backups.
- Prefer OAuth PKCE and system authentication sessions.
- Bind OAuth callbacks to state, redirect URI and the initiating account/session; reject mismatches and replay.
- Request the narrowest provider scopes that support selected features.

### Cache

- Encrypt sensitive cache material at rest using platform-protected keys.
- Separate metadata and content keys where practical.
- Exclude cache from cloud device backups by default.
- Securely forget encryption keys when an account is removed.
- Dirty pending writes require explicit recovery handling before account removal.

### Network

- TLS certificate validation enabled by default.
- No silent acceptance of self-signed certificates.
- For advanced private-CA use, show fingerprint and scope the exception to one endpoint.
- Do not forward credentials on cross-origin redirects. Treat selected endpoints and all returned names, IDs, metadata and error bodies as untrusted.
- Bound response sizes, pagination, decoding, timeouts and parser resources. Disable external entity resolution in WebDAV XML.
- SMB requires modern dialects; SMB1 is out of scope.
- SFTP host keys use trust-on-first-use or explicit fingerprint verification.

### Diagnostics

- Redact URLs containing tokens, credentials, file names and account identifiers.
- Diagnostic export is opt-in and previewable.
- No analytics SDK in the core data path for the initial release.

## Primary threats

- Token theft from insecure local persistence
- Malicious or compromised remote server
- Path traversal and unsafe filename normalization
- Cache poisoning or stale metadata presented as current
- Data loss from interrupted write-back
- Cross-account identifier collision
- Privilege escalation through Android root helper
- Extension/app race conditions on iOS

## Trust boundaries

1. External SAF/Files client to platform permission/URI grant or domain, then to account-scoped item resolution and app-private storage.
2. iOS host app to extension through App Group storage: separate processes, lifetimes and concurrent writers.
3. Provider adapter to remote server, OAuth endpoints and redirect targets.
4. Memory to metadata/content/journal persistence, then to OS backup and device-transfer mechanisms.
5. Private state to diagnostic exports, and account removal to revocation, recovery and key destruction.

Assets include authorization codes, access/refresh tokens, passwords, encryption keys, content, sensitive metadata, account permissions, pending writes, conflict copies and diagnostics.

## Threat/control and evidence matrix

“Required” means not implemented or not verified in the reviewed mock. Each implementation issue must supply its own evidence before its real-data gate opens.

| Risk | Required mitigation and acceptance evidence | Snapshot status | Owner issues |
|---|---|---|---|
| Credential theft / OAuth confusion | Protected key/token storage; no backup/log persistence; least scopes; test callback mismatch, replay, cancellation, expiry and refresh failure | Required; no accounts/OAuth | #12, #21, #22, #30 |
| Content/metadata disclosure | Account-scoped encryption and key lifecycle; backup exclusions; test restart and unavailable-key errors | Required; local mock files are not app-layer encrypted | #12, #18 |
| Hostile server / transport downgrade | TLS validation, scoped CA trust, safe redirects, bounded parsing, no SMB1, explicit SFTP host-key change handling | Required; no remote I/O | #15, #16, #23, #28, #29 |
| Path traversal / unsafe names | Opaque IDs; reject root escape, invalid encodings, absolute paths and unsafe names; test containment for reads and mutations including symlinks | Partial; canonical containment exists, conformance suite pending | #1, #8, #11 |
| Cross-account collision / ID reuse | Scope IDs by account/domain; preserve identity across rename/move and restart; removed identities never retarget a new account/item | Required; reviewed Android snapshot uses path IDs | #1, #8, #11, #12 |
| Stale metadata / cache poisoning | Record provider/account/version/freshness; enforce available version preconditions; preserve conflict copies | Required; local metadata only | #11, #18, #20 |
| Interrupted writes / unknown remote result | Durable journal, staging and atomic local commit; reconcile uncertain results; never report synced on close/upload error; test disk-full, timeout, kill and conflict | Required; reviewed mock writes directly to local files | #20, #27, #38 |
| Evicting protected data | Never automatically evict dirty or pinned content; actionable budget errors; concurrency and restart tests | Required; no cache engine | #18, #19, #26, #40 |
| Diagnostic leakage | Redact credentials, cookies, signed URLs, paths/names, account IDs and server error bodies; opt-in previewable export; test sentinel secrets absent | Required; no diagnostics pipeline | #24, #39 |
| Backup / account removal | Verify OS backup/device transfer; stop new operations and reconcile in-flight/dirty writes before domain removal and token/key destruction; explicit recover/export/discard choice | Partial; Android backup disabled, device transfer untested, no account removal | #12, #18, #20, #39 |
| App/extension races | Durable transactional coordination or one writer; verify concurrent mutation, process termination and restart | Required; iOS spike must supply independent evidence | #8, #17, #27, #42 |
| Privileged helper abuse | Separate distribution/security review; authenticated minimal IPC, fixed mount definitions, reject arbitrary commands/paths | Not present; remains gated by Phase 0 decision | #4, #10, #34 |

## Findings and release blockers

- **SM-01 — identity correctness:** reviewed `DocumentIdCodec` encodes paths, and rename returns an ID derived from the new path. Old paths can be reused. Replace with durable opaque identity and regression tests in #1; extend to account/domain isolation in #11. This finding does not establish a demonstrated permission bypass.
- **SM-02 — interrupted local writes:** the reviewed `openDocument` exposes the original file and ignores close errors. Truncation can leave partial content. Synthetic fixtures only; #20/#38 must establish staging, journal and recovery before valuable data is accepted. Change notifications alone are not durable-sync confirmation.
- **SM-03 — misleading security status:** the original Controls section did not distinguish planned controls from implementation. This review renames it and records actual evidence/owners. README claims must remain consistent (#41).

No device, OS backup/transfer, real server, root helper or final iOS lifecycle audit was performed. Record remediation commits and test results against these IDs; keep real-data gates closed while a critical/high finding or its required verification remains unresolved.

## Root helper boundary

If developed, the Android privileged component must:

- expose a minimal authenticated IPC surface;
- accept only preconfigured mount definitions;
- reject arbitrary shell commands and arbitrary host paths;
- run filesystem/network code with the least privilege possible;
- be versioned and distributed separately from the Play Store build.
