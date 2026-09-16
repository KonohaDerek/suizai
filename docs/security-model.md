# Security model

## Trust model

SUIZAI is a client. By default, it connects the device directly to user-selected providers. A SUIZAI-operated relay is not required.

## Assets

- OAuth refresh tokens and provider credentials
- File content in local cache
- File and directory metadata
- Remote account permissions
- Pending writes and conflict copies
- Diagnostic logs

## Controls

### Credentials

- Android Keystore and iOS Keychain only.
- Never store secrets in SQLite, preferences, logs, crash reports or exported backups.
- Prefer OAuth PKCE and system authentication sessions.
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

## Root helper boundary

If developed, the Android privileged component must:

- expose a minimal authenticated IPC surface;
- accept only preconfigured mount definitions;
- reject arbitrary shell commands and arbitrary host paths;
- run filesystem/network code with the least privilege possible;
- be versioned and distributed separately from the Play Store build.
