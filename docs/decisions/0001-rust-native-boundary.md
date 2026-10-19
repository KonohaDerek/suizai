# ADR 0001: retain native system integrations; evaluate a bounded Rust worker

- Status: provisional Phase 0 experiment; issue #6 stays open pending review and device evidence.
- Scope: local disposable fixtures only. No provider credentials, remote I/O, production cache or write-back.
- Related: #1, #6, #8 and the Phase 0 decision gate #10.

## Question

Can Android DocumentsProvider and iOS File Provider call the same cancellable Rust operation without moving OS lifecycle, permissions or file-descriptor ownership into Rust?

## Experiment and ownership

The existing native providers remain the default. An opt-in fixture path calls a small Rust static library through C ABI / JNI. Native code owns asynchronous dispatch, completion, cancellation wiring, temporary files and descriptors. Rust owns only a bounded fixture operation and its cancellation state. Fixture IDs are opaque identifiers, not filesystem paths. The output buffer belongs to the caller; Rust retains no buffer pointer and calls no native callback.

A handle registry retains each operation until explicit release. An in-flight read retains its own reference, so removing a handle does not invalidate memory used by that read. Cancellation is cooperative, not a promise to interrupt a completed operation. Platform wrappers must complete exactly once and clean up on every terminal path.

## Decision boundary

Keep domain registration, permissions, OS callbacks, UI, protected-data access and descriptor/temporary-file ownership native. The experiment does not justify placing the production cache, upload journal, SQLite ownership or account secrets in a shared Rust service. Those responsibilities need crash recovery, process termination and cross-process coordination evidence absent from a small fixture read.

If the bridge passes automated checks, it is a candidate for bounded reusable data operations behind a native adapter. This is a conditional split design, not approval to start Phase 1 or to claim Android/iOS production support. The explicit go/no-go remains #10.

## Evidence and limits

Automated measurements and exact source/run links are recorded here after the integration build. Cold/warm build observations, APK/library sizes and process-memory snapshots are workload-specific; they are not a production throughput or mobile memory-budget benchmark.

Real Android OEM behaviour and iOS Files extension activation, eviction, low-memory termination, reboot and protected-data behaviour require the tester's device evidence. Unit tests of native wrappers do not reproduce the operating system killing an extension. A simulator compile does not verify signing, entitlements on hardware or App Store readiness.
