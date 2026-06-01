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

## PVF dispatch internals (Claude deep-dive, source-cited)

The registry above tells you *which* commands exist; this section documents *how a message is actually routed and executed* once it arrives. Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

### One PV variable per command — no numeric multiplexing

Registration (`Common/Init/Init_PublicVariables.sqf:43-51`) creates one PV name per command (`WFBE_PVF_RequestJoin`, `WFBE_PVF_TownCaptured`, …), each with its own `addPublicVariableEventHandler`. There is **no** single multiplexed channel with a numeric protocol ID. The handlers are gated by role: client handlers register under `if (!isServer || local player)`; server handlers under `if (isServer)`.

### Index-0 routing on the client side

`Client/Functions/Client_HandlePVF.sqf` inspects element 0 of the payload to decide whether *this* client should run the function:

- `nil` → run on **all** clients.
- a `SIDE` value → run only if `sideJoined == destination` (`:14`).
- a `STRING` (player UID) → run only if `getPlayerUID player == destination` (`:15`).

The actual function is resolved from element 1 (`"CLTFNC<Command>"`) and executed with `_parameters Spawn (Call Compile _script)` (`:22`). The server dispatcher `Server/Functions/Server_HandlePVF.sqf:1-13` is simpler — no routing, just `Spawn (Call Compile _script)`.

### The four send wrappers map to four engine primitives

| Wrapper (compiled name `WFBE_CO_FNC_…`) | Direction | Engine primitive | Element 0 |
| --- | --- | --- | --- |
| `Common_SendToServer` / `…Optimized` → `SendToServer` | client→server | `publicVariable` (vanilla) / `publicVariableServer` (OA/CO) | n/a |
| `Common_SendToClients` → `SendToClients` | server→clients | `publicVariable` | destination (`nil`/SIDE/UID) |
| `Common_SendToClient` → `SendToClient` | server→one client | `publicVariableClient` to `owner _player` | player object (rewritten to UID for the client filter) |

### Two layers of multiplexing

A second routing layer lives *inside* two god-functions, dispatched by a runtime string tag:

- `Client/PVFunctions/HandleSpecial.sqf:8-37` — `switch (_request)` over 20+ cases (`join-answer`, `attack-wave`, `commander-vote`, `endgame`, …). Server side mirrors this in `Server/Functions/Server_HandleSpecial.sqf`.
- `Client/PVFunctions/LocalizeMessage.sqf:10-113` — `switch` over message keys (`Teamkill`, `FundsTransfer`, `AttackModeActivated`, …).

When tracing a feature, a single registered command (`WFBE_PVF_HandleSpecial`) can carry many heterogeneous messages — grep for the string tag, not just the command name.

### Gotchas

- **UID-targeted broadcast is wasteful.** `SendToClients` with a UID at element 0 (e.g. `Server/PVFunctions/RequestOnUnitKilled.sqf:86` awarding bounty) still `publicVariable`s to *every* client; each non-matching client deserializes and discards it in `Client_HandlePVF.sqf:15`. For true unicast prefer `SendToClient` (`publicVariableClient`).
- **All handlers `Spawn` (not `Call`).** Messages run in fresh scheduled threads with no ordering guarantee; two rapid messages mutating the same state (e.g. back-to-back `ChangeScore`) can race.
- **`Call Compile` per dispatch.** Both dispatchers recompile the function-name string on every message even though the function object already exists in a global — a minor per-message CPU cost on hot paths.
- **Per-side copy-paste channels.** Some bare-PV channels are duplicated per side rather than parameterized, e.g. `wfbe_supply_temp_west` / `wfbe_supply_temp_east` each get their own event handler in `Server/Functions/Server_ChangeSideSupply.sqf` (no resistance handler).

### Security: the `Call Compile` trust boundary

`Server_HandlePVF.sqf` / `Client_HandlePVF.sqf` run `Call Compile` on the function-name string taken from the **value a remote machine broadcast** (`select 0` / `select 1`), with no check that it names a registered command — and the shipped `BattlEyeFilter/publicvariable.txt` only carries the `kickAFK` feature rule, not a security filter. Validate the command string against the known `SRVFNC*`/`CLTFNC*` set before compiling, and add a real BattlEye PV filter. Full analysis and remediation playbook: [Deep-review findings](Deep-Review-Findings) DR-1.

