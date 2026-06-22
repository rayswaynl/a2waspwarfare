# Supply Mission Scan Narrowing

This page records the branch-scoped state for the `supply-mission-scan-narrowing` lane. It is a contained performance cleanup candidate inside the broader supply-mission authority cleanup work.

## Status

Canonical branch/root matrix: [Supply mission architecture](Supply-Mission-Architecture#current-branch-matrix) — use it for branch/root truth, not this leaf page. Current source evidence is branch-split: docs/source `15563691` carries the truck-only typed 80 m command-center scan at `supplyMissionStarted.sqf:25,28,44`; current stable `origin/master@0139a346` carries the heli-aware typed scan at `:7,55,61,83`; direct current Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f` still broad-enumerate command-center candidates at `:25,28,44`. Historical release commits `a96fdda2` (`:7,53,59,81`) and `7ff18c49` (`:7,52,58,80`) remain local release-line evidence because current origin exposes no `release/*` head. Hosted/dedicated Arma 2 OA smoke is still pending.

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

The server supply-mission start handler owns the live return-to-base loop. The command-center search is now different by branch:

- Docs/source `origin/docs/developer-wiki-index@15563691`: `_x isKindOf "Base_WarfareBUAVterminal"` at `supplyMissionStarted.sqf:25`, typed `nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 80]` at `:28`, and the intentionally broad nearby-player scan at `:44`.
- Current stable `origin/master@0139a346`: `_byHeli` comes from `SupplyByHeli` at `:7`; the terminal guard remains at `:55`; the typed command-center scan uses `["Base_WarfareBUAVterminal"]` with 400 m for heli runs and 80 m for trucks at `:61`; the nearby-player scan remains broad at `:83`.
- Direct current Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f`: both maintained roots still post-filter `Base_WarfareBUAVterminal` at `:25`, broad-enumerate `nearestObjects [..., [], 80]` at `:28`, and keep the broad nearby-player scan at `:44`.

The intent is already one class family: command-center terminal objects. The mission's side configs define command centers as `*_WarfareBUAVterminal` classes in `Common/Config/Core_Structures/Structures_*.sqf:10`, other mission code uses `Base_WarfareBUAVterminal`, and `WASP/baserep/data.sqf:6` labels `Base_WarfareBUAVterminal` as the Command Center base class.

The nearby-player check remains intentionally broad because it is looking for player objects/vehicle occupants near the truck or heli delivery vehicle, not command-center terminals.

Guardrail: if this performance cleanup is ported to current source, use a class-filtered `nearestObjects`/`nearObjects` scan plus the `isKindOf "Base_WarfareBUAVterminal"` check. Do not replace it with `nearEntities`; this target is a command-center structure, while this mission uses `nearEntities` for entity/logics scans such as camps, towns, vehicles and units.

Scope note: this patch applies to the live supply mission return-to-base handler in `supplyMissionStarted.sqf`. (If a compiled dead twin `supplyMissionActive.sqf` ever existed, it is not present on master; verify its existence on any working branch before treating it as a live or legacy handler, and retire or annotate it if found during the broader cleanup.)

## Patch Shape

Current stable `origin/master@0139a346` and historical release typed scan shape:

```sqf
} forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]);
```

Docs/source `15563691` carries the truck-only 80 m typed scan in both maintained roots and is source-unchanged from the older `4bd37b98` / `8a6695b8` line anchors for the checked supply start file. Current stable already carries the heli-aware typed scan; do not reopen it there. Direct current Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f` are the old-shape targets that still broad-enumerate command-center candidates. Root discovery for any future propagation run is documented as branch-sensitive in [Tools/build workflow](Tools-And-Build-Workflow): docs/current source and current stable `origin/master@0139a346` accept either an `a2waspwarfare` ancestor or repo markers, while direct current Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f` still need the ancestor. `Modded_Missions/*` are not claimed by this propagation lane.

## Why It Matters

This remains a small, source-backed performance cleanup for old-shape targets, and a smoke/readiness item for current stable. On current stable the static scan narrowing is source-present; the remaining work is Arma truck/heli command-center smoke plus the broader authority cleanup.

Status: **docs/source and current stable carry typed command-center scans in both maintained roots; current Miksuu/perf still broad-enumerate then post-filter; current origin has no release head, so release evidence is historical; hosted/dedicated smoke pending**.

## Validation

Source/Vanilla checks completed:

- Docs/source `origin/docs/developer-wiki-index@15563691` Chernarus and maintained Vanilla both have the typed 80-meter command-center enumeration at `supplyMissionStarted.sqf:28`; targeted `4bd37b98..15563691` and `8a6695b8..15563691` diffs for the checked supply start files are empty.
- Current stable `origin/master@0139a346` Chernarus and maintained Vanilla both have the heli-aware typed command-center enumeration at `supplyMissionStarted.sqf:61`, with `_byHeli` at `:7`, the terminal guard at `:55` and the broad nearby-player scan at `:83`.
- Direct current Miksuu `b8389e74` and `origin/perf/quick-wins@0076040f` both still have broad 80-meter command-center enumeration at `supplyMissionStarted.sqf:28`, with a `Base_WarfareBUAVterminal` post-filter at `:25`.
- Historical release commits `a96fdda2` and `7ff18c49` have the narrowed PR #1-compatible typed scan in both maintained roots at `:53,59` and `:52,58` respectively; current origin exposes no live `release/*` head on 2026-06-22.
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
- Do not mark `supply-mission-authority-cleanup` complete; the typed command-center scan is only the scan sub-step. Current stable carries that static shape, while Miksuu/perf remain old-shape and all branches still need runtime smoke plus authority hardening.

Claude:

- Contradiction check: verify Arma 2 OA runtime class filtering for `nearestObjects` accepts `Base_WarfareBUAVterminal` exactly as source usage suggests.
- Keep looking for any command-center subclass that does not inherit from `Base_WarfareBUAVterminal`.

Future code owner:

- If porting the typed scan into old-shape targets such as current Miksuu or perf, smoke it in Arma 2 OA on dedicated or hosted test. Current stable still needs truck/heli completion smoke before release-complete wording.
- Continue supply cleanup with server-owned loaded/tracking state, `Killed` handler idempotency, cooldown casing standardization and server-side cargo validation.

## Continue Reading

Previous: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
