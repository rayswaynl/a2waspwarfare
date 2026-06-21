# Camp and Respawn-Camp Getter Reference (counting + spawn-eligibility helpers)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the camp getter family: five `Common/Functions/Common_Get*.sqf` helpers that count a town's camps, filter them by side, and decide which camps a dying unit may respawn at. They share a common domain object — a *town* (a location logic) holds a `"camps"` array of camp logics, and each camp logic carries a `"sideID"` and a `"wfbe_camp_bunker"` object. These functions are the read side; town-capture and camp-ownership writes live elsewhere. This reference is the call-contract complement to the lifecycle prose in [Respawn-And-Death-Lifecycle-Atlas](Respawn-And-Death-Lifecycle-Atlas).

All five are compiled in `Common/Init/Init_Common.sqf`: `GetFriendlyCamps` (line 31), `GetRespawnCamps` (line 37), `GetRespawnThreeway` (line 38), `GetTotalCamps` (line 61), `GetTotalCampsOnSide` (line 62). `GetTotalCamps` / `GetTotalCampsOnSide` are additionally aliased to namespaced names `WFBE_CO_FNC_GetTotalCamps` / `WFBE_CO_FNC_GetTotalCampsOnSide` (`Common/Init/Init_Common.sqf:145-146`); the bare and namespaced names are the same compiled body.

## Function index

| Function | Signature `[args]` | Returns | Source |
|---|---|---|---|
| `GetTotalCamps` | `_town` (location, NOT array) | camp count of town; `1` if town has zero camps | `Common/Functions/Common_GetTotalCamps.sqf:9-12` |
| `GetTotalCampsOnSide` | `[_town, _side]` | count of camps on `_town` whose `sideID` matches `_side`; `1` if town has zero camps | `Common/Functions/Common_GetTotalCampsOnSide.sqf:10-22` |
| `GetFriendlyCamps` | `[_town, _side, _lives?]` | array of camp logics on `_town` owned by `_side` (optionally only those with a live bunker) | `Common/Functions/Common_GetFriendlyCamps.sqf:3-18` |
| `GetRespawnThreeway` | `_side` (bare side, NOT array) | array of `_side`-owned towns where every camp belongs to `_side` | `Common/Functions/Common_GetRespawnThreeway.sqf:3-10` |
| `GetRespawnCamps` | `[_deathLoc, _side]` | array of camp logics the dying `_side` unit may respawn at near `_deathLoc` | `Common/Functions/Common_GetRespawnCamps.sqf:3-94` |

## GetTotalCamps — raw camp count with a safe-denominator floor

Reads the town's `"camps"` array and returns its size. The argument is the town logic *itself*, not an array — it is invoked `_location Call GetTotalCamps`, and the body does `_this getVariable "camps"` (`Common/Functions/Common_GetTotalCamps.sqf:9`).

| Aspect | Detail | Source |
|---|---|---|
| Input | the town location logic (bare, not wrapped) | `Common/Functions/Common_GetTotalCamps.sqf:9` |
| Zero-camp floor | `if (count _camps == 0) exitWith {1}` — a campless town reports **1**, not 0 | `Common/Functions/Common_GetTotalCamps.sqf:10` |
| Normal return | `count _camps` | `Common/Functions/Common_GetTotalCamps.sqf:12` |

The `{1}` floor exists so the value is safe to use as a **denominator**. `server_town.sqf:183` divides `GetTotalCampsOnSide / GetTotalCamps` to scale the town-capture rate; the floor prevents a divide-by-zero on a campless town. The cost is that a campless town is indistinguishable from a one-camp town through this function — callers that need a true count must read `_town getVariable "camps"` directly (as the Tactical menu does, see below).

## GetTotalCampsOnSide — per-side camp count, same floor

Counts how many of a town's camps belong to a given side. Resolves the side to its numeric id via `WFBE_CO_FNC_GetSideID` (`Common/Functions/Common_GetTotalCampsOnSide.sqf:13`) and increments `_total` for each camp whose `"sideID"` matches (`Common/Functions/Common_GetTotalCampsOnSide.sqf:20`).

| Aspect | Detail | Source |
|---|---|---|
| Input | `[_town, _side]` | `Common/Functions/Common_GetTotalCampsOnSide.sqf:10-11` |
| Side id | `_sideID = _side Call WFBE_CO_FNC_GetSideID` | `Common/Functions/Common_GetTotalCampsOnSide.sqf:13` |
| Zero-camp floor | `if (count _camps == 0) exitWith {1}` — same `1` floor as `GetTotalCamps` | `Common/Functions/Common_GetTotalCampsOnSide.sqf:16` |
| Count loop | `{if ((_x getVariable "sideID") == _sideID) then {_total = _total + 1}} forEach _camps` | `Common/Functions/Common_GetTotalCampsOnSide.sqf:20` |
| Return | `_total` | `Common/Functions/Common_GetTotalCampsOnSide.sqf:22` |

Note the floor is reached *before* the side filter: a campless town returns `1` for **any** side queried. On a town that has camps, a side owning none of them correctly returns `0`. The pairing `GetTotalCampsOnSide == GetTotalCamps` is the standard "this side owns ALL the camps" test (used by the capture gate, the unit-purchase gate, and `GetRespawnThreeway`).

## GetFriendlyCamps — a side's camps from one town, optional live-bunker filter

Returns the subset of a town's camps owned by `_side`, optionally restricted to camps whose bunker object is still alive. The third argument `_lives` is optional and defaults to `false` (`Common/Functions/Common_GetFriendlyCamps.sqf:5`).

| Aspect | Detail | Source |
|---|---|---|
| Input | `[_town, _side, _lives?]`; `_lives` defaults `false` when `count _this <= 2` | `Common/Functions/Common_GetFriendlyCamps.sqf:3-5` |
| Side id | `_sideID = _side Call GetSideID` | `Common/Functions/Common_GetFriendlyCamps.sqf:7` |
| Ownership filter | keep camp when `(_x getVariable "sideID") == _sideID` | `Common/Functions/Common_GetFriendlyCamps.sqf:11` |
| Live-bunker filter | when `_lives` is true, drop a camp if `!(alive (_x getVariable "wfbe_camp_bunker"))` | `Common/Functions/Common_GetFriendlyCamps.sqf:13` |
| Iterates over | `_town getVariable "camps"` | `Common/Functions/Common_GetFriendlyCamps.sqf:16` |
| Return | `_friendlyCamps` (array of camp logics) | `Common/Functions/Common_GetFriendlyCamps.sqf:18` |

Unlike the two count helpers, this returns the camp **objects**, and it has **no zero-camp floor** — an unowned or campless town yields an empty array. `GetRespawnCamps` mode 1 calls it with `_lives = true` so a destroyed-bunker camp is never offered as a classic respawn point (`Common/Functions/Common_GetRespawnCamps.sqf:17`).

## GetRespawnThreeway — towns where one side owns every camp

Used only in three-way (GUER-enabled) games for the defender side. Walks the side's owned towns and keeps each town where the side's camp count equals the town's total camp count — i.e. the side holds *all* of that town's camps.

| Aspect | Detail | Source |
|---|---|---|
| Input | `_side` (bare side value; `_side = _this`) | `Common/Functions/Common_GetRespawnThreeway.sqf:3` |
| Town source | `_side Call GetSideTowns` — towns whose `sideID` matches the side | `Common/Functions/Common_GetRespawnThreeway.sqf:8` |
| Keep condition | `(_x Call GetTotalCamps) == ([_x, _side] Call GetTotalCampsOnSide)` | `Common/Functions/Common_GetRespawnThreeway.sqf:7` |
| Append | `[_availableSpawn, _x] Call WFBE_CO_FNC_ArrayPush` | `Common/Functions/Common_GetRespawnThreeway.sqf:7` |
| Return | `_availableSpawn` (array of town logics) | `Common/Functions/Common_GetRespawnThreeway.sqf:10` |

The equality test inherits the `1`-floor quirk of both count helpers: for a *campless* town the comparison is `1 == 1`, which is **true**, so a side-owned campless town is treated as a valid threeway respawn town. Because both sides of the equality are floored identically, the test still correctly means "the side owns all camps present (if any)". The returned values are **towns**, not camps — distinct from `GetRespawnCamps`, which returns camp logics.

## GetRespawnCamps — the respawn-eligibility dispatcher

The largest helper (94 lines). Given a death location and side, it returns the camp logics the dying unit may spawn on. It dispatches on `WFBE_C_RESPAWN_CAMPS_MODE` into three branches, and within each applies an optional hostile-proximity safety rule driven by `WFBE_C_RESPAWN_CAMPS_RULE_MODE`.

**Signature and pre-read state**

| Aspect | Detail | Source |
|---|---|---|
| Input | `[_deathLoc, _side]` | `Common/Functions/Common_GetRespawnCamps.sqf:3-4` |
| `_respawnCampsRuleMode` | `getVariable "WFBE_C_RESPAWN_CAMPS_RULE_MODE"` | `Common/Functions/Common_GetRespawnCamps.sqf:7` |
| `_respawnMinRange` | `getVariable "WFBE_C_RESPAWN_CAMPS_SAFE_RADIUS"` | `Common/Functions/Common_GetRespawnCamps.sqf:8` |
| Dispatch | `switch (getVariable "WFBE_C_RESPAWN_CAMPS_MODE")` | `Common/Functions/Common_GetRespawnCamps.sqf:11` |
| Return | `_availableSpawn` (array of camp logics) | `Common/Functions/Common_GetRespawnCamps.sqf:94` |

Note that `_availableSpawn` is left empty (`[]`, line 6) if `WFBE_C_RESPAWN_CAMPS_MODE` is `0` or any value the `switch` has no `case` for — there is no `default` branch.

### Mode branches

| Mode | Meaning | Camp source | Source |
|---|---|---|---|
| 1 | **Classic** — camps of the nearest town within range | `[_deathLoc] Call GetClosestLocation`, range-gated by `WFBE_C_RESPAWN_CAMPS_RANGE`, then `[_town,_side,true] Call GetFriendlyCamps` (live bunkers only) | `Common/Functions/Common_GetRespawnCamps.sqf:12-34` |
| 2 | **Enhanced** — friendly live camps physically near the death spot | `_deathLoc nearEntities [WFBE_Logic_Camp, WFBE_C_RESPAWN_CAMPS_RANGE]`, kept when `sideID` matches and bunker alive | `Common/Functions/Common_GetRespawnCamps.sqf:36-61` |
| 3 | **Defender-only** — like Enhanced, but only if the camp's town is also friendly | same `nearEntities` scan, kept only when both the camp `sideID` AND the town `sideID` equal the unit's side id, bunker alive | `Common/Functions/Common_GetRespawnCamps.sqf:63-90` |

Mode 1 reads the *nearest* town's camps via `GetClosestLocation` then `GetFriendlyCamps`; modes 2 and 3 scan for camp logics directly with `nearEntities [WFBE_Logic_Camp, …]` (the camp class string is `"LocationLogicCamp"`, `Common/Init/Init_Common.sqf:210`). Mode 3 additionally reads `_x getVariable 'town'` and that town's `'sideID'` so a friendly camp inside an enemy-held town is rejected (`Common/Functions/Common_GetRespawnCamps.sqf:68-70`).

### Rule-mode hostile-safe-radius gate

When `_respawnCampsRuleMode > 0`, each candidate camp is checked for nearby enemies before being offered. The enemy-side set is resolved as follows, identically in all three branches:

| Condition | Enemy sides | Source |
|---|---|---|
| `WFBE_ISTHREEWAY` true | `[west, east, resistance] - [_side]` (both other sides) | `Common/Functions/Common_GetRespawnCamps.sqf:21-22, 44-45, 73-74` |
| Not threeway, rule mode 1 | the single opposing main side: `if (_side == west) then {[east]} else {[west]}` | `Common/Functions/Common_GetRespawnCamps.sqf:24, 47, 76` |
| Not threeway, rule mode 2 | opposing main side **plus** `resistance` | `Common/Functions/Common_GetRespawnCamps.sqf:25, 48, 77` |

`WFBE_ISTHREEWAY` is itself gated on the playable GUER faction: `((getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0)` (`Common/Init/Init_Common.sqf:293`).

The hostile check uses `GetHostilesInArea` with the resolved enemy set and `_respawnMinRange`:

- **Mode 1** computes the closest camp via `WFBE_CO_FNC_GetClosestEntity`, then if `_deathLoc distance _closestCamp < _respawnMinRange && _hostiles > 0` it *removes that one camp* from the offered set (`Common/Functions/Common_GetRespawnCamps.sqf:20,27-28`).
- **Modes 2 and 3** apply the gate per-camp: only when `_deathLoc distance _x < _respawnMinRange` is the hostile count consulted, and the camp is offered only if `_hostiles == 0`; camps farther than the safe radius are always offered (`Common/Functions/Common_GetRespawnCamps.sqf:43,50-53` and `72,79-82`).

So the safe radius is a *proximity* gate, not a hard ownership gate: a camp far from the death location bypasses the hostile check entirely.

## Configuration constants

| Constant | Runtime fallback (isNil) | Parameter default (HPP) | Meaning | Source |
|---|---|---|---|---|
| `WFBE_C_RESPAWN_CAMPS_MODE` | `2` | `1` | 0 off, 1 Classic, 2 Enhanced, 3 Defender-only | `Common/Init/Init_CommonConstants.sqf:445`; `Rsc/Parameters.hpp:412-417` |
| `WFBE_C_RESPAWN_CAMPS_RANGE` | `550` | `400` | distance from town/death spot to look for camps (m) | `Common/Init/Init_CommonConstants.sqf:446`; `Rsc/Parameters.hpp:449-454` |
| `WFBE_C_RESPAWN_CAMPS_RULE_MODE` | `2` | `1` | 0 off, 1 West/East, 2 West/East/Resistance hostile set | `Common/Init/Init_CommonConstants.sqf:447`; `Rsc/Parameters.hpp:418-423` |
| `WFBE_C_RESPAWN_CAMPS_SAFE_RADIUS` | `50` (unconditional) | n/a — not a lobby parameter | hostile-check radius around a camp (m) | `Common/Init/Init_CommonConstants.sqf:452` |

The lobby (`Parameters.hpp`) defaults and the runtime `isNil` fallbacks differ: the lobby selection wins when a server picks parameters; the `isNil` fallback (mode `2`, rule mode `2`) only applies if the variable was never set at all. `WFBE_C_RESPAWN_CAMPS_SAFE_RADIUS` is set unconditionally (no `isNil` guard, no lobby parameter) and is always `50`.

## Call sites

| Caller | Line | Function | Purpose |
|---|---|---|---|
| `Client/Functions/Client_GetRespawnAvailable.sqf` | 103 | `GetRespawnCamps` | adds camp respawns for the human player when `WFBE_C_RESPAWN_CAMPS_MODE > 0` | 
| `Client/Functions/Client_GetRespawnAvailable.sqf` | 92 | `GetRespawnThreeway` | in a threeway, adds side-controlled towns for the defender (`WFBE_DEFENDER`, = `resistance`, `Common/Init/Init_Common.sqf:296`) |
| `Server/AI/AI_SquadRespawn.sqf` | 38 | `GetRespawnCamps` | AI squad respawn camp set, gated on `_rcm > 0 && !_isForcedRespawn` (`_rcm` read line 10) |
| `Server/AI/AI_AdvancedRespawn.sqf` | 39 | `GetRespawnCamps` | AI advanced respawn camp set, same gate (`_rcm` read line 9) |
| `Client/GUI/GUI_Menu_Tactical.sqf` | 163, 191 | `GetFriendlyCamps` | fast-travel eligibility: a town is a valid FT start only if `count _camps == count _allCamps` (side owns every camp) |
| `Client/GUI/GUI_Menu_BuyUnits.sqf` | 120-121 | `GetTotalCamps`, `GetTotalCampsOnSide` | Depot infantry purchase gate: blocks buying unless `_totalCamps == _campsSide` (side owns all camps), bypassed for resistance |
| `Server/FSM/server_town.sqf` | 167, 170/173/176 | `GetTotalCamps`, `GetTotalCampsOnSide` | town-capture eligibility: a side may only flip the town if it owns all camps present for that side |
| `Server/FSM/server_town.sqf` | 183 | `WFBE_CO_FNC_GetTotalCampsOnSide` / `WFBE_CO_FNC_GetTotalCamps` | scales capture rate by `(camps owned by new side / total camps) * _town_camps_capture_rate` (the `{1}` floor guards this division) |
| `Common/Functions/Common_GetRespawnCamps.sqf` | 17 | `GetFriendlyCamps` | mode-1 classic camp lookup (with `_lives = true`) |
| `Common/Functions/Common_GetRespawnThreeway.sqf` | 7 | `GetTotalCamps`, `GetTotalCampsOnSide` | the all-camps equality test |

Two consumption patterns recur. The `GetTotalCamps == GetTotalCampsOnSide` / `count _camps == count _allCamps` comparison is the "does this side own every camp" test used by purchase, capture, fast-travel, and threeway gates. `GetRespawnCamps` is the spawn-set producer consumed by all three respawn entry points (one client, two AI). The GUI fast-travel and buy-units sites deliberately read `_x getVariable "camps"` / `_closest getVariable "camps"` for the *true* total rather than `GetTotalCamps`, sidestepping the `1` floor so a campless town is not mistaken for a fully-owned town.

## Continue Reading

- [Respawn-And-Death-Lifecycle-Atlas](Respawn-And-Death-Lifecycle-Atlas) — where these getters fit in the full death-to-respawn flow
- [Position-And-Proximity-Function-Reference](Position-And-Proximity-Function-Reference) — `GetClosestLocation`, `GetClosestEntity`, `GetHostilesInArea` consumed by `GetRespawnCamps`
- [Towns-Camps-And-Capture-Atlas](Towns-Camps-And-Capture-Atlas) — town/camp domain objects and the capture mechanics in `server_town.sqf`
- [Side-Team-State-Function-Reference](Side-Team-State-Function-Reference) — `GetSideID`, `GetSideTowns`, and side-id constants used throughout
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — town ownership and supply context for the purchase/capture gates
