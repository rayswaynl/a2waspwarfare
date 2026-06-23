# Available-Actions Client Gate FSM (proximity range-flags for buy/gear/service/build)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the client BIS-FSM `Client/FSM/updateavailableactions.fsm` (283 lines) — the once-per-client loop that recomputes every proximity range-flag the player UI gates on (buy units, buy gear, service point, fast travel, town depot, command center, AA radar, hangar, MHQ-build), then paints the matching action icons. Each tick it writes a fixed set of global booleans (`hqInRange`, `barracksInRange`, `gearInRange`, `lightInRange`, `heavyInRange`, `aircraftInRange`, `hangarInRange`, `serviceInRange`, `depotInRange`, `commandInRange`, `antiAirRadarInRange`) that menus and add-actions all over the client read instead of re-running their own `nearEntities` scans. It consumes — but does not own — the `Client_GetClosest*` proximity getters; those are catalogued in [Client Service Structure Proximity Getters](Client-Service-Structure-Proximity-Getters). This page owns the FSM: its spawn, its three-state structure, the range-flag table, and the icon-write contract.

## Spawn And Locality

| Aspect | Value | Source |
| --- | --- | --- |
| Launched by | `[] execFSM "Client\FSM\updateavailableactions.fsm";` | `Client/Init/Init_Client.sqf:609` |
| Launch form | `execFSM` (own FSM VM), no arguments | `Init_Client.sqf:609` |
| Locality | client-local; every player runs its own copy, writes its own globals | (no `publicVariable`; all writes are local globals) |
| First-tick force | `WFBE_ForceUpdate = true;` set during client init so the loop runs immediately, not after the first 5 s | `Init_Client.sqf:435` |

The FSM never replicates anything — every flag it writes is a plain `missionNamespace` global on the local client, read back by the same client's menus and HUD. The `OptionsAvailable` title resource it paints is also local (`12450 cutRsc`).

## State Machine

The FSM is a three-state loop: `Init` (one-time setup) -> `Update_Client_Ac` (the recompute body) -> back to itself, with a `Gameover` escape to `End`. `initState="Init"` (`:277`); the only final state is `End` (`:278-281`).

| State | Role | Source |
| --- | --- | --- |
| `Init` | Caches all `WFBE_C_*` range constants and feature flags into script-local `_vars`, primes the AI-delegation counters, and builds the 19-entry `_icons` path array once | `:22-98` |
| `Update_Client_Ac` | The per-tick body: recomputes every range-flag, runs the AI-delegation FPS report, map-info title, boundaries handler, fast-travel test, and the icon-write loop | `:100-263` |
| `End` | Empty terminal state; entered on `gameOver` | `:265-274` |

### Links (transitions and their guards)

| From | To | Condition | Source |
| --- | --- | --- | --- |
| `Init` (Loop) | `Update_Client_Ac` | `(time - _lastUpdate > 5 \|\| WFBE_ForceUpdate) && !gameOver` | `:88-95` |
| `Update_Client_Ac` (Gameover) | `End` | `gameOver` | `:242-251` |
| `Update_Client_Ac` (Loop) | `Update_Client_Ac` (self) | `(time - _lastUpdate > 5 \|\| WFBE_ForceUpdate) && !gameOver` | `:252-261` |

Both Loop links share the identical condition, so the cadence is uniform whether entering the body the first time from `Init` or re-entering it: a recompute happens at most every **5 seconds**, unless `WFBE_ForceUpdate` short-circuits the timer. `_lastUpdate` is reset to `time` at the end of every body pass (`:238`), and `WFBE_ForceUpdate` is reset to `false` once consumed (`:235`).

## Cadence And The Force-Update Bypass

| Mechanism | Detail | Source |
| --- | --- | --- |
| Normal cadence | `time - _lastUpdate > 5` — one recompute every 5 s | `:93,:258` |
| Reset of clock | `_lastUpdate = time;` at end of body | `:238` |
| Force bypass | `WFBE_ForceUpdate` OR'd into the condition forces an immediate pass regardless of the 5 s timer | `:93,:258` |
| Force consume | `if (WFBE_ForceUpdate) then {WFBE_ForceUpdate = false};` | `:235` |
| Force set (init) | `WFBE_ForceUpdate = true;` at client init | `Init_Client.sqf:435` |
| Force set (menu open) | `WFBE_ForceUpdate = true;` when the main menu opens, so range-flags are fresh before the player can click | `Client/GUI/GUI_Menu.sqf:11` |

The force-update path is why a player who walks into range and immediately opens the buy menu sees correct availability without waiting up to 5 s for the next scheduled tick: `GUI_Menu.sqf:11` raises the flag the moment the menu opens.

## Init-State Inputs (cached constants and flags)

`Init` reads every range/feature constant once into `_vars` so the hot body does not re-fetch them each tick. Defaults shown are from `Common/Init/Init_CommonConstants.sqf`.

| Local var | Source constant | Default | FSM line | Constant line |
| --- | --- | --- | --- | --- |
| `_ft` | `WFBE_C_GAMEPLAY_FAST_TRAVEL` | `1` | `:29` | `Init_CommonConstants.sqf:612` |
| `_ftr` | `WFBE_C_GAMEPLAY_FAST_TRAVEL_RANGE` | `175` | `:30` | `:621` |
| `_mhqbr` | `WFBE_C_BASE_HQ_BUILD_RANGE` | `120` | `:31` | `:456` |
| `_pur` | `WFBE_C_UNITS_PURCHASE_RANGE` | `150` | `:32` | `:758` |
| `_pura` | `WFBE_C_UNITS_PURCHASE_HANGAR_RANGE` | `50` | `:33` | `:762` |
| `_ccr` | `WFBE_C_STRUCTURES_COMMANDCENTER_RANGE` | `5500` | `:34` | `:689` |
| `_pgr` | `WFBE_C_UNITS_PURCHASE_GEAR_RANGE` | `150` | `:35` | `:759` |
| `_rptr` | `WFBE_C_UNITS_REPAIR_TRUCK_RANGE` | `40` | `:36` | `:763` |
| `_spr` | `WFBE_C_STRUCTURES_SERVICE_POINT_RANGE` | `50` | `:37` | `:694` |
| `_tpr` | `WFBE_C_TOWNS_BUILD_PROTECTION_RANGE` | `450` | `:38` | `Init_CommonConstants.sqf:705` |
| `_tcr` | `WFBE_C_TOWNS_CAPTURE_RANGE` | `40` | `:39` | `:719` |
| `_is` | `WFBE_C_ECONOMY_INCOME_SYSTEM` | `3` (Commander) | `:40` | `:525` |
| `_buygearfrom` | `WFBE_C_TOWNS_GEAR` | `1` (Camps) | `:41` | `:709` |
| `_gear_field_range` | `WFBE_C_UNITS_PURCHASE_GEAR_MOBILE_RANGE` | `5` | `:42` | `:760` |
| `_antiairradar_enabled` | `WFBE_C_STRUCTURES_ANTIAIRRADAR > 0` | `1` -> true | `:45` | `:681` |
| `_boundaries_enabled` | `WFBE_C_GAMEPLAY_BOUNDARIES_ENABLED > 0` | `1` -> true | `:46` | `:611` |
| `_ai_delegation_enabled` | `WFBE_C_AI_DELEGATION == 1` | `0` -> false | `:49` | `:130` |

`_buygearfrom` is the `WFBE_C_TOWNS_GEAR` mode (`0` None, `1` Camps, `2` Depot, `3` Camps & Depot) and selects which getter the gear fallback calls (`:160-166`). The `WFBE_C_GAMEPLAY_HANGARS_ENABLED` gate (default `1`, `Init_CommonConstants.sqf:614`) and `WFBE_C_AI_DELEGATION_FPS_INTERVAL` (`60*3` = 180 s, `:371`) are read in-body, not cached in `Init`.

## The Range-Flags Written Each Tick

These are the global booleans the FSM recomputes every pass. Each is a `missionNamespace` global, written unconditionally except where the structure-dependent guards noted below apply. Many are computed via `Common\Functions\Common_BuildingInRange.sqf` (compiled to `BuildingInRange`, `Common/Init/Init_Common.sqf:18`), which runs `GetFactories` for the `WFBE_<side><type>` factory list and returns the closest in range or `objNull`.

| Global flag | True when | Range used | FSM line |
| --- | --- | --- | --- |
| `hqInRange` | `player distance _base < _mhqbr` AND `alive _base` AND `side _base in [sideJoined,civilian]` (only set when `_base` non-null) | `_mhqbr` (HQ-build, 120) | `:153-155` |
| `barracksInRange` | `BuildingInRange ['BARRACKSTYPE',...]` non-null | `_purchaseRange` | `:157` |
| `gearInRange` | `BuildingInRange ['BARRACKSTYPE',...]` non-null at `_pgr`; OR mobile fallback (see below) | `_pgr` (150), then `_gear_field_range` (5) | `:158-175` |
| `lightInRange` | `BuildingInRange ['LIGHTTYPE',...]` non-null | `_purchaseRange` | `:177` |
| `heavyInRange` | `BuildingInRange ['HEAVYTYPE',...]` non-null | `_purchaseRange` | `:178` |
| `aircraftInRange` | `BuildingInRange ['AIRCRAFTTYPE',...]` non-null | `_purchaseRange` | `:179` |
| `serviceInRange` | `BuildingInRange ['SERVICEPOINTTYPE',...]` non-null; OR repair-truck nearby; OR `depotInRange` | `_spr` (50), then `_rptr` (40) | `:180-186,:195` |
| `antiAirRadarInRange` | `GetFactories` for `WFBE_<side>AARADARTYPE` returns >0 (only set when `_antiairradar_enabled`) | factory scan over `_buildings` | `:188-191` |
| `depotInRange` | `Client_GetClosestDepot` at `_tcr` non-null | `_tcr` (town-capture, 40) | `:194` |
| `commandInRange` | `BuildingInRange ['COMMANDCENTERTYPE',...]` non-null | `_ccr` (5500) | `:197-199` |
| `hangarInRange` | `Client_GetClosestAirport` at `_pura` non-null (only set when `WFBE_C_GAMEPLAY_HANGARS_ENABLED > 0`) | `_pura` (50) | `:202-204` |

`_purchaseRange` is itself proximity-dependent: `if (commandInRange) then {_ccr} else {_pur}` (`:111`) — being inside command-center range widens barracks/light/heavy/aircraft checks from the 150 purchase range to the 5500 command-center range, using **last tick's** `commandInRange` value (it is recomputed at `:199`, after these reads).

### `gearInRange` fallback chain

`gearInRange` has the most complex derivation — three stacked attempts, each only tried if the previous left it `false`:

| Attempt | Condition | Mechanism | FSM line |
| --- | --- | --- | --- |
| 1. Static barracks | always | `BuildingInRange ['BARRACKSTYPE',_buildings,_pgr,...]` | `:158` |
| 2. Camp/Depot getter | `!gearInRange && _buygearfrom in [1,2,3]` | switch on `_buygearfrom`: `1` -> `GetClosestCamp`, `2` -> `GetClosestDepot`, `3` -> first non-null of both, all at `_gear_field_range` | `:159-169` |
| 3. Mobile ammo truck | `!gearInRange` | `nearEntities [_typeAmmo, _gear_field_range]` where `_typeAmmo = WFBE_<side>AMMOTRUCKS` | `:171-175` |

`_typeAmmo` is cached in `Init` from `WFBE_%1AMMOTRUCKS` (`:59`); `_typeRepair` likewise from `WFBE_%1REPAIRTRUCKS` (`:58`) and feeds the `serviceInRange` truck fallback (`:182-186`).

### `serviceInRange` is OR-folded from three sources

`serviceInRange` ends `true` if any of: a `SERVICEPOINTTYPE` factory within `_spr` (`:180`), a friendly repair truck (`_typeRepair`) within `_rptr` (`:182-186`), or a town depot in range setting `depotInRange` (`:194-195`). The depot hit explicitly sets `serviceInRange = true` (`:195`), so town depots double as service points for the client gate.

## Getters Consumed (defer to the sibling page)

The FSM is a *consumer* of the `Client_GetClosest*` proximity getters and the generic `Common_*` helpers; their internals (scan class, side filter, last-match-not-nearest behaviour) are documented in [Client Service Structure Proximity Getters](Client-Service-Structure-Proximity-Getters). What the FSM calls:

| Getter / helper | Used for | FSM line |
| --- | --- | --- |
| `WFBE_CL_FNC_GetClosestCamp` | gear fallback `case 1`/`case 3` | `:163,:165` |
| `WFBE_CL_FNC_GetClosestDepot` | gear fallback `case 2`/`case 3`; town-depot `depotInRange` | `:164,:165,:194` |
| `WFBE_CL_FNC_GetClosestAirport` | `hangarInRange` | `:203` |
| `WFBE_CO_FNC_GetClosestEntity` | `_closest` nearest town (for fast travel) | `:113` |
| `BuildingInRange` (`Common_BuildingInRange.sqf`) | barracks/gear/light/heavy/aircraft/service/command factory tests | `:157,:158,:177,:178,:179,:180,:197` |
| `GetFactories` (`Common_GetFactories.sqf`) | AA-radar factory scan | `:189` |
| `WFBE_CO_FNC_GetSideStructures` / `GetSideHQ` / `GetSideUpgrades` | `_buildings`, `_base`, `_upgrades` inputs | `:107,:108,:109` |

The town-depot getter is called at `_tcr` (town-capture range, 40), not at a depot-specific range — this is the only spot in the FSM that reuses the capture range for a service test (`:194`).

## Fast Travel

Fast travel is not a structure scan but a layered distance test, only evaluated when `_ft > 0 && commandInRange` (`:207`) and only granting when the `WFBE_UP_FASTTRAVEL` upgrade is owned (`:210`). The result lands in `_fastTravel` (a script-local, not a global flag), consumed by the icon-write at `_usable` slot 9.

| Branch | Grants `_fastTravel` when | FSM line |
| --- | --- | --- |
| Own HQ | `player distance _base < _ftr && alive _base && _isDeployed` | `:211` |
| Nearest friendly town | `player distance _closest < _ftr && (_closest getVariable 'sideID') == sideID` | `:212-213` |
| Command center | `!isNull _commandCenter && player distance _commandCenter < _ftr` | `:214-216` |

`_isDeployed` is the side HQ deploy status (`GetSideHQDeployStatus`, `:209`); `_commandCenter` is the object returned by the `COMMANDCENTERTYPE` `BuildingInRange` at `:198`.

## The Icon-Write Contract

After all flags are computed, the FSM packs the consumed booleans into `_usable` and paints the `OptionsAvailable` title resource. Note `_usable` carries **12** entries while the cached `_icons` array has **19** path strings — only the first 12 icons are ever driven by this loop.

`_usable` (`:222`), index -> flag -> icon:

| `_usable` idx | Flag | Control IDC | `_icons` path | FSM line |
| --- | --- | --- | --- | --- |
| 0 | `hqInRange` | 3500 | `icon_wf_building_mhq.paa` | `:222,:64` |
| 1 | `barracksInRange` | 3501 | `icon_wf_building_barracks.paa` | `:222,:65` |
| 2 | `gearInRange` | 3502 | `icon_wf_building_gear.paa` | `:222,:66` |
| 3 | `lightInRange` | 3503 | `icon_wf_building_lvs.paa` | `:222,:67` |
| 4 | `heavyInRange` | 3504 | `icon_wf_building_hvs.paa` | `:222,:68` |
| 5 | `aircraftInRange` | 3505 | `icon_wf_building_air.paa` | `:222,:69` |
| 6 | `hangarInRange` | 3506 | `icon_wf_building_hangar.paa` | `:222,:70` |
| 7 | `serviceInRange` | 3507 | `icon_wf_building_repair.paa` | `:222,:71` |
| 8 | `serviceInRange` (again) | 3508 | `icon_wf_building_firstaid.paa` | `:222,:72` |
| 9 | `_fastTravel` | 3509 | `icon_wf_support_fasttravel.paa` | `:222,:73` |
| 10 | `commandInRange` | 3510 | `icon_wf_building_cc.paa` | `:222,:74` |
| 11 | `antiAirRadarInRange` | 3511 | `icon_wf_building_aa_radar.paa` | `:222,:75` |

The write loop (`:226-233`) iterates `_usable`, and for each entry either `CtrlSetText (_icons select _c)` when true or clears it to `""` when false, into control `3500 + _c` of the current cut display. The `OptionsAvailable` resource (idd `10200`, channel `12450`) declares `OptionsIcon0..17` at IDCs `3500..3517` (`Rsc/Titles.hpp:168-179,484-575`); the FSM only writes `3500..3511`, leaving the ARTY-radar / transport / supply-drop / artillery / mortar / CAS / UAV icon strings (`_icons` indices 12-18, `:76-82`) declared but unused by this loop.

`serviceInRange` is intentionally listed twice (slots 7 and 8) so both the repair icon and the first-aid icon light from the single service flag. The resource is (re)created with `12450 cutRsc ["OptionsAvailable","PLAIN",0]` in `Init` (`:62`) and re-asserted in the body if the shared `currentCutDisplay` handle is null (`:225`) — see [Client UI Systems Atlas](Client-UI-Systems-Atlas) for the `currentCutDisplay` ownership hazard this shares with RHUD and endgame stats.

## Side Effects Beyond Range-Flags

The body does four things unrelated to the proximity gate, folded into the same tick:

| Side effect | What | FSM line |
| --- | --- | --- |
| HC group sync | If `commanderTeam == group player && _hc_enabled`, `HCSetGroup`s the client teams (note `_hc_enabled` is hard-`false` at `:47`, so this branch is dead in this build) | `:115-119` |
| AI-delegation FPS report | Accumulates `diag_fps`, and every `WFBE_C_AI_DELEGATION_FPS_INTERVAL` (180 s) sends `["update-clientfps", uid, avg]` via `WFBE_CO_FNC_SendToServer` (only when `_ai_delegation_enabled`) | `:121-130` |
| Boundaries handler | When `_boundaries_enabled`, spawns/terminates `BoundariesHandleOnMap` based on `BoundariesIsOnMap` | `:132-141` |
| Map-info title | When `visibleMap`, writes the commander/income/supply line into `findDisplay 12 displayCtrl 116` | `:143-150` |
| Performance audit | Records `updateavailableactions` timing + `nearEntities` count via `PerformanceAudit_Record` | `:236-237` |

## Quirks Worth Knowing

| Quirk | Where | Detail |
| --- | --- | --- |
| `_purchaseRange` uses last tick's `commandInRange` | `:111` vs `:199` | barracks/light/heavy/aircraft ranges widen to `_ccr` based on the previous pass's `commandInRange`, since the current value is not computed until `:199` |
| Dead HC-sync branch | `:47,:115` | `_hc_enabled = false` is hard-set in `Init` and never reassigned, so the `HCSetGroup` block never runs in this build |
| Unused icon tail | `:76-82` vs `:222` | 7 of the 19 cached `_icons` (ARTY radar through UAV) have no `_usable` slot — declared but never painted by this FSM |
| Town-capture range reused for depot | `:194` | `depotInRange` scans at `_tcr` (40, the town-capture range), not a depot-specific constant |
| `serviceInRange` triple-OR | `:180,:185,:195` | service-point factory OR repair-truck OR town-depot; a depot hit also flips `serviceInRange` |
| Sibling vehicle-menu FSM | `Client/FSM/updateactions.fsm` (145 lines) | the smaller `updateactions.fsm` drives the vehicle "Options" `addAction` menu and is a separate FSM, not part of this range-gate loop |

## Continue Reading

- [Client Service Structure Proximity Getters](Client-Service-Structure-Proximity-Getters)
- [Client UI Systems Atlas](Client-UI-Systems-Atlas)
- [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas)
- [Service Point Pricing Model](Service-Point-Pricing-Model)
- [Gameplay Systems Atlas](Gameplay-Systems-Atlas)
