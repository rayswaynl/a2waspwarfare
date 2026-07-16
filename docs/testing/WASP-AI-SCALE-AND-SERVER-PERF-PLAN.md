# WASP AI scale and server-performance plan

> **LAB ONLY — NEVER DEPLOYED.** This plan merges as tooling documentation (owner plan pick 4, 2026-07-15; see "Lab-only tooling policy" in `docs/AGENT-HANDBOOK.md`). The proving-ground scheduler is a default-off, server-only v0. Utes and every performance claim remain dedicated-rig work.

Status: source-verified design and proving-ground plan. No production flag, service, executable, allocator, mod, DLL or sidecar is changed by this document or the proving-ground PR.

## Decision in one sentence

Treat **group count, locality failure and bursty mission work** as the current ceiling before treating 400 AI as a hard engine ceiling. First make 400 AI fit below roughly 90 groups with truthful HC ownership; only then raise units in 10–15% rungs.

## What the live evidence says

The 2026-07-09/10 production cycle produced both healthy 300–400-AI periods and a live delegation collapse in which the dedicated server carried 85–93% of the AI while two HC processes remained up. The same night samples showed a much sharper relationship with total groups: below 80 groups the server was near its 47 FPS ceiling; 80–99 groups averaged in the low 40s; samples at/above 100 groups averaged in the low 20s. Peak 424 AI / 123 groups was about 24 FPS.

Those observations are not a universal engine benchmark. They are evidence that raising the raw unit cap on the current architecture will reproduce the bad side of the curve.

## Ranked mission-side work

| Order | Change | Why it is high leverage | Verification gate |
|---|---|---|---|
| 1 | Truthful 10–60 s owner-aware HC telemetry | Existing `DELEGSTAT` can call 7% remote “not dead”; owner-aware AI counts reveal the real scheduler placement. | 0/1/2 HC, both HC bounces, player join/leave; census excludes humans and matches owner IDs. |
| 2 | Stop pre-creating throwaway town groups on the HC path | `Server/FSM/server_town_ai.sqf:348-376` creates 2–8 server groups before locality is selected at `:379-399`; the HC receiver creates replacements for empty inputs. Activation bursts temporarily inflate group slots and every `allGroups` scan. | Activate 12 towns: created HC groups equal completed requests, no extra empty server groups, group count returns to baseline within 120 s. |
| 3 | Compile-free, paced, acknowledged HC dispatch | `Common_SendToClient.sqf`, `Common_SendToClients.sqf` and `Common_SendToServerOptimized.sqf` compile a generated assignment on every send; `Server_DelegateAITownHeadless.sqf` emits a tight per-group burst. | Common_Send A/B at fixed 1/5/10/20 msg/s; zero loss/duplicate creation, bounded queue, lower CPU/probe cost. |
| 4 | Fresh owner-keyed HC registry and bounce grace | Alive/non-null is not a freshness or owner check. A stale owner 2 or duplicate owner row can win selection; new groups then become sticky on the server. | Kill/rejoin each HC: no invalid-owner sends, no new server fallback during grace, new delegatable load returns to healthy HCs. |
| 5 | Remove the O(`allGroups`) scan from every group creation | `Common/Functions/Common_CreateGroup.sqf:28-32` scans every group for every create; close to cap it performs GC and a second scan at `:35-58`. | Fixed 100-group creation microbench, exact cap behavior, same attribution and no `grpNull` regression. |
| 6 | Compile vehicle helper code once during init | `Common/Functions/Common_CreateVehicle.sqf:30,33,40,46,50,56` preprocesses/compiles helpers repeatedly for every vehicle, including three unconditional paths. | 100 mixed vehicles, identical classes/crew/EHs/textures/JIP init; lower creation time and no missing helper. |
| 7 | Measure group partition before expanding group size | W/E town merge target is five while GUER is already denser. More units per existing local group may cost less than more group brains, but larger formations can reduce offensive breadth or path quality. | Equal-unit `density-4/6/8/10/12` screen with realized member/anchor exposure; then composition-specific production trials. Preserve capture/arrival/combat outcome. |
| 8 | Smooth hot scans and public-variable churn | Each active town's camp loop performs `nearEntities` per camp (`server_town_camp.sqf:40-54,132-134`). Full patrol/AICOM marker arrays can rebroadcast every 20 s (`server_side_patrols.sqf:84-120`). | Time-normalized camp capture within 5%; JIP markers recover within SLA; lower PV bytes/messages and fewer frame spikes. |
| 9 | Prove cooperative mission-work scheduling | The lab v0 can measure dispatcher overhead and phase only its synthetic group/path/bus work. Production value begins only after one bounded real loop migrates with parity. | Three matched off/shadow/active `scheduler-ramp` runs; shadow overhead below measurement noise; p5/min improves without lower workload attainment or worse outcomes. |
| 10 | Delegate GUER wildcard/garrison work | GUER wildcard/garrison groups are created directly on the server, making them a large steady local-AI floor. | Soak-only: kill credit, ledger, cleanup, owner loss and behavior parity before enabling. |

## What should the server own?

The server should own authority: economy, towns, commander decisions, dispatch, network routing, reconciliation and cleanup policy. It should not be the normal home for every AI group when healthy HCs exist. Eligible combat and town groups should usually be created on HCs; the server keeps unavoidable categories plus a deliberate bounded fallback floor. Because OA cannot safely transfer an existing group to another machine, locality must be correct at creation time and a server-created group remains a server cost until it dies or is deliberately retired.

The proving-ground's synthetic density/path/combat and scheduler groups are server-local on purpose: they isolate dedicated-process cost. That benchmark topology is not a production ownership recommendation. `hc-delegation` is the separate real-path ownership test.

## Can a server mod buy more AI?

There is no credible drop-in A2 OA addon that removes the engine's main simulation/pathfinding limit. Most “better AI” addons add danger-FSM, sensing or tasking work. A mod can still help when it is narrowly scoped and tested correctly.

### Worth A/B testing

1. **Large-address-aware status.** First inspect, do not assume, the executable's current LAA state. A compatible LAA executable may provide more 32-bit virtual-address headroom and reduce or delay memory-exhaustion failures. It does not reduce per-frame AI/pathfinding work and is not an FPS claim. Any executable change requires a separate reversible maintenance-rig plan; none is included here.
2. **Allocator, engine arguments and CPU affinity (no addon).** Test the current allocator against one known-compatible alternative, `-cpuCount`/`-exThreads` variants, and deliberate physical-core masks for server/HC-A/HC-B. Allocators primarily affect fragmentation, memory pressure, stability and possibly stutter; do not promise an FPS gain. Judge memory growth, p5/min FPS and bounce recovery as well as median. Never change the live command line blindly.
3. **A small `@wasp_perf` server+HC package.** “Server-side” is insufficient for HC-owned AI: any local AI config/FSM/helper must also load on both HCs. The package should contain only measured, reversible modules and a boot signature proving which processes loaded them.
4. **A lean background-AI profile without simulation gating.** A simplified skill/danger-FSM profile for rear/background groups could save mission/behavior work while every unit remains fully engine-simulated. This is gameplay-sensitive; compare arrival, contact reaction, casualties and stuck rate, not FPS alone.
5. **Move pure-data advisory work out of SQF.** No extension exists in this PR. A later x86 extension could aggregate telemetry or calculate road/score candidates, while Arma retains all engine object access, final commands, path execution and continuous AI simulation. Treat this as bounded advisory/observability work, not an AI-ceiling fix.
6. **Isolated vehicle-steering trial.** A steering-only component may improve convoy completion but is not expected to increase raw capacity. Test it as a path-quality intervention with equal load.

A2 OA is a 32-bit process and cannot directly load a 64-bit DLL. If later measurement justifies a 64-bit worker, the research shape is an x86 bridge DLL exchanging immutable numeric/string jobs with a separate x64 sidecar over bounded local IPC. Neither process may receive engine pointers or own AI simulation, and synchronous `callExtension` submit/poll calls must return immediately. This bridge is unbuilt, outside this PR and lower priority than locality and direct SQF hot-path fixes.

### Poor bets or unsafe shortcuts

- Adding ASR/Zeus/GL4/DAC/UPSMON as a “performance mod”: these change or add AI work; tasking mods also fight WASP's commander driver.
- Loading an AI addon only on the dedicated server while most relevant AI is HC-local.
- A third HC while the first two are idle or stale. It adds another endpoint without fixing routing; add one only after both current HCs are genuinely saturated and a physical core is free.
- Blind `basic.cfg` queue-size changes. They can move loss/latency around without reducing send volume or ownership errors.
- Disabling all RPT output. It may reduce I/O but destroys the only evidence needed to find collapse. Replace verbose content logs with low-volume structured health/error streams.
- A3 dynamic simulation, `setGroupOwner`, `remoteExec` or other A3-only mechanisms. They are not available to A2 OA 1.64.
- Simulation gating, frozen/virtualized forces or external combat/movement simulation. WASP's scale target keeps all materialized AI fully engine-simulated.
- Treating LAA, a different allocator or an x64 sidecar as a guaranteed FPS upgrade. They address different constraints and must earn their place in separate A/Bs.

## Proving-ground matrix

`Tools/ProvingGround` turns the current source into generated test missions and emits `WASPLAB|v1` telemetry.

| Recipe | Primary question |
|---|---|
| `fast-smoke` | Does current code boot and produce two-HC ownership on the three-town Utes topology? |
| `hc-delegation` | Does real AICOM/town delegation remain distributed, including after each HC bounce? |
| `bus-ramp` | Does the Common_Send change reduce cost without loss, duplication or invalid routing? |
| `scheduler-ramp` | What overhead does server-only v0 add in shadow mode, and does active pacing improve p5/min without reducing equal-total work? |
| `pathfinding-ramp` | How many moving infantry/vehicle groups complete repeated short legs; where does stuck rate rise? |
| `combat-ramp` | Does FPS remain usable under contact, damage, deaths and cleanup rather than idle AI? |
| `density-4/6/8/10/12` | At the same realized 240 infantry, how do 60/40/30/24/20 groups change cost and route outcomes? |
| `current-map-fast` | Does a change still work against the current Chernarus topology and feature wiring? |

Run mod/allocator changes as named variants of the exact same recipe and compare the last run in each RPT. Keep git SHA, mission, `basic.cfg`, process topology, view distance, mods, OS power plan and duration fixed.

The partition screen uses two fixed 120-member anchors. A separate 360-unit confirmation uses three fixed 120-member anchors: `90x4`, `60x6`, `45x8`, `36x10`, `30x12`. Every arm is pure infantry (`vehicleEvery=0`) and server-local (`expectedHcs=0`). `SPAWN -> SETTLE -> GO -> MEASURE -> CLEANUP` prevents ramp duration from contaminating the post-GO FPS sample; realized composition, member-seconds, group-seconds and route starts/completions are mandatory evidence. Use `Tools/ProvingGround/group_partition.py`; do not weaken the generic comparer or treat the 12-member arm as production policy.

Exact scheduler arms:

```text
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-off --scheduler-mode off --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-shadow --scheduler-mode shadow --force
python Tools\ProvingGround\build.py scheduler-ramp --variant sched-active --scheduler-mode active --force
```

Active changes temporal shape by spreading group creation and path continuations, so it measures scheduling plus pacing. Shadow versus off is the dispatcher-overhead comparison. Run at least three repetitions per arm.

The harness reports server FPS and counts non-player AI against registered, valid-looking HC owner IDs; it still does not classify delegation eligibility. Bus-enabled recipes now add validated per-endpoint LabPong ACK rows carrying HC `diag_fps`. `SAMPLE` exposes `hcFresh` and the lowest fresh-endpoint `hcFpsMin`; `RESULT`, monitor and comparer promote the post-warm-up sample count/minimum and final fresh-endpoint count. `minHcFps` defaults to 25, and missing/stale/low-HC-FPS gates apply only when `busRate > 0` and `expectedHcs > 0`. No-bus recipes still require the HC RPTs. The planned production `DELEGHEALTH` census must still close delegation eligibility before the 85% ownership gate is declared automated.

The builder resolves every `expectedHcs=0` arm to `busRate=0` because no legal HC round-trip target exists. Treat `hc0` as the server-only ownership/fallback baseline for the topology and bounce matrix, never as bus-throughput or HC-FPS evidence.

## Expected performance range — hypotheses only

- Server-only scheduler v0: 0–5% median-FPS movement is plausible; the intended signal is roughly 5–15% better p5/min FPS during creation/scan bursts. It may be neutral or negative when engine AI dominates.
- Collective mission-side compile/poll/scan/churn fixes: roughly 5–15% script-bound headroom is a planning range, not a result attributable to one change.
- Correct HC locality is the larger lever because it moves local AI simulation off the dedicated process. The observed 47→30 sag and later recovery are not a guaranteed before/after forecast.
- LAA and allocator work may improve memory headroom, stability or stutter. No FPS range is assigned without a matched rig A/B.

Reject every apparent win if requested workload, AI/groups, arrivals, stuck rate, HC ownership, bus throughput, combat outcomes or cleanup are worse.

## Scale ladder and gates

Do not jump directly from the present cap to 600. Use 50→100→200→300→400, then 450/500 in 10–15% increments. A rung advances only when all apply:

- eligible AI on HCs ≥85% after warm-up; HC load imbalance ≤20%; no two consecutive samples below 25% (requires the planned freshness/eligibility-aware census, not raw current lab `hcPct` alone);
- total groups p95 below 90 and no sustained period at/above 100;
- server median ≥39 and p5/min target ≥30–35; both HCs median ≥40 with no sustained sub-25 period. Bus-enabled lab arms provide a validated minimum/freshness channel and enforce the default 25 floor; use HC RPTs for no-bus recipes and richer per-process history. The 25 floor is not a replacement for the ≥40 scale target;
- agreed client median ≥30 at the fixed test view distance;
- no `grpNull`, invalid owner, missing ACK, duplicate dispatch, mission-load or SQF failure;
- JIP usable within 60 s;
- arrivals, captures, casualties and economy remain within an agreed 5% band of control.

The near-term target is therefore **400 AI below 90 groups with ≥85% eligible HC ownership**, not “600 AI at any cost.” Once that shape is stable, the unit ceiling becomes a measured question instead of a guess.
