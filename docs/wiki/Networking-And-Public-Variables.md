# Networking And Public Variables

Arma 2 OA networking here is built around public variables, public-variable event handlers and wrapper functions that dispatch named PVF commands.

## Central PVF Registration

`Common/Init/Init_PublicVariables.sqf` creates two command lists:

Server PVF commands:

- `RequestVehicleLock`
- `RequestOnUnitKilled`
- `RequestChangeScore`
- `RequestCommanderVote`
- `RequestNewCommander`
- `RequestStructure`
- `RequestDefense`
- `RequestJoin`
- `RequestMHQRepair`
- `RequestSpecial`
- `RequestTeamUpdate`
- `RequestUpgrade`
- `RequestAutoWallConstructinChange`

Client PVF commands:

- `AllCampsCaptured`
- `AwardBounty`
- `AwardBountyPlayer`
- `CampCaptured`
- `ChangeScore`
- `HandleSpecial`
- `LocalizeMessage`
- `SetTask`
- `SetVehicleLock`
- `TownCaptured`
- `SetMHQLock`
- `Available`
- `RequestBaseArea`
- `NukeIncoming`

Each command is compiled into either `SRVFNC...` or `CLTFNC...`, and `WFBE_PVF_<Command>` receives an event handler that passes payloads to `Server_HandlePVF` or `Client_HandlePVF`.

## Network Helper Layer

- `Common_SendToServer`: sends a server PVF; uses optimized `publicVariableServer` outside vanilla mode.
- `Common_SendToClients`: broadcasts client PVF to all clients.
- `Common_SendToClient`: targets one client where supported.

These wrappers are preferred over hand-coded public variable dispatch for new features.

## Direct Public Variables

Some systems use explicit public-variable channels outside the generic PVF list:

| Channel | Direction | Evidence | Notes |
| --- | --- | --- | --- |
| `WFBE_DAYNIGHT_DATE` | server -> clients | `Server/Module/Server_DayNightCycle.sqf:88-89`, `initJIPCompatible.sqf:176-182` | Server-authoritative date sync. |
| `SEND_MESSAGE` | mixed broadcast/client receive | `Client/FSM/updateclient.sqf:10-24`, `Common/Functions/Common_SendMessage.sqf:37-38` | Bare message channel outside PVF routing. |
| `MARKER_CREATION` | mixed broadcast/client receive | `Client/FSM/updateclient.sqf:10-24`, `Common/Functions/Common_CreateMarker.sqf:82-83` | Marker creation channel. |
| `ICBM_launched`, `PLAYER_RADIATED` | nuke/radiation module -> clients | `Client/FSM/updateclient.sqf:10-24`, `Common/Module/ICBM/radzone.sqf:103-104` | ICBM marker/radiation notifications. |
| `REQUEST_SUPPLY_VALUE`, `SUPPLY_VALUE_REQUESTED` | client request -> server response | `Common/Functions/Common_GetSideSupply.sqf:14-41`, `Server/Functions/Server_PV_RequestSupplyValue.sqf:1-8`, `Client/Functions/Client_ReceiveSupplyValue.sqf:1-7` | Side-supply value request/response. |
| `WFBE_Client_PV_IsSupplyMissionActiveInTown`, `WFBE_Client_PV_SupplyMissionStarted` | client -> server | `Client/Module/supplyMission/supplyMissionStart.sqf:6-49` | Supply mission start/availability requests. |
| `WFBE_Server_PV_IsSupplyMissionActiveInTown`, `WFBE_Server_PV_SupplyMissionCompleted`, `WFBE_Server_PV_SupplyMissionCompletedMessage` | server local/PV -> clients | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1-18`, `supplyMissionStarted.sqf:1-65`, `supplyMissionCompleted.sqf:2-34` | Supply mission state and completion publication. |
| `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH`, `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`, `WFBE_C_PLAYER_OBJECT` | client/server anti-stack and supply support | `Client/Init/Init_Client.sqf:442-454`, `Server/Module/AntiStack/clientHasConnectedAtLaunch.sqf:1-15` | Launch-side/anti-stack and player object bookkeeping. |
| `AFKthresholdExceededName`, `kickAFK` | client -> server/BattlEye | `Client/Module/AFK/monitorAFK.sqf:25`, `Server/Module/AFK/initAFKkickHandler.sqf:9`, `BattlEyeFilter/publicvariable.txt:1-2` | `kickAFK` is intentionally caught by BattlEye because `serverCommand` is unavailable. |
| `SERVER_FPS_GUI`, `WFBE_VAR_SERVER_FPS` | server -> clients | `Server/Module/serverFPS/serverFpsGUI.sqf:7-8`, `Server/Init/Init_Server.sqf:578,595` | Two server-FPS publication paths exist. |

## Second-Pass Direct PV Inventory

Archimedes/James and Galileo's second-pass reports expanded the direct-channel map. These are not automatically covered by the `WFBE_PVF_*` registration list or a future PVF dispatcher fix, so treat them as separate review targets when hardening the network layer.

| Channel | Direction | Owner / evidence | Trust or lifecycle note |
| --- | --- | --- | --- |
| `ATTACK_WAVE_INIT`, `ATTACK_WAVE_DETAILS`, `CLIENT_INIT_READY` | client/common -> server; server/PVEH coordination | `Common/Functions/Common_AttackWaveActivate.sqf`, `Server/Functions/Server_AttackWave.sqf`, `Server/PVFunctions/AttackWave.sqf`, `Client/Init/Init_Client.sqf` | Attack-wave sync is outside the generic PVF list and should be reviewed separately for JIP/order behavior. |
| `wfbe_supply_temp_west`, `wfbe_supply_temp_east`, `wfbe_supply_<side>` | common/client -> server; server -> clients | `Common/Functions/Common_ChangeSideSupply.sqf`, `Server/Functions/Server_ChangeSideSupply.sqf` | West/east server handlers recompute supply; no resistance handler was found. DR-22 found the overspend windfall in the server clamp. |
| `WFBE_Client_PV_IsSupplyMissionActiveInTown`, `WFBE_Client_PV_SupplyMissionStarted` | client -> server | `Client/Module/supplyMission/supplyMissionStart.sqf`, `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf`, `supplyMissionStarted.sqf` | Client starts availability/completion flow. DR-18 found first-use cooldown nil risk; supply reward variables still need server-side recompute. |
| `WFBE_Server_PV_IsSupplyMissionActiveInTown`, `WFBE_Server_PV_SupplyMissionCompleted`, `WFBE_Server_PV_SupplyMissionCompletedMessage` | server -> clients / server local PVEH | `Server/Module/supplyMission/*.sqf`, `Client/Module/supplyMission/*.sqf` | Completion publication is live-only and intertwined with supply vehicle object variables. |
| `WFBE_CL_MASH_MARKER_CREATED`, `WFBE_SE_MASH_MARKER_SENT` | client -> server -> clients | `Server/Module/MASH/MASHMarker.sqf`, `Client/Module/MASH/receiverMASHmarker.sqf` | Server relay is live, but the client receiver compile is commented; MASH markers are broken (DR-3). |
| `IS_WEST_HQ_ALIVE`, `IS_EAST_HQ_ALIVE`, `HQ_WEST_MARKER_INFOS`, `HQ_EAST_MARKER_INFOS` | server -> clients | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` | HQ state is broadcast directly; DR-20 found the HQ-killed consumer is not idempotent when multiple clients detect the same death. |
| `SUPPLY_COMPENSATION_AMOUNT_EAST`, `SUPPLY_COMPENSATION_AMOUNT_WEST` | server -> clients | `Server/Module/AntiStack/skillDiffCompensation.sqf` | AntiStack skill compensation publishes side-specific supply deltas outside PVF; depends on external DB/skill data when AntiStack is enabled. |
| `TEAM_WEST_TICKS_NO_PLAYERS`, `TEAM_EAST_TICKS_NO_PLAYERS` | common/server -> clients | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf` | No-player stagnation state is a direct broadcast channel. |
| `CLIENT_INIT_READY` | client -> server | `Client/Init/Init_Client.sqf`, `Server/PVFunctions/AttackWave.sqf` | Despite the `Server/PVFunctions` path, this is a direct PVEH channel and not part of `_serverCommandPV`. |

### Direct PV Hardening Order

1. Fix PVF dispatcher command resolution first (DR-1), because that closes arbitrary command-string execution.
2. Harden registered high-impact handlers next: construction, upgrades, score, vehicle lock, commander/team changes.
3. Review the direct channels above separately, because they will not be protected by a `WFBE_PVF_*` allow-list.
4. Design BattlEye `publicvariable.txt` from both lists: registered `WFBE_PVF_*` channels plus explicit direct channels such as `kickAFK`, supply mission PVs, day/night, HQ markers, attack waves and AntiStack compensation.

## Safety Notes

- Keep payloads small and structured; Arma 2 public-variable traffic can be expensive.
- Prefer server authority for state changes. Client scripts should request, not mutate, team/base/economy state directly.
- When adding a PVF command, update both the registration list and the target `Client/PVFunctions` or `Server/PVFunctions` file.
- Hosted-server paths often call the handler locally in addition to broadcasting. Preserve those branches when modernizing code.

## PVF Dispatch Internals

Claude independently deep-read the dispatch path and confirmed these runtime details. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### One PV Variable Per Command

`Common/Init/Init_PublicVariables.sqf:43-51` creates one public-variable name per command, such as `WFBE_PVF_RequestJoin` and `WFBE_PVF_TownCaptured`, each with its own `addPublicVariableEventHandler`. This is not one numeric multiplexed protocol channel. Client handlers register under `if (!isServer || local player)`; server handlers register under `if (isServer)`.

### Client-Side Index-0 Routing

`Client/Functions/Client_HandlePVF.sqf` uses payload element 0 as the destination filter:

| Element 0 | Client behavior |
| --- | --- |
| `nil` | Run on all clients. |
| `SIDE` | Run only if `sideJoined == destination`. |
| `STRING` | Run only if `getPlayerUID player == destination`. |

The actual function name comes from element 1 (`CLTFNC<Command>`) and is executed with `_parameters Spawn (Call Compile _script)`. `Server/Functions/Server_HandlePVF.sqf` is simpler: it resolves `SRVFNC<Command>` and spawns it with no destination filtering.

### Wrapper To Engine Primitive Map

| Wrapper | Direction | Engine primitive | Destination handling |
| --- | --- | --- | --- |
| `Common_SendToServer` / optimized variant | client -> server | `publicVariable` or `publicVariableServer` | Server PVF receives command payload. |
| `Common_SendToClients` | server -> clients | `publicVariable` | Payload element 0 is `nil`, side, or UID. |
| `Common_SendToClient` | server -> one client | `publicVariableClient` to `owner _player` | Player object is rewritten to UID for the client filter. |

### Second-Level Multiplexers

Some registered commands are broad routers:

- `Client/PVFunctions/HandleSpecial.sqf` switches over tags such as `join-answer`, `attack-wave`, `commander-vote` and `endgame`.
- `Client/PVFunctions/LocalizeMessage.sqf` switches over message keys such as `Teamkill`, `FundsTransfer` and `AttackModeActivated`.

When tracing one feature, grep the string tag as well as the PVF command name.

### Gotchas

- UID-targeted `SendToClients` still broadcasts to every client and lets non-matching clients discard locally. Use `SendToClient` for true unicast when possible.
- PVF handlers use `Spawn`, so rapid messages that mutate shared state have no strict ordering guarantee.
- Both dispatchers use `Call Compile` on the generated function-name string per dispatch. Keep command names controlled and avoid turning hot paths into chatty PVF streams.
- Some bare PV channels are copied per side, such as `wfbe_supply_temp_west` and `wfbe_supply_temp_east`; there is no resistance-side handler in that path.
- A real BattlEye PV filter must include direct non-PVF channels as well as `WFBE_PVF_*`; the current repo filter only contains `kickAFK`.

### Security: the `Call Compile` trust boundary

`Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` run `Call Compile` on the function-name string taken from the **value a remote machine broadcast** (`select 0` / `select 1`), with no check that it names a registered command — and the shipped `BattlEyeFilter/publicvariable.txt` only carries the `kickAFK` feature rule, not a security filter. Validate the command string against the known `SRVFNC*`/`CLTFNC*` set before compiling, and add a real BattlEye PV filter (restrictive default + whitelist of `WFBE_PVF_*` and the direct channels, keeping `kickAFK`). Full analysis and remediation playbook: [Deep-review findings](Deep-Review-Findings) DR-1.

### Residual Authority Risks After Dispatch Hardening

Replacing `Call Compile` with mission-namespace lookup closes arbitrary code execution from forged function-name strings, but it does not make registered commands authoritative. Hilbert's PV boundary pass found several handlers that still need per-handler sender and payload validation:

| Handler | Trust issue | Evidence |
| --- | --- | --- |
| `RequestChangeScore` | Client payload can overwrite score and broadcast the result. | `Server/PVFunctions/RequestChangeScore.sqf:3-13` |
| `RequestStructure` / `RequestDefense` | Server side mostly checks class existence, then trusts side, position, direction and manning. | `Server/PVFunctions/RequestStructure.sqf:3-21`, `RequestDefense.sqf:2-10` |
| `RequestUpgrade` | Directly spawns upgrade processing; handler itself does not show commander/funds validation. | `Server/PVFunctions/RequestUpgrade.sqf:5`, `Server/Functions/Server_ProcessUpgrade.sqf:40-43` |
| `RequestVehicleLock` | Locks the payload vehicle without visible owner/side/range check. | `Server/PVFunctions/RequestVehicleLock.sqf:3-8` |
| `RequestTeamUpdate` | Accepts array or side and mutates group behavior/combat/formation/speed. | `Server/PVFunctions/RequestTeamUpdate.sqf:3-26` |
| `RequestSpecial` | Broad router for paratroops, support, ICBM, camp repair, teamleader update and HC registration. Claude DR-27 found the `"ICBM"` branch can be forged to server-spawn `NukeDammage` at a client-chosen position with no upgrade/commander/funds validation. | `Client/Module/Nuke/nukeincoming.sqf:23`, `Server/PVFunctions/RequestSpecial.sqf:1`, `Server/Functions/Server_HandleSpecial.sqf:97-112` |

### Highest-Priority Registered Command: ICBM / Nuke

DR-27 makes `RequestSpecial` the highest-priority registered-command hardening target discovered so far. The Tactical menu does client-side ICBM gating and the client sends `["RequestSpecial", ["ICBM", side, baseObj, cruiseObj, team]]`; the server's `HandleSpecial` `"ICBM"` case trusts the payload and spawns nuke damage from it. A forged PV therefore becomes a server-applied map-wide kill. Fixes belong server-side in the `"ICBM"` branch, paired with BattlEye restrictions around `RequestSpecial`.

## Continue Reading

Previous: [Function/module index](Function-And-Module-Index) | Next: [Gameplay atlas](Gameplay-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
