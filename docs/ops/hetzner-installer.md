# Transactional installer controller v2

This is a local, fail-closed controller for preparing, verifying, uninstalling,
and locally adapting a new WASP Hetzner install directory. It is intentionally
separate from existing deploy, box, HC, and runtime tooling. The repository does
not contain SSH, transfer, credential, production-host, or PBO-build behavior.
Runtime actions require an explicitly selected, hash-pinned adapter and matching
configuration inside the same fence, plus an explicit `-Apply`. Configuration is
accepted only when its environment identity is exactly `MIKSUUS-TEST`.

The local Apply path now has the bounded T14 transaction foundation: one
exclusive transaction per install, a write-through atomic journal outside the
install root, a tamper-evident immutable journal projection, sealed preimages,
operation checkpoints, status, and idempotent recovery. T13 now also seals the
two source configs and mission PBO into a journal-bound transaction snapshot;
managed file copies execute only from that snapshot through verified,
write-through, same-parent atomic promotion. T12 adds explicit per-path adoption
and replacement ownership, and T11 adds executable sealed-journal rollback with
action-by-action recovery. Adoption-aware uninstall uses its own sealed,
interruptible journal contract. T16/T15 add bound-adapter isolation attestation
and service-health acceptance through wrapper actions. The included Windows
adapter is a generic local implementation and its example configuration contains
deliberately invalid placeholder hashes; it confers no host authority. Measured
MIKSUUS-TEST runtime evidence and independent review remain mandatory before a
release gate can open.

## Safety contract

- `DryRun` and `ApplyPlan` require an explicit `-MissionPboPath` whose leaf is a
  `.pbo`. The source PBO is copied unchanged to `mpmissions`; its SHA-256 is
  recorded in the manifest and receipt. The tool never builds or deploys it.
- `Preflight` reports the supplied PBO and hash. It may be run without a PBO
  when only source/profile inspection is wanted; staging, verification, and
  uninstall require one.
- Every mutation requires `-Apply`. Plans are revalidated immediately before
  mutation, including action, install/fence/backup roots, relative targets,
  manifest/receipt hashes, PBO identity, source-config hashes, and the exact
  canonical operation kinds/order/paths/launcher-content hashes. Apply executes
  a freshly re-derived canonical operation sequence, not mutable plan operations.
- Mutation paths must remain strictly below `-FenceRoot`. UNC, runtime-shaped
  `C:\WASP`, protected Windows paths, traversal, and reparse points/junctions
  are rejected. Install and backup roots must be disjoint in both directions;
  neither may equal or descend from the reserved
  `.hetzner-installer-transactions` namespace.
- Backup uses a fresh run-specific path when `-BackupRoot` is omitted and
  refuses any existing backup root; it never recursively replaces one.
- Apply stores its current journal and verified preimages under
  `<FenceRoot>\.hetzner-installer-transactions\<install-path-sha256>`, which is
  outside the install root. Journal replacement is same-directory and atomic,
  with write-through flushes. A delete-on-close exclusive lock prevents a
  second Apply or recovery owner. A nonterminal transaction blocks new Apply
  until `RecoverPlan -Apply` restores the exact captured pre-state. Recovery
  first validates the immutable entry fingerprint, entry order/path contract,
  every referenced preimage hash/size, target types, reparse safety, and the
   absence of unexpected content before changing the install tree. A committed
   journal makes recovery idempotently preserve the verified post-state.
- Before the first install-tree mutation, Apply snapshots exactly two canonical
  configs plus the supplied mission PBO under the external transaction root.
  The journal binds their original paths, transaction-contained snapshot paths,
  hashes, sizes, order, and snapshot fingerprint. Apply then verifies all three
  artifacts and uses only their snapshot paths. Later source mutation or deletion
  cannot change the transaction input; snapshot corruption fails before managed
  copy mutation while recovery remains driven solely by sealed preimages.
- Snapshot, preimage, managed-file, and recovery copies share one verified
  write-through primitive: copy to a unique temp beside the destination, flush,
  verify hash and size, then atomically replace or move on the same volume.
  Recovery, while holding the exclusive transaction lock, removes only exact
  `.apply-<32 lowercase hex>.(tmp|bak)` and
  `.recover-<32 lowercase hex>.(tmp|bak)` artifacts. Lookalikes are preserved
  and cause whole-target recovery preflight to fail closed.
- Apply stages only into a new/empty root or an existing root whose complete
  manifest, receipt, expected managed-file set, and current hashes prove prior
  installer ownership. A non-empty root with missing, incomplete, or drifting
  metadata is refused before overwrite; existing-install adoption is not
  implicit.
- T12 accepts an explicit, plan-fingerprinted
  `AdoptUnchanged` record only when an existing host file already equals the
  exact desired bytes. Its path, pre/post hashes and sizes, `HostAdopted` owner,
  and `PreserveHost` rollback/uninstall dispositions are copied into both sealed
  metadata files. Unrelated host files remain untouched.
  `PreserveHost` is additionally accepted only for a host-owned stale HC
  launcher that the selected profile would otherwise delete; Apply and Verify
  preserve and attest its exact bytes. Preservation of required
  config/PBO/active-launcher targets is not accepted by this slice.
- `ReplaceWithBackup` is accepted for a differing canonical file-producing
  target. Before install mutation, Apply copies the transaction preimage through
  the same verified atomic helper into the short external transaction namespace
  `a\<entry>.bin`, then records its absolute path, hash, size, replacement owner,
  and `RestoreBackup` rollback/uninstall dispositions in both sealed metadata
  files. A committed replacement blocks another Apply until rollback or the
  adoption-aware uninstall restores it.
- `RollbackPlan` without `-BackupRoot` binds only to the committed external Apply
  journal. Before the Apply journal can become `Committed`, it records the exact
  final manifest, receipt, and ownership-seal hashes and sizes in a committed
  metadata contract covered by the journal fingerprint. Rollback rejects even a
  semantic-equivalent three-file rewrite that recomputes the local seal. It then
  fingerprints the manifest, receipt, ownership seal, managed
  postimages, ownership decisions, preimages, and exact rollback actions. Before
  the first restore it verifies every postimage, backup/preimage, directory
  content set, and reparse fence. Apply restores replaced/prior files with the
  verified atomic-copy helper, never rewrites `AdoptUnchanged` or `PreserveHost`
  files, removes only paths proven absent in the sealed pre-state, and journals
  every action as `RollingBack` before the final `RolledBack` state. Interrupted
  runs resume against a mixed pre/post-state preflight. A repeat call over a
  `RolledBack` journal re-proves the terminal phase/index and every action's
  sealed pre-state before reporting idempotent success, so a forged terminal
  marker over a partial rollback fails closed. Normal Apply performs the same
  terminal proof before it may replace the prior journal, preventing a partial
  rollback from being adopted as a new host pre-state. Supplying the older
  whole-tree `-BackupRoot` selects
  `LegacyBackup`, whose restore stays disabled.
- Uninstall re-derives the exact committed manifest, receipt, ownership seal,
  and journal contract under the same exclusive T14 transaction lock. It seals
  an ordered action list before mutation, checkpoints each action in the journal,
  and resumes safely after every injected interruption. Installer-owned files
  are deleted, `AdoptUnchanged` and `PreserveHost` files are preserved byte for
  byte, and `ReplaceWithBackup` files are restored through the verified atomic
  copy primitive. Each action intent is written before mutation and completion is
  journaled afterward; a pending action may resume from either sealed side of
  that crash window. The terminal `Uninstalled` state is re-proved on repeated
  calls, so forged progress or drift fails closed.
- Receipts and manifests contain identities, relative paths, sizes, and hashes;
  they contain no credential value. Generated launchers require but never
  overwrite host-provided `ARMA2OA_ROOT`. Their batch layer never expands
  `WASP_HC_PASSWORD`; a PowerShell argument-array adapter reads it from the host
  environment and passes it as one process argument.
- T16 seals the exact adapter file and configuration file, holds each reviewed
  file deny-write/delete while hashing, reading, or executing it, captures a baseline,
  and attests the primary `hc-2` topology (or experimental `hc-3`) against the
  configured process, sandbox, profile, command-line fingerprint, and real RPT
  paths. Core code reads each RPT timestamp itself and requires advancement
  inside its own fresh, fatal-free bounded observation window. The shared T14 lock is held across adapter
  calls and receipt commit; the plan, adapter, configuration, and committed
  install are revalidated immediately before receipt write. Failure restores and
  independently re-observes the captured baseline, with no receipt emitted.
- T15 accepts `hc-0` and `hc-1` only as fallback controls and `hc-2` as the
  primary release-gate topology. The primary path requires a fresh T16 receipt
  bound to the same committed T14 contract and adapter configuration. Service
  evidence must match the mission hash, Running service, advancing server RPT,
  exact configured HC identities, and a bounded fatal-free observation. It uses
  the same lock/revalidation/restore contract as T16. `hc-3` service activation
  is deliberately fail-closed as an experimental stretch topology.

## Profiles and HC topology

`profiles.json` defines four deterministic profiles:

| Profile | Generated HC launchers | Server port | Controller role |
| --- | ---: | ---: | --- |
| `hc-0` | 0 | 2302 | server-only fallback control |
| `hc-1` | 1 | 2302 | single-HC fallback control |
| `hc-2` | 2 | 2302 | primary; bound adapter and T16 receipt required |
| `hc-3` | 3 | 2302 | experimental stretch; service activation closed |

Every generated HC uses port `2302`, with unique names
`HC-AI-Control-1` through `HC-AI-Control-3` and unique profile/RPT identity
records. `hc-2` and `hc-3` remain explicitly non-operational in profile metadata
until a topology-specific adapter configuration and measured test-box evidence
are independently verified. A launcher or local receipt is not runtime proof.

Generated launchers use the documented `@CBA_CO;@adwasp;@admkswf` mod order and
`tbb4malloc_bi` allocator. Batch metacharacters are rejected from profile
strings.

## Action matrix

Run from the repository root with PowerShell 5.1 or newer. These examples use
only local staging paths.

```powershell
$fence = 'C:\Temp\wasp-staging'
$install = 'C:\Temp\wasp-staging\hetzner-install'
$pbo = 'C:\Temp\wasp-input\candidate.chernarus.pbo'
$backup = 'C:\Temp\wasp-staging\backups\before-change'
$adapter = 'C:\Temp\wasp-staging\controller\WindowsServiceAdapter.ps1'
$adapterConfig = 'C:\Temp\wasp-staging\controller\miksuus-test.json'
$adapterId = 'windows-service-adapter-v1'

# Read-only source/profile checks; -MissionPboPath is reported when supplied.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action Preflight -ProfileName hc-2 -MissionPboPath $pbo

# Build and inspect a plan; no directory is created.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action DryRun -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo -Json

# Apply only to the fenced local staging directory.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action ApplyPlan -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo -Apply

# Verify the exact profile-managed set, PBO identity, and all managed hashes.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action Verify -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo

# Inspect the durable transaction journal without mutation.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action TransactionStatus -InstallRoot $install -FenceRoot $fence -Json

# Inspect recovery without mutation; add -Apply only to restore a nonterminal pre-state.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action RecoverPlan -InstallRoot $install -FenceRoot $fence -Json

# Prepare or apply a local backup. Omit -BackupRoot for a fresh run-specific path.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action Backup -InstallRoot $install -BackupRoot $backup -FenceRoot $fence -Apply

# Print the sealed committed-transaction rollback plan; add -Apply to execute it.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action RollbackPlan -InstallRoot $install -FenceRoot $fence

# A legacy whole-tree backup can be inspected, but its Apply remains disabled.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action RollbackPlan -InstallRoot $install -BackupRoot $backup -FenceRoot $fence

# Print an uninstall plan. Add -Apply only for the same fenced local tree.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action UninstallPlan -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo

# Inspect the bound two-HC isolation plan. This never invokes the adapter.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action IsolationPlan -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo `
  -AdapterPath $adapter -AdapterConfigPath $adapterConfig -AdapterId $adapterId -Json

# Only after independent configuration review: apply isolation and capture its receipt.
$isolation = powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action IsolationPlan -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo `
  -AdapterPath $adapter -AdapterConfigPath $adapterConfig -AdapterId $adapterId -Apply -Json | ConvertFrom-Json

# Inspect service activation; omit -Apply until the exact host binding is approved.
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\Invoke-HetznerInstaller.ps1 `
  -Action ServiceActivationPlan -ProfileName hc-2 -InstallRoot $install -FenceRoot $fence -MissionPboPath $pbo `
  -AdapterPath $adapter -AdapterConfigPath $adapterConfig -AdapterId $adapterId -ServiceName 'WASP-MIKSUUS-TEST' `
  -IsolationAttestationPath $isolation.AttestationReceiptPath -Json
```

Both adapter files must be ordinary, non-reparse files inside the fence. Replace
every placeholder in `Adapters\windows-service-adapter.example.json` with
current measured MIKSUUS-TEST identities and SHA-256 values before planning;
placeholder values are rejected. `-Apply` is an execution boundary, not a grant
of test-box or production authority.

Profile transitions are deterministic: applying `hc-0` after `hc-3` removes
only stale launchers whose prior installer hash matches. An unowned or
host-modified stale launcher makes Apply refuse before any mutation, so Apply
cannot report success for a tree that verification immediately rejects.
Verification independently derives the exact expected managed-file set from
the requested profile instead of trusting an edited manifest.

## Canonical prior-art consumption

The canonical proposal folder reviewed for this revision is:

`W:\Mijn vualt\Fleet\Docs\Proposals\arma2-perf-program-20260713`

Relevant artifacts read:

- `W:\Mijn vualt\Fleet\Docs\Proposals\arma2-perf-program-20260713\PROVIDER-GROK-ADDENDUM.md`
- `W:\Mijn vualt\Fleet\Docs\Proposals\arma2-perf-program-20260713\VERIFICATION-RECEIPT.md`
- `W:\Mijn vualt\Fleet\Docs\Proposals\arma2-perf-program-20260713\AUTONOMY-CHECKPOINT.md`
- `W:\Mijn vualt\Fleet\Docs\Proposals\arma2-perf-program-20260713\HETZNER-TWO-HC-NETWORK-RECOVERY-PROTOCOL.md`

No accepted exact-provenance Grok session/model artifact was available in that
folder, and the current network/JIP/queue R2 report was not ready there. Grok
material is therefore treated only as hypotheses, candidate failure modes, and
falsifiers; deterministic local tests, installer invariants, and future measured
test-box/client evidence override it. The controller/collector can consume
future evidence through the manifest/receipt, server and HC RPTs, process and
NIC counters, ETW/loopback captures, monitor transcripts, event ledgers, and
`RESULTS.md`; this script does not collect those signals or apply runtime work.

## Local verification and limits

The dependency-free contract suite uses a temporary fence and does not contact
a host:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Review3.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Transaction.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Adoption.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Rollback.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.ServiceHealth.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Receipt.Tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Tools\HetznerInstaller\HetznerInstaller.Adapter.Tests.ps1
```

The receipt helper records concrete UTC timestamps and recomputes every declared
artifact hash and byte length before verification:

```powershell
& .\Tools\HetznerInstaller\New-HetznerInstallerReceipt.ps1 `
  -OutputPath C:\Temp\installer-receipt.json -RootPath $PWD.Path `
  -TaskId arma2-perf-hetzner-72h-installer-controller-20260713 -TestSummary 'Verified local controller gate' `
  -ArtifactPath .\Tools\HetznerInstaller\HetznerInstaller.psm1 .\Tools\HetznerInstaller\Adapters\WindowsServiceAdapter.ps1

& .\Tools\HetznerInstaller\New-HetznerInstallerReceipt.ps1 `
  -OutputPath C:\Temp\installer-receipt.json -RootPath $PWD.Path -Verify
```

Repository verification proves only the local controller contract. Host
credential setup, PBO transfer, real MIKSUUS-TEST service/task binding, measured
server/HC RPT advancement, restore proof, collector integration, JIP/client
health, and the 0/1/2-HC runtime matrix remain external evidence gates. `hc-2`
is the mandatory primary/release gate; `hc-0` and `hc-1` are fallback controls;
`hc-3` is an experimental stretch and not a release gate. None of these scripts
authorizes production or substitutes local receipts for independent runtime
review.
