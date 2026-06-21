# Town-Capture Garrison And Airfield Rebuild

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

When a town flips owner, `server_town.sqf` does far more than recolor a marker. Inside the single `if(_captured)` block (`Server/FSM/server_town.sqf:203`, after `TownCaptured` is dispatched) it tears down the old garrison, re-seeds the new owner's defenses on three different paths, spawns a one-shot mop-up squad, and — at airfield towns — rebuilds the entire service/hangar/counter-battery stack for the new side. [Towns, Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas) caps its `server_town.sqf` coverage at the capture-detection / SV loop (`:12-276`) and stops its capture-branch summary at "removes old town defense units and creates new defenses if enabled"; this page documents the post-capture follow-through (`:251-575`) that the atlas omits.

All of these side-effects run after `_newSID` (numeric) and `_newSide` (the SIDE value) are resolved at `server_town.sqf:181-182`, with `_side` holding the *old* owner. Because `WFBE_DEFENDER = resistance` (`Common/Init/Init_Common.sqf:296`), the test `_newSide == WFBE_DEFENDER` (`server_town.sqf:277`) reads as "resistance just captured this town".

## Capture Follow-Through Map

| Stage | Lines | What fires |
|---|---|---|
| FM-5 active-flag clear | `server_town.sqf:251-258` | Clears `wfbe_active` / `wfbe_active_air` / `wfbe_episode_spawned` so the new owner can re-garrison immediately |
| Defender linger | `server_town.sqf:260-273` | Old gunners keep fighting `WFBE_C_TOWNS_DEFENDER_LINGER` s, then a fire-time-guarded cleanup deletes them |
| Resistance garrison (new owner = GUER) | `server_town.sqf:277-293` | Delayed `ManageTownDefenses` + optional `OperateTownDefensesUnits` spawn |
| Anti-turtle GUER-static deletion | `server_town.sqf:295-303` | WEST/EAST captor strips inherited GUER emplacements |
| Lazy garrison + mop-up squad (new owner = WEST/EAST) | `server_town.sqf:305-398` | T+60 s single squad, auto-despawn on 2 clear scans |
| Airfield rebuild | `server_town.sqf:401-572` | Garrison despawn, ServicePoint, hangar, CBR for the new side |

## FM-5: Clear The Old Garrison's Active Flags

Immediately after the `TownCaptured` broadcast and the `SetCampsToSide` spawn, the branch resets the town's activation latches (`server_town.sqf:253-256`):

- `wfbe_active` -> `false`
- `wfbe_active_air` -> `false`
- `wfbe_episode_spawned` -> `false`

The header comment (`server_town.sqf:251-252`) states the intent: without this, the new owner would face an up-to-`WFBE_C_TOWNS_UNITS_INACTIVE` undefended window on a rapid recapture, because the activation FSM in `server_town_ai.sqf` would still think the town is active and skip re-spawning. Clearing `wfbe_episode_spawned` also releases the episode latch so the new owner's first activation episode is not blocked.

## Task 32: Defender Linger Window

The old garrison is **not** deleted instantly. A detached `spawn` thread (`server_town.sqf:262-273`) holds the previous-owner gunners in place for a configurable linger window so a recapture feels like a fight rather than an instant vacuum.

| Element | Detail | Line |
|---|---|---|
| Linger duration | `sleep (WFBE_C_TOWNS_DEFENDER_LINGER)`, default 180 s | `server_town.sqf:267` |
| Fire-time ownership guard | Cleanup only if `_loc getVariable "sideID" == _newSIDAtCapture` (the captor still holds it) | `server_town.sqf:269` |
| Delete lingering units | `deleteVehicle` every alive unit of `WFBE_<oldSide>_DefenseTeam` | `server_town.sqf:270` |
| De-man emplacements | `[_loc, _oldSide, "remove"] Call WFBE_SE_FNC_OperateTownDefensesUnits` | `server_town.sqf:271` |

The guard at `:269` is the key safety property: the `_newSIDAtCapture` snapshot is captured *at fire time*, so if the town flips back to the old owner during the linger window, the cleanup aborts and the old defenders are kept. The `"remove"` action hands off to the manning state machine documented in [Static-Defense Manning Reference](Static-Defense-Manning-Reference) (`Server_OperateTownDefensesUnits.sqf`), which de-mans and reaps the pooled gunner groups.

## The Three Garrison Re-Seed Paths

After the linger thread is launched, the branch forks on who captured the town (`server_town.sqf:277`). The FINAL spec (2026-06-12) splits resistance recapture from owned-town occupation.

### Path A — Resistance recaptured (new owner = GUER)

Gated on `_town_defender_enabled` (`WFBE_C_TOWNS_DEFENDER > 0`, resolved at `server_town.sqf:24`, default 2). A delayed `spawn` thread (`server_town.sqf:280-292`):

1. sleeps `WFBE_C_TOWNS_DEFENSE_SPAWN_DELAY` (default 300 s, `server_town.sqf:286`);
2. aborts if the town flipped away from `_newSIDAtCapture` during the delay (`server_town.sqf:287`);
3. calls `WFBE_SE_FNC_ManageTownDefenses` to (re)spawn the GUER emplacements (`server_town.sqf:288`);
4. if `WFBE_C_TOWNS_GUNNERS_ON_CAPTURE` (default `true`, `server_town.sqf:289`), mans them immediately via `OperateTownDefensesUnits "spawn"` (`server_town.sqf:290`).

This is the **only** capture path that calls `ManageTownDefenses` — which is why [Static-Defense Manning Reference](Static-Defense-Manning-Reference) notes the (re)spawn driver is "invoked on the GUER recapture path". The WEST/EAST occupation path (below) never calls it, so it never inherits static emplacements.

### Path B — Anti-turtle: WEST/EAST stripping inherited GUER statics

When a WEST or EAST side captures a town whose *old* owner was GUER (`_sideID == WFBE_C_GUER_ID`, `server_town.sqf:298`), the branch deletes every GUER-era emplacement (`server_town.sqf:299-303`):

```
{ private "_def"; _def = _x getVariable "wfbe_defense";
  if (!isNil "_def" && {!isNull _def}) then {deleteVehicle _def};
  _x setVariable ["wfbe_defense", nil];
} forEach (_location getVariable ["wfbe_town_defenses", []]);
```

The B36 comment (`server_town.sqf:295-297`) explains: the captor must not be able to turtle behind inherited GUER emplacements. GUER keeps its statics because a GUER recapture re-spawns them via Path A's `ManageTownDefenses`, whereas the WEST/EAST occupation path deliberately never calls that driver.

### Path C — Owned-town lazy garrison + mop-up squad (new owner = WEST/EAST)

Gated on `_town_occupation_enabled` (`WFBE_C_TOWNS_OCCUPATION > 0`, resolved at `server_town.sqf:25`, default 2). A WEST/EAST captor does **not** get a full garrison on capture; it gets one small squad whose only job is mop-up. Full defenses spawn later only when an enemy enters the radius (handled in `server_town_ai.sqf`, per the FINAL-spec comment at `server_town.sqf:308`).

The mop-up `spawn` thread (`server_town.sqf:310-397`):

| Step | Detail | Line |
|---|---|---|
| T+60 s arm | `sleep 60`; abort with a log if the town flipped before the timer | `server_town.sqf:319-322` |
| Template pick | `Squad_<barracksLevel>`, where level = `(GetSideUpgrades) select WFBE_UP_BARRACKS` | `server_town.sqf:325-326` |
| Spawn position | `GetRandomPosition` (50-200 m from centre) then `GetEmptyPosition` | `server_town.sqf:328-330` |
| Group + team | `[_side,"town-ai"] Call WFBE_CO_FNC_CreateGroup`, then `WFBE_CO_FNC_CreateTeam` with `_probability` 90 | `server_town.sqf:332-336` |
| Create guard | Abort + log if `isNull _squadGrp` or zero units/vehicles created | `server_town.sqf:338-340` |
| Defender tagging | Every unit/vehicle gets `WFBE_IsTownDefenderAI = true` (broadcast) so it does not re-trigger activation scans | `server_town.sqf:343` |
| No fleeing | `_squadGrp allowFleeing 0` | `server_town.sqf:344` |
| Location refs | `wfbe_mopup_group` / `wfbe_mopup_units` stored on the town for deactivation hard-despawn | `server_town.sqf:347-348` |

The `WFBE_CO_FNC_CreateTeam` call shape `[_tplName, _spawnPos, _side, true, _squadTeam, true, 90]` maps to `[_list, _position, _side, _lockVehicles, _team, _global, _probability]` — see [Spawn Primitive Function Reference](Spawn-Primitive-Function-Reference) for the full signature.

**Auto-despawn scan** (`server_town.sqf:352-387`). Every 30 s the squad scans for resistance presence and stands down when clear:

| Condition | Effect | Line |
|---|---|---|
| Scan range | `600 * WFBE_C_TOWNS_DETECTION_RANGE_COEF` (town activation detection range) | `server_town.sqf:356` |
| Town deactivated (and `_clearCount > 0`) | `_scanActive = false` (hard stand-down) | `server_town.sqf:362-364` |
| Town flipped away | `_scanActive = false` | `server_town.sqf:365` |
| Detection | `nearEntities [["Man","Car",...],_townRange] unitsBelowHeight 20`; count resistance units **and** resistance crew of mounted vehicles | `server_town.sqf:368-378` |
| Clear-count latch | `_clearCount + 1` if no GUER; reset to 0 if any GUER present | `server_town.sqf:378-382` |
| Stand-down threshold | `_clearCount >= 2` (two consecutive clear scans) -> `_scanActive = false` | `server_town.sqf:384` |
| Despawn | `deleteVehicle` units + vehicles, `deleteGroup`, clear `wfbe_mopup_*` refs, log | `server_town.sqf:388-396` |

Counting resistance *crew* of vehicles (`server_town.sqf:374-376`) is deliberate — a mounted GUER patrol sitting in the town would otherwise read as zero and let the squad stand down prematurely.

## Airfield Rebuild (Task 12 / Task 13)

If the captured location is an airfield (`WFBE_C_AIRFIELDS > 0` and `wfbe_is_airfield`, `server_town.sqf:403`, AIRFIELDS default 1), the branch rebuilds the airfield's service infrastructure for the new owner. All work resolves the nearest `LocationLogicAirport` within 1500 m of the depot logic (`server_town.sqf:440`) and anchors new objects to it.

### Item 1 — Garrison despawn broadcast

The airfield garrison (units tagged `wfbe_airfield_garrison = true` by `server_town_ai.sqf`) is torn down (`server_town.sqf:407-430`):

- Local survivors in `wfbe_airfield_garrison_units` are `deleteVehicle`'d directly (`server_town.sqf:412-424`), then the list is cleared.
- Because garrison units spawned on headless clients are **not local** to the server, a `cleanup-airfield-garrison` HandleSpecial is broadcast to all machines (`server_town.sqf:427-429`) so each deletes its own local units — mirroring the deactivation-cleanup pattern.

### Item 2 — Side-matched ServicePoint

| Element | Detail | Line |
|---|---|---|
| Side classname switch | west/east/default each pick a Chernarus (`IS_chernarus_map_dependent`) vs Takistan `_EP1` ServicePoint class | `server_town.sqf:433-438` |
| Old-SP cleanup | Delete `wfbe_airfield_sp` and prune it from `wfbe_structures` on `WFBE_L_BLU` / `WFBE_L_OPF` / `WFBE_L_GUE` | `server_town.sqf:443-454` |
| Placement | New SP 80 m north of the airport logic (or the location if no logic) | `server_town.sqf:457-462` |
| Repair flag | `WFBE_RepairTruckServicePoint = true` (broadcast) | `server_town.sqf:464` |
| `wfbe_side` fix (A1) | Set `wfbe_side = _newSide` so `Server_BuildingDamaged/BuildingKilled` don't read nil side and throw on hit | `server_town.sqf:465-467` |
| Register | Add to the new side's `GetSideLogic` `wfbe_structures` (broadcast) | `server_town.sqf:470-471` |
| Client marker | `setVehicleInit` -> `Init_BaseStructure.sqf` + `processInitCommands` | `server_town.sqf:474-475` |
| Destruction EHs | `hit` -> `BuildingDamaged`, `killed` -> `BuildingKilled` (mirrors `Construction_SmallSite.sqf`) | `server_town.sqf:478-480` |
| Persist | Store `wfbe_airfield_sp` for next-capture cleanup | `server_town.sqf:482` |

### Item 3 — Exclusive hangar respawn

The old owner's hangar is deleted and a fresh one is spawned on the airport logic (`server_town.sqf:485-498`):

- Old hangar: `deleteVehicle wfbe_airfield_hangar_obj`; clear `wfbe_hangar` on the airport logic (`server_town.sqf:485-489`).
- New hangar: `WFBE_C_HANGAR createVehicle (getPos _airfieldLogic)`, rotated by `WFBE_C_HANGAR_RDIR`, flagged `wfbe_is_airfield_hangar = true` (`server_town.sqf:492-496`).
- The airport logic is updated with `wfbe_hangar` and `wfbe_airfield_side = _newSide` (C-1 GUER ownership gate, `server_town.sqf:497`), and `wfbe_airfield_hangar_obj` is stored on the location (`server_town.sqf:498`).

The `wfbe_is_airfield_hangar` flag and `wfbe_airfield_side` are what the captured-airfield buy-menu roster swap keys off (the exclusive aircraft roster lives in `GUI_Menu_BuyUnits.sqf`); `Client_GetClosestAirport.sqf` also requires an alive `wfbe_hangar` and a matching `wfbe_airfield_side` for resistance.

### Item 4 — Counter-Battery Radar lifecycle

Gated on `WFBE_C_STRUCTURES_COUNTERBATTERY > 0` (`server_town.sqf:505`). On recapture the old radar is removed and a new one is spawned for the new owner (`server_town.sqf:505-570`):

| Element | Detail | Line |
|---|---|---|
| Old-radar cleanup | Remove from both `WFBE_CBR_WEST`/`WFBE_CBR_EAST` registries, delete its `wfbe_dressing` props, then delete the radar | `server_town.sqf:506-517` |
| WEST/EAST only | New radar spawned only if `_newSide == west || east` | `server_town.sqf:521` |
| Class + position | `Land_Antenna` 60 m east of the airport logic (off the runway centerline) | `server_town.sqf:521-538` |
| Fixed 2000 m radius | `wfbe_cbr_radius = 2000` (broadcast) so clients draw the fixed circle, not an upgrade tier (AF2) | `server_town.sqf:537` |
| Invincible | `addEventHandler ["HandleDamage", {0}]` — the codebase's only invincibility idiom | `server_town.sqf:539` |
| Side dressing | `WFBE_NEURODEF_CBRADAR_<WEST/EAST>` via `WFBE_SE_FNC_SpawnStructureDressing` | `server_town.sqf:543` |
| Client circle | `setVehicleInit` -> `Init_BaseStructure.sqf` with a local `_cbrSID` (0=west,1=east), **not** the town `_newSID` | `server_town.sqf:546-552` |
| Register | Append to `WFBE_CBR_WEST`/`WFBE_CBR_EAST` and store `wfbe_airfield_cbr` on the location | `server_town.sqf:555-560` |
| Resistance | GUER capture: no CBR registry, radar skipped; `wfbe_airfield_cbr` set to `objNull` | `server_town.sqf:564-567` |

Because the radar is indestructible (`HandleDamage {0}`), the Killed EH never fires, so the lazy registry prune never runs — which is why the explicit de-register at `:509-511` on recapture is required to avoid dead-object accumulation. The CBR detection/firing side of this structure (radius tiers, per-gun rate limiting, AI threat response) is owned by [Counter-Battery Radar System](Counter-Battery-Radar-System); this section covers only the capture-time spawn/teardown lifecycle, which that page also references at `server_town.sqf:508-560`.

## Ownership-Guard Pattern

Every detached thread launched from this branch (linger, Path A delayed defenses, the mop-up squad) snapshots `_newSIDAtCapture` at fire time and re-checks `_loc getVariable "sideID"` against it before acting:

- Linger cleanup runs only if the captor still holds the town (`server_town.sqf:269`).
- Path A defenses abort if the town flipped during the spawn delay (`server_town.sqf:287`).
- The mop-up squad aborts at T+60 if the town flipped (`server_town.sqf:320`) and stands down mid-scan if it flips (`server_town.sqf:365`).

This is the consistent re-flip-abort discipline that keeps a fast double-capture from leaving stale defenders or duplicate garrisons behind.

## Continue Reading

- [Towns, Camps And Capture Atlas](Towns-Camps-And-Capture-Atlas) — the capture-detection / SV loop this page picks up from
- [Static-Defense Manning Reference](Static-Defense-Manning-Reference) — `OperateTownDefensesUnits` / `ManageTownDefenses` internals referenced here
- [Counter-Battery Radar System](Counter-Battery-Radar-System) — CBR detection/firing system whose airfield variant this page spawns
- [Town Runtime Tuning Constants](Town-Runtime-Tuning-Constants) — the `WFBE_C_TOWNS_*` knobs gating each step
- [Server Init Deadspawn And Airfield Probe](Server-Init-Deadspawn-And-Airfield-Probe) — the boot-time airfield probe (distinct from this capture-time rebuild)
