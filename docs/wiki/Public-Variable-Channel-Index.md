# Public Variable Channel Index

> Claude-owned, source-cited (2026-06-02). The single canonical inventory of **every** `publicVariable` channel in the mission: the registered PVF commands (routed through the dispatcher) **and** the direct channels (their own `addPublicVariableEventHandler`s). This is the design surface for any BattlEye `publicvariable.txt` filter and for the server-authority redesign. Supersedes the two ad-hoc tables in [Networking](Networking-And-Public-Variables) and the duplicate in [SQF atlas](SQF-Code-Atlas) (those should point here — see [Wiki quality audit](Wiki-Quality-Audit) DUP-11). Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

## Trust legend

- **PVF (registered):** travels as `WFBE_PVF_<Name>`; the dispatcher `Spawn`s `WFBE_SE_FNC_HandlePVF` / `WFBE_CL_FNC_HandlePVF`, which **`Call Compile` the sender-chosen command string** — the DR-1 RCE/forgery surface. Payload fields are trusted (no server re-derivation) unless a specific handler validates them.
- **Direct:** a bare `publicVariable`/`publicVariableServer`/`publicVariableClient` with its own event handler — **not** behind the dispatcher, so the DR-1 dispatcher fix does not cover it; each must be hardened individually (DR-41 is the confirmed exploit of this class).
- **BattlEye:** none of these are filtered except the `kickAFK` feature rule (DR-30); `ATTACK_WAVE_INIT` and all others are unfiltered.

## 1. Registered PVF commands

Registration: `Common/Init/Init_PublicVariables.sqf` — server-bound list `:8-20`, client-bound list `:23-37`, dispatch wiring `:44-50`. Each name `X` → channel `WFBE_PVF_X` → pre-compiled `SRVFNC X` / `CLTFNC X` (built `:44,:49`) but dispatched via `Call Compile` (`Server_HandlePVF.sqf:14` / `Client_HandlePVF.sqf:22`).

### 1a. Server-bound (client → server) — 13

| Command (`WFBE_PVF_*`) | Purpose / notable finding |
| --- | --- |
| `RequestVehicleLock` | lock/unlock a vehicle |
| `RequestOnUnitKilled` | report a kill for scoring |
| `RequestChangeScore` | score mutation |
| `RequestCommanderVote` | commander vote |
| `RequestNewCommander` | assign new commander — **DR-15** (`_side = _this` call-shape bug) |
| `RequestStructure` | build a structure — **DR-6** (no commander/funds/placement check) |
| `RequestDefense` | build a defense — **DR-6** |
| `RequestJoin` | join handshake (robust 30s-retry, DR-37) |
| `RequestMHQRepair` | MHQ repair — DR-6-class (`_side` from payload) |
| `RequestSpecial` | multiplexer → `Server_HandleSpecial.sqf` (ICBM/paradrop/uav/HC/…) — **DR-27** (forged `["ICBM",…]` = map-wide kill) |
| `RequestTeamUpdate` | team roster update |
| `RequestUpgrade` | side upgrade purchase — **DR-23** (client-authoritative) |
| `RequestAutoWallConstructinChange` | auto-wall construction toggle |

### 1b. Client-bound (server → client) — 14

| Command (`WFBE_PVF_*`) | Purpose / notable finding |
| --- | --- |
| `AllCampsCaptured` | all-camps event |
| `AwardBounty` / `AwardBountyPlayer` | bounty award to side / player |
| `CampCaptured` | camp capture event |
| `ChangeScore` | push score change to clients |
| `HandleSpecial` | multiplexer → `Client_FNC_Special.sqf` (endgame/group/icbm-display/hq-status/delegate-*/…) |
| `LocalizeMessage` | localized message multiplexer |
| `SetTask` | task assignment |
| `SetVehicleLock` / `SetMHQLock` | lock-state push |
| `TownCaptured` | town capture event |
| `Available` | availability push |
| `RequestBaseArea` | base-area (client-bound despite the name) |
| `NukeIncoming` | nuke-incoming broadcast (paired with the ICBM direct channels) |

> `DatabaseDebug` is registered-commented (`:30`).

## 2. Direct publicVariable channels (own event handlers)

Each has its own `addPublicVariableEventHandler`; not behind the dispatcher.

| Channel | Direction | Purpose / notable finding | Source |
| --- | --- | --- | --- |
| `ATTACK_WAVE_INIT` | client → server | activate heavy attack-wave; **DR-41** — server trusts client `_supply`/`_side`, no re-derivation → free units side-wide | `Common/Functions/Common_AttackWaveActivate.sqf:6-8`, `Server/Functions/Server_AttackWave.sqf` |
| `ATTACK_WAVE_DETAILS` | server → clients | broadcast resulting price modifier + length | `Server/Functions/Server_AttackWave.sqf:23-27` |
| `WFBE_CL_MASH_MARKER_CREATED` | (intended) client → server | **DR-34** — never broadcast (dead) | `Server/Module/MASH/MASHMarker.sqf:1` (orphaned PVEH) |
| `WFBE_SE_MASH_MARKER_SENT` | (intended) server → clients | **DR-34** — receiver commented `Init_Client.sqf:132` (dead) | `Client/Module/MASH/receiverMASHmarker.sqf:1` |
| `WFBE_Client_PV_IsSupplyMissionActiveInTown` | client → server | supply-cooldown query (pull-based; JIP-correct, DR-39) | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1` |
| `WFBE_Server_PV_IsSupplyMissionActiveInTown` | server → clients | cooldown answer (broadcast not targeted) | `Client/Module/supplyMission/townSupplyStatus.sqf:1` |
| `WFBE_Client_PV_SupplyMissionStarted` | client → server | start supply mission (live loop) | `Server/Module/supplyMission/supplyMissionStarted.sqf:1` |
| `WFBE_Server_PV_SupplyMissionCompleted` / `…CompletedMessage` | server | completion / message | `Server/Module/supplyMission/supplyMissionCompleted.sqf` |
| `wfbe_supply_temp_east` / `wfbe_supply_temp_west` | client → server | side-supply mutation — economy-authority class (DR-22) | `Common/Functions/Common_ChangeSideSupply.sqf` |
| `ICBM_launched` | server → clients | ICBM launch FX trigger | `Client/FSM/updateclient.sqf:20` |
| `PLAYER_RADIATED` | server → clients | nuke radiation effect | `Client/Module/Nuke/OnEventHandler_player_radiated.sqf` |
| `AFKthresholdExceededName` / `kickAFK` | client → server/BattlEye | AFK kick (the one BattlEye-filtered PV, DR-30) | `Client/Module/AFK/monitorAFK.sqf`; `BattlEyeFilter/publicvariable.txt` |
| `WFBE_DAYNIGHT_DATE` | server → clients | day/night drift sync (reviewed clean, Round 17) | `Server/Functions/Server_DayNightCycle.sqf` |
| `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` | server → clients | server FPS GUI/HUD publication | `Server/Module/serverFPS/serverFpsGUI.sqf`, `Server/Init/Init_Server.sqf` |
| `IS_WEST_HQ_ALIVE` / `IS_EAST_HQ_ALIVE` | server → clients | HQ alive-state broadcast | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `HQ_WEST_MARKER_INFOS` / `HQ_EAST_MARKER_INFOS` | server → clients | HQ marker payload broadcast | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `SUPPLY_COMPENSATION_AMOUNT_EAST` / `SUPPLY_COMPENSATION_AMOUNT_WEST` | server → clients | AntiStack skill-difference supply compensation | `Server/Module/AntiStack/skillDiffCompensation.sqf` |
| `TEAM_WEST_TICKS_NO_PLAYERS` / `TEAM_EAST_TICKS_NO_PLAYERS` | common/server → clients | no-player supply-income stagnation counters | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf` |
| `MARKER_CREATION` | server → clients | map-marker creation channel | WASP/marker code |
| `SEND_MESSAGE` | mixed | message channel | message code |
| `REQUEST_SUPPLY_VALUE` / `SUPPLY_VALUE_REQUESTED` | client ↔ server | supply-value request/response | supply code |
| `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` / `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | client ↔ server | launch-connect handshake (DR-37) | `Client/Init/Init_Client.sqf:444-` |
| `CLIENT_INIT_READY` | client → server | client-init-ready signal | `Client/Init/Init_Client.sqf` |
| `WFBE_C_PLAYER_OBJECT` | mixed | player-object publication | client/server |

## Hardening note

For a real BattlEye `publicvariable.txt`, the default-deny whitelist must cover **both** tables — registered `WFBE_PVF_*` names and these direct channels — keeping `kickAFK`. But BattlEye is defense-in-depth only; the durable fix is server-side authority in the PVF handlers (DR-1) **and** each direct handler (DR-41). See [Pending owner decisions](Pending-Owner-Decisions).

## Continue Reading

Conventions: [Variable and naming conventions](Variable-And-Naming-Conventions) | Dispatch internals: [Networking](Networking-And-Public-Variables) | Findings: [Deep-review findings](Deep-Review-Findings)
