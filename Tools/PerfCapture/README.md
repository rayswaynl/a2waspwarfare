# WASP Performance Capture

`Tools/PerfCapture` creates reproducible evidence for Arma 2 OA performance
experiments. It validates and seals `MANIFEST.json`, then observes explicitly
declared Windows process IDs for server, headless-client, and player-client
roles.

The collector is measurement-only. It does not launch, stop, restart,
reprioritize, re-affinitize, inject into, or configure a target process. It
writes only to the selected run artifact directory.

## Artifact layout

```text
<DATE>_<REGIME>_<SCENARIO>_<ARM>_<RUNID>_<BUILD8>/
  MANIFEST.json
  MANIFEST.sha256                 # after finalization
  CONFIG-SNAPSHOT/
  server.rpt
  hc-01.rpt
  client-01.telemetry.json
  process-metrics.csv
  process-identity.json
  collector-overhead.json
  network-metrics.csv
  gameplay-invariants.json
  analysis/
```

The directory leaf must exactly match the identity fields in the manifest.
`run_id` is eight uppercase hexadecimal characters and `build_id` is exactly
eight alphanumeric characters.

## Manifest lifecycle

1. Copy `fixtures/valid-pending/MANIFEST.json` into the correctly named run
   directory and replace every example identity/hash/value.
2. Record only anonymized `host.machine_id`. Never put credentials in the
   manifest. `command_line_redacted` replaces password values with
   `<redacted>`; `command_line_sha256` hashes the exact unredacted UTF-8 command
   line so identity remains provable. The validator rejects unredacted common
   password switches.
3. Validate before capture:

   ```powershell
   python Tools\PerfCapture\validate_run_manifest.py <run>\MANIFEST.json
   ```

4. Capture the PIDs declared in `process_topology`:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File Tools\PerfCapture\Collect-ProcessMetrics.ps1 `
     -ManifestPath <run>\MANIFEST.json `
     -OutputDirectory <run> `
     -SampleCount 600 `
     -IntervalSeconds 1
   ```

   The collector fails before sampling if PID/start time, executable SHA-256,
   raw-command SHA-256, or affinity does not match the manifest. It also hashes
   the manifest before and after capture and rejects a run whose identity changed
   while samples were being taken. Capture accepts only a pending manifest stored
   directly in that output directory; finalized runs cannot be recaptured.

5. After the run, fill attained workload, end UTC, valid/invalid status, invalid
   reasons, and artifact SHA-256 values. For directory-shaped artifacts, point
   the manifest at a deterministic `SHA256SUMS` inventory file rather than at a
   directory.
6. Finalize once:

   ```powershell
   python Tools\PerfCapture\validate_run_manifest.py <run>\MANIFEST.json --finalize
   ```

   Finalization requires `valid` or `invalid`, canonicalizes JSON, writes
   `MANIFEST.sha256` atomically, and refuses to replace a mismatching seal.

## Exact manifest contract

`run-manifest.schema.json` is JSON Schema draft-07. Every object uses
`additionalProperties:false`, every contract field is required, and null means
unknown/not yet attained. Zero is a measured zero.
Artifact paths are forward-slash, relative, run-local file paths; absolute,
backslash, empty-segment, and traversal paths are rejected.

Top-level fields are:

| Field | Meaning |
| --- | --- |
| `schema_version` | Constant `a2wasp-perf-run-manifest-v1`. |
| `run_id`, `date_utc`, `regime`, `scenario`, `arm`, `build_id` | Immutable run/directory identity. |
| `created_utc`, `timing` | UTC creation, start, warm-up end, and end boundaries. |
| `source` | Repository, exact commit/tree, and dirty declaration. |
| `specimens` | Executable, relevant DLL, mission PBO, config, and collector/tool SHA-256/size identities. |
| `host` | Anonymous machine label plus OS/CPU/topology. |
| `mission` | Map, mission PBO reference, flags, mod order, players, expected HCs. |
| `process_topology` | Unique role/PID/start/executable reference/command hash/affinity/mod order. |
| `workload` | Requested and attained labels/counts/experiment-specific parameters. |
| `validation` | Pending/valid/invalid state, predeclared rules, actual invalid reasons. |
| `artifacts` | Required/optional artifact paths and final hashes. |

The dependency-free validator additionally enforces unique IDs/roles/PIDs and
artifact paths, valid specimen references, required specimen kinds, HC count,
directory identity, UTC ordering, pending/final consistency, and required
artifact hashes for a valid run.

## Process output contracts

`process-identity.json` (`a2wasp-process-identity-v1`) stores the manifest and
collector hashes plus one target record per role. Each record contains PID,
start UTC, executable path/hash/specimen ID, redacted command line, raw-command
hash, affinity, context-switch source, and a one-time loaded-module inventory.
Each accessible module has path, file name, SHA-256, byte size, file version,
and null error; inaccessible entries use null values plus an error string.

`process-metrics.csv` has this frozen column order:

```text
schema_version,run_id,sample_index,sample_utc,monotonic_seconds,
role,pid,process_start_utc,sample_status,error,
cpu_total_seconds,cpu_user_seconds,cpu_kernel_seconds,cpu_percent,
cpu_logical_core_equivalents,cpu_percent_total_capacity,
logical_processor_count,affinity_mask_hex,thread_count,handle_count,
context_switches_per_second,context_switches_available,
working_set_bytes,private_bytes,commit_bytes,virtual_bytes,
page_faults_total,page_faults_per_second,
io_read_operations_total,io_write_operations_total,io_other_operations_total,
io_read_bytes_total,io_write_bytes_total,io_other_bytes_total,
io_read_operations_per_second,io_write_operations_per_second,
io_other_operations_per_second,io_read_bytes_per_second,
io_write_bytes_per_second,io_other_bytes_per_second
```

Counter sources and calculations:

- cumulative user/kernel CPU, faults, I/O totals, thread count, handle count,
  working/page-file/virtual values: `Win32_Process`;
- working/private/virtual bytes and affinity: `Get-Process` where accessible;
- `commit_bytes`: `Win32_Process.PrivatePageCount` (private committed pages in
  bytes; kept as its own source alongside the live-process private-byte value);
- CPU percent and fault/I/O rates: non-negative deltas divided by monotonic
  sample time; the first row has null rates;
- `cpu_percent` is percentage of one logical CPU and may exceed 100;
  `cpu_logical_core_equivalents = cpu_percent / 100`; total-capacity percentage
  divides by the manifest logical-processor count.

The low-overhead process provider exposes thread count but not per-process
context-switch totals. The formatted thread provider exceeded 15 seconds in a
bounded local probe, so it is deliberately excluded. These fields are currently
null/false and identity states the source is unavailable; unavailable never
means zero.

`collector-overhead.json` (`a2wasp-collector-overhead-v1`) records target and
sample counts, interval/wall/collector CPU, peak collector working set,
module-hash time, query p50/p95/max, missed deadlines, output bytes, bytes per
process-sample, and before/after manifest hashes.

## Tests

No Arma process is required. Tests use three test-owned sleeping PowerShell
processes standing in for server, HC, and client roles.

```powershell
python Tools\PerfCapture\tests\test_validate_run_manifest.py
python Tools\PerfCapture\validate_run_manifest.py --self-test
powershell -NoProfile -ExecutionPolicy Bypass -File Tools\PerfCapture\Collect-ProcessMetrics.Tests.ps1
pwsh -NoProfile -File Tools\PerfCapture\Collect-ProcessMetrics.Tests.ps1
```

## Rollback

Close/revert the draft PR or delete this tool directory before adoption. Run
artifacts live outside the repository. Because the tool never changes target
processes, services, launch settings, game files, or server configuration, no
runtime rollback or restart is required.
