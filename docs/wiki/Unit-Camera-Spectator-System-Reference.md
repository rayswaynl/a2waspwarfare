# Unit Camera Spectator System Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`RscMenu_UnitCamera` is the in-dialog spectator camera the commander drives after the Tactical menu launches it. The dialog body lives in one file, `Client/GUI/GUI_Menu_UnitCamera.sqf` (130 lines), which builds two player/unit listboxes plus a camera-mode listbox over an embedded minimap, then runs a 0.1s loop that resolves a target unit-or-vehicle and applies `switchCamera` to it. This page documents that runtime body: the camera modes, the listboxes, the map-click-to-spectate path, the unflip button, the dead-unit fallback, and teardown. The launch gate (the `commandInRange` check and the no-fee entry point) is owned by [Tactical-Support-Menu-Player-Guide](Tactical-Support-Menu-Player-Guide); the dialog's IDC registration and minimap geometry are owned by [Client-UI-Systems-Atlas](Client-UI-Systems-Atlas) and [Map-Control-Template-And-Minimap-Embed-Reference](Map-Control-Template-And-Minimap-Embed-Reference).

## Launch and teardown

The Tactical menu's `Units_Camera` request closes itself and opens this dialog. Entry is gated on `commandInRange` (the control is enabled only when that flag is true); there is no fee.

| Step | Location | Behavior |
| --- | --- | --- |
| Enable gate | `Client/GUI/GUI_Menu_Tactical.sqf:283-284` | `case "Units_Camera": { _controlEnable = commandInRange; }` |
| Launch | `Client/GUI/GUI_Menu_Tactical.sqf:339-342` | `closeDialog 0; createDialog "RscMenu_UnitCamera";` |
| Dialog init | `Client/GUI/GUI_Menu_UnitCamera.sqf:6-10` | `disableSerialization`; caches `_display`; resets `MenuAction`, `mouseButtonUp`, and `WF_MenuAction` to `-1` (latch reset, mirroring other map-click dialogs per Client-UI-Systems-Atlas:95) |
| Teardown | `Client/GUI/GUI_Menu_UnitCamera.sqf:130-131` | After the loop exits, `closeDialog 0;` then `((player) Call GetUnitVehicle) switchCamera _currentMode;` restores the viewer's own camera |

Note that teardown reuses `_currentMode`, so the viewer's restored camera inherits whatever mode the spectator last selected, applied to their own unit-or-vehicle.

## Camera modes

The mode applied to `switchCamera` is taken from a fixed four-element array, not from the listbox labels.

| Item | Location | Detail |
| --- | --- | --- |
| Mode array | `GUI_Menu_UnitCamera.sqf:12` | `_cameraModes = ["Internal","External","Gunner","Group"]` — these strings are passed to `switchCamera` |
| Initial mode | `GUI_Menu_UnitCamera.sqf:33-34` | `_currentMode = "Internal"; _currentUnit switchCamera _currentMode;` |
| Listbox labels | `GUI_Menu_UnitCamera.sqf:43-45` | `_type = if (!(difficultyEnabled "3rdPersonView")) then {["Internal"]} else {["Internal","External","Ironsight","Group"]};` populates listbox `21006`, pre-selecting index 0 |
| Mode select | `GUI_Menu_UnitCamera.sqf:97-100` | On `MenuAction == 103`, `_currentMode = (_cameraModes select (lbCurSel 21006));` |

There is a label/value mismatch worth flagging: listbox index 2 is shown to the player as **"Ironsight"** (line 43) but `_cameraModes select 2` resolves to **"Gunner"** (line 12). Selecting the third row therefore enters gunner view, not ironsight. When `3rdPersonView` is disabled in difficulty, only "Internal" appears in the listbox, so the player can pick no other mode.

## Player list (listbox 21002)

On open, the dialog enumerates `clientTeams` and lists only groups whose leader is a human player, so empty AI slots are excluded. The viewer's own group is pre-selected.

| Item | Location | Detail |
| --- | --- | --- |
| Build list | `GUI_Menu_UnitCamera.sqf:18-26` | `forEach clientTeams`: if `isPlayer (leader _x)`, append the group to `_list_Players` and `lbAdd[21002,Format["[%1] %2",_n,name (leader _x)]]`; `_n` is the displayed index |
| Pre-select self | `GUI_Menu_UnitCamera.sqf:28-31` | `_player_group = group player; _id = clientTeams find _player_group; lbSetCurSel[21002,_id];` |
| Leader select | `GUI_Menu_UnitCamera.sqf:74-86` | On `MenuAction == 101`, resolves `_selected = leader (_list_Players select (lbCurSel 21002))`, sets `_currentUnit` to that leader's unit-or-vehicle, rebuilds the AI list, and flags `_cameraSwap = true` |

The selected-index `_id` is computed against `clientTeams` (the raw team list), while the listbox rows come from the filtered `_list_Players`. The two indices coincide only when no AI-led groups precede the viewer's group in `clientTeams`; with AI-led groups present, the pre-selected row can point at a different entry than the viewer's own group.

## AI-unit list (listbox 21004)

For the selected leader, the dialog lists that leader's live subordinate units (the leader itself excluded), each labelled with its AI digit, vehicle display name, and unit name.

| Item | Location | Detail |
| --- | --- | --- |
| Initial units | `GUI_Menu_UnitCamera.sqf:35` | `_units = (Units (group player) - [player]) Call GetLiveUnits;` |
| Row format | `GUI_Menu_UnitCamera.sqf:37-40` | Per unit: `_unitNumber = (_x) Call GetAIDigit;` then `lbAdd[21004,Format["[%1] (%2) %3", _unitNumber, GetText (configFile >> "CfgVehicles" >> (typeOf (vehicle _x)) >> "displayName"), name _x]]` |
| Rebuild on leader change | `GUI_Menu_UnitCamera.sqf:79-84` | `lbClear 21004` then re-populate from `(Units (group _selected) - [_selected]) Call GetLiveUnits` |
| AI select | `GUI_Menu_UnitCamera.sqf:90-93` | On `MenuAction == 102`, `_currentUnit = (_units select (lbCurSel 21004)) Call GetUnitVehicle;` and flag a camera swap |

`GetAIDigit` and `GetUnitVehicle` are generic helpers documented elsewhere — see [Namespace-Profile-And-Diagnostic-Utility-Reference](Namespace-Profile-And-Diagnostic-Utility-Reference) and [Array-And-Collection-Utility-Reference](Array-And-Collection-Utility-Reference). `GetUnitVehicle` resolves a man to their vehicle when mounted, which is why spectating a crewed unit frames the vehicle.

## Map-click spectate

Clicking the embedded minimap (control `21007`) picks the nearest valid entity at the clicked world position. The latch `mouseButtonUp` is set by input handling and consumed here.

| Step | Location | Behavior |
| --- | --- | --- |
| Consume latch | `GUI_Menu_UnitCamera.sqf:58-59` | `if (mouseButtonUp == 0) then { mouseButtonUp = -1;` |
| Screen to world | `GUI_Menu_UnitCamera.sqf:60` | `_near = _map PosScreenToWorld[mouseX,mouseY];` |
| Candidate scan | `GUI_Menu_UnitCamera.sqf:61` | `_list = _near nearEntities [["Man","Car","Motorcycle","Ship","Tank","Air"],200];` (200 m radius) |
| Side filter | `GUI_Menu_UnitCamera.sqf:64` | Per candidate: a friendly entity (`side _x == sideJoined`) is appended to `_objects`; an empty enemy vehicle has a (no-op) removal applied |
| Resolve nearest | `GUI_Menu_UnitCamera.sqf:65-67` | If any friendly candidate, `_currentUnit = ([_near,_objects] Call WFBE_CO_FNC_GetClosestEntity) Call GetUnitVehicle;` and `_cameraSwap = true` |

The filter at line 64 only ever **adds** friendly entities to `_objects` (the array starts empty at line 63); the enemy-empty-vehicle branch performs `_objects - [_x]` on an array that does not yet contain `_x`, so it has no effect. In practice the result is: only friendly entities within 200 m of the click are eligible, and the closest of them is spectated. `WFBE_CO_FNC_GetClosestEntity` is the same closest-entity helper used by the fired event handler (`Client/Functions/Client_FNC_OnFired.sqf:22`).

## Unflip button and dead-unit fallback

A dedicated unflip button lets the spectator right a flipped friendly vehicle, and a guard snaps the camera home when the spectated unit dies.

| Item | Location | Behavior |
| --- | --- | --- |
| Unflip trigger | `GUI_Menu_UnitCamera.sqf:103-104` | `if (WF_MenuAction == 140 && !(isNil "_currentUnit")) then { WF_MenuAction = -1;` |
| Player guard | `GUI_Menu_UnitCamera.sqf:106` | Only acts `if(!(isPlayer (_currentUnit)))` — players are not nudged |
| Nudge | `GUI_Menu_UnitCamera.sqf:107-110` | `_vehicle = vehicle _currentUnit;` then `_vehicle setPos [...x, ...y, 0.5]; _vehicle setVelocity [0,0,-0.5];` — drops the vehicle to z=0.5 with a small downward velocity so it settles upright |
| Swap after unflip | `GUI_Menu_UnitCamera.sqf:113` | `_cameraSwap = true;` |
| Dead-unit fallback | `GUI_Menu_UnitCamera.sqf:116-119` | `if !(alive _currentUnit) then { _currentUnit = (player) Call GetUnitVehicle; _cameraSwap = true; };` |

The nudge does not teleport or rotate the vehicle; it re-seats it at z=0.5 above its current x/y and lets engine physics resolve the upright orientation as it falls. For a general treatment of vehicle recovery, see [AutoFlip-Vehicle-Recovery-Reference](AutoFlip-Vehicle-Recovery-Reference).

## The per-frame loop

The body of the dialog is a `while {true}` loop sleeping 0.1s per iteration, with an exit guard and a single camera-update block that runs when any action set `_cameraSwap`.

| Step | Location | Behavior |
| --- | --- | --- |
| Loop and tick | `GUI_Menu_UnitCamera.sqf:51-52` | `while {true} do { sleep 0.1;` |
| Reset swap flag | `GUI_Menu_UnitCamera.sqf:54` | `_cameraSwap = false;` each iteration |
| Exit guard | `GUI_Menu_UnitCamera.sqf:55` | `if (side group player != sideJoined || !dialog) exitWith {};` — leaves the loop (and proceeds to teardown) if the player changed side or the dialog closed |
| Camera update | `GUI_Menu_UnitCamera.sqf:122-127` | If `_cameraSwap`: `ctrlMapAnimClear _map;` then animate the minimap to `getPos _currentUnit` over 0.25 and `_currentUnit switchCamera _currentMode;` |

Every interaction path — map click, leader select, AI select, mode change, unflip, dead-unit fallback — funnels into the one `_cameraSwap` block, so the minimap re-centers on the target and `switchCamera` re-applies on the same frame the selection changes. The initial minimap animation is set up once on open at `GUI_Menu_UnitCamera.sqf:47-49` (`ctrlMapAnimAdd [0,.25,getPos _currentUnit]`), before the loop starts.

## Continue Reading

- [Tactical-Support-Menu-Player-Guide](Tactical-Support-Menu-Player-Guide) — the launch gate, `commandInRange`, and no-fee entry point for this dialog
- [Client-UI-Systems-Atlas](Client-UI-Systems-Atlas) — `RscMenu_UnitCamera` IDC 21000 registration and the map-click latch-reset convention
- [Map-Control-Template-And-Minimap-Embed-Reference](Map-Control-Template-And-Minimap-Embed-Reference) — the embedded `CA_MiniMap` (control 21007) geometry used by this dialog
- [AutoFlip-Vehicle-Recovery-Reference](AutoFlip-Vehicle-Recovery-Reference) — broader vehicle-righting mechanics related to the unflip button
- [Array-And-Collection-Utility-Reference](Array-And-Collection-Utility-Reference) — `GetUnitVehicle` and related collection helpers used to resolve the spectated target
