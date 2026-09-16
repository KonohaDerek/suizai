# iOS File Provider plan

## Supported product promise

SUIZAI can expose configured remote storage in the Files app and document pickers through a File Provider extension. It cannot create an SD card, replace another app's private container or force BOOK☆WALKER to relocate its internal downloads.

## Architecture

- Main SwiftUI app: account setup, settings, cache controls and diagnostics.
- File Provider extension: enumeration, materialization, mutations and change signaling.
- App Group container: shared metadata and cache coordination.
- Keychain access group: provider credentials and tokens.
- Rust core: provider and cache operations where extension runtime constraints allow.

## Key engineering constraints

- Extension execution time and memory are constrained.
- Background work must be resumable and coordinated with the system.
- Stable item identifiers are mandatory.
- Materialized local copies are managed together with File Provider semantics.
- Authentication failures must surface as user-actionable errors.
- Provider state cannot depend on the main app always running.

## MVP acceptance criteria

- Add a WebDAV account in the main app.
- A SUIZAI domain appears in Files.
- Browse nested directories with stable identifiers.
- Open a remote file and materialize it locally.
- Edit and upload with visible progress/error state.
- Pin and unpin a file for offline access.
- Recover after process termination or network loss.
