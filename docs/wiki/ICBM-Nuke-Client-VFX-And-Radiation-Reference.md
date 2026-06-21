# ICBM Nuke Client VFX and Radiation Reference (mushroom-cloud, blast PP-effects, radzone)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the ICBM/nuke **client runtime** -- the presentation half of the module: the launch animation, the mushroom-cloud particle/post-process choreography, the radiation-zone lifecycle, and the side-targeted text+audio messages and map markers. It is deliberately **distinct from** [ICBM authority playbook](ICBM-Authority-Playbook), which owns the DR-27 forged-`RequestSpecial` server trust boundary. Everything here is what a client sees and hears; the only server-side scripts described (`NukeDammage`, `NukeRadiation`) are included because they are compiled in the same module init and drive the radiation broadcast that clients react to.

The module is loaded only when its gate is set: `Init_Common.sqf:329` runs `Client\Module\Nuke\ICBM_Init.sqf` when `WFBE_C_MODULE_WFBE_ICBM > 0`, and that flag defaults to `1` (`Common/Init/Init_CommonConstants.sqf:407`).

## Module init and the compile split

`ICBM_Init.sqf` first sets the two radius constants into `missionNamespace`, then compiles two disjoint sets of functions depending on machine role.

| Symbol | Value / compiled-from | Role gate | Citation |
| --- | --- | --- | --- |
| `ICBM_DAMAGE_RADIUS` | `800` | always | `Client/Module/Nuke/ICBM_Init.sqf:1` |
| `ICBM_RADIATION_RADIUS` | `900` | always | `Client/Module/Nuke/ICBM_Init.sqf:2` |
| `Nuke` | `nuke.sqf` (mushroom-cloud VFX) | `if (local player)` | `Client/Module/Nuke/ICBM_Init.sqf:4-5` |
| `NukeIncoming` | `nukeincoming.sqf` (launch anim) | `if (local player)` | `Client/Module/Nuke/ICBM_Init.sqf:6` |
| `ICBM_FriendySide_Message` | `ICBM_friendlySide_Message.sqf` | `if (local player)` | `Client/Module/Nuke/ICBM_Init.sqf:8` |
| `ICBM_EnemySide_Message` | `ICBM_EnemySide_Message.sqf` | `if (local player)` | `Client/Module/Nuke/ICBM_Init.sqf:9` |
| `NukeDammage` | `damage.sqf` (map-wide destruction) | `if (isServer)` | `Client/Module/Nuke/ICBM_Init.sqf:12-13` |
| `NukeRadiation` | `radzone.sqf` (radiation zone) | `if (isServer)` | `Client/Module/Nuke/ICBM_Init.sqf:14` |

Note the function symbol is spelled `ICBM_FriendySide_Message` (missing the second `l`), consistently at the definition and both call sites -- do not "correct" it.

The two public-variable event handlers that the client reacts to are **not** wired here; they are registered in the client FSM init (see "Event-handler wiring" below).

## Stage 1 -- launch animation (`NukeIncoming`)

`Nuke (nukeincoming.sqf)` runs on the launching commander's client, spawned by the tactical menu as `[_obj,_ICBM_marker_name] Spawn NukeIncoming` (`Client/GUI/GUI_Menu_Tactical.sqf:499`). `_obj` is a `"HeliHEmpty"` object the menu creates at the map-click world position (`Client/GUI/GUI_Menu_Tactical.sqf:471`) to serve as the impact anchor.

| Step | Behavior | Citation |
| --- | --- | --- |
| Params | `_target = _this select 0`, `_nukeMarker = _this select 1` | `Client/Module/Nuke/nukeincoming.sqf:3-4` |
| Impact delay | Sleeps `WFBE_ICBM_TIME_TO_IMPACT * 60` seconds (param is in minutes; default `1`) | `Client/Module/Nuke/nukeincoming.sqf:7-8`, default `Common/Init/Init_CommonConstants.sqf:409` |
| Cruise object | Creates `Chukar` (vanilla/CO) or `Chukar_EP1` via `createVehicle [..,"FLY"]` at the target position, then snaps it to altitude **570 m** with `setPos`/`flyInHeight 570`, `setSpeedMode "FULL"` | `Client/Module/Nuke/nukeincoming.sqf:14-22` |
| Server hand-off | Sends `["RequestSpecial", ["ICBM", sideJoined, _target, _cruise, clientTeam]]` via `WFBE_CO_FNC_SendToServer` | `Client/Module/Nuke/nukeincoming.sqf:23` |
| Display fan-out | After `sleep 1.5`, broadcasts `[nil,"HandleSpecial",["icbm-display",_target,_cruise]]` via `WFBE_CO_FNC_SendToClients` | `Client/Module/Nuke/nukeincoming.sqf:25-27` |
| Flare/exhaust (vanilla/CO only) | Spawns a `cruiseMissileFlare1` 600 m above the drop, `inflame true`, then `execVM`s the stock `cruisemissileflare.sqf` and `exhaust1.sqf` from `\ca\air2\cruisemissile\data\scripts\` and retextures the cruise with the exhaust flame | `Client/Module/Nuke/nukeincoming.sqf:29-43` |
| Teardown | `sleep 7`, then `waitUntil {!alive _cruise}`, `sleep 5`, delete flare (vanilla/CO) and cruise | `Client/Module/Nuke/nukeincoming.sqf:45-51` |

The trailing `deleteMarkerLocal` is commented out (`Client/Module/Nuke/nukeincoming.sqf:53-54`); marker cleanup is handled separately by the tactical menu's timed `WFBE_CL_FNC_Delete_Marker` calls (`Client/GUI/GUI_Menu_Tactical.sqf:504-505`).

The `"icbm-display"` `HandleSpecial` case routes to `WFBE_CL_FNC_Display_ICBM` on every client (`Client/PVFunctions/HandleSpecial.sqf:60`). That helper waits for the cruise to die, then triggers the blast VFX: `waitUntil {!alive _cruise}; [_obj] Spawn Nuke;` (`Client/Functions/Client_FNC_Special.sqf:51-59`). This is what synchronizes the mushroom cloud to the moment the cruise missile is destroyed.

## Stage 2 -- mushroom-cloud blast VFX (`Nuke`)

`Nuke (nuke.sqf)` runs locally on every client as `[_obj] Spawn Nuke`. It builds a layered local-particle mushroom cloud plus a distance-gated post-process flash. `_target = _this select 0` (`Client/Module/Nuke/nuke.sqf:4`).

### Distance gate

All post-process work is gated on `player distance _target < 4000` -- a far-away player gets the particles but no screen effects. The first gate (an immediate `dynamicBlur` punch-in) is at `Client/Module/Nuke/nuke.sqf:5-9`; the main flash block is at `Client/Module/Nuke/nuke.sqf:52-73`; the recovery block at `:93-97`; the final disable at `:145`.

### Particle and light emitters

Each emitter is a local `"#particlesource"` / `"#lightpoint"` created with `createVehicleLocal` at `getPos _target`.

| Local var | Object | Role / notable params | Citation |
| --- | --- | --- | --- |
| `_Cone` | `#particlesource` | Ground cone, `setParticleCircle [10,...]`, drop interval `0.005` | `Client/Module/Nuke/nuke.sqf:11-17` |
| `_top` | `#particlesource` | Rising stem (initial), drop `0.001` | `Client/Module/Nuke/nuke.sqf:19-23` |
| `_top2` | `#particlesource` | Stem detail, drop `0.002` | `Client/Module/Nuke/nuke.sqf:25-29` |
| `_smoke` | `#particlesource` | Dark smoke column (recolored later), drop `0.002` | `Client/Module/Nuke/nuke.sqf:31-37` |
| `_Wave` | `#particlesource` | Ground shock-wave ring, `setParticleCircle [50,...]`, drop `0.0002` | `Client/Module/Nuke/nuke.sqf:39-45` |
| `_light` | `#lightpoint` | Flash light 500 m above target, ambient/color `[1500,1200,1000]`, brightness `100000.0` | `Client/Module/Nuke/nuke.sqf:47-50`, re-set `:74` |
| `_top3` | `#particlesource` | Cap layer at z=500, lifetime `0.6 s` | `Client/Module/Nuke/nuke.sqf:82-89` |
| `_top4` | `#particlesource` | Cap layer at z=800 | `Client/Module/Nuke/nuke.sqf:99-107` |
| `_top5` | `#particlesource` | Cap layer at z=1000 | `Client/Module/Nuke/nuke.sqf:110-114` |
| `_smoke2` | `#particlesource` | High smoke at z=900 | `Client/Module/Nuke/nuke.sqf:125-131` |

All emitters use the stock `\Ca\Data\ParticleEffects\Universal\Universal` sprite sheet.

### Post-process flash sequence (within 4000 m)

| Phase | Effect | Citation |
| --- | --- | --- |
| Pre-detonation blur | `dynamicBlur` enable + adjust `[1]`, commit `1` | `Client/Module/Nuke/nuke.sqf:6-8` |
| Flash | `colorCorrections` enable + harsh adjust, commit `0.4`; `dynamicBlur` adjust `[0.5]` commit `3` | `Client/Module/Nuke/nuke.sqf:53-57` |
| Settle (spawned, +4 s) | A `[] Spawn` waits `Sleep 4` then warms the palette: `colorCorrections` adjust to a warm tint, commit `7` | `Client/Module/Nuke/nuke.sqf:61-66` |
| Blur ramp-down | `dynamicBlur` adjust `[2]` commit `1`, then adjust `[0.5]` commit `4` | `Client/Module/Nuke/nuke.sqf:68-72` |
| Mid recovery (+~3.5 s later) | `colorCorrections` back toward neutral commit `1`, re-enable; `dynamicBlur` adjust `[0]` commit `1` | `Client/Module/Nuke/nuke.sqf:93-97` |
| Final disable (+~20 s) | `"colorCorrections" ppEffectEnable false` | `Client/Module/Nuke/nuke.sqf:145` |

### Cloud teardown and FX restore

The emitters are deleted in staged `sleep`/`deleteVehicle` steps over the rest of the script: `_top`/`_top2` (`:79-80`), `_top3` (`:89`), `_light`/`_top4` (`:106-107`), `_top5` (`:134`), `_smoke2` (`:139`), and finally `_Wave`/`_cone`/`_smoke` (`:141-143`). The cone/wave/smoke drop intervals are throttled down (`setDropInterval 0.01`/`0.02`) before deletion to taper the effect (`:116-117,135-136`).

The script ends with `[currentFX] Spawn FX;` (`Client/Module/Nuke/nuke.sqf:146`), which re-applies the player's selected color/FX preset. `FX` is compiled from `Client\Functions\Client_FX.sqf` (`Client/Init/Init_Client.sqf:74`) and `currentFX` is the player's chosen index (default `0`, `Client/Init/Init_Client.sqf:340`). This restores baseline post-processing after the nuke's `colorCorrections`/`dynamicBlur` overrides.

## Stage 3 -- map-wide destruction (`NukeDammage`, server)

`NukeDammage (damage.sqf)` runs on the **server**, invoked from `Server_HandleSpecial.sqf` after the ICBM request is accepted (see the authority playbook for the trust gap). `_target = _this select 0` (`Client/Module/Nuke/damage.sqf:13`).

| Step | Behavior | Citation |
| --- | --- | --- |
| Range | `_range = ICBM_DAMAGE_RADIUS` (`800`) | `Client/Module/Nuke/damage.sqf:14` |
| Gather | `nearestObjects [_target,[],_range]` -- the empty type filter is deliberate so trees/walls are included | `Client/Module/Nuke/damage.sqf:16` |
| Preserve list | A large `_logic_class` array of game-logic/manager classes, plus `WFBE_C_CAMP_FLAG`/`WFBE_C_DEPOT`/`WFBE_C_CAMP` and the `land_nav_pier_*` set, are subtracted out so core mechanics survive | `Client/Module/Nuke/damage.sqf:17-26` |
| Destroy | `_x setDamage 1` on every remaining object | `Client/Module/Nuke/damage.sqf:28-31` |
| Chain | `[_target] Spawn NukeRadiation` | `Client/Module/Nuke/damage.sqf:34` |

## Stage 4 -- radiation zone (`NukeRadiation`, server)

`NukeRadiation (radzone.sqf)` runs on the **server**, spawned by `NukeDammage`. It paints per-side warning markers, ticks damage over time, and broadcasts which player is currently irradiated so each client can play the geiger sound.

| Constant / setting | Value | Citation |
| --- | --- | --- |
| `_radiation_duration` | `WFBE_RADZONE_TIME * 60` seconds (param in minutes, default `1`) | `Client/Module/Nuke/radzone.sqf:42-43`, default `Common/Init/Init_CommonConstants.sqf:410` |
| `_radiation_interval` | `5` seconds per tick | `Client/Module/Nuke/radzone.sqf:45` |
| `_radiation_range` | `ICBM_RADIATION_RADIUS` (`900`) | `Client/Module/Nuke/radzone.sqf:47` |
| Marker type / text / color | `mil_warning` / `"RADIOACTIVE ZONE"` / `ColorGreen` | `Client/Module/Nuke/radzone.sqf:51-53` |

### Markers

Two per-side markers are created via `WF_createMarker` (`Common/Init/Init_Common.sqf:167` -> `Common_CreateMarker.sqf`), one keyed to `west` and one to `east`, each with a paired ellipse marker for the radius circle. Names get a random suffix (`format ["RADZONE_west_%1_%2", round time, round (random 10000)]`) to avoid collisions: `Client/Module/Nuke/radzone.sqf:57-85`.

### Per-tick damage loop

```
while {time < _radiation_end_time} do {
    _array = _target nearEntities [["Man","Car","Motorcycle","Tank","Ship","Air","StaticWeapon"], _radiation_range];
    { _x setDammage (getDammage _x + 0.03);
      {_x setDammage (getDammage _x + 0.05)} forEach crew _x;
      if (isPlayer _x) then { ...PLAYER_RADIATED broadcast... };
    } forEach _array;
    sleep _radiation_interval;
};
```
-- `Client/Module/Nuke/radzone.sqf:88-110`. Each tick adds **0.03** damage to the entity body and **0.05** to each crew member (`:93-94`). When the entity is a player, the loop sets `PLAYER_RADIATED` to that player and `publicVariable`s it (`:102-104`), which fires the radiated-sound handler on every client.

> Note: the per-player `publicVariable "PLAYER_RADIATED"` inside the inner loop fires once **per irradiated player per 5 s tick** -- the per-tick broadcast cost is the subject of a separate finding in [Deep-review findings](Deep-Review-Findings) (radzone.sqf:102-104). This page documents the runtime as written; that page owns the perf assessment.

### Cleanup

After the loop, `deleteVehicle _target` removes the impact anchor (`Client/Module/Nuke/radzone.sqf:112`), and all four markers (two zone, two ellipse) are removed immediately with delay `0` via `WFBE_CL_FNC_Delete_Marker` (`Client/Module/Nuke/radzone.sqf:120-124`).

## Messages, sounds, and map markers (client reactions)

### Side-targeted text + audio (`ICBM_FriendySide_Message` / `ICBM_EnemySide_Message`)

Both build a deferred multi-language message string and a sound name, then hand off to `WF_sendMessage` (`Common/Init/Init_Common.sqf:169` -> `Common_SendMessage.sqf`) targeting a side.

| Function | Localized string | Sound | Citation |
| --- | --- | --- | --- |
| `ICBM_FriendySide_Message` | `STR_WF_CHAT_ICBM_Launch_BY_OUR_TEAM` (formatted with impact time) | `ICBM_message_to_friendly_players` | `Client/Module/Nuke/ICBM_friendlySide_Message.sqf:13-25` |
| `ICBM_EnemySide_Message` | `STR_WF_CHAT_ICBM_Launch_BY_ENEMY_TEAM` (formatted with impact time) | `ICBM_message_to_enemy_players` | `Client/Module/Nuke/ICBM_EnemySide_Message.sqf:12-25` |

Both strings are defined in `stringtable.xml`; the three sound classes are defined in `Sounds/description.ext` (`ICBM_message_to_enemy_players` at `:96-99`, `ICBM_message_to_friendly_players` at `:102-105`, `radiationSound` at `:144-146`). The friendly-message file warns that Arma 2 OA must be **restarted** for a newly added sound to register (`Client/Module/Nuke/ICBM_friendlySide_Message.sqf:9`).

At launch the tactical menu calls **both** directly on the commander's own client: `[playerSide] call ICBM_FriendySide_Message` and `[_enemy_side] call ICBM_EnemySide_Message` (`Client/GUI/GUI_Menu_Tactical.sqf:495-496`).

### Launch map-marker handler (`OnEventHandler_ICBM_Launch`)

This is the public-variable event handler for `ICBM_launched`. Its design intent (per its header) is the addPublicVariableEventHandler quirk that the **publishing client does not run its own handler**, so the commander draws its own marker via the GUI while remote clients draw theirs through this handler.

| Step | Behavior | Citation |
| --- | --- | --- |
| Read value | `_ICBM_infos = _this select 1` (select 0 is the var name, not the value) | `Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:17` |
| Unpack | `_ICBM_postion = _ICBM_infos select 0`, `_ICBM_side = _ICBM_infos select 1` | `Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:19-20` |
| Friendly branch | If `playerSide == _ICBM_side`: call `ICBM_FriendySide_Message`, then `createMarkerLocal ["icbmstrike",_ICBM_postion]` styled `mil_warning` / text `"ICBM"` / `ColorRed`, auto-deleted after `WFBE_ICBM_TIME_TO_IMPACT*60` s via `WFBE_CL_FNC_Delete_Marker` | `Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:22-34` |
| Enemy branch | Else call `ICBM_EnemySide_Message` | `Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:35-38` |

> Source caveat: the `ICBM_launched` public variable is **registered** as an event handler (`Client/FSM/updateclient.sqf:19-20`) but is never `publicVariable`'d anywhere in the current mission source -- a wiki-clone-independent grep for an `ICBM_launched =`/`publicVariable "ICBM_launched"` producer returns nothing. In the shipped flow the friendly/enemy messages reach players through the GUI-local commander calls (`GUI_Menu_Tactical.sqf:495-496`) and the per-side `WF_sendMessage` broadcast inside those functions; the per-client `icbmstrike` marker that this handler would draw is therefore not currently triggered. The handler is wired and ready but dormant.

### Radiated geiger sound (`OnEventHandler_player_radiated`)

Public-variable event handler for `PLAYER_RADIATED`. `_PLAYER_radiated = _this select 1`; if that object is the local `player`, `playSound ["radiationSound", true]` (`Client/Module/Nuke/OnEventHandler_player_radiated.sqf:14-18`). This is the client-side reaction to the server's per-tick broadcast in `radzone.sqf`.

## Event-handler wiring

Both ICBM public-variable event handlers are compiled and registered in the client FSM update init, not in `ICBM_Init.sqf`:

| PV name | Handler symbol / compiled-from | Citation |
| --- | --- | --- |
| `ICBM_launched` | `OnEventHandler_ICBM_Launch` <- `OnEventHandler_ICBM_Launch.sqf` | `Client/FSM/updateclient.sqf:19-20` |
| `PLAYER_RADIATED` | `OnEventHandler_player_radiated` <- `OnEventHandler_player_radiated.sqf` | `Client/FSM/updateclient.sqf:23-24` |

## End-to-end flow

1. Commander confirms an ICBM map-click in the tactical menu; client debits funds, creates the `HeliHEmpty` anchor and the local commander marker, plays both side messages locally, and spawns `NukeIncoming` (`GUI_Menu_Tactical.sqf:463-499`).
2. `NukeIncoming` waits the impact time, spawns the `Chukar` cruise object at 570 m, sends the `RequestSpecial` to the server and the `icbm-display` `HandleSpecial` to all clients (`nukeincoming.sqf:7-27`).
3. On every client `WFBE_CL_FNC_Display_ICBM` waits for the cruise to die, then spawns `Nuke` for the mushroom-cloud + PP flash (`Client_FNC_Special.sqf:51-59`, `nuke.sqf`).
4. On the server (after authority acceptance) `NukeDammage` flattens objects in 800 m and chains `NukeRadiation` (`damage.sqf`), which paints per-side radzone markers and ticks 0.03/0.05 damage over `WFBE_RADZONE_TIME`, broadcasting `PLAYER_RADIATED` per affected player (`radzone.sqf`).
5. Each client's `PLAYER_RADIATED` handler plays `radiationSound` for the local player while irradiated (`OnEventHandler_player_radiated.sqf`).

## Continue Reading

- [ICBM authority playbook](ICBM-Authority-Playbook) -- the server-side forged-`RequestSpecial` trust boundary (DR-27) this VFX page complements.
- [Marker cleanup restoration systems atlas](Marker-Cleanup-Restoration-Systems-Atlas) -- `WF_createMarker` / `WFBE_CL_FNC_Delete_Marker` patterns used by the radzone and launch markers.
- [Public variable channel index](Public-Variable-Channel-Index) -- where `ICBM_launched` / `PLAYER_RADIATED` sit among PV channels.
- [Support specials and tactical modules atlas](Support-Specials-And-Tactical-Modules-Atlas) -- the broader special/tactical-menu module family.
- [Deep-review findings](Deep-Review-Findings) -- the `PLAYER_RADIATED` per-tick broadcast perf finding.
