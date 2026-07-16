# WASP runtime scheduler — A2 OA lab design

> **LAB ONLY — DO NOT MERGE OR DEPLOY.** The implemented v0 exists only in generated proving-ground missions, is default-off and server-only, and still requires an A2 OA dedicated-rig run. It does not authorize a production flag, addon, allocator, executable change, native extension or service action.

## Feasibility and non-goals

WASP can own a **cooperative mission-work scheduler**. It can decide when bounded SQF jobs scan, score, create, clean, publish and dispatch. That makes synchronized wakeups, repeated scans and uncontrolled creation bursts measurable and, after outcome-preserving migrations, deferrable.

It cannot pre-empt a function that is already running or replace the engine's AI simulation/pathfinder. Once a job spends 500 ms, that time is already lost. Heavy work therefore has to become bounded continuation steps before a launch budget can help.

This design does **not** use simulation gating. All test AI remains continuously materialized and fully simulated by Arma. The scheduler does not freeze units, call `enableSimulation false` on AI, virtualize off-map forces, export movement/combat simulation or reduce simulation by distance. Historic `enableSimulation false` entries in the Utes SQM apply to town/camp logic objects, not AI.

Replacing the engine scheduler would require binary-hook/reverse-engineering work against the closed A2 OA executable. That is a separate high-risk research program with a much larger crash, BattlEye, maintenance and reproducibility surface; it is neither implemented nor proposed for this PR.

## Server and HC responsibility

The dedicated server must remain authoritative for mission state, economy, towns, commander decisions, dispatch, public-variable routing, cleanup policy and reconciliation. It does not need to own every AI group. With healthy HCs, eligible combat and town groups should normally be created on the HCs while the server retains unavoidable categories and an explicit bounded fallback floor.

The proving-ground density, path, combat and scheduler recipes intentionally create synthetic groups on the server. That isolates server cost and is not a production ownership recommendation. `hc-delegation` separately exercises the mission's real create-local HC path.

A future production architecture could run one mission-work dispatcher per simulation process:

```text
server: authority, strategy, dispatch, cleanup, aggregate snapshots
HC-A/B: HC-local creation workers, bounded local helpers, completion ACKs
client: no simulation dispatcher; optional low-priority UI telemetry only
```

Only the first line exists in v0, and only for lab work. `RuntimeScheduler.sqf` exits on every non-server process.

## V0 as implemented

V0 is copied only into generated proving-ground missions. `WASP_LAB_SCHEDULER_MODE` defaults to `off`; `shadow` and `active` are explicit build choices.

- `off`: original lab loops own group batches, path checks and bus sends.
- `shadow`: original lab loops remain authoritative while cheap no-op jobs exercise scheduler cadence and overhead.
- `active`: the scheduler owns only the lab group ramp, path continuation and Common_Send pressure job.
- No production mission loop, cleanup worker, commander behavior or HC creation route is migrated.
- No timing wheel, shared world snapshot, HC backpressure queue or HC-local scheduler exists yet.

### A2-safe job record

No hash maps or A3 commands are required. A job is an array:

```text
[id, lane, dueAt, interval, maxMs, code, state, enabled, runCount, overrunCount]
```

- `id`: unique stable string; duplicates are rejected.
- `lane`: 0 critical, 1 active-combat mission work, 2 normal mission work, 3 maintenance.
- `dueAt`: `diag_tickTime` deadline.
- `interval`: normal recurrence; a job may return a different next delay.
- `maxMs`: telemetry/health contract, not a pre-emption guarantee.
- `code`: bounded code called with `[state, now]`; it must not sleep or start an unbounded scan.
- `state`: continuation cursor/data returned for the next step.

V0 uses four small arrays and linearly scans enabled jobs on each pass. It rejects a 33rd job, runs at most 16 jobs per pass and compacts disabled entries every five seconds. Lane order gives earlier lanes first opportunity, but v0 does not enforce a hard “lane 2/3 forbidden below FPS X” rule. A timing wheel and deterministic registration phasing remain target design, not implemented behavior.

### Current advisory launch budget

The dispatcher is one spawned work loop plus a separate minimal heartbeat. Current code uses:

| Server FPS | V0 launch budget per pass | Actual behavior |
|---:|---:|---|
| ≥42 | 1 ms | Visit lanes 0→3 until budget or 16-run cap. |
| 32–41 | 0.75 ms | Same ordering with a smaller budget. |
| 25–31 | 0.5 ms | Same ordering with a smaller budget. |
| <25 | 0.25 ms | Same ordering; only work reached before budget runs. |

The budget is advisory. A single call may overrun it, and OA may suspend the shared scheduled environment while the call is active. V0 therefore records both elapsed time and frame crossings. After an overrun it launches no more jobs once the pass budget is exhausted, but it cannot claw time back or guarantee that a critical job runs on a specific frame.

## Exact lab A/B

Build all arms from the same tree and keep mission recipe, HC count, `basic.cfg`, mods, CPU masks, view distance, OS power plan and duration fixed:

```text
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-off --scheduler-mode off --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-shadow --scheduler-mode shadow --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-active --scheduler-mode active --force
```

Run at least three repetitions per arm and retain each server RPT. Shadow versus off measures dispatcher overhead. Active versus off measures the scheduler **plus deliberate pacing**: group creation changes from a tight batch to one group per interval slice, and path checks are spread across continuations. Equal total requested work does not mean identical temporal load, so an active result must not be presented as dispatcher-only gain.

Expected gain remains unverified. A realistic lab hypothesis is 0–5% median-FPS movement and 5–15% better p5/min FPS during creation/scan bursts. Collective hot-loop phasing, shared scans and direct compile/churn fixes might produce roughly 5–15% headroom in script-bound periods; engine-AI-bound scenes may gain less or nothing. Fixing HC locality is expected to be the larger scale lever. The live 47→30→recovery observation is evidence for testing, not a scheduler forecast.

Advance only if workload attainment, AI/groups, HC ownership, path arrivals, stuck rate, bus throughput/loss, combat outcomes and cleanup stay comparable. Bus-enabled, nonzero-HC arms also require fresh ACK rows from every expected HC and a post-warm-up minimum HC FPS at or above the recipe's `minHcFps` (default 25). That floor is a safety gate, not the desired scale target. Median server FPS alone is insufficient.

## Target runtime after v0 — not implemented

### Timing and shared snapshots

A later dispatcher may use a bounded near/coarse timing wheel instead of scanning every job. Registration should phase recurring jobs deterministically so restarts do not wake every town on one frame.

Repeated `allUnits`, `allGroups`, `vehicles` and town scans are a large avoidable multiplier. A process-local snapshot service could publish arrays plus a generation number:

```text
[generation, capturedAt, aiBySide, aiByOwner, groupsBySide, localGroups,
 activeTowns, players, vehiclesByKind]
```

Consumers must declare acceptable age. Never broadcast the full snapshot; only small aggregate health/ACK data should cross machines.

### Backpressure and network work

PVEH handlers should validate and enqueue, then return. A future server dispatch contract may use:

- one creation send per 250 ms globally;
- at most two accepted-but-incomplete jobs per HC;
- owner/freshness revalidation immediately before send;
- dispatch ID and target owner;
- accept ACK, completion ACK and bounded de-duplication history;
- reconciliation before retry;
- exact per-dispatch refund/reset on final failure.

None of that HC creation flow control exists in scheduler v0. The lab bus job only paces bounded ping traffic through the real Common_Send wrappers. Scheduling also does not replace removing `Call Compile Format` from each transport operation.

### Migration order

1. Prove shadow overhead below measurement noise.
2. Migrate low-risk telemetry and marker-feed publishing.
3. Split empty-vehicle candidate scans from bounded cleanup actions.
4. Phase dormant town/camp scans while preserving elapsed-time behavior.
5. Add owner-fresh HC creation queue/ACK/backpressure.
6. Reuse snapshots for commander sensing/scoring in bounded continuations.
7. Touch group drivers only if measurement proves it necessary.

Candidate hot spots include town preallocation/delegation (`server_town_ai.sqf:337-403`), camp `nearEntities` scans (`server_town_camp.sqf:40-54`), repeated group-creation scans (`Common_CreateGroup.sqf:28-58`) and periodic feed broadcasts (`server_side_patrols.sqf:84-120`). Every production migration needs outcome parity and a default-off rollback path.

## Native worker extension — separate, unbuilt research

This PR contains no DLL, sidecar, binary hook or extension loader. A later research PR could test asynchronous **pure-data advisory** work such as road-graph candidate search, commander candidate scoring or telemetry aggregation.

A2 OA is a 32-bit process. It cannot directly load a 64-bit DLL. The simplest in-process extension must therefore be x86. If a justified workload needs a 64-bit worker, the only proposed shape is an optional x86 bridge DLL forwarding immutable numeric/string requests to a separate x64 sidecar over bounded local IPC:

```text
SQF submit(requestId, immutable payload) -> x86 bridge returns immediately
x86 bridge -> bounded named pipe/local socket/shared-memory queue -> x64 sidecar
x64 sidecar performs pure-data work without engine pointers
SQF poll(requestId) -> pending or immutable result
SQF validates generation/locality, then applies final engine commands
```

`callExtension` is synchronous from SQF's perspective, so submit/poll must stay short and bounded. Never pass engine object pointers, call engine functions from worker threads, let the sidecar own simulation, or apply a result without generation/locality validation. The worker may suggest road nodes; Arma still performs unit movement, collision avoidance, terrain navigation, combat and all continuous simulation.

## LAA, allocator and process experiments

Large-address-aware status is a memory-headroom question, not an FPS feature. If the executable is compatible and actually marked LAA, it may reduce 32-bit address-space exhaustion or delay an out-of-memory failure; it does not reduce per-frame AI/pathfinding work. No executable flag is changed here.

Allocator alternatives, `-cpuCount`/`-exThreads` and CPU affinity can affect fragmentation, memory pressure, stutter or contention. They are stability/headroom experiments, not promised FPS gains. Test one variable at a time on a maintenance rig, give the server and HCs deliberate physical-core placement, capture boot signatures/command lines, and judge p5/min FPS, memory growth and HC bounce recovery as well as median.

## Telemetry: current versus target

V0 currently emits rate-limited plain `diag_log`:

```text
WASPSCHED|v1|START|proc=server|mode=|queueCap=32
WASPSCHED|v1|HEALTH|proc=server|mode=|fps=|budgetMs=|elapsedMs=|frameDelta=|ran=|deferred=|due=|queued=|oldestMs=|overruns=
WASPSCHED|v1|JOB|id=|elapsedMs=|frameDelta=|maxMs=|state=OVERRUN
WASPSCHED|v1|REJECT|id=|reason=
WASPLAB|v1|SCHED|run=|mode=|budgetMs=|elapsedMs=|frameDelta=|ran=|deferred=|due=|queued=|oldestMs=|overruns=
WASPLAB|v1|SAMPLE|run=|fps=|hcFresh=|hcFpsMin=|...
WASPLAB|v1|RESULT|run=|hcFpsSamples=|hcFpsMin=|busFreshEndpoints=|...
```

LabPing returns its endpoint token and `diag_fps`; LabPong accepts the reading only after shape/type, pending-sequence, endpoint, warm-up token and sent-time validation. A current registered endpoint becomes fresh after at least four accepted ACKs and remains fresh for ten seconds. When `busRate > 0` and `expectedHcs > 0`, the final verdict requires every expected endpoint fresh, at least one complete post-warm-up HC-FPS sample, and minimum HC FPS at or above `minHcFps` (default 25). No-bus recipes still require the HC RPTs for process-FPS analysis.

For an `expectedHcs=0` control the builder forces `busRate=0` because the HC round-trip bus has no legal target. That arm remains a server-only topology/ownership baseline; it cannot be compared as bus throughput or HC FPS.

The server controller also writes scheduler totals and health ages into `WASPLAB|v1|RESULT`. The proving-ground monitor promotes HC freshness/FPS with server FPS, owner percentage, arrivals, stuck groups, bus data and fatal RPT signatures; the comparer includes minimum HC FPS and requires matching `minHcFps`. Per-lane histograms and shared-snapshot records are future telemetry; v0 does not emit `LANE` or `SNAP` records.

## Failure containment as implemented

- Mode defaults to `off`, and only generated lab workers switch behavior.
- Queue size is capped at 32; disabled jobs are compacted.
- A returned failure or invalid result disables that job and increments the error count.
- An arbitrary SQF interpreter error may still terminate the dispatcher; A2 provides no general exception boundary here.
- The separate heartbeat and scheduler-health timestamps make a dead work loop observable, but v0 has no live watchdog that stops work or restarts anything. The harness checks stale health in its final verdict.
- No scheduler degradation pages Peach+, restarts a process, changes a service or mutates production.

The realistic prize is a mission runtime that stops launching avoidable SQF bursts on the same frame. It is not a new engine and must never be sold as one.
