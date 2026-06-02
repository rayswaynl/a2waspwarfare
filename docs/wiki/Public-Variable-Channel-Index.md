# Public Variable Channel Index

> Claude-owned, source-cited (2026-06-02). The single canonical inventory of **every** `publicVariable` channel in the mission: the registered PVF commands (routed through the dispatcher) **and** the direct channels (their own `addPublicVariableEventHandler`s). This is the design surface for any BattlEye `publicvariable.txt` filter and for the server-authority redesign. Supersedes the two ad-hoc tables in [Networking](Networking-And-Public-Variables) and the duplicate in [SQF atlas](SQF-Code-Atlas) (those should point here — see [Wiki quality audit](Wiki-Quality-Audit) DUP-11). Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

## Trust legend

- **PVF (registered):** travels as `WFBE_PVF_<Name>`; the dispatcher `Spawn`s `WFBE_SE_FNC_HandlePVF` / `WFBE_CL_FNC_HandlePVF`, which **`Call Compile` the sender-chosen command string** — the DR-1 RCE/forgery surface. Payload fields are trusted (no server re-derivation) unless a specific handler validates them.
- **Direct:** a bare `publicVariable`/`publicVariableServer`/`publicVariableClient` with its own event handler — **not** behind the dispatcher, so the DR-1 dispatcher fix does not cover it; each must be hardened individually (DR-41 is the confirmed exploit of this class).
- **BattlEye:** none of these are filtered except the `kickAFK` feature rule (DR-30); `ATTACK_WAVE_INIT` and all others are unfiltered.

## 1. Registered PVF commands

Registration: `Common/Init/Init_PublicVariables.sqf` — server-bound list `:9-21`, client-bound list `:25-40`, dispatch wiring `:44-51`. Each name `X` -> channel `WFBE_PVF_X` -> pre-compiled `SRVFNC X` / `CLTFNC X` (built `:45,:50`) but dispatched via `Call Compile` (`Server_HandlePVF.sqf:14` / `Client_HandlePVF.sqf:22`).

### 1a. Server-bound (client → server) — 13

For implementation work after PVF dispatch allowlisting, use the [registered server PVF handler authority matrix](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix). This index owns channel inventory; the authority map owns per-handler validation shape.

| Command (`WFBE_PVF_*`) | Purpose / notable finding |
| --- | --- |
| `RequestVehicleLock` | lock/unlock a vehicle |
| `RequestOnUnitKilled` | report a kill for scoring |
| `RequestChangeScore` | score mutation; accepts payload score and applies `addScore`, unlike safer server-derived award helpers |
| `RequestCommanderVote` | commander vote |
| `RequestNewCommander` | assign new commander — **DR-15** (`_side = _this` call-shape bug); flow map in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| `RequestStructure` | build a structure — **DR-6** (no commander/funds/placement check) |
| `RequestDefense` | build a defense — **DR-6** |
| `RequestJoin` | join handshake (robust 30s-retry, DR-37) |
| `RequestMHQRepair` | MHQ repair — DR-6-class (`_side` from payload); lifecycle/risk map in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| `RequestSpecial` | multiplexer → `Server_HandleSpecial.sqf` (ICBM/paradrop/uav/HC/…) — **DR-27** (forged `["ICBM",…]` = map-wide kill) |
| `RequestTeamUpdate` | team roster update |
| `RequestUpgrade` | side upgrade purchase — **DR-23** (client-authoritative) |
| `RequestAutoWallConstructinChange` | auto-wall construction toggle |

### 1b. Client-bound (server → client) — 15

For runtime/JIP behavior after these messages arrive, use the [registered client PVF runtime matrix](Networking-And-Public-Variables#registered-client-pvf-runtime-matrix). This page owns channel inventory; Networking owns client-side effect and replay notes.

| Command (`WFBE_PVF_*`) | Purpose / notable finding |
| --- | --- |
| `AllCampsCaptured` | all-camps event |
| `AwardBounty` / `AwardBountyPlayer` | bounty award to side / player |
| `CampCaptured` | camp capture event |
| `ChangeScore` | push score change to clients |
| `HandleSpecial` | multiplexer → `Client_FNC_Special.sqf` (endgame/group/icbm-display/hq-status/delegate-*/…) |
| `LocalizeMessage` | localized message multiplexer |
| `SetTask` | task assignment |
| `SetVehicleLock` / `SetMHQLock` | lock-state push; HQ/MHQ context in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| `TownCaptured` | town capture event |
| `Available` | availability push |
| `RequestBaseArea` | base-area (client-bound despite the name); multiplayer-sensitive HQ deploy edge in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| `HandleParatrooperMarkerCreation` | paratrooper-drop unit marker creation; source and maintained Vanilla are propagated, Arma smoke pending in [Paratrooper marker revival](Paratrooper-Marker-Revival) |
| `NukeIncoming` | nuke-incoming broadcast (paired with the ICBM direct channels) |

> `DatabaseDebug` is registered-commented (`:30`).

## 2. Direct publicVariable channels (own event handlers)

Each has its own `addPublicVariableEventHandler`; not behind the dispatcher.

| Channel | Direction | Purpose / notable finding | Source |
| --- | --- | --- | --- |
| `ATTACK_WAVE_INIT` | client → server | activate heavy attack-wave; **DR-41** — server trusts client `_supply`/`_side`, no re-derivation → free units side-wide | `Common/Functions/Common_AttackWaveActivate.sqf:6-8`, `Server/Functions/Server_AttackWave.sqf` |
| `ATTACK_WAVE_DETAILS` | direct server event channel | DR-41 detail payload; `Server_AttackWave.sqf` uses `publicVariableServer`, and the server handler then notifies clients through PVF `HandleSpecial` / `LocalizeMessage` | `Server/Functions/Server_AttackWave.sqf:23-27`, `Server/PVFunctions/AttackWave.sqf:19-25,40-46,58-60` |
| `WFBE_CL_MASH_MARKER_CREATED` | (intended) client → server | **DR-34** — never broadcast in current Chernarus (dead/orphaned); modded forks have sender-only drift | `Server/Module/MASH/MASHMarker.sqf:1` (orphaned PVEH) |
| `WFBE_SE_MASH_MARKER_SENT` | (intended) server → clients | **DR-34** — receiver commented `Init_Client.sqf:132` (dead) | `Client/Module/MASH/receiverMASHmarker.sqf:1` |
| `WFBE_Client_PV_IsSupplyMissionActiveInTown` | client → server | supply-cooldown query (pull-based; JIP-correct, DR-39) | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1` |
| `WFBE_Server_PV_IsSupplyMissionActiveInTown` | server → clients | cooldown answer (broadcast not targeted) | `Client/Module/supplyMission/townSupplyStatus.sqf:1` |
| `WFBE_Client_PV_SupplyMissionStarted` | client → server | start supply mission; live handler is `supplyMissionStarted.sqf`, while compiled `supplyMissionActive.sqf` is a dead twin | `Client/Module/supplyMission/supplyMissionStart.sqf:39`, `Server/Module/supplyMission/supplyMissionStarted.sqf:1`, `Server/Init/Init_Server.sqf:81` |
| `WFBE_Server_PV_SupplyMissionCompleted` / `…CompletedMessage` | server | completion / message; still consumes vehicle object vars that are stamped during client start | `Server/Module/supplyMission/supplyMissionStarted.sqf:65`, `Server/Module/supplyMission/supplyMissionCompleted.sqf:2,9-12,34` |
| `wfbe_supply_temp_east` / `wfbe_supply_temp_west` | client → server | side-supply mutation — **DR-44** direct-PV forgery class plus DR-22 broken-floor risk; server applies `[side, amount, reason]` payload to keyed `wfbe_supply_%1` state, while generic `wfbe_supply` is legacy/cache | `Common/Functions/Common_ChangeSideSupply.sqf:28-30`, `Server/Functions/Server_ChangeSideSupply.sqf:1,19,21,25` |
| `ICBM_launched` | server → clients | ICBM launch FX trigger | `Client/FSM/updateclient.sqf:20` |
| `PLAYER_RADIATED` | server → clients | nuke radiation effect | `Client/Module/Nuke/OnEventHandler_player_radiated.sqf` |
| `AFKthresholdExceededName` / `kickAFK` | client → server/BattlEye | AFK kick (the one BattlEye-filtered PV, DR-30) | `Client/Module/AFK/monitorAFK.sqf`; `BattlEyeFilter/publicvariable.txt` |
| `WFBE_DAYNIGHT_DATE` | server → clients | day/night drift sync (reviewed clean, Round 17) | `Server/Functions/Server_DayNightCycle.sqf` |
| `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` | server → clients | server FPS GUI/HUD publication. Current source Chernarus player UI reads `SERVER_FPS_GUI`; `WFBE_VAR_SERVER_FPS` is a second dedicated publisher with no source Chernarus player-UI reader found. | `Server/GUI/serverFpsGUI.sqf:6-7`, `Server/Module/serverFPS/monitorServerFPS.sqf:5-6`, `Client/Client_UpdateRHUD.sqf:113`, `Server/Init/Init_Server.sqf:578,595` |
| `IS_WEST_HQ_ALIVE` / `IS_EAST_HQ_ALIVE` | server → clients | HQ alive-state broadcast; see [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `HQ_WEST_MARKER_INFOS` / `HQ_EAST_MARKER_INFOS` | server → clients | HQ marker payload broadcast; see [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `SUPPLY_COMPENSATION_AMOUNT_EAST` / `SUPPLY_COMPENSATION_AMOUNT_WEST` | server → clients | AntiStack skill-difference supply compensation | `Server/Module/AntiStack/skillDiffCompensation.sqf` |
| `TEAM_WEST_TICKS_NO_PLAYERS` / `TEAM_EAST_TICKS_NO_PLAYERS` | common/server → clients | no-player supply-income stagnation counters | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf` |
| `MARKER_CREATION` | server → clients | map-marker creation channel | WASP/marker code |
| `SEND_MESSAGE` | mixed | message channel | message code |
| `REQUEST_SUPPLY_VALUE` / `SUPPLY_VALUE_REQUESTED` | client ↔ server | supply-value request/response; read/probe surface rather than final mutation, and a useful safer pattern because the server derives the response value | `Common/Functions/Common_GetSideSupply.sqf:15`, `Server/Functions/Server_PV_RequestSupplyValue.sqf:1,8`, `Client/Functions/Client_ReceiveSupplyValue.sqf:1,7` |
| `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` / `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | client ↔ server | launch-connect handshake (DR-37) | `Client/Init/Init_Client.sqf:444-` |
| `CLIENT_INIT_READY` | client → server | client-init-ready signal | `Client/Init/Init_Client.sqf` |
| `WFBE_C_PLAYER_OBJECT` | client → server | player-object publication for `WFBE_SE_PLAYERLIST`; source indexing is patched, but disconnect pruning/stale row cleanup remains open | `Client/Init/Init_Client.sqf:759-760`, `Server/Module/supplyMission/playerObjectsList.sqf:1-35` |

## Hardening note

For a real BattlEye `publicvariable.txt`, the default-deny whitelist must cover **both** tables — registered `WFBE_PVF_*` names and these direct channels — keeping `kickAFK`. But BattlEye is defense-in-depth only; the durable fix is server-side authority in the PVF handlers (DR-1) **and** each direct handler (DR-41). See [Pending owner decisions](Pending-Owner-Decisions).

## Continue Reading

Conventions: [Variable and naming conventions](Variable-And-Naming-Conventions) | Dispatch internals: [Networking](Networking-And-Public-Variables) | Findings: [Deep-review findings](Deep-Review-Findings)
