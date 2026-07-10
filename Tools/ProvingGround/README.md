# WASP Proving Ground

> **LAB ONLY — DO NOT MERGE OR DEPLOY.** Utes still requires editor and dedicated 0/1/2-HC verification. The scheduler is an experimental server-only v0, not production runtime code.

A generated, current-source test mission for fast AI, HC, pathfinding, network-bus, group-density and server-performance experiments.

Nothing here deploys, restarts or edits a production mission. `build.py` copies the current Chernarus source into `Tools/ProvingGround/out/` (gitignored), applies a test-only overlay, and optionally writes a PBO through the reviewed `Tools/Stresstest` packer.

## Why two maps

- **Utes microbench:** three editor-authored towns and short travel legs make AI/path/HC failures visible in minutes. The geometry comes from this repository's removed same-lineage mission at `1cc641a91^:[55]warfarev2_073v48co.utes/mission.sqm`; the builder replaces its obsolete forced-HC slot with two current-style CIV HC slots and runs today's mission code.
- **Chernarus fast bench:** the current `mission.sqm` plus the existing team/town scenario pins. Use it for map objects, features and full topology that Utes cannot represent.

The Utes topology is deliberately marked `editorVerificationRequired` in every manifest. It is a draft test asset until an editor load and a real dedicated server + two-HC boot prove its SQM, slots, synchronization and init path. It is not a fourth production mirror and is never placed under `Missions_Vanilla`.

## Build

List recipes:

```text
python Tools\ProvingGround\build.py --list
```

Build the ten-minute Utes smoke mission as an unpacked mission folder:

```text
python Tools\ProvingGround\build.py fast-smoke --force
```

Build and pack a PBO for a test rig:

```text
python Tools\ProvingGround\build.py fast-smoke --force ^
  --pbo C:\WASP\staging\WASP_ProvingGround_fast-smoke.utes.pbo
```

If that PBO already exists, its replacement requires separate, explicit consent:

```text
python Tools\ProvingGround\build.py fast-smoke --force ^
  --pbo C:\WASP\staging\WASP_ProvingGround_fast-smoke.utes.pbo --force-pbo
```

Build the current-map feature bench:

```text
python Tools\ProvingGround\build.py current-map-fast --force
```

The output manifest records HEAD plus a dirty suffix, source/lab content fingerprints, complete resolved recipe, variant and whether editor verification is still required. The builder refuses active `WF_DEBUG`, malformed recipe bounds, stale patch anchors and unsafe paths. Repository-local output is restricted to the gitignored `Tools\ProvingGround\out` tree; an explicit external staging path is also allowed.

`--force` only removes a directory carrying a matching `WASP-LAB-MANIFEST.json` ownership sentinel. It will not recursively remove a foreign, partial or renamed directory. PBO overwrite permission is deliberately separate: an existing `.pbo` is preserved unless `--force-pbo` is supplied. Candidate and variant labels accept only letters, digits, dot, underscore and dash (`--candidate` up to 64 characters; `--variant` up to 48).

It only stages artifacts. Copying to a rig, changing server config, stopping services, starting Arma and rolling back remain explicit operator actions.

## Run topology and A/B labels

Use the same recipe with named variants. For the required 0/1/2-HC matrix:

```text
python Tools\ProvingGround\build.py hc-delegation --expected-hcs 0 --variant hc0 --force
python Tools\ProvingGround\build.py hc-delegation --expected-hcs 1 --variant hc1 --force
python Tools\ProvingGround\build.py hc-delegation --expected-hcs 2 --variant hc2 --force
```

The builder forces `busRate=0` and disables the HC-ownership threshold whenever `expectedHcs=0`, even if the base recipe normally sends pings. There is no legal HC round-trip target in that topology. The `hc0` arm is therefore the server-only ownership/fallback baseline for the 0/1/2-HC and bounce comparisons, not a bus-throughput result.

Common bounded overrides are available without editing JSON:

```text
--duration-sec N  --sample-sec N  --groups N  --units-per-group N
--bus-rate N      --team-cap N    --pop-pin N  --expected-hcs N
--scheduler-mode off|shadow|active
```

For allocator, command-line, addon or scheduler experiments, label the arms `--variant control` and `--variant candidate-name`. Keep git SHA, mission recipe, `basic.cfg`, HC count, CPU masks, mods, view distance, OS power plan and run duration fixed unless that item is the tested dimension.

## Recipes

| Recipe | Use |
|---|---|
| `fast-smoke` | Current-code boot/init and real two-HC ownership in about ten minutes. |
| `hc-delegation` | Real AICOM/town delegation, collapse detection and HC bounce/rejoin. |
| `bus-ramp` | Bounded `Common_SendToClient` + `Common_SendToServerOptimized` round trips for compile/pacing A/Bs. |
| `scheduler-ramp` | Equal-total creation/path/bus workload for scheduler off/shadow/active A/Bs; active deliberately changes work timing. |
| `pathfinding-ramp` | Repeated town-to-town infantry and supply-vehicle legs; arrival/stuck telemetry. |
| `combat-ramp` | WEST/EAST SAD convergence, combat, deaths and cleanup. |
| `density-4` | 240 synthetic infantry in 60 groups. |
| `density-8` | The same 240 infantry in 30 groups; paired group-brain-cost test. |
| `current-map-fast` | Current Chernarus with one nearest town per side and two commander teams; live features enabled. |

Synthetic groups are intentionally server-local so the density/path/combat and scheduler recipes stress the dedicated process. That is a benchmark topology, not a production ownership recommendation. In production the server should retain authoritative mission/economy/network work and the unavoidable or explicit fallback AI floor; eligible combat and town groups should normally be created on healthy HCs. `hc-delegation` uses the mission's real town/AICOM dispatch path; it does not fake locality.

## Live monitoring

Human summary of the last run in an RPT:

```text
python Tools\ProvingGround\monitor.py C:\path\arma2oaserver.RPT
```

Agent-friendly live stream:

```text
python Tools\ProvingGround\monitor.py C:\path\arma2oaserver.RPT --follow --json-lines --min-fps 30
```

Machine-readable final summary:

```text
python Tools\ProvingGround\monitor.py C:\path\arma2oaserver.RPT --json
```

The parser treats `BOOT` as a new attempt, scopes completed data to the following `START`, tolerates normal Arma RPT quoting/prefixes, excludes warm-up from benchmark statistics, and reports server FPS, AI/groups, registered-valid-HC-owner percentage and balance, bus-backed HC FPS/freshness, stuck groups, path legs, bus throughput/loss/latency, scheduler health, harness verdict and fatal mission/SQF signatures. The comparer promotes minimum HC FPS alongside server FPS and rejects mismatched `minHcFps` configurations. `--follow` handles in-place RPT truncation; reopen it after an external rename/rotation.

The ownership census de-duplicates owner IDs and requires a non-null group, living leader and owner `>2`, but it does not classify which AI is delegation-eligible. When `busRate > 0`, validated LabPong ACK rows add a separate responsiveness signal: an endpoint must match a pending sequence/token, remain in the registered owner set, return at least four ACKs, and have an ACK no older than ten seconds. `SAMPLE` reports the fresh endpoint count and minimum returned `diag_fps`; `RESULT`, the monitor and the comparer promote the post-warm-up minimum. Recipes with `busRate == 0` do not have this channel and still require the individual HC RPTs for HC-process FPS.

Compare two matched runs:

```text
python Tools\ProvingGround\compare.py control.RPT candidate.RPT
python Tools\ProvingGround\compare.py control.RPT candidate.RPT --json
```

## Telemetry contract

Plain `diag_log` is used so the lab remains visible when `WF_LOG_CONTENT` is compiled off:

```text
WASPLAB|v1|START|run=...|scenario=...|map=...|variant=...|...
WASPLAB|v1|SAMPLE|run=...|t=...|fps=...|ai=...|groups=...|srvAi=...|hcAi=...|hcPct=...|hcImbalancePct=...|hcFresh=...|hcFpsMin=...|stuck=...|probeMs=...
WASPLAB|v1|BATCH|run=...|batch=...|spawnedTotal=...|spawnedDelta=...|ai=...|groups=...
WASPLAB|v1|BUS|run=...|sentTotal=...|ackTotal=...|dropTotal=...|latencyMs=...
WASPLAB|v1|PATHLEG|run=...|from=...|to=...|elapsed=...|status=ARRIVED
WASPLAB|v1|SCHED|run=...|budgetMs=...|elapsedMs=...|frameDelta=...|due=...|deferred=...
WASPLAB|v1|ALERT|run=...|state=DEGRADED|COLLAPSED|OK|hcPct=...
WASPLAB|v1|RESULT|run=...|status=PASS|FAIL|reason=...|hcFpsSamples=...|hcFpsMin=...|busFreshEndpoints=...|...
```

Unlike the old `remote == 0` alert, the lab counts non-player AI against registered HC owner IDs that pass the validity checks above. With at least 40 AI after warm-up it marks `<60%` HC ownership for three samples as degraded and `<25%` for two samples as collapsed. Thresholds remain recipe data, and the result does not page or restart anything.

`minHcFps` defaults to 25. The harness enforces missing/stale endpoint and HC-FPS-floor failures only when both `busRate > 0` and `expectedHcs > 0`; this avoids pretending a no-bus or zero-HC control measured HC FPS. The 25-FPS floor is a lab safety gate, not evidence that 25 FPS is the desired scale target.

## Scheduler and custom-runtime experiments

The generated mission now contains a **server-only v0 cooperative scheduler**. Active mode controls only the lab's group-creation ramp, path-driver continuation and Common_Send pressure; shadow mode adds matching no-op scheduling overhead while the original lab workers remain authoritative. It uses four small lane arrays, unique job IDs, a 32-job cap, disabled-job compaction, a separate heartbeat script and an advisory 0.25–1 ms launch budget. It does not yet implement the proposed timing wheel, shared snapshots, production cleanup, HC dispatch backpressure or HC-local schedulers.

Build the three matched arms from the same tree:

```text
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-off --scheduler-mode off --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-shadow --scheduler-mode shadow --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-active --scheduler-mode active --force
```

The scheduler cannot pre-empt a long SQF function or replace engine AI/pathfinding. Its elapsed timing can include OA suspending the shared scheduled environment, so telemetry also records frame crossings and operation outcomes.

All AI in these arms remains continuously materialized and fully simulated by the Arma engine. The scheduler phases bounded mission SQF work; it does not freeze units, call `enableSimulation false` on AI, virtualize forces, export movement/combat simulation or reduce simulation by distance. The inherited `enableSimulation false` entries in the Utes SQM apply to town/camp logic objects, not AI.

Expected gain is a hypothesis to test, not a release claim. For this narrow v0, median FPS may move only 0–5%; the more plausible hypothesis is a 5–15% improvement in p5/min FPS during creation/scan bursts. After real hot-loop migration and shared scans, script-bound periods might gain roughly 5–15%, while a 400-AI engine-simulation-bound scene may gain less or nothing. Active versus off includes deliberate pacing: group creation changes from a tight batch to one group per interval slice, and path checks are spread across continuations. Use shadow versus off to measure dispatcher overhead; do not attribute the active result to the dispatcher alone. Any number is rejected unless workload attainment, arrivals, HC ownership, bus throughput and group counts remain comparable.

Recommended rollout:

1. Shadow scheduler: register job cadence and measure would-run/defer/jitter without owning behavior.
2. Migrate low-risk telemetry/PV/cleanup jobs.
3. Migrate dormant town/camp scans into phased buckets.
4. Add server→HC creation backpressure and ACK jobs.
5. Migrate commander sensing/scoring only after outcome parity.

No native extension is built or shipped by this PR. A later, separate research PR could prototype a 32-bit `wasp_runtime.dll` for asynchronous pure-data advisory work such as road-graph candidates, target scoring or telemetry aggregation. A2 OA is a 32-bit process and cannot load a 64-bit DLL directly. If a workload genuinely needs a 64-bit worker, an optional 32-bit bridge DLL could exchange immutable numeric/string messages with a separate 64-bit sidecar over a bounded local IPC channel. The bridge/sidecar must never receive engine pointers or own AI simulation. OA's string-form `callExtension` is blocking, so submit/poll calls must return immediately; final validation, locality and engine commands stay in SQF. Any future module that affects HC-local work must be loaded and identified on the server and both HCs, then tested as a named variant.

Large-address-aware status, allocator choice and engine/process arguments are separate headroom/stability experiments. LAA can reduce 32-bit address-space exhaustion only if the executable is actually marked and the complete setup is compatible; it does not reduce per-frame AI work. Allocator changes can affect fragmentation, memory pressure or stutter, but are not an FPS claim. Neither executable flags nor allocators are changed here, and each candidate must be tested one variable at a time on a maintenance rig.

## Verification

Static/tool checks:

```text
python -m unittest discover -s Tools\ProvingGround\tests -p "test_*.py" -v
python Tools\ProvingGround\build.py fast-smoke --validate-only
python Tools\Lint\check_sqf.py --select A3CMD,A3SELECT,GROUPGETVAR,BRACKET,BOOLCMP,A3NUMGATE,NSSETVAR3,PUBVARSV,FLAGGATE,MILMARKER --no-classname-index Tools\ProvingGround\mission\test\ProvingGround_PreInit.sqf
python Tools\Lint\check_sqf.py --select A3CMD,A3SELECT,GROUPGETVAR,BRACKET,BOOLCMP,A3NUMGATE,NSSETVAR3,PUBVARSV,FLAGGATE,MILMARKER --no-classname-index Tools\ProvingGround\mission\test\ProvingGround_ResetParams.sqf
python Tools\Lint\check_sqf.py --select A3CMD,A3SELECT,GROUPGETVAR,BRACKET,BOOLCMP,A3NUMGATE,NSSETVAR3,PUBVARSV,FLAGGATE,MILMARKER --no-classname-index Tools\ProvingGround\mission\test\RuntimeScheduler.sqf
python Tools\Lint\check_sqf.py --select A3CMD,A3SELECT,GROUPGETVAR,BRACKET,BOOLCMP,A3NUMGATE,NSSETVAR3,PUBVARSV,FLAGGATE,MILMARKER --no-classname-index Tools\ProvingGround\mission\test\ProvingGround_Server.sqf
python Tools\Lint\check_sqf.py --select A3CMD,A3SELECT,GROUPGETVAR,BRACKET,BOOLCMP,A3NUMGATE,NSSETVAR3,PUBVARSV,FLAGGATE,MILMARKER --no-classname-index Tools\ProvingGround\mission\Client\PVFunctions\LabPing.sqf
python Tools\Lint\check_sqf.py --select A3CMD,A3SELECT,GROUPGETVAR,BRACKET,BOOLCMP,A3NUMGATE,NSSETVAR3,PUBVARSV,FLAGGATE,MILMARKER --no-classname-index Tools\ProvingGround\mission\Server\PVFunctions\LabPong.sqf
```

Before using Utes results for a release decision:

1. Open generated Utes in the A2 OA editor and save/load once; confirm three towns, two camps each, five starts and two separate CIV HC slots.
2. Dedicated cold boot with 0 HCs, then 1, then 2; require MISSINIT and START/RESULT with no load/SQF errors.
3. Confirm both HC processes register, own real AICOM/town AI, and answer LabPing.
4. Bounce HC-A then HC-B and observe owner-aware degradation/recovery without duplicate groups.
5. Compare against `current-map-fast` before generalizing concentrated Utes combat to Chernarus.

See `docs/testing/WASP-AI-SCALE-AND-SERVER-PERF-PLAN.md` for the prioritized production change ladder and scale gates.
