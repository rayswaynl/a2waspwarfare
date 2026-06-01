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

### Security: the `Call Compile` trust boundary

`Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` run `Call Compile` on the function-name string taken from the **value a remote machine broadcast** (`select 0` / `select 1`), with no check that it names a registered command — and the shipped `BattlEyeFilter/publicvariable.txt` only carries the `kickAFK` feature rule, not a security filter. Validate the command string against the known `SRVFNC*`/`CLTFNC*` set before compiling, and add a real BattlEye PV filter (restrictive default + whitelist of `WFBE_PVF_*` and the direct channels, keeping `kickAFK`). Full analysis and remediation playbook: [Deep-review findings](Deep-Review-Findings) DR-1.

## Continue Reading

Previous: [Function/module index](Function-And-Module-Index) | Next: [Gameplay atlas](Gameplay-Systems-Atlas)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
