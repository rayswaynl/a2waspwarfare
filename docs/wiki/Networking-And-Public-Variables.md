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

- Supply mission: `WFBE_Client_PV_IsSupplyMissionActiveInTown`, `WFBE_Client_PV_SupplyMissionStarted`, `WFBE_Server_PV_IsSupplyMissionActiveInTown`, `WFBE_Server_PV_SupplyMissionCompleted`, `WFBE_Server_PV_SupplyMissionCompletedMessage`.
- Anti-stack join checks: `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH`, `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`, `WFBE_C_PLAYER_OBJECT`.
- Day/night: `WFBE_DAYNIGHT_DATE`.
- Server FPS/HUD: `SERVER_FPS_GUI`, `WFBE_VAR_SERVER_FPS`.
- AFK kick: `AFKthresholdExceededName` and `kickAFK`; `kickAFK` is intentionally caught by BattlEye filters because serverCommand is unavailable.
- Markers/messages: `MARKER_CREATION`, `SEND_MESSAGE`, ICBM and radiation variables.

## Safety Notes

- Keep payloads small and structured; Arma 2 public-variable traffic can be expensive.
- Prefer server authority for state changes. Client scripts should request, not mutate, team/base/economy state directly.
- When adding a PVF command, update both the registration list and the target `Client/PVFunctions` or `Server/PVFunctions` file.
- Hosted-server paths often call the handler locally in addition to broadcasting. Preserve those branches when modernizing code.

