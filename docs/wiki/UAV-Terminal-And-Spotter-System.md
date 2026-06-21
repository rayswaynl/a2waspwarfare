# UAV Terminal and Spotter System (live orbit drone)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The live UAV is a player-launched reconnaissance drone, distinct from the Takistan-airfield FPV-drone branch feature. The Tactical Center spends supply on a UAV upgrade, then a player spawns the drone at the command-center factory for a flat cash fee, takes camera control through the vanilla `BIS_UAV` terminal (with a separate OA-interface variant), and the drone auto-flies a circular orbit while a server-side spotter loop reveals fuzzed enemy positions onto the map. The whole flow lives in `Client/Module/UAV/` plus a server cleanup monitor.

This page documents the build/gate, the orbit auto-route planner, the camera/minimap/aperture terminal (vanilla vs OA), and the spotter intel reveal pipeline. It is NOT the recon-uav / Takistan FPV drone — see [Takistan Airfield FPV Drone Design](Takistan-Airfield-FPV-Drone-Design).

## Build, gate, and cost

The UAV is reached from the Tactical Center menu. The list entry `"UAV"` is enabled only when the side has the UAV upgrade and the player can pay.

| Element | Value | Citation |
|---|---|---|
| Tactical menu entry id | `"UAV"` (index 6 of the special list) | Client/GUI/GUI_Menu_Tactical.sqf:59 |
| Enable gate | `_funds >= _currentFee && WFBE_UP_UAV level > 0 && !(alive playerUAV)` | Client/GUI/GUI_Menu_Tactical.sqf:273-275 |
| Displayed fee (menu) | `12500` (fee list index 6) | Client/GUI/GUI_Menu_Tactical.sqf:60 |
| Selecting `UAV` | `closeDialog 0; ExecVM "Client\Module\UAV\uav.sqf"` | Client/GUI/GUI_Menu_Tactical.sqf:324-327 |
| `UAV_Remote_Control` (re-enter live UAV) | same `ExecVM uav.sqf` | Client/GUI/GUI_Menu_Tactical.sqf:335-337 |
| `UAV_Destroy` | sets full damage on `playerUAV` + crew, nulls it | Client/GUI/GUI_Menu_Tactical.sqf:328-334 |
| Upgrade constant | `WFBE_UP_UAV = 5` | Common/Init/Init_CommonConstants.sqf:42 |

The fee shown in the menu (`12500`) is the gate; the *actual* debit happens inside the spawn script:

| Spawn step | Detail | Citation |
|---|---|---|
| Re-entry shortcut | if `playerUAV` already alive, just re-open the interface and exit | Client/Module/UAV/uav.sqf:4-13 |
| Faction gate | exits if `WFBE_%1UAV` (by `sideJoinedText`) is nil or `""` | Client/Module/UAV/uav.sqf:15-16 |
| Spawn anchor | nearest command-center factory (`WFBE_%1COMMANDCENTERTYPE`) to the player | Client/Module/UAV/uav.sqf:18-25 |
| Create drone | `createVehicle [WFBE_%1UAV, getPos factory, [], 0, "FLY"]` → `playerUAV` | Client/Module/UAV/uav.sqf:27-28 |
| Crew | driver always; **gunner only for `west`** (OPFOR UAV has no gunner slot) | Client/Module/UAV/uav.sqf:33-46 |
| Cash debit | `-12500 Call ChangePlayerFunds` | Client/Module/UAV/uav.sqf:50 |
| Server hand-off | `["RequestSpecial", ["uav",sideJoined,_uav,clientTeam]] Call WFBE_CO_FNC_SendToServer` | Client/Module/UAV/uav.sqf:52 |
| Targeting | driver `disableAI ["TARGET","AUTOTARGET"]` so it just orbits | Client/Module/UAV/uav.sqf:7, 37-38 |

The UAV research upgrade itself is a single level, gated behind Air Superiority:

| Upgrade attribute | Value | Citation |
|---|---|---|
| Availability | enabled only if `WFBE_%1UAV` is defined for the side | Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:11 |
| Cost | `[[2000,0]]` (2000 supply, single level) | Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:38 |
| Prerequisite | `[[WFBE_UP_AIR,2]]` (Air upgrade level 2) | Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:98 |
| Research time | `[60]` seconds | Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:130 |

### Per-faction UAV classnames

| Side var | Classname | Citation |
|---|---|---|
| `WFBE_%1UAV` (US) | `MQ9PredatorB_US_EP1` | Common/Config/Core_Root/Root_US.sqf:20 |
| `WFBE_%1UAV` (RU) | `Pchela1T` | Common/Config/Core_Root/Root_RU.sqf:18 |

## Orbit auto-route planner

After spawn, `uav.sqf` runs a self-renewing waypoint loop that keeps the drone circling. Each pass plants four `MOVE` waypoints on a 1000m-radius ring around the last waypoint, and a background spawn keeps appending the next ring point as the drone advances — so the patrol never runs out of route.

| Planner element | Value | Citation |
|---|---|---|
| Orbit radius | `_radius = 1000` | Client/Module/UAV/uav.sqf:58 |
| Waypoints per ring | `_wpcount = 4`, step `360/4 = 90°` | Client/Module/UAV/uav.sqf:59-60 |
| Ring point math | `[_lastWPpos, 1000, _dir+_add] call bis_fnc_relPos` | Client/Module/UAV/uav.sqf:88, 110 |
| Waypoint type | `"MOVE"`, blank description (`' '`) | Client/Module/UAV/uav.sqf:90-91, 112-113 |
| Completion radius | `1000/_wpcount` = 250m | Client/Module/UAV/uav.sqf:92, 114 |
| Refresh trigger | `waituntil` on waypoint-description / count change or drone death | Client/Module/UAV/uav.sqf:76, 120 |
| Background appender | `"UAV Route planning"` script keeps adding the next ring point | Client/Module/UAV/uav.sqf:95-117 |
| Previous-pass cleanup | `terminate _spawn` before re-planning | Client/Module/UAV/uav.sqf:74, 77 |

Manual override: clicking the map (left button) deletes all current waypoints and drops a single `MOVE` waypoint at the clicked world position, so the operator can redirect the orbit center — see the terminal section below (Client/Module/UAV/uav_interface.sqf:254-267; OA variant uav_interface_oa.sqf:105-118).

### Group-leak cleanup (SP4)

The single driver is split into his own group at spawn time (`[driver _uav] join grpnull`) so the crew survivors don't accumulate toward the engine's group cap. When the drone dies, both the misc crew group and the driver's split group are emptied and deleted.

| Cleanup step | Detail | Citation |
|---|---|---|
| Driver split | `if (count units _uav > 1) then {[driver _uav] join grpnull}` | Client/Module/UAV/uav.sqf:56 |
| On-death sweep | delete units of `_group` + driver group, then `deleteGroup` both | Client/Module/UAV/uav.sqf:124-130 |

## Terminal interface (vanilla `BIS_UAV`)

Entering the UAV switches the player into the gunner's camera and brings up the `RscUnitInfoUAV` HUD with a centered minimap. The interface seeds default aperture/height/speed, then installs key/mouse handlers for altitude, speed, brightness, NVG-inversion, and map-click retasking. It runs only when `WF_A2_Vanilla` is true.

| Terminal element | Detail | Citation |
|---|---|---|
| Camera takeover | `_uav switchcamera "internal"; player remoteControl gunner _uav` | Client/Module/UAV/uav_interface.sqf:13-14 |
| Lock + weapon select | drone locked while controlled; select weapon 0 | Client/Module/UAV/uav_interface.sqf:15-17 |
| Globals | `BIS_UAV_PLANE = _uav`, `BIS_UAV_TIME = 0` | Client/Module/UAV/uav_interface.sqf:20-21 |
| Post-process | `ColorCorrections` (1999), `dynamicBlur` 0.5 (505), `filmGrain` (2005) | Client/Module/UAV/uav_interface.sqf:30-41 |
| HUD resource | `1124 cutrsc ["RscUnitInfoUAV","plain"]` | Client/Module/UAV/uav_interface.sqf:44 |
| Minimap center | ctrl `112410` `mapcenteroncamera true` | Client/Module/UAV/uav_interface.sqf:49 |
| Default aperture | `24` daytime (5–19h) else `0.07` | Client/Module/UAV/uav_interface.sqf:52-58 |
| Default height | rounded to nearest 50, floor 100m, written to ctrl `112413` | Client/Module/UAV/uav_interface.sqf:60-70 |
| Default speed | rounded to nearest 50, written to ctrl `112412` | Client/Module/UAV/uav_interface.sqf:72-82 |
| Live speed readout | ctrl `112411` updated each tick `round speed _uav` | Client/Module/UAV/uav_interface.sqf:104-130 |
| Hidden GUI ctrls | `[112401,112402,112403,112404]` hidden on init | Client/Module/UAV/uav_interface.sqf:84-93 |
| Hint text ctrl | `112414` (exit / brightness / marker key binds) | Client/Module/UAV/uav_interface.sqf:94-100 |

### Key and mouse bindings (vanilla)

| Input | Action | Citation |
|---|---|---|
| `menuback` | sets `bis_uav_terminate` (exit) | Client/Module/UAV/uav_interface.sqf:138 |
| `NightVision` | toggles a `colorInversion` pp effect (NVG) | Client/Module/UAV/uav_interface.sqf:141-153 |
| `binocular` (not on map) | drops a numbered `mil_destroy` user marker at screen center, timestamped | Client/Module/UAV/uav_interface.sqf:156-168 |
| `HeliUp` / `HeliDown` | height ±50m, clamped 100–1000m | Client/Module/UAV/uav_interface.sqf:171-192 |
| `HeliForward` / `HeliBack` | speed ±50, clamped 200–500 (km/h → `/3.6` for forcespeed) | Client/Module/UAV/uav_interface.sqf:195-218 |
| Mouse wheel (`mousezchanged`) | adjusts aperture, finer steps below 1.0 / 0.1, floor 0.001 | Client/Module/UAV/uav_interface.sqf:239-252 |
| Mouse button 1 (not on map) | exit if `menuback` bound to it | Client/Module/UAV/uav_interface.sqf:235 |
| Map left-click | clears waypoints, sets a new `MOVE` waypoint (retask orbit) | Client/Module/UAV/uav_interface.sqf:254-267 |

> The mouse-button-007 branch that toggles ctrls `112401-112404` is explicitly `comment 'DISABLED'` (uav_interface.sqf:226-234) — the dead button noted in the Modules Atlas.

On exit (`bis_uav_terminate` / drone or player death), the script restores targeting AI, unlocks the drone, clears all pp effects, removes the `1124` HUD, and detaches the three display handlers plus the map handler (Client/Module/UAV/uav_interface.sqf:272-301).

## OA interface variant

When `WF_A2_Vanilla` is false the spawn routes to `uav_interface_oa.sqf` instead (uav.sqf:8-12, 67-71). It is a slimmer interface: no `RscUnitInfoUAV` HUD or minimap controls, a single `ColorCorrections` pp effect, an OA exit *action* instead of the `menuback` key, and height handling via `flyinheight` rather than the stored-variable readouts.

| Difference vs vanilla | OA behavior | Citation |
|---|---|---|
| Exit | addAction `STR_EP1_UAV_action_exit` → `uav_actionCommit.sqf` | Client/Module/UAV/uav_interface_oa.sqf:24-33 |
| HUD | no `1124 cutrsc` / no minimap ctrls (commented out) | Client/Module/UAV/uav_interface_oa.sqf:49-50, 150 |
| Post-process | single `ColorCorrections` (1999), darker fade target | Client/Module/UAV/uav_interface_oa.sqf:43-46 |
| Keydown handler | `BIS_UAV_HELI_keydown` spawned per keypress | Client/Module/UAV/uav_interface_oa.sqf:53-93 |
| Marker key | `binocular` → numbered `mil_destroy` marker (same as vanilla) | Client/Module/UAV/uav_interface_oa.sqf:62-74 |
| Height | `HeliUp/HeliDown` set `flyinheight ±50`, clamp 100–1000m, `land 'none'` | Client/Module/UAV/uav_interface_oa.sqf:77-91 |
| Speed control | none (no HeliForward/Back, no aperture wheel) | Client/Module/UAV/uav_interface_oa.sqf (absent) |
| Map left-click | same waypoint retask as vanilla | Client/Module/UAV/uav_interface_oa.sqf:105-118 |

## Spotter intel reveal pipeline

While the drone flies, a per-drone loop (`uav_spotter.sqf`, ExecVM'd from uav.sqf:72) scans nearby entities. Anything the UAV `knowsAbout` above the sensitivity threshold — and not friendly/civilian — is broadcast to all clients as a `uav-reveal`, which paints a fuzzed orange ellipse on each player's map at a randomized offset from the real position.

### Scan loop

| Scan element | Value | Citation |
|---|---|---|
| Loop interval | `WFBE_C_PLAYERS_UAV_SPOTTING_DELAY` = `20`s | Client/Module/UAV/uav_spotter.sqf:13, 18; Common/Init/Init_CommonConstants.sqf:440 |
| Scan radius | `WFBE_C_PLAYERS_UAV_SPOTTING_RANGE` = `1100`m (`nearEntities`) | Client/Module/UAV/uav_spotter.sqf:14, 26; Common/Init/Init_CommonConstants.sqf:442 |
| Knowledge threshold | `WFBE_C_PLAYERS_UAV_SPOTTING_DETECTION` = `0.21` (knowsAbout 0–4) | Client/Module/UAV/uav_spotter.sqf:15, 22; Common/Init/Init_CommonConstants.sqf:441 |
| Friend/civ filter | `!(side _x in [sideJoined, civilian])` | Client/Module/UAV/uav_spotter.sqf:22 |
| Per-hit jitter | `sleep (0.05 + random 0.05)` before send | Client/Module/UAV/uav_spotter.sqf:23 |
| Broadcast | `[sideJoined,"HandleSpecial",["uav-reveal",_uav,_x]] Call WFBE_CO_FNC_SendToClients` | Client/Module/UAV/uav_spotter.sqf:24 |
| Dispatch | `case "uav-reveal": {_args spawn WFBE_CL_FNC_Reveal_UAV}` | Client/PVFunctions/HandleSpecial.sqf:68 |

### Fuzzed reveal marker

`WFBE_CL_FNC_Reveal_UAV` draws a local ellipse whose size — and the random offset of its center — scales with how far the target is from the drone (farther = larger and blurrier circle). The marker auto-deletes after three spotting intervals.

| Reveal element | Value | Citation |
|---|---|---|
| Type guard | both args must be `OBJECT`, else logged error | Client/Functions/Client_FNC_Special.sqf:96 |
| Fuzz size | `_size = round((_uav distance _target) / 16)` | Client/Functions/Client_FNC_Special.sqf:98 |
| Marker name | `WFBE_UAV_SPOTTED_%1` keyed by global `unitMarker` (then incremented) | Client/Functions/Client_FNC_Special.sqf:99-100 |
| Position jitter | each axis `± random(_size)` around `getPos _target` | Client/Functions/Client_FNC_Special.sqf:101 |
| Shape / color | `createMarkerLocal` ellipse, `ColorOrange`, size `[_size,_size]` | Client/Functions/Client_FNC_Special.sqf:102-104 |
| Lifetime | `sleep (DELAY*3)` = 60s, then `deleteMarkerLocal` | Client/Functions/Client_FNC_Special.sqf:106-108 |

The reveal is purely local cosmetic intel (`createMarkerLocal` / `*Local` setters) — it is not a public-variable target lock, so it expires per client without server bookkeeping. The `unitMarker` counter is the shared local marker-id sequence also used by respawn, paratrooper, and AA-radar markers (Common/Init/Init_Common.sqf:177).

## Server cleanup monitor

The `RequestSpecial ["uav",...]` from spawn lands on the server as `KAT_UAV` (compiled from `Support_UAV.sqf`), which watches the owning team and trashes the drone + crew once the team's leader is no longer a live player or the drone dies.

| Server step | Detail | Citation |
|---|---|---|
| Compile | `KAT_UAV = Compile preprocessFile "Server\Support\Support_UAV.sqf"` | Server/Init/Init_Server.sqf:49 |
| Route | `case "uav": {_args spawn KAT_UAV}` | Server/Functions/Server_HandleSpecial.sqf:63-65 |
| Watch loop | 5s poll; exit when team leader not a live player OR drone dead | Server/Support/Support_UAV.sqf:13-16 |
| Teardown | `setDammage 1` + `TrashObject` (with `wfbe_trashed` guard) on uav/driver/gunner | Server/Support/Support_UAV.sqf:18-20 |

## Continue Reading

- [Support Specials and Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas)
- [Tactical Support Menu Player Guide](Tactical-Support-Menu-Player-Guide)
- [Modules Atlas](Modules-Atlas)
- [Takistan Airfield FPV Drone Design](Takistan-Airfield-FPV-Drone-Design)
- [Upgrades and Research Atlas](Upgrades-And-Research-Atlas)
