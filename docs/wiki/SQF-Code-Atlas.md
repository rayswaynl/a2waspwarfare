# SQF Code Atlas

This page is the first deeper code-level atlas for the Chernarus source mission. It is generated from source inspection, not memory.

Source mission: `Missions/[55-2hc]warfarev2_073v48co.chernarus`

## Compile Registry Summary

The source mission contains 659 `preprocessFile` references:

| Kind | Count | Notes |
| --- | ---: | --- |
| `preprocessFileLineNumbers` | 452 | Preferred for source-backed runtime errors and debugging. |
| plain `preprocessFile` | 207 | Older or performance/legacy style compiles; still common in init files. |
| commented compile references | 21 | Includes disabled systems, duplicate old lines and experiments. |

Target area counts:

| Target area | Count |
| --- | ---: |
| `Common` | 424 |
| `Client` | 140 |
| `Server` | 90 |
| `WASP` / `Wasp` | 3 |
| `Headless` | 1 |
| `briefing.sqf` | 1 |

Top source registrars:

| Registrar | Count |
| --- | ---: |
| `Common/Init/Init_Common.sqf` | 187 |
| `Client/Init/Init_Client.sqf` | 112 |
| `Server/Init/Init_Server.sqf` | 89 |
| `Common/Config/Core_Root/Root_GUE.sqf` | 12 |
| `Common/Config/Core_Root/Root_TKA.sqf` | 12 |
| `Common/Config/Core_Root/Root_USMC.sqf` | 12 |
| `Common/Config/Core_Root/Root_PMC.sqf` | 11 |
| `Common/Config/Core_Root/Root_RU.sqf` | 11 |
| `Common/Config/Core_Root/Root_TKGUE.sqf` | 11 |
| `Common/Config/Core_Root/Root_US_Camo.sqf` | 11 |

## Init Owners

### `initJIPCompatible.sqf`

Early bootstrap compiles the log function first, checks headless-client identity, prepares server connect/disconnect callbacks, then compiles MP parameters and common constants. This file is the role router: common init runs for all roles, server init runs on server, client init runs on players and headless init runs on headless clients.

Key compile targets:

- `Common/Functions/Common_LogContent.sqf`
- `Headless/Functions/HC_IsHeadlessClient.sqf`
- `Server/Functions/Server_OnPlayerConnected.sqf`
- `Server/Functions/Server_OnPlayerDisconnected.sqf`
- `Common/Init/Init_Parameters.sqf`
- `Common/Init/Init_CommonConstants.sqf`

### `Common/Init/Init_Common.sqf`

Common init owns shared helpers, old global helper names, newer `WFBE_CO_FNC_*` helpers, profile helpers, core config loading, root faction imports, public variable function setup, boundaries, ICBM, IRS smoke and CIPHER module loading.

Important categories:

- Combat/event helpers: `HandleAT`, `HandleRocketTraccer`, reload handlers, missile/bomb handlers.
- Economy/state helpers: side supply, team funds, team move mode, team respawn, upgrades, towns held/income.
- Object creation helpers: teams, town units, vehicles, static defense crew, backpacks, vehicle cargo and turrets.
- Network helpers: `WFBE_CO_FNC_SendToClient`, `WFBE_CO_FNC_SendToClients`, `WFBE_CO_FNC_SendToServer`.
- Config loaders: model core, gear core, faction roots, defenses, town groups.
- Module entrypoints: ICBM, IRS, CIPHER.

Risk notes:

- `WFBE_CO_FNC_SendToServer` switches between old broadcast behavior and `publicVariableServer`-optimized behavior depending on `WF_A2_Vanilla`.
- Gear config loads only on `local player`, while class/core config loads more broadly.
- Root faction files compile side-specific units, structures, artillery, squads and upgrades; changes here affect buy menus, AI and production.

### `Server/Init/Init_Server.sqf`

Server init owns AI, town, building, construction, special support, supply mission, AntiStack, attack wave, headless delegation and long server loops.

Important categories:

- Legacy server functions: AI buy, AI respawn, AI orders, building damage/killed, defense construction, special supports and team updates.
- New `WFBE_SE_FNC_*` functions: town attack pathing, town groups, empty vehicle handling, PVF dispatch, town defenses, commander voting, upgrades and HQ death/repair flows.
- Supply mission handlers: `supplyMissionStarted`, `supplyMissionCompleted`, `supplyMissionActive`, `isSupplyMissionActiveInTown`, `playerObjectsList`, `supplyMissionTimerForTown`.
- AntiStack handlers: database retrieve/store/flush/set-map, player score sampling, team score compare, launch-side ACK.
- Direct event-channel systems: attack waves, MASH marker, server FPS, day/night, global game stats.

Risk notes:

- `UpdateSupplyTruck` is commented while `Server/AI/AI_UpdateSupplyTruck.sqf` still exists and references a missing `Server/FSM/supplytruck.fsm`; treat autonomous AI supply logistics as broken/deferred.
- `WFBE_CO_FNC_monitorServerFPS` is commented as a compile target but server FPS is still run directly elsewhere.
- `WFBE_SE_FNC_MASH_MARKER` appears once active and once commented in the init file; MASH marker status requires careful source verification before changes.

### `Client/Init/Init_Client.sqf`

Client init owns player object setup, player event handlers, UI helpers, PVF reception, supply mission client entrypoints, gear template helpers, action menus, profile variables, CoIn construction, skill modules, keybinds, markers, RHUD and Valhalla low-gear support.

Important categories:

- Player setup: `sideJoined`, temp respawn position, fired handlers, damage handler, RPG drop support and map icon combat state.
- Legacy client functions: build unit, player funds, respawn handlers, support repair/refuel/rearm/heal, UI list helpers.
- New `WFBE_CL_FNC_*` functions: action menu helper, delegation, gear UI, map click, PVF dispatch, kill handler, respawn selector, supply mission UI.
- Long loops and modules: watchdog player AI, Zeta cargo, skill system, EASA, countermeasures, keybinds, markers, CoIn, Valhalla.

Risk notes:

- `TaskSystem` is commented in the legacy client function block.
- MASH receiver, old full-map icon blinking and old AddUnitToTrack compile lines are commented.
- Combat icon blinking is guarded by `WFBE_C_MAP_ICON_BLINKING_ENABLED`; avoid reintroducing unconditional fired-handler or marker scan loops.

### `Headless/Init/Init_HC.sqf`

Headless init compiles the same delegation helpers used by clients plus `WFBE_CL_FNC_HandlePVF`. Headless support is version-gated earlier in `initJIPCompatible.sqf`, and server-side delegation helpers are compiled in server init when the version allows it.

## PVF Contract

`Common/Init/Init_PublicVariables.sqf` builds two command lists and registers `WFBE_PVF_<Command>` event handlers.

Server-bound PVF commands:

| Command | Target file |
| --- | --- |
| `RequestVehicleLock` | `Server/PVFunctions/RequestVehicleLock.sqf` |
| `RequestOnUnitKilled` | `Server/PVFunctions/RequestOnUnitKilled.sqf` |
| `RequestChangeScore` | `Server/PVFunctions/RequestChangeScore.sqf` |
| `RequestCommanderVote` | `Server/PVFunctions/RequestCommanderVote.sqf` |
| `RequestNewCommander` | `Server/PVFunctions/RequestNewCommander.sqf` |
| `RequestStructure` | `Server/PVFunctions/RequestStructure.sqf` |
| `RequestDefense` | `Server/PVFunctions/RequestDefense.sqf` |
| `RequestJoin` | `Server/PVFunctions/RequestJoin.sqf` |
| `RequestMHQRepair` | `Server/PVFunctions/RequestMHQRepair.sqf` |
| `RequestSpecial` | `Server/PVFunctions/RequestSpecial.sqf` |
| `RequestTeamUpdate` | `Server/PVFunctions/RequestTeamUpdate.sqf` |
| `RequestUpgrade` | `Server/PVFunctions/RequestUpgrade.sqf` |
| `RequestAutoWallConstructinChange` | `Server/PVFunctions/RequestAutoWallConstructinChange.sqf` |

Client-bound PVF commands:

| Command | Target file |
| --- | --- |
| `AllCampsCaptured` | `Client/PVFunctions/AllCampsCaptured.sqf` |
| `AwardBounty` | `Client/PVFunctions/AwardBounty.sqf` |
| `AwardBountyPlayer` | `Client/PVFunctions/AwardBountyPlayer.sqf` |
| `CampCaptured` | `Client/PVFunctions/CampCaptured.sqf` |
| `ChangeScore` | `Client/PVFunctions/ChangeScore.sqf` |
| `HandleSpecial` | `Client/PVFunctions/HandleSpecial.sqf` |
| `LocalizeMessage` | `Client/PVFunctions/LocalizeMessage.sqf` |
| `SetTask` | `Client/PVFunctions/SetTask.sqf` |
| `SetVehicleLock` | `Client/PVFunctions/SetVehicleLock.sqf` |
| `TownCaptured` | `Client/PVFunctions/TownCaptured.sqf` |
| `SetMHQLock` | `Client/PVFunctions/SetMHQLock.sqf` |
| `Available` | `Client/PVFunctions/Available.sqf` |
| `RequestBaseArea` | `Client/PVFunctions/RequestBaseArea.sqf` |
| `NukeIncoming` | `Client/PVFunctions/NukeIncoming.sqf` |

PVF dispatch mechanics:

- Server-bound packets start as `[Command, params...]`; `Common_SendToServer`/`Common_SendToServerOptimized` rewrites index 0 to `SRVFNC<Command>`.
- Client-bound packets use the command at index 1; `Common_SendToClient` and `Common_SendToClients` rewrite it to `CLTFNC<Command>`.
- Hosted server paths call the handler locally and may also broadcast in multiplayer.
- Client filtering in `Client_HandlePVF.sqf` supports side destinations and player UID destinations.
- Both client and server dispatch call `Call Compile _script`, so malformed function names or unsanitized command names would be high-risk.

Unregistered PV function files:

- `Client/PVFunctions/HandleParatrooperMarkerCreation.sqf` exists but is not in the client command list.
- `Client/PVFunctions/DatabaseDebug.sqf` is present but the registry entry is commented out in `Init_PublicVariables.sqf`.
- `Server/PVFunctions/LogGameEnd.sqf` is present but not registered; server init compiles `Server/Functions/Server_LogGameEnd.sqf` instead.
- `Server/PVFunctions/AttackWave.sqf` is a direct/public-variable handler path rather than a standard PVF command-list entry.

## Direct Public Variable Channels

Not all networking uses the PVF wrapper. The canonical inventory is [Public variable channel index](Public-Variable-Channel-Index), which covers registered `WFBE_PVF_*` commands and direct channels such as day/night, message/marker creation, ICBM/radiation, AFK/BattlEye, supply missions, side supply, server FPS, attack waves, MASH marker channels, HQ marker/state broadcasts and client-init handshakes.

Use this atlas for compile/registration ownership. Use [Networking and public variables](Networking-And-Public-Variables) for dispatcher mechanics and [Public variable channel index](Public-Variable-Channel-Index) for channel inventory and BattlEye whitelist design.

## Disabled Or Deferred Compile Signals

High-signal disabled/deferred compile lines:

| Source | Target | Evidence |
| --- | --- | --- |
| `Server/Init/Init_Server.sqf` | `Server/AI/AI_UpdateSupplyTruck.sqf` | `UpdateSupplyTruck` compile line is block-commented. |
| `Server/AI/AI_UpdateSupplyTruck.sqf` | `Server/FSM/supplytruck.fsm` | The target FSM is missing; only client FSM files exist. |
| `Client/Init/Init_Client.sqf` | `Client/Functions/Client_TaskSystem.sqf` | `TaskSystem` compile line is commented. |
| `Client/Init/Init_Client.sqf` | `Client/Module/MASH/receiverMASHmarker.sqf` | Receiver compile line is commented. |
| `Client/Init/Init_Client.sqf` | `Client/Functions/Client_BlinkMapIcons.sqf` | Old full-map icon blinking compile line is commented; guarded per-unit blinking remains. |
| `Client/Init/Init_Client.sqf` | `Client/Functions/Client_AddUnitToTrack.sqf` | Old unit tracking compile line is commented. |
| `Common/Init/Init_Common.sqf` | `Common/Functions/Common_HandleATReloadVehicle.sqf` | Compile line is commented. |
| `Common/Init/Init_Common.sqf` | `Common/Functions/Common_HandleBombs.sqf` | Compile line is commented while newer bomb/missile handlers remain. |
| `Server/Init/Init_Server.sqf` | `Server/Module/serverFPS/monitorServerFPS.sqf` | Compile line is commented twice; server FPS is still executed directly elsewhere. |

## FSM Inventory

Only three `.fsm` files exist in the source mission:

- `Client/FSM/updateactions.fsm`
- `Client/FSM/updateavailableactions.fsm`
- `Client/kb/hq.fsm`

Server-side long-running systems are mostly `.sqf` loop scripts under `Server/FSM`. The missing `Server/FSM/supplytruck.fsm` is therefore concrete evidence of an incomplete old AI logistics path rather than just a naming convention mismatch.

## Development Guidance

- Use `-LiteralPath` in PowerShell for mission paths containing `[55-2hc]`; plain `-Path` treats brackets as wildcards.
- Prefer adding new registered function names in the existing init owner for that side: common in `Init_Common`, server in `Init_Server`, client in `Init_Client`.
- If adding a PVF command, update both the command list and the corresponding `Client/PVFunctions` or `Server/PVFunctions` file, then document payload shape.
- Avoid `Call Compile` on data strings unless following an established PVF/localization pattern and the source is controlled.
- For performance-sensitive loops, preserve existing parameter guards and `WF_Debug` logging style.

## Continue Reading

Previous: [WASP overlay](WASP-Overlay) | Next: [Function/module index](Function-And-Module-Index)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
