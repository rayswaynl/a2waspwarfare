# Supply Mission Scan Narrowing

This page records the branch-local source patch for the `supply-mission-scan-narrowing` lane. It is a contained performance cleanup inside the broader supply-mission authority cleanup work.

## Status

Canonical branch/root matrix: [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix).

Short status: docs/source Chernarus and maintained Vanilla narrow the truck command-center scan at `supplyMissionStarted.sqf:25-28`; stable `origin/master`, `miksuu/master` and `origin/perf/quick-wins` still use `nearestObjects [..., [], 80]`; current release head `7195b331` carries a PR #1-compatible heli-aware narrowed scan in both maintained release roots at `:52,58`. Hosted/dedicated Arma 2 OA smoke is still pending.

## What I Read

Source:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/supplyMission/supplyMissionStarted.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/supplyMission/supplyMissionStart.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/supplyMission/supplyMissionCompleted.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Structures/Structures_*.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/baserep/data.sqf`

Wiki/docs:

- [Performance opportunity sweep](Performance-Opportunity-Sweep)
- [Supply mission architecture](Supply-Mission-Architecture)
- [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## What The Code Did

The server supply-mission start handler owns the live return-to-base loop. Every 3 seconds, while the associated supply vehicle is alive, it looked for a nearby command center with:

- Branch-local `Server/Module/supplyMission/supplyMissionStarted.sqf:20`: `while { alive _associatedSupplyTruck }`
- Branch-local `Server/Module/supplyMission/supplyMissionStarted.sqf:25`: `_x isKindOf "Base_WarfareBUAVterminal"`
- Branch-local `Server/Module/supplyMission/supplyMissionStarted.sqf:28`: `nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 80]`

On `origin/master`, each active supply mission scanned all nearby object classes inside 80 meters, then filtered the result in SQF at `supplyMissionStarted.sqf:24-28`. The intent was already one class family: command-center terminal objects. The mission's side configs define command centers as `*_WarfareBUAVterminal` classes in `Common/Config/Core_Structures/Structures_*.sqf:10`, other mission code uses `Base_WarfareBUAVterminal`, and `WASP/baserep/data.sqf:6` labels `Base_WarfareBUAVterminal` as the Command Center base class.

The nearby-player check at branch-local `supplyMissionStarted.sqf:44` still uses `nearestObjects [..., [], 8]`; that scan is intentionally left broad because it is looking for player objects/vehicle occupants near the truck, not command-center terminals.

Guardrail: keep the command-center completion scan as a class-filtered `nearestObjects`/`nearObjects` scan plus the `isKindOf "Base_WarfareBUAVterminal"` check (`supplyMissionStarted.sqf:25,28`). Do not replace it with `nearEntities`; this target is a command-center structure, while this mission uses `nearEntities` for entity/logics scans such as camps, towns, vehicles and units.

Scope note: this patch applies to the live supply mission return-to-base handler in `supplyMissionStarted.sqf`. The compiled dead twin `supplyMissionActive.sqf` still carries the older broad-scan logic; retire or annotate that path during the broader cleanup instead of treating it as a second live implementation.

## Patch Shape

Patched branch-local source Chernarus:

```sqf
} forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 80]);
```

Maintained Vanilla Takistan was propagated by `Tools/LoadoutManager` on 2026-06-02 after the root-discovery and `A2WASP_SKIP_ZIP` tooling patch in this docs/source branch. `Modded_Missions/*` are not claimed by this propagation lane.

## Why It Matters

This removes an avoidable broad object scan from the live active supply mission handler without changing the completion trigger, cadence or reward path. It is small, source-backed and low-risk compared with the remaining supply-mission authority work.

Status: **docs/source and maintained Vanilla propagated for the truck scan; stable/upstream/perf still broad; current release `7195b331` narrowed in both maintained roots; hosted/dedicated smoke pending**.

## Validation

Source/Vanilla checks completed:

- This docs branch's source Chernarus has zero 80-meter broad command-center scans and one narrowed `["Base_WarfareBUAVterminal"]` 80-meter scan.
- Maintained Vanilla Takistan contains the same narrowed 80-meter command-center scan after the 2026-06-02 propagation run.
- `origin/master`, `miksuu/master` and `origin/perf/quick-wins` still have the broad command-center scan at `supplyMissionStarted.sqf:24-28`; current release `origin/release/2026-06-feature-bundle` head `7195b331` has the narrowed PR #1-compatible scan in both maintained roots at `:52,58`.
- Source Chernarus still has the 8-meter broad nearby-player scan.
- `git diff --check` passed.
- `Tools/LoadoutManager` generation/copy now works from this checkout by detecting repo-root markers; set `A2WASP_SKIP_ZIP=1` for propagation-only runs.

Hosted/dedicated/JIP smoke still needed:

- Truck delivery completes when the supply vehicle reaches a west/east command center.
- PR #1 light/heavy supply helicopter delivery completes at a command center.
- Delivery does not complete near unrelated objects inside 80 meters.
- Dead twin cleanup is not part of this smoke: confirm `supplyMissionActive.sqf` is either retired or explicitly documented before anyone edits it as a live handler.
- Destroying a loaded supply vehicle still pays interdiction once; this is existing PR #1 handler behavior and should be smoke-tested when the broader supply cleanup is patched.
- JIP cooldown behavior remains pull-based and unchanged.

## Handoff

Codex:

- Keep this page linked from the performance sweep, supply mission pages, dashboard/status files, backlog and [propagated fix smoke pack](Testing-Debugging-And-Release-Workflow#propagated-fix-smoke-pack).
- Do not mark `supply-mission-authority-cleanup` complete; only the command-center scan sub-step is patched in branch-local/release source, not in `origin/master`.

Claude:

- Contradiction check: verify Arma 2 OA runtime class filtering for `nearestObjects` accepts `Base_WarfareBUAVterminal` exactly as source usage suggests.
- Keep looking for any command-center subclass that does not inherit from `Base_WarfareBUAVterminal`.

Future code owner:

- Smoke the patched scan in Arma 2 OA on dedicated or hosted test.
- Continue supply cleanup with server-owned loaded/tracking state, `Killed` handler idempotency, cooldown casing standardization and server-side cargo validation.

## Continue Reading

Previous: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
