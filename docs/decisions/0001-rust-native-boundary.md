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

Measurements below were observed on 2026-10-20 (Asia/Taipei). They are single CI-run observations, not controlled benchmarks or performance thresholds. Build times exclude toolchain installation and can benefit from runner caches. The archive size includes code that the final linker can remove; it is not the installed-library overhead.

| Evidence | Observation | Scope |
|---|---|---|
| Rust/C ABI + debugger | 4 Rust tests and C caller passed; GDB reached `suizai_fixture_read`, displayed arguments and the C caller stack | [Linux debug run](https://github.com/KonohaDerek/suizai/actions/runs/39283385226), core unchanged after `36a4777` |
| Android package/build | Unit tests and both APKs built in 29 s with warm caches; app APK 3,408,416 bytes, bundling arm64-v8a and x86_64 | [CI at `55847a5`](https://github.com/KonohaDerek/suizai/actions/runs/39286281793); earlier uncached build took 107 s. The previous native-only APK was 904,257 bytes, but this is not an isolated Rust size comparison: UI/glue also changed. |
| Android native archives | arm64 Rust archive 21,783,774 bytes / unstripped JNI library 5,440,792 bytes; x86_64 archive 20,770,162 bytes / JNI library 5,200,352 bytes | Intermediate build products; final APK uses stripped, compressed native libraries. |
| Android API 33 behaviour | 13 instrumentation tests passed with no failures/skips; stock system picker listed SUIZAI | Same CI run; includes three-language reads/UI, before/during cancellation, explicit Activity-destruction cancellation and zero remaining handles. This is an x86_64 emulator, not the user's Android 14 OEM device. |
| Android provider reads | Native README: 46 bytes / 2.796 ms; Rust fixture: 32 bytes / 501.206 ms | Rust path intentionally delays 500 ms to make cancellation observable. Different payloads and dispatch paths; this is not FFI overhead. |
| Android 100 zero-delay operations | Java byte copy 1.293 ms; JNI open/read/release 0.785 ms | 29 bytes each, single ordered sample; warm-up, allocation and scheduling differ. This does not establish a performance advantage. |
| Android process PSS | Java sequence 57,650 → 57,670 KiB; Rust sequence 57,674 → 57,682 KiB | Whole-process snapshots, not retained Rust heap, a leak test or an OEM memory budget. |
| iOS host behaviour | 12 Swift tests passed, including cancellation/cleanup and synthetic item/collision regression cases | [CI at `2499c3c`](https://github.com/KonohaDerek/suizai/actions/runs/39284617385) |
| iOS host 100 reads | Native materialization 36.011 ms; Rust wrapper + materialization 87.738 ms, delay=0 | Same host process, native then Rust; scheduler, fixture contents and file-write paths differ. This is not isolated FFI latency. |
| iOS peak RSS | Native sequence 42,631,168 → 43,565,056 bytes; subsequent Rust sequence 43,565,056 → 44,318,720 bytes | `ru_maxrss` is a process high-water mark, not retained heap or a device extension budget. Order matters. |
| iOS Rust target build | Simulator 3 s / 15,794,792-byte archive; device 2 s / 15,790,632-byte archive | Rust 1.85.1 optimized static archives |
| iOS unsigned products | Simulator build 28 s, app 3,608 KiB incl. extension 1,816 KiB; device build 19 s, app 3,616 KiB incl. extension 1,820 KiB | arm64, debug Xcode targets; no simulator launch, signing, installation or OS extension activation |

Independent review identified and resolved three iOS overlay defects: missing item-specific enumeration, a deletable parent, and native-name collisions. The fixture now lives at root. `SUIZAI-Rust.txt` is reserved for this experiment even while disabled; an older native file with that name is preserved and prevents enabling the fixture. This small namespace rule is specific to the experiment, not the proposed production provider contract.

Android 13 has a cancellation limitation in the framework's typed-read route: [`ContentResolver.openAssetFileDescriptor(..., "r", signal)`](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-13.0.0_r1/core/java/android/content/ContentResolver.java) dispatches a `*/*` typed read, and [`DocumentsProvider.openTypedAssetFileImpl`](https://android.googlesource.com/platform/frameworks/base/+/refs/tags/android-13.0.0_r1/core/java/android/provider/DocumentsProvider.java) falls back to `openAssetFile(uri, "r")` without the signal. The in-app cancellation experiment therefore uses `ContentProviderClient.openFile` to reach the same provider with its cancellation transport intact. Normal ContentResolver reads remain covered separately. This does not fix or establish cancellation behaviour for third-party apps using the framework's typed route.

Real Android OEM behaviour and iOS Files extension activation, eviction, low-memory termination, reboot and protected-data behaviour require the tester's device evidence. Unit tests of native wrappers do not reproduce the operating system killing an extension. A simulator compile does not verify signing, entitlements on hardware or App Store readiness.
