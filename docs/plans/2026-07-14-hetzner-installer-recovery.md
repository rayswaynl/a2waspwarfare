# Hetzner Installer Recovery Implementation Plan

**Goal:** Convert the rejected local-only Hetzner installer controller into a fail-closed, hash-bound, transaction-safe package that can earn independent approval before any MIKSUUS-TEST access.

**Architecture:** Keep the existing immutable install/rollback transaction as the authority root. Replace caller-supplied service callbacks with an adapter script that is hash-pinned in the plan and loaded from that exact path. Put T15 and T16 under the same per-install transaction lock as T14, revalidate the complete plan after lock acquisition, and compare measured process isolation to canonical expected identities. Reuse the sealed rollback contract for adoption-aware uninstall so host-owned files are preserved or restored exactly. Treat two HCs as the mandatory topology, zero/one HC as fallback controls, and three HCs as explicitly experimental and fail-closed without a third isolation identity.

**Tech Stack:** Windows PowerShell 5.1, PowerShell 7 compatibility, JSON receipts, SHA-256 artifact binding, filesystem transaction journals, script-level test harnesses.

---

### Task 1: Bind the executing adapter to the reviewed artifact

**Files:**
- Modify: `Tools/HetznerInstaller/HetznerInstaller.ServiceHealth.Tests.ps1`
- Modify: `Tools/HetznerInstaller/HetznerInstaller.psm1`
- Create: `Tools/HetznerInstaller/Adapters/WindowsServiceAdapter.ps1`

1. Add RED tests proving T15/T16 reject an in-memory callback, execute only the hash-pinned adapter file, and reject adapter replacement before the first action.
2. Run the service-health suite and retain the expected failure output.
3. Add a constrained adapter loader that re-hashes the planned path, invokes its defined entry point, and exposes no arbitrary callback parameter.
4. Implement a generic Windows adapter with capture/apply/observe/restore actions and no checked-in hostnames, credentials, or private paths.
5. Rerun the suite under Windows PowerShell 5.1 and PowerShell 7.

### Task 2: Share T14 locking and revalidation with T15/T16

**Files:**
- Modify: `Tools/HetznerInstaller/HetznerInstaller.ServiceHealth.Tests.ps1`
- Modify: `Tools/HetznerInstaller/HetznerInstaller.psm1`

1. Add RED tests that hold the T14 lock and prove T15/T16 make zero adapter calls, plus tests that tamper with the committed contract while waiting and prove post-lock revalidation rejects it.
2. Run the focused suite and retain the expected failures.
3. Acquire the canonical install transaction lock for each applied T15/T16 operation.
4. Re-assert the plan, adapter hash, committed install identity, and prerequisite receipt immediately after the lock is acquired and before every mutation or receipt write.
5. Hold the lock through restore/re-observation and receipt commit; rerun focused tests.

### Task 3: Require measured canonical isolation and fresh RPT evidence

**Files:**
- Modify: `Tools/HetznerInstaller/HetznerInstaller.ServiceHealth.Tests.ps1`
- Modify: `Tools/HetznerInstaller/HetznerInstaller.psm1`
- Modify: `Tools/HetznerInstaller/profiles.json`

1. Add RED tests for expected-versus-measured sandbox root, profile root, RPT path, launcher fingerprint, process start identity, and RPT freshness.
2. Add negative cases for duplicate identities, stale RPTs, path drift, fingerprint drift, and unsupported third-HC isolation.
3. Bind canonical expected identities into the plan and compare them exactly to adapter observations.
4. Make `hc-0` and `hc-1` explicit fallback/control profiles, `hc-2` the operational primary gate, and `hc-3` experimental/fail-closed unless a distinct third identity is supplied.
5. Rerun focused and legacy suites.

### Task 4: Make uninstall adoption-aware through the sealed rollback contract

**Files:**
- Modify: `Tools/HetznerInstaller/HetznerInstaller.Adoption.Tests.ps1`
- Modify: `Tools/HetznerInstaller/HetznerInstaller.Rollback.Tests.ps1`
- Modify: `Tools/HetznerInstaller/HetznerInstaller.Tests.ps1`
- Modify: `Tools/HetznerInstaller/HetznerInstaller.psm1`

1. Replace the existing disabled-uninstall expectations with RED tests for `PreserveHost`, `RestoreBackup`, installer-created deletion, interruption recovery, repeated uninstall, and plan tampering.
2. Run adoption/rollback/base suites and retain the expected failures.
3. Derive uninstall actions from the committed journal's sealed rollback contract instead of mutable manifest-only records.
4. Execute uninstall under the canonical transaction lock with whole-plan preflight and exact terminal-state proof.
5. Rerun adoption, rollback, transaction, and base suites.

### Task 5: Expose safe controller actions and valid receipts

**Files:**
- Modify: `Tools/HetznerInstaller/Invoke-HetznerInstaller.ps1`
- Modify: `Tools/HetznerInstaller/profiles.json`
- Modify: `docs/ops/hetzner-installer.md`
- Create: `Tools/HetznerInstaller/New-HetznerInstallerReceipt.ps1`

1. Add RED wrapper tests for plan-only T15/T16 behavior and explicit Apply requirements.
2. Add wrapper actions that accept hash-bound adapter/config inputs and never accept scriptblocks.
3. Document the primary two-HC gate, zero/one fallback controls, three-HC experimental boundary, and rollback/uninstall sequence.
4. Add a deterministic receipt writer/verifier that expands real UTC timestamps and computes real SHA-256 values; reject placeholders and control characters.
5. Rerun wrapper and receipt tests.

### Task 6: Verify, independently review, and decide the runtime gate

**Files:**
- Verify all files under `Tools/HetznerInstaller/`
- Verify: `docs/ops/hetzner-installer.md`

1. Run all installer suites in Windows PowerShell 5.1 and the service/receipt suites in PowerShell 7.
2. Parse every PowerShell file with the AST parser and scan for private hostnames, credentials, remote-action helpers, and placeholder hashes.
3. Generate a fresh local receipt, read it back, and independently verify every listed artifact hash.
4. Request an independent read-only review against the six rejected gates; fix any finding with RED-first tests and repeat review.
5. Only after an approval, re-read Fleet authority and decide whether a bounded MIKSUUS-TEST primary two-HC run is authorized. If not, block with the exact remaining external gate rather than claiming runtime proof.
6. If all mandatory gates and measured evidence pass, create a draft PR against `master`; never deploy to production or merge.
