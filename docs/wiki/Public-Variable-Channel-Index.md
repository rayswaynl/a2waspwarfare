# Public Variable Channel Index

Source-cited (2026-06-03). This is the active Arma 2 OA 1.64 networking map for `publicVariable*` channels and mission namespace replication paths in:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`

## Trust Legend

- **PVF (registered):** goes through `WFBE_PVF_<Name>` + `Server_HandlePVF` / `Client_HandlePVF`.
- **Direct channel:** sends with bare `publicVariable*` and dedicated handlers.
- **Authority owner:** where validation happens; dispatcher trust is not authority.
- **JIP risk:** whether late joiners can recover this value automatically.

## 1. Registered PVF commands (`Init_PublicVariables.sqf`)

Registration details:
- server command list around lines 8-20
- client command list around lines 25-41
- handler binding around lines 43-50
- every token is compiled into `SRVFNC*` / `CLTFNC*` in mission namespace and run by Spawn in the dispatchers.

### 1a) Server-bound PVF commands (Client -> Server)

| Command (`WFBE_PVF_*`) | Sender | Receiver | Payload | Authority owner | JIP risk | Source |
| --- | --- | --- | --- | --- | --- | --- |
| `RequestVehicleLock` | Client request wrappers | `WFBE_SE_FNC_HandlePVF` -> `Server_PV_RequestVehicleLock` handler | Request args for vehicle and lock flag | Handler-level checks are command-specific | Event-like only; no replay | `Common/Init/Init_PublicVariables.sqf`, `Server/Functions/Server_HandleVehicleLock.sqf`, `Server/PVFunctions/RequestVehicleLock.sqf` |
| `RequestOnUnitKilled` | Score/kill reporter | `WFBE_SE_FNC_HandlePVF` -> `Server_HandleOnUnitKilled` handler | Kill event payload | Scoring path trust is handler-local | Event-like only; no replay | `Common/Init/Init_PublicVariables.sqf`, `Server/Functions/Server_OnUnitKilled.sqf`, `Server/PVFunctions/Server_OnUnitKilled.sqf` |
| `RequestChangeScore` | Unit scoring hooks | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestChangeScore.sqf` | Score delta + player/side args | **High risk:** handler currently applies provided payload directly | Event-like only; no replay | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestChangeScore.sqf` |
| `RequestCommanderVote` | Commander vote UI | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestCommanderVote.sqf` | Vote + candidate args | Handler trust and rate-limits are command-specific | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestCommanderVote.sqf` |
| `RequestNewCommander` | Commander vote UI | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestNewCommander.sqf` | `[side, newCommander]` currently inferred | **Unclear ownership:** no strict requester identity check; duplicate notify path exists | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestNewCommander.sqf`, `Server/Functions/Server_AssignNewCommander.sqf`, `Deep-Review-Findings.md DR-15` |
| `RequestStructure` | Construction UI | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestStructure.sqf` | Construction request array | Server does class checks, but authority shape is mixed | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestStructure.sqf` |
| `RequestDefense` | Construction/defense UI | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestDefense.sqf` | Construction request array | Similar to `RequestStructure` | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestDefense.sqf` |
| `RequestJoin` | Join handshake | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestJoin.sqf` | Join-side args | Join path includes handler state checks | Event-like only; no replay | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestJoin.sqf` |
| `RequestMHQRepair` | HQ repair action path | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestMHQRepair.sqf` | Repair request + team context | Mutating effect path is server-side but payload validation is command-level | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestMHQRepair.sqf`, `Server/Functions/Server_MHQRepair.sqf` |
| `RequestSpecial` | Tactical/module special sender | `WFBE_SE_FNC_HandlePVF` -> `Server/Functions/Server_HandleSpecial.sqf` | Multi-action string key payload | **Critical:** per-action authorization is handler-local; `ICBM` remains DR-27 gap | Event-like only; no replay | `Common/Init/Init_PublicVariables.sqf`, `Server/Functions/Server_HandleSpecial.sqf`, `Server/PVFunctions/RequestSpecial.sqf`, `Deep-Review-Findings.md DR-27` |
| `RequestTeamUpdate` | Team UI/logic | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestTeamUpdate.sqf` | Team/slot update args | Side/leader authority in handler | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestTeamUpdate.sqf` |
| `RequestUpgrade` | Upgrade request UI | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestUpgrade.sqf` | upgrade request args | **High risk:** handler chain still trusts client-sourced side/upgrade intent | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestUpgrade.sqf`, `Server/Functions/Server_ProcessUpgrade.sqf` |
| `RequestAutoWallConstructinChange` | Auto-wall UI | `WFBE_SE_FNC_HandlePVF` -> `Server/PVFunctions/RequestAutoWallConstructinChange.sqf` | toggle + side/position args | Handler authority path partial | Event-like only | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/RequestAutoWallConstructinChange.sqf` |

### 1b) Client-bound PVF commands (Server -> Client)

| Command (`WFBE_PVF_*`) | Sender | Receiver | Payload | Authority owner | JIP risk | Source |
| --- | --- | --- | --- | --- | --- | --- |
| `AllCampsCaptured` | server event path | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/AllCampsCaptured.sqf` | world-state snapshot fields | Server event source; client consumes | no replay buffer (latest variable only if re-broadcast) | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/AllCampsCaptured.sqf` |
| `AwardBounty` / `AwardBountyPlayer` | bounty sender | `WFBE_CL_FNC_HandlePVF` -> bounty handlers | award amount + scope | server event source, client UI/fx | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Server/PVFunctions/AwardBounty*.sqf`, `Client/PVFunctions/AwardBounty*.sqf` |
| `CampCaptured` | capture engine | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/CampCaptured.sqf` | camp id + ownership | server event source | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/CampCaptured.sqf` |
| `ChangeScore` | score engine | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/ChangeScore.sqf` | score update payload | server event source, client scoreboard updates | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/ChangeScore.sqf` |
| `HandleSpecial` | `Server/Functions/Server_HandleSpecial.sqf` | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/HandleSpecial.sqf` | request key + args | Handler trust is client-side dispatch map-specific | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/HandleSpecial.sqf`, `Server/Functions/Server_HandleSpecial.sqf` |
| `LocalizeMessage` | message system | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/LocalizeMessage.sqf` | message key + args | server event source + client stringtable mapping | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/LocalizeMessage.sqf` |
| `SetTask` | task system | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/SetTask.sqf` | task tuple | server event source | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/SetTask.sqf` |
| `SetVehicleLock` / `SetMHQLock` | lock engine | `WFBE_CL_FNC_HandlePVF` -> lock handlers | vehicle/object lock payload | server-side state then client apply | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/SetVehicleLock.sqf`, `Client/PVFunctions/SetMHQLock.sqf` |
| `TownCaptured` | capture engine | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/TownCaptured.sqf` | town/town-state payload | server event source | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/TownCaptured.sqf` |
| `Available` | availability engine | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/Available.sqf` | availability chunk | server event source | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/Available.sqf` |
| `RequestBaseArea` | base-area response path | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/RequestBaseArea.sqf` | base-area response payload | server event source | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/RequestBaseArea.sqf` |
| `NukeIncoming` | nuke flow | `WFBE_CL_FNC_HandlePVF` -> `Client/PVFunctions/NukeIncoming.sqf` | explosion + warning payload | server event source | no replay buffer | `Common/Init/Init_PublicVariables.sqf`, `Client/PVFunctions/NukeIncoming.sqf`, `Server/Functions/Server_HandleSpecial.sqf` |

Current registration gap:
- `HandleParatrooperMarkerCreation` sender/handler exists in support flow, but `_clientCommandPV` registration is missing in source Chernarus and generated Vanilla.

## 2. Direct publicVariable channels (non-PVF)

| Channel | Direction | Sender / receiver | Payload | Authority owner | JIP risk | Source |
| --- | --- | --- | --- | --- | --- | --- |
| `ATTACK_WAVE_INIT` | client -> server | `Common/Functions/Common_AttackWaveActivate.sqf` -> `Server/Functions/Server_AttackWave.sqf` | `[_supply, _side]` | **High**: server trusts client payload (DR-41) | event only | `Common/Functions/Common_AttackWaveActivate.sqf`, `Server/Functions/Server_AttackWave.sqf` |
| `ATTACK_WAVE_DETAILS` | server -> clients | `Server/Functions/Server_AttackWave.sqf` -> marker/FSM + listeners | attack-wave details | server-owned payload generation | latest-value if variable is read after join | `Server/Functions/Server_AttackWave.sqf` |
| `WFBE_CL_MASH_MARKER_CREATED` | client -> server | intended MASH sender -> `Server/Module/MASH/MASHMarker.sqf` | marker payload | server-side listener present | dead/no replay if no sender broadcast | `Server/Module/MASH/MASHMarker.sqf` |
| `WFBE_SE_MASH_MARKER_SENT` | server -> clients | `Client/Module/MASH/receiverMASHmarker.sqf` (compile path currently commented) | marker payload | **dead** without active receiver compile | effectively dead for current code | `Client/Module/MASH/receiverMASHmarker.sqf`, `Client/Init/Init_Client.sqf` |
| `WFBE_Client_PV_IsSupplyMissionActiveInTown` | client -> server | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf` | town/side query tuple | query path; authority depends on handler validation | no replay; pull-response pattern | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf`, `Client/Module/supplyMission/townSupplyStatus.sqf` |
| `WFBE_Server_PV_IsSupplyMissionActiveInTown` | server -> clients | supply cooldown query responder -> map/status UI | town availability payload | server-owned status | latest-value available if queried after join | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf`, `Client/Module/supplyMission/townSupplyStatus.sqf` |
| `WFBE_Client_PV_SupplyMissionStarted` | client -> server | `Server/Module/supplyMission/supplyMissionStarted.sqf` | truck/objective + mission args | server-side mission start handler | no replay | `Client/Module/supplyMission/supplyMissionStart.sqf`, `Server/Module/supplyMission/supplyMissionStarted.sqf` |
| `WFBE_Server_PV_SupplyMissionCompleted` / `WFBE_Server_PV_SupplyMissionCompletedMessage` | server -> clients | supply complete announcer -> client HUD/chat | payout + message fields | server event source | latest-value only; no sequence replay | `Server/Module/supplyMission/supplyMissionCompleted.sqf`, `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf` |
| `wfbe_supply_temp_east` / `wfbe_supply_temp_west` | client -> server | `Common/Functions/Common_ChangeSideSupply.sqf` -> `Server/Functions/Server_ChangeSideSupply.sqf` | `[change, side]` request | **High**: request side and amount are client-authored | event only | `Common/Functions/Common_ChangeSideSupply.sqf`, `Server/Functions/Server_ChangeSideSupply.sqf`, `Common/Functions/Common_GetSideSupply.sqf` |
| `ICBM_launched` | server -> clients | nuke runtime -> clients | damage/effect payload | server-owned | no replay | `Server/Functions/Server_HandleSpecial.sqf`, `Client/FSM/updateclient.sqf` |
| `PLAYER_RADIATED` | server -> clients | radiation runtime -> local listeners | dose + source payload | server-owned | no replay | `Client/Module/Nuke/OnEventHandler_player_radiated.sqf`, `Server/Module/Nuke` |
| `AFKthresholdExceededName` / `kickAFK` | client -> server | AFK monitor -> moderation path | AFK name/uid tuple | moderation whitelist exists for known AFK rule only | no replay | `Client/Module/AFKkick/monitorAFK.sqf`, `BattlEyeFilter/publicvariable.txt` |
| `WFBE_DAYNIGHT_DATE` | server -> clients | day/night cycle broadcaster -> client time state | date + offset tuple | server-owned + JIP bootstrap fallback | latest-value works for post-join sync | `Server/Functions/Server_DayNightCycle.sqf`, `initJIPCompatible.sqf` |
| `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` | server -> clients | server FPS publisher -> client HUD | FPS counters | server-owned metrics | periodic publication; no guaranteed replay | `Server/Module/serverFPS/serverFpsGUI.sqf`, `Server/Module/serverFPS/monitorServerFPS.sqf` |
| `IS_WEST_HQ_ALIVE` / `IS_EAST_HQ_ALIVE` | server -> clients | HQ status publisher -> HUD/logic | HQ alive booleans | server-owned | latest-value if variable is republished | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `HQ_WEST_MARKER_INFOS` / `HQ_EAST_MARKER_INFOS` | server -> clients | HQ marker payload broadcaster -> client marker handler | marker arrays | server-owned | latest-value if republished | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `SUPPLY_COMPENSATION_AMOUNT_EAST` / `SUPPLY_COMPENSATION_AMOUNT_WEST` | server -> clients | compensation broadcaster -> UI | compensation integer + side | server-owned | no replay semantics | `Server/Module/AntiStack/skillDiffCompensation.sqf` |
| `TEAM_WEST_TICKS_NO_PLAYERS` / `TEAM_EAST_TICKS_NO_PLAYERS` | server/common -> clients | server stat publisher | stagnation tick arrays | server-owned | latest-value on latest publish | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf` |
| `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` / `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | client/server handshake path | launch handshake + ack scripts | handshake payload | mixed owner, minimal auth in source | no replay semantics | `Client/Init/Init_Client.sqf`, `Server/Functions/Server_OnPlayerConnected.sqf` |
| `CLIENT_INIT_READY` | client -> server | init-ready sender -> bootstrap responder | readiness bools | bootstrap sequencing helper | no replay | `Client/Init/Init_Client.sqf`, `Server/Functions/Server_OnPlayerConnected.sqf` |
| `WFBE_C_PLAYER_OBJECT` | mixed | runtime object announcer | player object + context | mixed ownership, flow-specific auth | no replay by design; state should use setVariable true | `Client/Init/Init_Client.sqf`, `Server/Functions/Server_OnPlayerConnected.sqf` |
| `REQUEST_SUPPLY_VALUE` / `SUPPLY_VALUE_REQUESTED` | client -> server -> clients | request/response supply query | town + side + request id | pull model owns state server-side | effectively safe for JIP because value comes from request response | `Server/Functions/Server_PV_RequestSupplyValue.sqf`, `Client/Functions/Client_ReceiveSupplyValue.sqf` |
| `MARKER_CREATION` / `SEND_MESSAGE` | mixed legacy | WASP/event system -> marker/chat handlers | message payloads | mixed ownership, command-specific handlers | no replay guarantees | `WASP/global_marking_monitor.sqf`, message handler scripts |

## 3. Unclear ownership / duplicates / races

### Unclear ownership

- `WFBE_CL_MASH_MARKER_CREATED` has an active server listener but no proven live client sender.
- `WFBE_SE_MASH_MARKER_SENT` has a live handler file but commented compile in `Client/Init/Init_Client.sqf`.
- `HandleParatrooperMarkerCreation` remains the known send->receive gap: sender and client handler exist, but `_clientCommandPV` registration is missing in Chernarus/Vanilla currently.

### Missing validation

- Direct channels are trust-bearing by default unless handler validation is explicit:
  - `ATTACK_WAVE_INIT`
  - `wfbe_supply_temp_*`
  - `RequestNewCommander`, `RequestUpgrade`, `RequestStructure`, `RequestDefense`, `RequestSpecial` for handler-level validation gaps.

### Duplicate / duplicate-like handlers

- Commander reassignment paths are already documented as multi-notify duplicate candidates in `Feature-Status-Register` (DR-15 follow-up).
- Destination filter by side/UID in `Client_HandlePVF.sqf` does not dedupe by transaction ID; repeated packets can re-run handler logic if sender resends.

### Likely races and lost ordering

- `Client_HandlePVF.sqf` and `Server_HandlePVF.sqf` execute each packet via `Spawn`, so there is no strict ordering guarantee across fast successive `publicVariable` events.
- `Client_HandlePVF.sqf` still uses `publicVariable` broadcast before applying destination filters (`nil`/`SIDE`/`UID`), so all clients deserialize then ignore, which can magnify timing and performance under bursts.
- Nested handlers (e.g., `HandleSpecial`, `LocalizeMessage`) switch by request key with no dedupe tokens, so repeated packets can duplicate one-shot UX effects.

## Hardening note

This index is routing + inventory only. The durable security boundary is `handler validation` + `owner/requester proof`.
`PVF` dispatcher hardening (allowlisted handler lookup) addresses only one layer (DR-1/DR-38); direct channels need separate authority hardening.

## Continue Reading

Conventions: [Variable and naming conventions](Variable-And-Naming-Conventions) | Dispatch internals: [Networking](Networking-And-Public-Variables) | Findings: [Deep-review findings](Deep-Review-Findings)
