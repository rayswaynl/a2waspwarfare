# Immutable Performance Capture Design

## Purpose and boundaries

`Tools/PerfCapture` supplies the common evidence spine for offline and test-lab
Arma 2 OA performance experiments. It does two things only: validate/finalize a
strict run manifest, and observe explicitly named Windows processes without
changing them. It never launches, stops, reprioritizes, re-affinitizes, injects
into, or otherwise controls a server, headless client, or player client.

The public interface is deliberately explicit. A run manifest names every
process as a stable role/PID/start-time/executable specimen tuple. The sampler
does not discover "whatever ArmA process looks right" because that can silently
mix server, HC, client, or stale processes. Files are written only beneath the
operator-selected artifact directory.

The manifest has two lifecycle states. A `pending` manifest is valid before the
run and may contain null end/attained values. After capture, the operator records
attained workload, end time, validity, invalid reasons, and artifact paths, then
finalizes it. Finalization rewrites JSON into a canonical byte representation
and creates `MANIFEST.sha256`. Any later validation verifies the digest and
refuses a changed sealed manifest. This resolves the apparent conflict between
predeclared experiment fields and facts that are only known after the run.

## Considered approaches

1. A Python-only `ctypes` collector would provide low-level APIs and one test
   language, but reliable command-line, module, and context-switch collection
   requires fragile native structures or extra packages.
2. A PowerShell-only tool fits Windows collection naturally, but implementing a
   strict JSON Schema subset, canonical JSON, and deterministic sealing in
   Windows PowerShell 5.1 would be harder to audit and test.
3. The selected hybrid keeps each language on its strongest surface: stdlib-only
   Python for validation/canonical sealing, and PowerShell/CIM for Windows
   observation. It adds no third-party dependency and supports both Windows
   PowerShell 5.1 and PowerShell 7.

## Manifest contract

`run-manifest.schema.json` uses JSON Schema draft-07, requires all contract
fields, and sets `additionalProperties:false` on every object. Null means
unknown or not yet attained; zero remains a measured zero. The schema covers:

- run identity, artifact directory naming, regime/scenario/arm/build;
- source commit/tree identity and dirty-state declaration;
- executable, DLL, mission PBO, config, and tool specimens with SHA-256/size;
- anonymized host OS/CPU/topology;
- map, mission, flags, mod order, player count, expected HCs;
- per-process role, PID, start UTC, executable specimen reference, redacted
  command line plus raw-command SHA-256, and affinity mask;
- requested and attained workload;
- UTC start/warm-up/end boundaries;
- pending/valid/invalid status and invalid-run reasons;
- required artifact locations.

The Python validator implements the schema keywords this contract uses and adds
cross-field checks JSON Schema cannot express concisely: unique specimen IDs and
process roles, valid specimen references, folder-name identity, time ordering,
status/null consistency, required specimen kinds, and role/topology agreement.

## Process data flow

The collector validates the manifest, records its starting SHA-256, resolves
each declared PID, and verifies PID reuse protection (creation time), executable
hash, raw-command hash, and affinity before sampling. A mismatch is a fail-closed
preflight error. Accessible loaded modules are hashed once into
`process-identity.json`; unavailable modules are represented as null/error, never
as a fabricated zero.

Each interval queries `Win32_Process`, formatted process counters, formatted
thread counters, and `Get-Process`. Rows are emitted in stable role order to
`process-metrics.csv`. They include cumulative CPU user/kernel/total time,
process CPU percentage, logical-core equivalents, total-capacity percentage,
thread and handle counts, context-switch rate when available, working/private/
commit/virtual bytes, page-fault total/rate, cumulative I/O operations/bytes and
formatted rates, affinity, and explicit sample status/error. If a target exits,
the row records `process-unavailable`; the tool does not restart it.

At completion the collector re-hashes the manifest and fails if it changed
during capture. `collector-overhead.json` reports collector wall/CPU time,
per-sample query p50/p95/max, deadline misses, module-hash time, output size, and
CPU expressed both as logical-core and total-machine percentages. The contract
does not invent a universal pass threshold; every experiment reports these
values beside the effect it is attempting to measure.

## Error handling, testing, and rollback

Every partial/unavailable metric stays null with an availability/error marker.
Identity mismatches and manifest mutation stop the capture. Ordinary counter
unavailability is recorded without changing the target process.

Python unit tests exercise valid, malformed, cross-field-invalid, canonical,
sealed, and tampered manifests. Plain-assertion PowerShell integration tests use
a benign test-owned sleeping process, prove the collector leaves it running,
verify CSV/identity/overhead schemas, and verify PID/hash mismatch failures.
No Arma runtime is required.

Rollback is deletion of `Tools/PerfCapture` and its documentation, or closing
the draft PR. Runtime artifacts are external to the repository, and the tool
does not mutate game/server state, so no service or configuration rollback is
needed.
