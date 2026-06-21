# End-Of-Game Stats Victory Screen

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The end-of-game victory screen is the title-resource scoreboard every client cuts up when a match ends. It is a single client GUI script, `Client/GUI/GUI_EndOfGameStats.sqf`, that renders four faction-comparison rows (soldiers recruited, soldiers lost, vehicles built, vehicles lost) as animated count-up numbers and growing bars, one column per side. The numbers it shows are not computed at end-game: they are four cumulative per-side counters that `WF_Logic` has been accumulating across the whole match through one tiny producer, `Common/Functions/Common_UpdateStatistics.sqf`. The [Victory and Endgame Atlas](Victory-And-Endgame-Atlas) owns the win-condition loop and the outro camera; this page documents only the renderer and the counter pipeline that feeds it, which that atlas references but does not describe.

This page covers: the renderer's read/normalize/animate flow, the `EndOfGameStats` title resource and its IDC layout, the `UpdateStatistics` accumulator, where the counters are zeroed, and the full set of producer call sites that increment them.

## How the screen is reached

`GUI_EndOfGameStats.sqf` is not called by the win loop directly. It is launched from the loser-side outro driver, `Client/Client_EndGame.sqf`, which receives the *losing* side, flips it to the *winning* side, and `ExecVM`s the renderer with that winner.

| Step | Path:line | Detail |
| --- | --- | --- |
| Caller receives losing side | `Client/Client_EndGame.sqf:3,5` | `_side = _this;` with comment `//todo improve that script, _side is the looser.` |
| Flip loser to winner | `Client/Client_EndGame.sqf:7-11` | `if (_side == west) then {_side = east} else { if (_side == east) then {_side = west} };` |
| Launch renderer | `Client/Client_EndGame.sqf:13` | `[_side] ExecVM "Client\GUI\GUI_EndOfGameStats.sqf";` — passes the winning side |
| Play outro music + run base flyover | `Client/Client_EndGame.sqf:15-86` | `playMusic "wf_outro"`, then a camera tour of each side's structures; ends `failMission "END1"` at `:89` |

Note the flip only handles WEST and EAST explicitly; a `resistance` winner falls through unchanged, so the renderer would receive `resistance` and take the "not West" branch (treated as East) at `GUI_EndOfGameStats.sqf:6-7`.

## Renderer: GUI_EndOfGameStats.sqf

A client-side title-resource script (`disableSerialization` at line 1) that cuts the `EndOfGameStats` resource, fills in the winning-side title, then for each of eight bars normalizes the counter to a fixed-width bar and animates a count-up. Signature: `[_side]` where `_side` is the winning side.

| Phase | Path:line | Behavior |
| --- | --- | --- |
| Clear prior title layer | `GUI_EndOfGameStats.sqf:3` | `12450 cutText ["","PLAIN",0];` blanks title layer 12450 |
| Resolve winner name | `GUI_EndOfGameStats.sqf:5-8` | `_side select 0`; localizes `STR_WF_PARAMETER_Side_East` (default) or `STR_WF_PARAMETER_Side_West`, then `Format[Localize "STR_WF_END_Victory",_sideText]` → "<Side> Team has won" |
| Cut the resource | `GUI_EndOfGameStats.sqf:10-13` | `_width = 0.4`; `TitleText["","PLAIN"]`; `sleep 0.5`; `CutRsc["EndOfGameStats","PLAIN",0]` |
| Read 8 counters | `GUI_EndOfGameStats.sqf:15-22` | `WF_Logic getVariable "eastUnitsCreated"` and the 7 siblings (see counter table below) |
| Compute count-up rates | `GUI_EndOfGameStats.sqf:24-32` | per stat: `rate = value / 5 * .1` (i.e. `value/50` per 0.1s tick → full value in ~5s, capped by the 8s loop) |
| Wait for display, set title | `GUI_EndOfGameStats.sqf:34-35` | `waitUntil {!isNull (["currentCutDisplay"] call BIS_FNC_GUIget)}`, then `DisplayCtrl 90001 CtrlSetText _sideName` |
| Bind west controls | `GUI_EndOfGameStats.sqf:37-44` | counter/bar control pairs 90200-90207 |
| Animate west bars | `GUI_EndOfGameStats.sqf:46-84` | per bar: normalize, commit width 0 instantly, then commit target over 8s |
| Bind east controls | `GUI_EndOfGameStats.sqf:86-93` | counter/bar control pairs 90101-90108 |
| Animate east bars | `GUI_EndOfGameStats.sqf:95-133` | same normalize/commit pattern |
| Count-up loop | `GUI_EndOfGameStats.sqf:135-182` | 8-second `while {_timePassed < 8}` loop, `sleep 0.1`, increments all 8 numeric counters |

### The eight counters it reads

The renderer reads four stats per side off `WF_Logic`. The variable name is `<side><stat>` (lowercase side prefix as hardcoded in the script).

| Renderer local | WF_Logic key (read) | Path:line | Stat |
| --- | --- | --- | --- |
| `_eastUnitsCreated` | `eastUnitsCreated` | `GUI_EndOfGameStats.sqf:15` | East soldiers recruited |
| `_eastCasualties` | `eastCasualties` | `GUI_EndOfGameStats.sqf:16` | East soldiers lost |
| `_eastVehiclesCreated` | `eastVehiclesCreated` | `GUI_EndOfGameStats.sqf:17` | East vehicles built |
| `_eastVehiclesLost` | `eastVehiclesLost` | `GUI_EndOfGameStats.sqf:18` | East vehicles lost |
| `_westUnitsCreated` | `westUnitsCreated` | `GUI_EndOfGameStats.sqf:19` | West soldiers recruited |
| `_westCasualties` | `westCasualties` | `GUI_EndOfGameStats.sqf:20` | West soldiers lost |
| `_westVehiclesCreated` | `westVehiclesCreated` | `GUI_EndOfGameStats.sqf:21` | West vehicles built |
| `_westVehiclesLost` | `westVehiclesLost` | `GUI_EndOfGameStats.sqf:22` | West vehicles lost |

Case note: the renderer reads lowercase-prefixed keys (`westUnitsCreated`), while both the producer (`str _side` / `sideJoinedText = str sideJoined`, which yield uppercase `"WEST"`) and the Init_Server zeroing (`Format["%1UnitsCreated",_side]`, which stringifies the side value to `"WEST"`) write uppercase-prefixed keys (`WESTUnitsCreated`). These resolve to the same slot because Arma's namespace variable keys are case-insensitive, so the screen reads the values the match accumulated despite the apparent prefix mismatch. There is no `KilledEnemy` row on this screen even though that counter is maintained alongside the others (see zeroing table); it feeds COMBATSTAT, not the scoreboard.

### Bar normalization

Each bar is an `RscText` whose width (`position select 2`) is driven to a fraction of the fixed `_width = 0.4`. The divisor differs by stat: soldier counts saturate at 500, vehicle counts at 150, and the result is clamped never to exceed `_width`.

| Bar | Path:line | Normalization | Saturates at |
| --- | --- | --- | --- |
| Soldiers recruited (per side) | `GUI_EndOfGameStats.sqf:47-48`, `96-97` | `_width * (UnitsCreated / 500)`, capped to `_width` | 500 |
| Soldiers lost (per side) | `GUI_EndOfGameStats.sqf:57-58`, `106-107` | `_width * (Casualties / 500)`, capped to `_width` | 500 |
| Vehicles built (per side) | `GUI_EndOfGameStats.sqf:67-68`, `116-117` | `_width * (VehiclesCreated / 150)`, capped to `_width` | 150 |
| Vehicles lost (per side) | `GUI_EndOfGameStats.sqf:77-78`, `126-127` | `_width * (VehiclesLost / 150)`, capped to `_width` | 150 |

The animation idiom is the same for every bar (e.g. west recruited at `GUI_EndOfGameStats.sqf:46-54`): read `CtrlPosition`, `Set[2,0]` then `CtrlCommit 0` to snap to zero width, then `Set[2,<normalized>]` then `CtrlCommit 8` to grow to target width over 8 seconds. The bar grow and the numeric count-up therefore play in parallel over the same ~8s window.

### Count-up loop

`GUI_EndOfGameStats.sqf:135-182` runs an 8-second loop (`_timePassed` starts 0, `sleep 0.1`, `+0.1` per pass). Each pass advances all eight numeric counters by their precomputed `rate` (`value / 5 * .1`), clamps each to its target value (`if (_count > _target) then {_count = _target}`), and writes the integer part via `CtrlSetText Format["%1", _count - (_count % 1)]` (e.g. east recruited at `:149-151`). Because `rate = value/50` per tick and there are 80 ticks, every counter reaches its target well before the loop ends and then holds. The script ends when `_timePassed` reaches 8; the resource itself persists per its `duration` (see resource table).

## The EndOfGameStats title resource

Defined in `Rsc/Titles.hpp:580-769`. A `idd = 90000` title resource with a 15000ms `duration`. Its `onLoad`/`onUnload` route through the shared `currentCutDisplay` helper, which is the source of the documented title-handle collision (see Continue Reading).

| Property | Path:line | Value |
| --- | --- | --- |
| `idd` | `Rsc/Titles.hpp:581` | 90000 |
| `duration` | `Rsc/Titles.hpp:582` | 15000 |
| `onLoad` | `Rsc/Titles.hpp:587` | `_this ExecVM "Client\GUI\GUI_SetCurrentCutDisplay.sqf"` |
| `onUnload` | `Rsc/Titles.hpp:588` | `_this ExecVM "Client\GUI\GUI_ClearCurrentCutDisplay.sqf"` |

### Control IDC map

The renderer addresses controls by IDC through `(["currentCutDisplay"] call BIS_FNC_GUIget) DisplayCtrl <idc>`. East count/bar pairs run 90101-90108; West pairs run 90200-90207; the title is 90001. Counter classes inherit from `SoldiersRecruitedCountBase` (`idc = 90100`, `Rsc/Titles.hpp:654`); bars are `style = 128` `RscText` blocks.

| Stat row | East count IDC | East bar IDC | West count IDC | West bar IDC | Hpp lines |
| --- | --- | --- | --- | --- | --- |
| Soldiers recruited | 90101 | 90102 | 90200 | 90201 | `Rsc/Titles.hpp:665-687` |
| Soldiers lost | 90103 | 90104 | 90202 | 90203 | `Rsc/Titles.hpp:694-714` |
| Vehicles created | 90105 | 90106 | 90204 | 90205 | `Rsc/Titles.hpp:721-741` |
| Vehicles lost | 90107 | 90108 | 90206 | 90207 | `Rsc/Titles.hpp:748-768` |

Title and frame controls: `SideWinsText` `idc = 90001` (`Rsc/Titles.hpp:608-609`); `StatsBackGroundHeader` 90002; `StatsBackGround` 90003. Faction imagery: `EastImage` uses `ruflag` (`Rsc/Titles.hpp:629-635`), `WestImage` uses `usflag` (`Rsc/Titles.hpp:638-641`). Row labels read localized strings `STR_WF_END_Soldier_Recruited`, `STR_WF_END_Soldier_Lost`, `STR_WF_END_Vehicle_Built`, `STR_WF_END_Vehicle_Lost` (`Rsc/Titles.hpp:651,691,718,745`), all present in `stringtable.xml:740-768`.

## Producer: Common_UpdateStatistics.sqf (UpdateStatistics)

The accumulator behind every counter. A one-line function compiled to the global `UpdateStatistics` at `Common/Init/Init_Common.sqf:86`.

| Aspect | Detail |
| --- | --- |
| Path | `Common/Functions/Common_UpdateStatistics.sqf:1` |
| Compile binding | `UpdateStatistics = Compile preprocessFileLineNumbers "Common\Functions\Common_UpdateStatistics.sqf";` (`Common/Init/Init_Common.sqf:86`) |
| Params | `[_side, _var, _val]` — side string, stat-name suffix, increment amount |
| Body | `WF_Logic setVariable [Format["%1%2",_side,_var], ((WF_Logic getVariable Format["%1%2",_side,_var]) + _val), true];` |
| Behavior | Reads the current `<side><var>` counter on `WF_Logic`, adds `_val`, writes it back with the public flag `true` so it broadcasts to all machines (the renderer can read it on any client) |
| Returns | nothing meaningful (last statement is the setVariable) |

Because the key is built as `Format["%1%2",_side,_var]`, the same function maintains every counter; the four scoreboard stats are just the `_var` values `UnitsCreated`, `Casualties`, `VehiclesCreated`, `VehiclesLost`, plus the non-scoreboard `KilledEnemy`.

## Counter zeroing (per side, at game setup)

The five `WF_Logic` counters are reset to 0 for each present side inside the per-side init loop in `Server/Init/Init_Server.sqf`. The loop variable `_side` is a side value (`_x select 1`, `Server/Init/Init_Server.sqf:381`), which `Format` stringifies into the key prefix.

| Path:line | Statement |
| --- | --- |
| `Server/Init/Init_Server.sqf:453` | `WF_Logic setVariable [Format["%1UnitsCreated",_side],0,true];` |
| `Server/Init/Init_Server.sqf:454` | `WF_Logic setVariable [Format["%1Casualties",_side],0,true];` |
| `Server/Init/Init_Server.sqf:455` | `WF_Logic setVariable [Format["%1VehiclesCreated",_side],0,true];` |
| `Server/Init/Init_Server.sqf:456` | `WF_Logic setVariable [Format["%1VehiclesLost",_side],0,true];` |
| `Server/Init/Init_Server.sqf:457` | `WF_Logic setVariable [Format["%1KilledEnemy",_side],0,true];` — feeds COMBATSTAT, not the scoreboard |

The `//todo improve.` comment at `Server/Init/Init_Server.sqf:452` sits directly above this block.

## Where each counter is incremented

`UnitsCreated` and `VehiclesCreated` are written from the many unit/vehicle creation paths; `Casualties` and `VehiclesLost` are written from the kill handler. All sites pass an uppercase side string (`str _side` / `_sideText = str _side` / `sideJoinedText`).

| Counter | Call site (path:line) | Context |
| --- | --- | --- |
| UnitsCreated | `Server/Functions/Server_BuyUnit.sqf:88,229` | Server buys a soldier / batch |
| VehiclesCreated | `Server/Functions/Server_BuyUnit.sqf:179` | Server buys a vehicle |
| UnitsCreated | `Client/Functions/Client_BuildUnit.sqf:302,548` | Client-built soldier / batch (`sideJoinedText`) |
| VehiclesCreated | `Client/Functions/Client_BuildUnit.sqf:380` | Client-built vehicle |
| UnitsCreated | `Client/Functions/Client_PreRespawnHandler.sqf:39` | Pre-respawn unit accounting |
| UnitsCreated | `Client/Init/Init_Client.sqf:816` | Initial client unit |
| UnitsCreated / VehiclesCreated | `Client/Module/UAV/uav.sqf:47-48` | UAV crew + airframe |
| UnitsCreated | `Server/AI/AI_SquadRespawn.sqf:16` | AI squad respawn |
| UnitsCreated / VehiclesCreated | `Common/Functions/Common_CreateTownUnits.sqf:96-97` | Town garrison spawn (gated `_built > 0` / `_builtveh > 0`) |
| UnitsCreated | `Common/Functions/Common_CreateUnitForStaticDefence.sqf:192` | Static-defense gunner spawn |
| UnitsCreated | `Common/Functions/Common_CreateUnitsForResBases.sqf:44` | Resistance base spawn |
| UnitsCreated | `Server/Functions/Server_HandleDefense.sqf:96` | Server defense unit |
| VehiclesCreated / UnitsCreated | `Server/Support/Support_Paratroopers.sqf:68,89`; `Support_ParaAmmo.sqf:31-32`; `Support_ParaVehicles.sqf:30-31` | Paradrop support inserts |
| Casualties / VehiclesLost | `Server/PVFunctions/RequestOnUnitKilled.sqf:183` | On kill: man → `Casualties`, else → `VehiclesLost`, gated `_killed_side in WFBE_PRESENTSIDES` |
| KilledEnemy (not on screen) | `Server/PVFunctions/RequestOnUnitKilled.sqf:190` | Credits killer side for a downed enemy; feeds COMBATSTAT |

The kill-side `Casualties`/`VehiclesLost` write at `RequestOnUnitKilled.sqf:183` is the same producer the [Kill And Score Pipeline](Kill-And-Score-Pipeline) documents as its faction-level counter step; this page's scope is the rest of the producer set and the screen that consumes all of it.

## Continue Reading

- [Victory and Endgame Atlas](Victory-And-Endgame-Atlas) — the win-condition loop and outro that trigger this screen via `Client_EndGame.sqf`
- [Kill and Score Pipeline](Kill-And-Score-Pipeline) — the kill handler that produces the `Casualties` / `VehiclesLost` counters
- [UI IDD Collision Repair](UI-IDD-Collision-Repair) — the `currentCutDisplay` shared-handle collision this resource participates in
- [Client UI Systems Atlas](Client-UI-Systems-Atlas) — catalog of title resources and HUD display ownership
- [Networking and Public Variables](Networking-And-Public-Variables) — how the `WF_Logic setVariable [...,true]` broadcast reaches every client
