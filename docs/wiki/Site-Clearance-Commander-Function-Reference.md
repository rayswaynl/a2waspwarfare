# Site Clearance (Commander Bulldozer Tree-Felling Action)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Site Clearance is a commander-only build-menu action that fells terrain trees inside the friendly base area so structures and defenses can be placed where the engine's nearby-vegetation would otherwise block them. It is unusual among CoIn build-menu entries: **no object is ever built**. The menu anchor classname `Land_Pneu` is registered alongside the side's defenses, but when the player places it the client routes a dedicated `RequestSiteClearance` public-variable function (PVF) — not the normal `RequestDefense` path — and the server function deletes nearby trees by damaging them, charging supply only for trees that actually fall.

The action is wrapped in an eight-gate anti-grief chain (feature toggle, alive, commander-identity, Barracks>=1, base-area containment, per-side rate-limit, at-least-one-tree, supply affordability) so it is a deliberate team action rather than a griefable one (`Server/Functions/Server_SiteClearance.sqf:13`).

## Call chain (client placement -> server fell)

| Step | File:line | What happens |
| --- | --- | --- |
| Menu registration | `Common/Config/Core_Structures/Structures_CDF.sqf:166-168` | `Land_Pneu` appended to `WFBE_%1DEFENSENAMES` only when `WFBE_C_UNITS_BULLDOZER > 0` |
| Build-menu arrays | `Client/Init/Init_Coin.sqf:46` | `_allDefenses = missionNamespace getVariable Format["WFBE_%1DEFENSENAMES",sideJoinedText]` — the defense list (already containing `Land_Pneu` from `Structures_CDF.sqf:167`) is read into `_allDefenses` for the build menu |
| Repair-truck exclusion | `Client/Init/Init_Coin.sqf:48` | In RCoin/`REPAIR` context, `Land_Pneu` is removed (`_allDefenses - ["Land_Pneu"]`) — commander-only, not a repair-truck action |
| Placement dispatch | `Client/Module/CoIn/coin_interface.sqf:725-726` | On placing `Land_Pneu`, client sends `["RequestSiteClearance", [sideJoined,_pos,player]]` via `WFBE_CO_FNC_SendToServer` (all other defenses use `RequestDefense`) |
| PV registration | `Common/Init/Init_PublicVariables.sqf:25` | `_l = _l + ["RequestSiteClearance"]` registers the PVF channel |
| Server PVF | `Server/PVFunctions/RequestSiteClearance.sqf:29` | Unpacks `[_side,_pos,_reqPlayer]`, calls `WFBE_SE_FNC_SiteClearance` |
| Server function | `Server/Functions/Server_SiteClearance.sqf:1-167` | Runs the gate chain and the fell loop |
| Compile binding | `Server/Init/Init_Server.sqf:111` | `WFBE_SE_FNC_SiteClearance = Compile preprocessFileLineNumbers "Server\Functions\Server_SiteClearance.sqf"` |

## RequestSiteClearance.sqf (the dedicated PVF)

| Property | Detail |
| --- | --- |
| Path | `Server/PVFunctions/RequestSiteClearance.sqf` |
| Params | `_this select 0` = side; `select 1` = placement position `[x,y,z]`; `select 2` = the placing player object (`RequestSiteClearance.sqf:17-20`) |
| Body | `[_side, _pos, _reqPlayer] Call WFBE_SE_FNC_SiteClearance` (`RequestSiteClearance.sqf:29`) |
| Why a dedicated PVF | The client passes the **real `player` object** in the payload so Gate 3 compares the actual placer against the commander. A server-side `leader()` lookup would always return the commander and make the identity gate inert (`RequestSiteClearance.sqf:5-8`) |
| Trust model | Client-supplied identity is acceptable: the gate requires the player BE the commander group leader, and `coin_interface` fires only on the requesting machine, so spoofing gains nothing an attacker could not get by simply being elected commander (`RequestSiteClearance.sqf:10-15`) |

## Server_SiteClearance.sqf

Single server-only function. Params (array): `_this select 0` = side, `select 1` = placement position, `select 2` = requesting player (`Server_SiteClearance.sqf:16-19, 26-28`). Returns nothing; its effect is felled trees + a side-supply charge + side-wide feedback message. The local-var block is declared up front in a capitalized `private [...]` declaration (`Server_SiteClearance.sqf:22-24`).

### The eight gates (sequential `exitWith`)

| Gate | Line | Condition (rejects when…) | Reject feedback |
| --- | --- | --- | --- |
| 1. Feature enabled | `Server_SiteClearance.sqf:31` | `WFBE_C_UNITS_BULLDOZER == 0` | WARNING log only (no player message) |
| 2. Player alive | `Server_SiteClearance.sqf:36` | `isNull _reqPlayer` or `!(alive _reqPlayer)` | silent `exitWith {}` |
| 3. Commander-only | `Server_SiteClearance.sqf:44-48` | `_reqPlayer != leader (_side Call WFBE_CO_FNC_GetCommanderTeam)` or null team | `SiteClearanceCommanderOnly` to player |
| 4. Barracks >= 1 | `Server_SiteClearance.sqf:50-59` | `wfbe_upgrades select WFBE_UP_BARRACKS < 1` (count-guarded) | `SiteClearanceNeedsBarracks1` to player |
| 5. Inside friendly base | `Server_SiteClearance.sqf:61-80` | `_pos distance` every base center `>= WFBE_C_BASE_AREA_RANGE` | `SiteClearanceOutsideBase` to player |
| 6. Per-side rate limit | `Server_SiteClearance.sqf:82-87` | `(time - wfbe_siteclear_last) < 15` | DEBUG log only |
| 7. At least one tree | `Server_SiteClearance.sqf:134-138` | `count _trees == 0` | `SiteClearanceNoTrees` to player |
| 8. Supply affordable | `Server_SiteClearance.sqf:140-147` | `GetSideSupply < (treeCount * 10)` | `SiteClearanceNoSupply` (with cost) to player |

Gate-3 detail: `_commanderTeam = _side Call WFBE_CO_FNC_GetCommanderTeam` reads the commander group stored as `wfbe_commander` on the side logic; the per-player check is `_reqPlayer != leader _commanderTeam` (`Server_SiteClearance.sqf:44-45`).

Gate-4 detail: `_logik = _side Call WFBE_CO_FNC_GetSideLogic`, `_upgrades = _logik getVariable ["wfbe_upgrades", []]`, then `_barrackLvl = _upgrades select WFBE_UP_BARRACKS` guarded by `count _upgrades > WFBE_UP_BARRACKS` (`Server_SiteClearance.sqf:52-55`). The pattern mirrors `Server_CounterBattery.sqf`'s `WFBE_UP_CBRADAR` check (`Server_SiteClearance.sqf:51`).

Gate-5 detail: base centers are built from `wfbe_startpos` (the HQ start position object) plus each `wfbe_basearea` logic, all read off the side logic; a point is "in base" if it is within `_baseRange` of any center (`Server_SiteClearance.sqf:64-75`).

Gate-6 detail: `wfbe_siteclear_last` is a server-local variable on the side logic, defaulting to `-99` so the first clearance always passes (`Server_SiteClearance.sqf:84`).

### `_matchAny` — inline A2-safe substring matcher

| Property | Detail |
| --- | --- |
| Defined | `Server_SiteClearance.sqf:91-115` |
| Signature | `[haystackLower (String), [needle1, needle2, ...]] call _matchAny -> Bool` |
| Why it exists | Arma 2 OA's string `find` is A3-only and throws on A2; this is a hand-rolled replacement (`Server_SiteClearance.sqf:89-90`) |
| Algorithm | `toArray` the haystack and each needle, then slide an index `0..(_hl - _nl)` comparing the needle's character codes; sets `_found` on first hit and short-circuits the remaining checks (`Server_SiteClearance.sqf:93-114`) |
| Guard | needle skipped unless `_nl > 0 && _nl <= _hl` (`Server_SiteClearance.sqf:101`) |

### Tree scan

| Aspect | Line | Detail |
| --- | --- | --- |
| Source set | `Server_SiteClearance.sqf:120` | `nearestObjects [_pos, [], 25]` — every object within 25 m, no type filter |
| Undamaged filter | `Server_SiteClearance.sqf:124` | `getDammage _tree < 1` (skip already-felled) |
| Name match | `Server_SiteClearance.sqf:125-128` | `toLower (str _tree)` must contain `": t_"` (Chernarus tree prefix) or `": str_"` (legacy) via `_matchAny` |
| Bush note | `Server_SiteClearance.sqf:119` | bushes (`b_` prefix) are excluded in v1 by design |
| Count | `Server_SiteClearance.sqf:132` | `_N = count _trees` feeds the supply cost |

### Fell + charge ordering

The charge ordering is deliberately **fell-first, count-confirmed-fells, then charge**, so a tree the engine refuses to drop costs nothing (`Server_SiteClearance.sqf:8-11, 152`).

| Step | Line | Detail |
| --- | --- | --- |
| Rate stamp | `Server_SiteClearance.sqf:150` | `_logik setVariable ["wfbe_siteclear_last", time]` set BEFORE the loop so re-entrant calls during felling are blocked |
| Cost | `Server_SiteClearance.sqf:141` | `_cost = _N * 10` (10 supply per tree) |
| Fell | `Server_SiteClearance.sqf:153` | `{_x setDamage 1} forEach _trees` |
| Confirm | `Server_SiteClearance.sqf:156-157` | `_felled` counts trees with `getDammage >= 1` after the fell |
| Charge | `Server_SiteClearance.sqf:160-161` | only if `_felled > 0`: `[_side, -(_felled * 10), <log>, false] Call ChangeSideSupply` |
| Side-wide feedback | `Server_SiteClearance.sqf:167` | `[_side, "LocalizeMessage", ["SiteClearanceDone", _felled, _felled * 10]] Call WFBE_CO_FNC_SendToClients` — team-visible by design |

`GetSideSupply` (Gate 8) and `ChangeSideSupply` (charge) are the global-name compiles bound at `Common/Init/Init_Common.sqf:42` and `:19`; `WFBE_CO_FNC_GetCommanderTeam` is bound at `Common/Init/Init_Common.sqf:124`.

## Localization keys

`Client/PVFunctions/LocalizeMessage.sqf` resolves six keys; `SiteClearanceNoSupply` formats one arg (cost) and `SiteClearanceDone` formats two (felled count, supply spent) (`LocalizeMessage.sqf:61-66`). English text from `stringtable.xml:9509-9524`:

| Key | LocalizeMessage.sqf | English text |
| --- | --- | --- |
| `SiteClearanceCommanderOnly` | `:61` | "Site Clearance can only be used by the commander." |
| `SiteClearanceNeedsBarracks1` | `:62` | "Site Clearance requires Barracks level 1 before use." |
| `SiteClearanceNoTrees` | `:63` | "Site Clearance: no trees found within 25 m of that position." |
| `SiteClearanceNoSupply` | `:64` | "Site Clearance: insufficient supply (need %1)." |
| `SiteClearanceDone` | `:65` | "Site clearance: %1 trees felled, -%2 supply." |
| `SiteClearanceOutsideBase` | `:66` | "Site Clearance position must be inside your base area." |

## Tunable constants

| Constant | Default | Defined | Role |
| --- | --- | --- | --- |
| `WFBE_C_UNITS_BULLDOZER` | `1` | `Common/Init/Init_CommonConstants.sqf:582` | Master feature gate ("Engineer base-area tree clearing"); also controls whether `Land_Pneu` is registered as a defense |
| `WFBE_C_BASE_AREA_RANGE` | `250` | `Common/Init/Init_CommonConstants.sqf:251` | Base-area radius (meters) used by Gate 5 |
| `WFBE_UP_BARRACKS` | `0` | `Common/Init/Init_CommonConstants.sqf:37` | Index into `wfbe_upgrades` for the Barracks level read by Gate 4 |
| 25 m tree-scan radius | hard-coded | `Server_SiteClearance.sqf:120` | `nearestObjects` radius |
| 10 supply/tree | hard-coded | `Server_SiteClearance.sqf:141, 161` | Per-tree cost |
| 15 s rate limit | hard-coded | `Server_SiteClearance.sqf:85` | Per-side cooldown |

## Engine deferral note

Whether `setDamage 1` actually fells A2 terrain trees and whether fallen trunks sync to JIP clients is flagged as DEFERRED to the integration smoke test in the function header; the charge-after-confirm ordering is the design safeguard that makes the uncertainty harmless on supply (`Server_SiteClearance.sqf:8-11`).

## Continue Reading

- [Construction and CoIn Systems Atlas](Construction-And-CoIn-Systems-Atlas) — the object-building build-menu paths Site Clearance deliberately bypasses
- [Server Composition Spawner Function Reference](Server-Composition-Spawner-Function-Reference) — structure/defense placement (`Server_ConstructPosition` / `CreateDefenseTemplate`) for contrast with this no-build action
- [Defense Structures Catalog](Defense-Structures-Catalog) — the `WFBE_%1DEFENSENAMES` defenses that `Land_Pneu` rides alongside in the build menu
- [Commanders Handbook](Commanders-Handbook) — the commander-only build powers this gate chain protects
- [Networking and Public Variables](Networking-And-Public-Variables) — the PVF / `SendToServer` channel model behind `RequestSiteClearance`
