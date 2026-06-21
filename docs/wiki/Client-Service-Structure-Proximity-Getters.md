# Client Service-Structure Proximity Getters

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the three client-side "which friendly logistics structure am I near" getters — `Client_GetClosestAirport`, `Client_GetClosestCamp` and `Client_GetClosestDepot` — plus the GUER-only town-center EASA predicate `Client_CanUseTownCenterEASA` that sits beside them in the same registration block. Each getter runs `nearEntities` over a `WFBE_Logic_*` proxy class, applies a side/alive/state filter specific to that structure, and returns the matching object or `objNull`. They are the proximity backbone behind the action FSM's gear/depot/hangar gates, the gear-store target picker, and the buy-units and service menus.

These are distinct from the generic `Common_*` proximity helpers (`GetClosestEntity*`, `GetClosestLocation*`, `SortByDistance`, `BuildingInRange`) documented in [Position And Proximity Function Reference](Position-And-Proximity-Function-Reference): those operate on caller-supplied lists or the global `towns` array, whereas these `Client_*` getters scan a fixed `WFBE_Logic_*` class and bake in the player's `sideID` ownership test. The EASA repair-point siblings (`Client_CanUseRepairPointEASA`, `Client_GetRepairTruckServicePoints`, `Client_CanRepairCampNearby`) are covered in [Player Skill Abilities Reference](Player-Skill-Abilities-Reference) and are not repeated here.

## Function Registry

All four are compiled into `WFBE_CL_FNC_*` aliases in the client function-load block of `Init_Client.sqf`.

| Function | Compile alias | Registration | Source | Returns |
| --- | --- | --- | --- | --- |
| `Client_GetClosestAirport.sqf` | `WFBE_CL_FNC_GetClosestAirport` | `Client/Init/Init_Client.sqf:125` | `Client/Functions/Client_GetClosestAirport.sqf:1-16` | Airfield logic object, or `objNull` |
| `Client_GetClosestCamp.sqf` | `WFBE_CL_FNC_GetClosestCamp` | `Client/Init/Init_Client.sqf:126` | `Client/Functions/Client_GetClosestCamp.sqf:1` | Camp logic object, or `objNull` |
| `Client_GetClosestDepot.sqf` | `WFBE_CL_FNC_GetClosestDepot` | `Client/Init/Init_Client.sqf:127` | `Client/Functions/Client_GetClosestDepot.sqf:1` | Depot logic object, or `objNull` |
| `Client_CanUseTownCenterEASA.sqf` | `WFBE_CL_FNC_CanUseTownCenterEASA` | `Client/Init/Init_Client.sqf:124` | `Client/Functions/Client_CanUseTownCenterEASA.sqf:1-29` | `true`/`false` |

## The three closest-structure getters

Each getter takes `[_positionOrObject, _range]` (callers pass `vehicle player`), scans a `WFBE_Logic_*` class with `nearEntities`, and assigns `_closest` on the last matching entity in the iteration (no nearest-sort — the last qualifying `_x` wins). All three default `_closest` to `objNull` (`Client_GetClosestAirport.sqf:9`, `Client_GetClosestCamp.sqf:1`, `Client_GetClosestDepot.sqf:1`), so callers test the result with `isNull`.

| Getter | Scanned class | Required state | Side filter | Source |
| --- | --- | --- | --- | --- |
| Airport | `WFBE_Logic_Airfield` | `wfbe_hangar` is set and `alive` | If `sideJoined == resistance`, also `wfbe_airfield_side == resistance` (default `civilian`); otherwise no side test | `Client_GetClosestAirport.sqf:13-14` |
| Camp | `WFBE_Logic_Camp` | `alive (_x getVariable "wfbe_camp_bunker")` | `(_x getVariable "sideID") == sideID`, unless the optional 3rd arg `_ignore_side` is `true` | `Client_GetClosestCamp.sqf:1` |
| Depot | `WFBE_Logic_Depot` | `sideID` set and `isNil {_x getVariable "wfbe_inactive"}` | `(_x getVariable "sideID") == sideID` | `Client_GetClosestDepot.sqf:1` |

Per-getter detail:

- **Airport** — The forEach guards on `!(isNil {_x getVariable "wfbe_hangar"})`, then `alive _hangar`. The side branch keys off `sideJoined`: resistance players additionally require the airfield's `wfbe_airfield_side` (read with default `civilian`) to equal `resistance`, so GUER only gets a neutral/captured-airfield match for an airfield they actually hold; WEST/EAST take the `else` branch and accept any alive-hangar airfield in range (`Client_GetClosestAirport.sqf:14`).
- **Camp** — Reads the optional third parameter into `_ignore_side` via `if (count _this > 2)`, defaulting `false`. The guard chain is `!(isNil sideID)` -> `alive wfbe_camp_bunker` -> side test. When `_ignore_side` is `true` the side test is skipped entirely, so any alive-bunker camp in range matches (`Client_GetClosestCamp.sqf:1`). Note the file's own header comment mislabels it as "closest depot" — it scans `WFBE_Logic_Camp`.
- **Depot** — The tightest filter: a single combined test `(_x getVariable "sideID") == sideID && isNil {_x getVariable "wfbe_inactive"}`, so a depot whose `wfbe_inactive` flag has been set is skipped even when owned by the player's side (`Client_GetClosestDepot.sqf:1`).

### `sideID` ownership

The Camp and Depot getters compare each structure's `sideID` variable against the client-global `sideID` (the joining player's numeric side). This is a structure-ownership test, not a side comparison via `side`/`sideJoined` — the structure must carry a matching numeric `sideID`. The Airport getter does not use `sideID`; it gates resistance on `wfbe_airfield_side` instead.

## Consumers

| Consumer | Getter(s) used | What it gates | Source |
| --- | --- | --- | --- |
| Action FSM — field gear | `GetClosestCamp`, `GetClosestDepot` | `gearInRange`: when `WFBE_C_TOWNS_GEAR` (`_buygearfrom`) is 1/2/3, picks camp / depot / either at `_gear_field_range` (`WFBE_C_UNITS_PURCHASE_GEAR_MOBILE_RANGE`) | `Client/FSM/updateavailableactions.fsm:162-167` |
| Action FSM — town depot | `GetClosestDepot` | `depotInRange` at `_tcr`; a hit also sets `serviceInRange = true` | `Client/FSM/updateavailableactions.fsm:194-195` |
| Action FSM — hangar | `GetClosestAirport` | `hangarInRange` at `_pura`, only when `WFBE_C_GAMEPLAY_HANGARS_ENABLED > 0` | `Client/FSM/updateavailableactions.fsm:202-204` |
| Gear-store AI target picker | `GetClosestCamp`, `GetClosestDepot` | `_add`: when `_camp_gear_enabled`, `_gear_mode` 1/2/3 selects camp / depot / either at the unit's mobile gear range | `Client/Functions/Client_UI_Gear_UpdateTarget.sqf:30-35` |
| Buy-units menu | `GetClosestDepot`, `GetClosestAirport` | `'Depot'` case at `WFBE_C_TOWNS_PURCHASE_RANGE`; `'Airport'` case at `WFBE_C_UNITS_PURCHASE_HANGAR_RANGE`, whose result also feeds the captured-airfield roster swap | `Client/GUI/GUI_Menu_BuyUnits.sqf:327,331` |
| Service menu | `GetClosestDepot` | Town depots added to the per-target `_nearSupport` list at `WFBE_C_UNITS_SUPPORT_RANGE` | `Client/GUI/GUI_Menu_Service.sqf:296` |

The `case 3` / `_gear_mode 3` "either" path in the FSM and gear picker iterates `[GetClosestCamp, GetClosestDepot]` and takes the first non-null with `if !(isNull _x) exitWith` (`updateavailableactions.fsm:165`, `Client_UI_Gear_UpdateTarget.sqf:33`). The buy-units `'Airport'` case feeds its result straight into the Task-12 captured-airfield exclusive-roster swap (`GUI_Menu_BuyUnits.sqf:334`).

## `Client_CanUseTownCenterEASA` (GUER-only)

A boolean predicate `[_unit, _vehicle] -> bool` that grants the aircraft-loadout editor (EASA) at friendly town centers for the playable GUER faction. GUER Insurgents are base-less — no service points, no EASA upgrade economy — so EASA is offered at town centers instead, mirroring the WEST/EAST service-point path (`Client_CanUseRepairPointEASA`). It is GUER-only by construction (`Client_CanUseTownCenterEASA.sqf:2-6`).

Early-out gates, in order (`Client_CanUseTownCenterEASA.sqf:13-17`):

| Gate | Condition that returns `false` | Line |
| --- | --- | --- |
| Playable GUER off | `WFBE_C_GUER_PLAYERSIDE <= 0` (read with default 0) | `:13` |
| Not resistance | `side group _unit != resistance` | `:14` |
| On foot | `_vehicle == _unit` | `:15` |
| Not the driver | `driver _vehicle != _unit` | `:16` |
| Wrong vehicle | `typeOf _vehicle` not in `WFBE_EASA_Vehicles` | `:17` |

If all gates pass, it reads `_range = WFBE_C_UNITS_SUPPORT_RANGE` (the same rearm-action range as the service-point EASA path) and scans the global `towns` array: a town qualifies as a friendly center when its `sideID` (default `-1`) is neither `WFBE_C_WEST_ID` nor `WFBE_C_EAST_ID` — i.e. GUER-owned or neutral, but not WEST- or EAST-held — and the unit is within `_range` of it. The first such town short-circuits `_ok = true` via `exitWith` (`Client_CanUseTownCenterEASA.sqf:19-26`). This "neutral-or-friendly = not-enemy-held" idiom matches the GUER respawn-pick logic.

## Edges to preserve

- **Last-match, not nearest.** None of the three getters sort; the last qualifying entity in `nearEntities` order is returned. Within the small `WFBE_Logic_*` candidate set at action ranges this is usually fine, but a refactor must not assume the result is the geometrically closest.
- **Depot `wfbe_inactive` skip.** A depot owned by the player's side is still rejected once `wfbe_inactive` is set; do not drop that flag check when touching the depot gate (`Client_GetClosestDepot.sqf:1`).
- **Airport resistance branch.** GUER matches an airfield only when `wfbe_airfield_side == resistance`; the default `civilian` read means an un-flagged airfield never matches for resistance (`Client_GetClosestAirport.sqf:14`).
- **Camp `_ignore_side` override.** The optional third argument disables the ownership test entirely — callers passing it accept any alive-bunker camp in range (`Client_GetClosestCamp.sqf:1`).
- **Camp header comment is wrong.** The `Client_GetClosestCamp.sqf` header reads "Return the closest depot"; the body scans `WFBE_Logic_Camp`. Trust the code, not the comment.

## Continue Reading

- [Position And Proximity Function Reference](Position-And-Proximity-Function-Reference)
- [Player Skill Abilities Reference](Player-Skill-Abilities-Reference)
- [Camp And Respawn Camp Getter Reference](Camp-And-Respawn-Camp-Getter-Reference)
- [Gear Loadout And EASA Atlas](Gear-Loadout-And-EASA-Atlas)
- [Factory And Purchase Systems Atlas](Factory-And-Purchase-Systems-Atlas)
