# Supply Mission Scan Narrowing

This page records the branch-scoped state for the `supply-mission-scan-narrowing` lane. It is a contained performance cleanup candidate inside the broader supply-mission authority cleanup work.

## Status

Canonical branch/root matrix: [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) — use it for branch/root truth, not this leaf page. In short: the typed 80 m command-center scan is present on docs/source (`f3e157f2`) and current release (`7ff18c49`, `:52,58`) in both maintained roots; local `HEAD` / stable `origin/master` / Miksuu (`89ae9dad`) and `perf/quick-wins` (`0076040f`) already use a typed `nearestObjects(["Base_WarfareBUAVterminal"])` scan at `supplyMissionStarted.sqf:61`, with a conditional radius of 80 m for trucks and 400 m for helicopters; an `isKindOf "Base_WarfareBUAVterminal"` guard remains at `:55` as a secondary check inside the `forEach`, but no broad-enumeration post-filter path exists in this branch. Hosted/dedicated Arma 2 OA smoke is still pending.

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

The server supply-mission start handler owns the live return-to-base loop. Every 1 second, while the associated supply vehicle is alive, local current source/stable/upstream/perf still look for a nearby command center with broad object enumeration plus a terminal class post-filter:

- Current source `Server/Module/supplyMission/supplyMissionStarted.sqf:20`: `while { alive _associatedSupplyTruck }`
- Current source `Server/Module/supplyMission/supplyMissionStarted.sqf:25`: `_x isKindOf "Base_WarfareBUAVterminal"`
- Current source `Server/Module/supplyMission/supplyMissionStarted.sqf:28`: `nearestObjects [(getPos _associatedSupplyTruck), [], 80]`

The intent is already one class family: command-center terminal objects. The mission's side configs define command centers as `*_WarfareBUAVterminal` classes in `Common/Config/Core_Structures/Structures_*.sqf:10`, other mission code uses `Base_WarfareBUAVterminal`, and `WASP/baserep/data.sqf:6` labels `Base_WarfareBUAVterminal` as the Command Center base class.

The nearby-player check at current-source `supplyMissionStarted.sqf:44` still uses `nearestObjects [..., [], 8]`; that scan is intentionally left broad because it is looking for player objects/vehicle occupants near the truck, not command-center terminals.

Guardrail: if this performance cleanup is ported to current source, use a class-filtered `nearestObjects`/`nearObjects` scan plus the `isKindOf "Base_WarfareBUAVterminal"` check. Do not replace it with `nearEntities`; this target is a command-center structure, while this mission uses `nearEntities` for entity/logics scans such as camps, towns, vehicles and units.

Scope note: this patch applies to the live supply mission return-to-base handler in `supplyMissionStarted.sqf`. (If a compiled dead twin `supplyMissionActive.sqf` ever existed, it is not present on master; verify its existence on any working branch before treating it as a live or legacy handler, and retire or annotate it if found during the broader cleanup.)

## Patch Shape

Release `7ff18c49` typed scan shape:

```sqf
} forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]);
```

Docs/source `f3e157f2` carries the 80 m typed scan in both maintained roots. Local `HEAD` / `origin/master` and the checked Miksuu/perf refs do not currently carry that typed scan; they still use broad enumeration plus post-filter at `supplyMissionStarted.sqf:25,28`. Root discovery for any future propagation run is documented as branch-sensitive in [Tools/build workflow](Tools-And-Build-Workflow): current source/stable/Miksuu/perf need an `a2waspwarfare` ancestor, while release `7ff18c49` has marker-root support. `Modded_Missions/*` are not claimed by this propagation lane.

## Why It Matters

This is a small, source-backed performance cleanup candidate compared with the remaining supply-mission authority work: porting the release typed scan would remove an avoidable broad object enumeration from the live active supply mission handler without changing the completion trigger, cadence or reward path.

Status: **docs/source and current release carry typed command-center scans in both maintained roots; local current source/stable/Miksuu/perf still broad-enumerate then post-filter; hosted/dedicated smoke pending**.

## Validation

Source/Vanilla checks completed:

- Docs/source `origin/docs/developer-wiki-index` `f3e157f2` Chernarus and maintained Vanilla both have the typed 80-meter command-center enumeration at `supplyMissionStarted.sqf:28`.
- Local current source Chernarus and maintained Vanilla, stable `origin/master` `89ae9dad`, Miksuu `89ae9dad` and `origin/perf/quick-wins` `0076040f` all still have broad 80-meter command-center enumeration at `supplyMissionStarted.sqf:28`, with a `Base_WarfareBUAVterminal` post-filter at `:25`.
- Current release `origin/release/2026-06-feature-bundle` head `7ff18c49` has the narrowed PR #1-compatible typed scan in both maintained roots at `:52,58`. The `7195b331..7ff18c49` delta does not touch the supply mission scan files.
- Current source Chernarus still has the 8-meter broad nearby-player scan.
- `git diff --check` passed.
- `Tools/LoadoutManager` generation/copy can skip packaging with `A2WASP_SKIP_ZIP=1`; see [Tools/build workflow](Tools-And-Build-Workflow) for the current branch-specific root-discovery rule before running it from a generated Codex checkout.

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
- Do not mark `supply-mission-authority-cleanup` complete; the typed command-center scan is present on docs/source and release `7ff18c49`, not local current source/stable/Miksuu/perf.

Claude:

- Contradiction check: verify Arma 2 OA runtime class filtering for `nearestObjects` accepts `Base_WarfareBUAVterminal` exactly as source usage suggests.
- Keep looking for any command-center subclass that does not inherit from `Base_WarfareBUAVterminal`.

Future code owner:

- If porting the typed scan into local current source or stable master, smoke it in Arma 2 OA on dedicated or hosted test; docs/source and release `7ff18c49` still need the same truck/heli completion smoke before branch claims are release-complete.
- Continue supply cleanup with server-owned loaded/tracking state, `Killed` handler idempotency, cooldown casing standardization and server-side cargo validation.

## Continue Reading

Previous: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
