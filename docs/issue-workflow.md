# Issue delivery workflow

Use the existing [suizai project](https://github.com/users/KonohaDerek/projects/4) as the live source of status; this document records transitions and dependencies, not a second status board.

| Column | Entry condition | Exit condition |
|---|---|---|
| Backlog | Work is unstarted or lacks a dependency, device, test account or decision | Record prerequisites and make the task executable |
| Ready | Scope and acceptance criteria are clear; required prerequisites are available | A worktree/branch is assigned and implementation starts |
| In progress | Active implementation or validation; keep the existing limit of 3 | PR, validation results and remaining acceptance gates are recorded |
| In review | Reviewable PR or evidence report exists | Merge and complete all acceptance criteria, or return to active work for findings |
| Done | Accepted implementation is merged and the issue's required verification is complete | Reopen when evidence invalidates acceptance |

An APK in a prerelease is a test handoff, not a completed device test. Keep device-dependent issues open and identify the pending checks in the issue and release notes. A draft PR can remain In review with an explicit device-test blocker. Do not use automatic closing keywords for partially completed issues.

## Dependency order

Phase 1 and later implementation stays in Backlog until #10 records the Phase 0 decision. The individual dependencies below then determine readiness; they do not override that phase gate.

| Issues | Work | Prerequisites / evidence needed |
|---|---|---|
| #1 | Android local DocumentsProvider | Build, conformance tests, tester's system-picker/device results |
| #2, #3 | BOOK☆WALKER public-storage experiments | #1; dedicated device/account and disposable content |
| #4 | Android virtual-volume/FUSE research | #2/#3 public-surface results; separate privileged test setup |
| #5 | Support matrix | Current platform references and explicit minimum/current test lanes |
| #6 | Rust/native bridge decision | Minimal Android/iOS integration surfaces from #1/#8; measured bridge evidence |
| #7 | Threat-model review | Architecture and mock code review; keep real-account gate closed |
| #8 | iOS local File Provider | Native mock spike, build/store tests, tester's Files/lifecycle results |
| #10 | Phase 0 decision | #1–#8 reports, unresolved risks and explicit go/no-go |
| #9 | Native app foundations | #5/#6/#8/#10; keep system integrations native |
| #11 | Provider contract/local test provider | #6/#9; opaque account-scoped IDs and reusable contract tests |
| #12 | Account manager/secret storage | #7/#9/#11; secure-storage and lifecycle evidence |
| #13 | Unified browser | #9/#11/#12 |
| #15, #16 | WebDAV then SMB3 | #11/#12; provider contract and controlled-server tests |
| #18 | Whole-file cache | #11/#12; identity, integrity and protected-data rules |
| #20 | Durable upload journal/conflicts | #11/#18; staging, version preconditions and recovery |
| #14, #17 | Android/iOS remote integration | #1 or #8, plus #12/#15/#18/#20 |
| #19 | Offline pinning | #18; protected-data accounting |
| #21, #22, #23 | Drive/OneDrive/S3 | Stable Phase 1 contract/cache; #12; provider-specific security tests |
| #24 | Transfer/diagnostics UI | #13/#20; redaction and opt-in export |
| #25 | Accessibility/localization/tablets | #13/#24 and both native integrations |
| #26 | Cache budgets/eviction | #18/#19/#20; dirty and pinned data protection |
| #27 | Network fault-injection suite | Remote adapters, #14/#17/#18/#20; lifecycle tests |
| #28, #29, #30 | OpenList/SFTP/Dropbox | Stable provider contract, #12 and Phase 1.5 reliability evidence |
| #31 | Optional config sync | #12; enrollment/revocation/key-recovery security review |
| #32 | Sharing/deep links | #12/#13/#14/#17; authorization and lifecycle tests |
| #33 | Provider SDK docs | Stable #11 contract and validated example provider |
| #34 | Optional Android compatibility edition | Explicit #4/#10 go decision; separate privilege/distribution boundary |
| #35 | Chunk cache/read-ahead | #18/#26/#27; whole-file correctness first |
| #36 | Desktop feasibility | Stable native/core boundary and measured desktop spike |
| #37 | Encrypted overlay assessment | Threat model, format/recovery prototype and cryptographic design review |
| #38 | Interrupted-upload release gate | #20/#27; no silent data loss evidence |
| #39 | Secret-leakage release gate | #12/#24 and implemented providers; storage/log/backup audit |
| #40 | Protected-cache release gate | #18/#19/#26/#27; restart/integrity evidence |
| #41 | Product-claim release gate | #5/#10 plus tests supporting each public claim |
| #42 | Provider-termination release gate | #14/#17/#20/#27; OS lifecycle/recovery evidence |

Each implementation handoff links its PR, exact commit, relevant CI run, downloadable build when applicable, tests executed and remaining manual checks. Only the integrating agent changes GitHub state; implementation agents work in isolated worktrees.
