# Client Marker FSM Updater Map (town, team, patrol, AICOM updaters)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page maps the four client-side marker-updater scripts under `Client/FSM/`. Each runs its own `while` loop on every client and writes only `...Local` markers, so every player paints a private, side-filtered view of the map that never replicates. The four cover distinct marker families: town supply-value text, friendly squad-leader arrows, friendly side-patrol arrows, and friendly AI-commander (HQ) arrows. Two of them (patrol, AICOM) consume a server-published feed; the other two read local/global state directly. Marker *content* (colours, text grammar, type glyphs across all families) is catalogued in [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog); the shared loop/registrar plumbing is in [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries).

## Spawn And Gate

All four are `execVM`'d from `Init_Client.sqf`. The side-identity globals they depend on (`sideID`, `clientTeams`, `WFBE_Client_SideID`) are set earlier in the same file.

| FSM script | Spawned at | Gate | Locality |
| --- | --- | --- | --- |
| `Client/FSM/updateteamsmarkers.sqf` | `Client/Init/Init_Client.sqf:404` | only if `WFBE_C_UNITS_TRACK_LEADERS > 0` (default `1`, `Common/Init/Init_CommonConstants.sqf:527`) | client-local |
| `Client/FSM/updatepatrolmarkers.sqf` | `Client/Init/Init_Client.sqf:405` | unconditional | client-local |
| `Client/FSM/updateaicommarkers.sqf` | `Client/Init/Init_Client.sqf:406` | unconditional | client-local |
| `Client/FSM/updatetownmarkers.sqf` | `Client/Init/Init_Client.sqf:418` | unconditional, but spawned inside a `[] Spawn` that first `waitUntil {townInit}` (`Init_Client.sqf:411-418`) | client-local |

Side-identity inputs (all `Client/Init/Init_Client.sqf`): `sideID = sideJoined Call GetSideID;` (`:257`), `clientTeams = ...WFBE_%1TEAMS` (`:259`), `WFBE_Client_SideID = sideID;` (`:311`). The global `towns` array is built in `Common/Init/Init_Town.sqf:165`.

## Per-Updater Detail

| Updater | Marker family / name pattern | Draws how | Cadence | Run conditions / per-marker write | Data source |
| --- | --- | --- | --- | --- | --- |
| `updatetownmarkers.sqf` | Town "Depot" markers; name `Format ["WFBE_%1_CityMarker", str _town]` (`:21`) | TEXT only — `setMarkerTextLocal`; never creates/colours (`:40,:42,:53,:60,:63`) | `while {!gameOver}`, fixed `sleep 5` (`:67`); NOT map-aware | per-town `_visible` if own side `(_town getVariable "sideID") == sideID` OR a live group unit within `range*WFBE_C_PLAYERS_MARKER_TOWN_RANGE` (`:20`); otherwise text cleared `""` (`:63`) | town logic `getVariable`s (`supplyValue`, `maxSupplyValue`, `supplyMissionCoolDownEnabled`, `LastSupplyMissionRun`); no feed |
| `updateteamsmarkers.sqf` | Own-side squad-leader "Arrow" markers, one per `clientTeams` entry; name `Format["%1AdvancedSquad%2Marker",_sideText,_count]` (`:22`) | CREATES + drives directly: `createMarkerLocal` (`:24`) then `setMarkerPos/Dir/Text/Alpha/Color Local` (`:196,:219,:227,:235,:243`) | `while {!gameOver}`; `sleep 0.5` skip when no map consumer visible, `sleep 0.2` when visible (`:61,:286`) | only updates while `visibleMap \|\| shownGPS` OR a Warfare dialog in `_wfMenuDisplays` is open (`:53-58`); AI leaders re-evaluated at most every 1 s (`:69-70,:185`); writes gated on actual change (`:195,:218,:226,:234,:242`) | `clientTeams` global + live `leader _team`; reads broadcast unit vars `WASP_AFK`, `wfbe_player_class` |
| `updatepatrolmarkers.sqf` | Friendly side-patrol arrows; name `Format["wfbe_patrolmarker_%1", _i]` (`:32`) | CREATES + drives directly: `createMarkerLocal` (`:35`), `setMarkerType/Color/Size/Text/Dir Local` (`:37-41`), follow via `setMarkerPos/Dir Local` (`:59,:68`), `deleteMarkerLocal` (`:73`) | `while {true}`; `sleep 0.5` when `visibleMap \|\| shownGPS`, else `sleep 5` (`:78`) | gated on `clientInitComplete` first (`:13`); friendly filter `_sid == WFBE_Client_SideID` (`:25`); drop when leader null/dead (`:53,:73`) | server feed `WFBE_ACTIVE_PATROLS` = `[[leaderUnit, sideID], ...]` (`:19`) |
| `updateaicommarkers.sqf` | Friendly AI-commander (HQ) arrows; name `Format["wfbe_aicommarker_%1", _i]` (`:56`) | CREATES + drives directly: `createMarkerLocal` (`:58`), `setMarkerType/Color/Size/Text/Dir Local` (`:59-63`), follow via `setMarkerPos/Dir Local` (`:96,:104`), `deleteMarkerLocal` (`:109`) | `while {true}`; `sleep 0.5` when `visibleMap \|\| shownGPS`, else `sleep 8` (`:114`) | gated on `clientInitComplete` (`:17`) + `waitUntil {!isNil "WFBE_Client_SideID"}` (`:33`); friendly filter `_sid == _mySid` where `_mySid = WFBE_Client_SideID` (`:34,:42`); drop when entry absent/null/leader dead (`:89,:109`) | server feed `WFBE_ACTIVE_AICOM_TEAMS` = `[[leaderUnit, sideID, dir, team], ...]` (`:23`) |

## Registrar Reuse Versus Direct Draw

None of the four reuse the shared `MarkerUpdate` registrar — each is a self-contained loop that calls `createMarkerLocal`/`setMarker*Local` itself. The patrol and AICOM headers state this explicitly (`updatepatrolmarkers.sqf:5-6`, `updateaicommarkers.sqf:9-10`), and they differ from the town/teams pair only in *where the data comes from*, not in how they write:

| Updater | Creates its own markers? | Reuses `MarkerUpdate`? | Input data origin |
| --- | --- | --- | --- |
| town | No — markers created in `Client/Init/Init_Markers.sqf:21-23` (`createMarkerLocal`, type `"Depot"`); FSM only rewrites text | No | local namespace + town-logic `getVariable` |
| teams | Yes — created once at startup (`:21-49`) | No | `clientTeams` global (own side's roster) |
| patrol | Yes — created on first sighting (`:35`) | No (header `:5`) | server `publicVariable` feed |
| AICOM | Yes — created on first sighting (`:58`) | No (header `:9-10`) | server `publicVariable` feed |

The town updater is the odd one: it owns *no* marker lifecycle. Existence, position, the `"Depot"` type and the side colour all live in `Init_Markers.sqf`, and recolour-on-capture is handled by `Client/PVFunctions/TownCaptured.sqf:23-24`. This FSM only ever calls `setMarkerTextLocal`. See [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries) for what `MarkerUpdate` does and which loops actually use it.

## Per-Marker Writes And Side Filtering

This is a structural summary; the exact text strings, glyph types and colour values are catalogued in [Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog).

| Updater | Verbs written | Friendly-only filter | Notes |
| --- | --- | --- | --- |
| town | `setMarkerTextLocal` only | visibility = own side OR group-unit-in-range (`:20`) | text is `"  SV: %1/%2 ..."` family (`:40-63`); cleared to `""` when not visible (`:63`) |
| teams | type/dir/size/alpha/colour at create (`:24-34`), then pos/dir/text/alpha/colour in loop (`:196-243`) | implicit — `clientTeams` is the player's own side only (`Init_Client.sqf:259`) | AI-led teams get alpha `0` + label `"AI"` (`:86-87`); player-led get alpha `1` and the name/class label (`:90-95`) |
| patrol | type/colour/size/text/dir at create (`:37-41`), then pos/dir in loop (`:59,:68`) | explicit `_sid == WFBE_Client_SideID` (`:25`) — enemy patrols never drawn | text `Format["Patrol %1", _i]` (`:40`); type `"mil_arrow2"` (`:37`) |
| AICOM | type/colour/size/text/dir at create (`:59-63`), then pos/dir in loop (`:96,:104`) | explicit `_sid == _mySid` (`:42`) using the stable joined-side id, NOT per-tick `side player` (`:24-34`) | text `"HQ Team"` (`:62`); colour by entry sideID via switch on `WFBE_C_WEST_ID/EAST_ID/GUER_ID` (`:49-54`); tracked by **team** not leader (`:65,:75`) |

The AICOM friendly filter is deliberately hardened: the header (`updateaicommarkers.sqf:24-32`) explains it uses the joined-side id captured at init rather than `side player`, because `side player` can resolve to a transient side during respawn/JIP/team-switch and would briefly leak enemy HQ arrows onto the map. The patrol filter has the same intent but a simpler form (`:25`).

## Server-Side Feed Maintenance

The patrol and AICOM feeds are declared and broadcast server-side in `Server/FSM/server_side_patrols.sqf` and mutated in `Server/Functions/Server_HandleSpecial.sqf`, each mutation followed by `publicVariable`. These are the only replicated state involved — the markers themselves never replicate.

| Feed | Declared | Entry shape | Added on | Removed on |
| --- | --- | --- | --- | --- |
| `WFBE_ACTIVE_PATROLS` | `Server/FSM/server_side_patrols.sqf:19` | `[leaderUnit, sideID]` | `"sidepatrol-started"`, then `publicVariable` (`Server/Functions/Server_HandleSpecial.sqf:351-352`) | `"sidepatrol-ended"`, then `publicVariable` (`Server/Functions/Server_HandleSpecial.sqf:372`) |
| `WFBE_ACTIVE_AICOM_TEAMS` | `Server/FSM/server_side_patrols.sqf:23` | `[leaderUnit, sideID, dir, team]` | `"aicom-team-created"`, then `publicVariable` (`Server/Functions/Server_HandleSpecial.sqf:232-233`) | `"aicom-team-ended"`, then `publicVariable` (`Server/Functions/Server_HandleSpecial.sqf:251`) |

The AICOM arrow direction (`dir`, slot 2) is patched in place by the `"aicom-team-heading"` case and re-broadcast, only when the bearing moves (`Server/Functions/Server_HandleSpecial.sqf:277-299`); the client re-reads slot 2 each tick (`updateaicommarkers.sqf:85`). The broadcast unit vars the teams updater consumes are set elsewhere: `WASP_AFK` with the global flag in `Client/FSM/updateclient.sqf:134`, and `wfbe_player_class` in `Client/Module/Skill/Skill_Init.sqf:68`.

## Quirks Worth Knowing

| Quirk | Where | Detail |
| --- | --- | --- |
| Town loop is not map-aware | `updatetownmarkers.sqf:67` | fixed `sleep 5` regardless of map/GPS state — unlike the other three, which all slow down when the map is closed |
| Blocking `waitUntil` inside the per-town loop | `updatetownmarkers.sqf:38` | on the supply-ready branch it does `waitUntil { !(isNil "WFBE_SK_V_Type") }` inside `forEach towns`; if the local class string never set, the whole town pass stalls |
| Supply-ready sound side effect | `updatetownmarkers.sqf:28-32` | plays `"ARTY_cooldown_over"` when a town's cooldown transitions active→ready AND the local player is `SpecOps` |
| Stale patrol header | `updatepatrolmarkers.sqf:4` | header calls the marker a "yellow circle", but creation uses type `"mil_arrow2"` (`:37`) — it is an arrow |
| Teams arrow points the way of travel | `updateteamsmarkers.sqf:202-214` | dir is derived from velocity heading when `_spd > 1.2`, falling back to `getDir` at rest, so the arrow shows movement not facing |
| AICOM keyed by team, patrol keyed by unit | `updateaicommarkers.sqf:19,:65`; `updatepatrolmarkers.sqf:43` | AICOM tracks by the stable team object (leader can change); patrol tracks by the leader unit |
| Camp markers untouched here | `Client/Init/Init_Markers.sqf:45-46` | `WFBE_%1_CityMarker_Camp%2` (type `"Strongpoint"`) is a sibling family created at init but driven by no FSM in this slice |

## Continue Reading

[Map Marker Families Content Catalog](Map-Marker-Families-Content-Catalog) | [Marker Loop Engine and Registries](Marker-Loop-Engine-And-Registries) | [Marker Subsystem Function Reference](Marker-Subsystem-Function-Reference) | [Side Patrol Runtime And Convoy Mechanics](Side-Patrol-Runtime-And-Convoy-Mechanics) | [Quad AI Commander](Quad-AI-Commander)
