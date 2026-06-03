# Supply Mission Scan Narrowing

This page records the `supply-mission-scan-narrowing` lane. It is a contained performance cleanup inside the broader supply-mission authority cleanup work.

> **✅ UPDATE 2026-06-03 (Claude): SHIPPED.** The narrowed scan this page proposes is now live in source. `supplyMissionStarted.sqf:56` reads `nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]` — class-filtered, with a **400 m radius for helicopters** (80 m for trucks) and a **horizontal 2D-distance gate (`<6400` = 80 m) for helis** at `:48-54` so a heli at altitude only completes when actually over the CC. The "current-source-unpatched / still broad" notes below are STALE; treat them as historical. Line numbers also shifted (loop `:45`, scan `:56`).

## Status

**Scan narrowing is SHIPPED** in source Chernarus: `supplyMissionStarted.sqf:56` uses the class-filtered `nearestObjects [..., ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]` with the `_x isKindOf "Base_WarfareBUAVterminal"` guard retained, plus a heli 2D-distance gate at `:48-54`. Verify generated Vanilla Takistan carries the same shape (LoadoutManager). Broader supply authority cleanup stays open.

## What I Read

Source:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/supplyMission/supplyMissionStarted.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Module/supplyMission/supplyMissionStart.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Module/supplyMission/supplyMissionCompleted.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/*/Config_Structures.sqf`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/WASP/baserep/data.sqf`

Wiki/docs:

- [Performance opportunity sweep](Performance-Opportunity-Sweep)
- [Supply mission architecture](Supply-Mission-Architecture)
- [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook)
- [`agent-hardening-backlog.jsonl`](agent-hardening-backlog.jsonl)

## What The Code Does Now

The server supply-mission start handler owns the live return-to-base loop. Every 3 seconds, while the associated supply vehicle is alive, it looks for a nearby command center with:

- Source Chernarus `Server/Module/supplyMission/supplyMissionStarted.sqf:37`: `while { alive _associatedSupplyTruck }`
- Source Chernarus `Server/Module/supplyMission/supplyMissionStarted.sqf:42`: `_x isKindOf "Base_WarfareBUAVterminal"`
- Source Chernarus `Server/Module/supplyMission/supplyMissionStarted.sqf:42-45`: current source still uses broad `nearestObjects [(getPos _associatedSupplyTruck), [], 80]`, then filters with `_x isKindOf "Base_WarfareBUAVterminal"`. Generated Vanilla Takistan has the same shape at `:25-28`.

The planned narrowed scan should ask the engine for the command-center terminal class family first, then keep the SQF `isKindOf` guard. The mission's side configs define command centers as `*_WarfareBUAVterminal` classes, other mission code uses `Base_WarfareBUAVterminal`, and `WASP/baserep/data.sqf` labels `Base_WarfareBUAVterminal` as the Command Center base class.

The nearby-player check at `supplyMissionStarted.sqf:61` also uses `nearestObjects [..., [], 8]`; that scan should remain broad because it is looking for player objects/vehicle occupants near the truck, not command-center terminals.

Do not swap the command-center structure scan to `nearEntities`. BI marks `nearEntities` as OA-compatible and faster for soldiers/vehicles, but its OA syntax is for entities; the current target is a `Base_WarfareBUAVterminal` structure. The OA-safe patch shape is class-filtered `nearestObjects` with the existing `isKindOf` guard. `nearObjects` can find structures too, but using it here would change sort/order behavior and needs its own runtime proof.

## Patch Shape

Expected source/Vanilla shape:

```sqf
} forEach (nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], (if (_byHeli) then {400} else {80})]); //--- SHIPPED: heli 400 m / truck 80 m, plus a heli 2D gate at :48-54
```

Important parity note: generated file changes may include unrelated current source parity such as `Killed` interdiction handler differences. Treat those as generation parity, not as a separate scan-narrowing design change. The stacked-handler risk remains documented in [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook).

## Why It Matters

This removes an avoidable broad object scan from every active supply mission without changing the completion trigger, cadence or reward path. It is small, source-backed and low-risk compared with the remaining supply-mission authority work.

Status: **SHIPPED in source (class-filtered + heli-aware); Arma smoke and broader supply authority cleanup still open**.

## Validation

Source-only after patch:

- After patching, source Chernarus has one narrowed `["Base_WarfareBUAVterminal"]` 80-meter command-center scan before the `_x isKindOf "Base_WarfareBUAVterminal"` guard.
- After patching, Vanilla Takistan has one narrowed `["Base_WarfareBUAVterminal"]` 80-meter command-center scan before the `_x isKindOf "Base_WarfareBUAVterminal"` guard.
- Both mission variants still have the 8-meter broad nearby-player scan.
- `git diff --check` passes.

Hosted/dedicated/JIP smoke still needed:

- Truck delivery completes when the supply vehicle reaches a west/east command center.
- PR #1 light/heavy supply helicopter delivery completes at a command center.
- Delivery does not complete near unrelated objects inside 80 meters.
- Destroying a loaded supply vehicle still pays interdiction once; this is existing PR #1 handler behavior and should be smoke-tested when the broader supply cleanup changes.
- JIP cooldown behavior remains pull-based and unchanged.

## Handoff

Codex:

- Keep this page linked from the performance sweep, supply mission pages, dashboard/status files and backlog.
- Do not mark `supply-mission-authority-cleanup` complete; only the command-center scan sub-step is covered in this lane.

Claude:

- Contradiction check closed for docs: BI documents `nearestObjects` as OA-era, sorted by distance and matching classes through `isKindOf`; BI documents `nearEntities` as faster for soldier/vehicle entity detection but not a structure-scan substitute. Runtime smoke still needs to prove the narrowed class filter catches every Wasp command-center variant.
- Keep looking for any command-center subclass that does not inherit from `Base_WarfareBUAVterminal`.

Future code owner:

- Smoke it in Arma 2 OA on dedicated or hosted test.
- Continue supply cleanup with server-owned loaded/tracking state, `Killed` handler idempotency, cooldown casing standardization and server-side cargo validation.

## Continue Reading

Previous: [Supply mission authority cleanup](Supply-Mission-Authority-Cleanup-Playbook) | Next: [Performance opportunity sweep](Performance-Opportunity-Sweep)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)

## 2026-06-03 verification note

- Source confirms scan narrowing logic is present in mission start flow and currently marked as shipped from recent history.
- Relevant upstream commits: 97dfff26 (PR #10), 8164cc33 (PR #11), 86ec28d6 (PR #12).
- Completion side is still trust-sensitive until supply amount/state is fully server-authored.
