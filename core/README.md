# Shared fixture core

This is the bounded local fixture bridge for issue #6. It contains no storage
provider, filesystem access, credentials, network work, or callback into a
native runtime. The public ABI and ownership/thread rules are in
[`include/suizai_core.h`](include/suizai_core.h).

Use Rust 1.85.1 and run `./test-ffi.sh` from this directory. The script runs
Rust unit tests, builds the static library, then compiles and runs a C caller
against the installed header and library. Android and iOS callers should run
`suizai_fixture_read` on their own background queue and may cancel it from a
different thread.

The fixture is intentionally one opaque ID, `bridge-welcome`. It returns a
short localized UTF-8 line. The configured delay is capped at 500 ms and is
checked for cancellation every 5 ms. A returned handle must be released. The
active-handle count exists only as a deterministic leak-test probe.
