# Public Variable Channel Index

> Claude-owned, source-cited (2026-06-02). The single canonical inventory of **every** `publicVariable` channel in the mission: the registered PVF commands (routed through the dispatcher) **and** the direct channels (their own `addPublicVariableEventHandler`s). This is the design surface for any BattlEye `publicvariable.txt` filter and for the server-authority redesign. Supersedes the two ad-hoc tables in [Networking](Networking-And-Public-Variables) and the duplicate in [SQF atlas](SQF-Code-Atlas) (those should point here — see [Wiki quality audit](Wiki-Quality-Audit) DUP-11). Paths relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`. Arma 2 OA 1.64.

## Trust legend

- **PVF (registered):** travels as `WFBE_PVF_<Name>`; the dispatcher `Spawn`s `WFBE_SE_FNC_HandlePVF` / `WFBE_CL_FNC_HandlePVF`, which **`Call Compile` the sender-chosen command string** — the DR-1 RCE/forgery surface. Payload fields are trusted (no server re-derivation) unless a specific handler validates them.
- **Direct:** a bare `publicVariable`/`publicVariableServer`/`publicVariableClient` with its own event handler — **not** behind the dispatcher, so the DR-1 dispatcher fix does not cover it; each must be hardened individually. DR-41/DR-44 prove authority forgery on direct channels, and DR-46 proves direct-channel RCE through `SEND_MESSAGE`.
- **BattlEye:** none of these are filtered except the `kickAFK` feature rule (DR-30); `ATTACK_WAVE_INIT` and all others are unfiltered.

## 1. Registered PVF commands

Registration: `Common/Init/Init_PublicVariables.sqf` — server-bound list `:9-21`, client-bound list `:25-40`, dispatch wiring `:44-51`. Each name `X` -> channel `WFBE_PVF_X` -> pre-compiled `SRVFNC X` / `CLTFNC X` (built `:45,:50`) but dispatched via `Call Compile` (`Server_HandlePVF.sqf:14` / `Client_HandlePVF.sqf:22`).

### 1a. Server-bound (client → server) — 13

For implementation work after PVF dispatch allowlisting, use the [registered server PVF handler authority matrix](Server-Authority-Migration-Map#registered-server-pvf-handler-authority-matrix). This index owns channel inventory; the authority map owns per-handler validation shape.

| Command (`WFBE_PVF_*`) | Purpose / notable finding |
| --- | --- |
| `RequestVehicleLock` | lock/unlock a payload-selected vehicle; owner/side/range validation is not visible in the handler |
| `RequestOnUnitKilled` | report a kill for scoring |
| `RequestChangeScore` | score mutation; accepts payload score and applies `addScore`, unlike safer server-derived award helpers |
| `RequestCommanderVote` | commander vote; DR-47 server/UI semantics mismatch and restart smoke route through [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) |
| `RequestNewCommander` | assign new commander — **DR-15** (`_side = _this` call-shape bug); flow map in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas), patch/smoke route in [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) |
| `RequestStructure` | build a structure — **DR-6** (no commander/funds/placement check) |
| `RequestDefense` | build a defense — **DR-6** |
| `RequestJoin` | join handshake (robust 30s-retry, DR-37) |
| `RequestMHQRepair` | MHQ repair — DR-6-class (`_side` from payload); lifecycle/risk map in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| `RequestSpecial` | multiplexer → `Server_HandleSpecial.sqf` (ICBM/paradrop/uav/HC/…) — **DR-27** (forged `["ICBM",…]` = map-wide kill) |
| `RequestTeamUpdate` | team/group property update; mutates behavior/combat/formation/speed from payload-selected team/side |
| `RequestUpgrade` | side upgrade purchase — **DR-23** (client-authoritative) |
| `RequestAutoWallConstructinChange` | auto-wall construction toggle; writes one global setting consumed by later SmallSite/MediumSite construction |

Scout refinement 2026-06-04: the thinner registered handlers above are still live hardening surfaces after a future PVF dispatcher fix. In particular, `RequestChangeScore`, `RequestVehicleLock`, `RequestTeamUpdate`, `RequestAutoWallConstructinChange`, `RequestStructure`, `RequestDefense` and `RequestUpgrade` need requester/side/object/funds validation at the handler/effect layer, not only dispatcher allowlisting.

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
| `RequestBaseArea` | base-area (client-bound despite the name); moves an object, stamps `avail`/`side` and appends to `wfbe_basearea` with no local validation in the client callback; multiplayer-sensitive HQ deploy edge in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) |
| `HandleParatrooperMarkerCreation` | paratrooper-drop unit marker creation; source and maintained Vanilla are propagated, Arma smoke pending in [Paratrooper marker revival](Paratrooper-Marker-Revival) |
| `NukeIncoming` | nuke-incoming broadcast name in the PVF list; current launch flow evidence still routes through `NukeIncoming` script, `RequestSpecial ["ICBM", ...]` and `HandleSpecial "icbm-display"` rather than the stale `ICBM_launched` direct channel |

Commander-tag note: `HandleSpecial` also carries commander/HQ message tags such as `commander-vote-start`, `new-commander-assigned`, `hq-setstatus` and `set-hq-killed-eh` through the client-side special router. Use [Commander vote/reassignment](Commander-Vote-And-Reassignment-Playbook) for the vote/reassignment semantics and [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) for the broader HQ-status chain before changing those tags.

> `DatabaseDebug` is registered-commented (`:30`).

## 2. Direct publicVariable channels (own event handlers)

Each has its own `addPublicVariableEventHandler`; not behind the dispatcher.

| Channel | Direction | Purpose / notable finding | Source |
| --- | --- | --- | --- |
| `ATTACK_WAVE_INIT` | client → server | activate heavy attack-wave; **DR-41** — server trusts client `_supply`/`_side`, no re-derivation → free units side-wide | `Common/Functions/Common_AttackWaveActivate.sqf:6-8`, `Server/Functions/Server_AttackWave.sqf` |
| `ATTACK_WAVE_DETAILS` | server self-loop via `publicVariableServer` | DR-41 detail payload; intended sender is `Server_AttackWave.sqf`, which publishes the packet back to the server-side PVEH rather than directly to clients. Client-visible effects happen later through `HandleSpecial` and `LocalizeMessage` sends from `AttackWave.sqf`. The direct handler still trusts payload `_side`, `_priceModifier` and `_attackLength`, stores active-side state, drains side supply and replays active modifiers to JIP clients. Treat this as a forgeable direct-PV authority surface unless BattlEye/handler validation prevents clients from publishing it. | `Server/Functions/Server_AttackWave.sqf:23-27,36-38`, `Server/PVFunctions/AttackWave.sqf:19-25,32-46,58-62` |
| `WFBE_CL_MASH_MARKER_CREATED` | (intended) client -> server | **DR-34 / 2026-06-05 branch recheck** - active server relay exists in source/Vanilla, stable, upstream and release, but maintained deploy paths do not send this channel. Modded `eden`/`lingor` still emit it, which is sender-only drift rather than proof maintained markers work. Canonical lifecycle matrix: [Respawn and death lifecycle](Respawn-And-Death-Lifecycle-Atlas#mash-split-live-respawn-dead-marker-relay). | `Server/Module/MASH/MASHMarker.sqf:1-13`, `Client/Module/Skill/Skill_Officer.sqf:25-27`, modded `Skill_Officer.sqf:38-40` |
| `WFBE_SE_MASH_MARKER_SENT` | (intended) server -> clients | **DR-34 / 2026-06-05 branch recheck** - server can rebroadcast, but maintained clients keep the receiver compile commented in source/Vanilla, stable, upstream and release. Local MASH respawn is separate and source-supported; the shared marker relay needs server-held marker state, delete replay and JIP resend or retirement. | `Server/Module/MASH/MASHMarker.sqf:9-11`, `Client/Module/MASH/receiverMASHmarker.sqf:1-29`, `Client/Init/Init_Client.sqf:132` |
| `WFBE_Client_PV_IsSupplyMissionActiveInTown` | client → server | supply-cooldown query (pull-based; JIP-correct, DR-39) | `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf:1` |
| `WFBE_Server_PV_IsSupplyMissionActiveInTown` | server → clients | cooldown answer (broadcast not targeted) | `Client/Module/supplyMission/townSupplyStatus.sqf:1` |
| `WFBE_Client_PV_SupplyMissionStarted` | client → server | start supply mission; live handler is `supplyMissionStarted.sqf`, while compiled `supplyMissionActive.sqf` is a dead twin | `Client/Module/supplyMission/supplyMissionStart.sqf:39`, `Server/Module/supplyMission/supplyMissionStarted.sqf:1`, `Server/Init/Init_Server.sqf:81` |
| `WFBE_Server_PV_SupplyMissionCompleted` | server module -> server handler | supply completion event; still consumes vehicle object vars that are stamped during client start | `Server/Module/supplyMission/supplyMissionStarted.sqf:64-65`, `Server/Module/supplyMission/supplyMissionCompleted.sqf:2,9-12` |
| `WFBE_Server_PV_SupplyMissionCompletedMessage` | server -> clients | supply completion message and client-side player cash/score side effects; exact channel matters for BattlEye filters and should not be hidden behind `...CompletedMessage` shorthand. The handler grants funds locally and sends `RequestChangeScore` when the payload player equals the local player. | `Server/Module/supplyMission/supplyMissionCompleted.sqf:24,34`, `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf:2,11-23` |
| `wfbe_supply_temp_east` / `wfbe_supply_temp_west` | client → server | side-supply mutation — **DR-44** direct-PV forgery class plus DR-22 broken-floor risk. Server handlers trust payload `_side` and `_amount`; the channel suffix does not constrain which side is mutated, so validation must check both side/channel consistency and amount bounds. | `Common/Functions/Common_ChangeSideSupply.sqf:28-30`, `Server/Functions/Server_ChangeSideSupply.sqf:1-21,25-45` |
| `wfbe_supply_WEST` / `wfbe_supply_EAST` | server -> clients / JIP state mirror | side-supply balance mirror after a server-side change. This is not the temp mutation channel above; clients wait for `wfbe_supply_<sideJoinedText>` on join and `GetSideSupply` reads the same namespace key. | `Server/Functions/Server_ChangeSideSupply.sqf:19-21,43-45`, `Client/Init/Init_Client.sqf:369-371`, `Common/Functions/Common_GetSideSupply.sqf:11-18` |
| `ICBM_launched` | legacy/unclear server -> clients | **Branch check 2026-06-05:** receiver-only legacy handler in source/Vanilla, `origin/master`, `miksuu/master` and `origin/release/2026-06-feature-bundle`. `Client/FSM/updateclient.sqf:20` registers the PVEH and `OnEventHandler_ICBM_Launch.sqf` documents the intended payload, but fixed-string branch searches found no active assignment or `publicVariable "ICBM_launched"` sender. Current tactical nuke flow uses `GUI_Menu_Tactical.sqf:499` (release Chernarus `:500`) -> `Client/Module/Nuke/nukeincoming.sqf:23,27` -> `RequestSpecial ["ICBM", ...]` and `HandleSpecial "icbm-display"`. Retire or revive deliberately; do not delete ICBM itself. | `Client/FSM/updateclient.sqf:20`, `Client/Module/Nuke/OnEventHandler_ICBM_Launch.sqf:5-9`, `Client/Module/Nuke/nukeincoming.sqf:23,27`, `Client/PVFunctions/HandleSpecial.sqf:22`, `Server/Functions/Server_HandleSpecial.sqf:97-111` |
| `PLAYER_RADIATED` | client -> clients | nuke radiation effect. `radzone.sqf` publishes the event from the client-side radiation check, and clients install the receiver in `updateclient.sqf`; do not treat this as server-authoritative damage logic. | `Client/Module/Nuke/radzone.sqf:103-104`, `Client/FSM/updateclient.sqf:24`, `Client/Module/Nuke/OnEventHandler_player_radiated.sqf` |
| `AFKthresholdExceededName` / `kickAFK` | client → server/BattlEye | Dual AFK paths. The older module publishes `AFKthresholdExceededName` and calls `failMission "END1"` after its local threshold; the server handler only logs the reported name. The newer FSM path publishes `kickAFK`, covered by the repo BattlEye filter rule. | `Client/Init/Init_Client.sqf:256-264`, `Client/Module/AFKkick/monitorAFK.sqf:24-30`, `Server/Module/afkKick/initAFKkickHandler.sqf:9-12`, `Client/FSM/updateclient.sqf:153-160`, `BattlEyeFilter/publicvariable.txt:1-2` |
| `WFBE_DAYNIGHT_DATE` | server → clients | day/night drift sync (reviewed clean, Round 17) | `Server/Functions/Server_DayNightCycle.sqf` |
| `SERVER_FPS_GUI` / `WFBE_VAR_SERVER_FPS` | server -> clients | server FPS GUI/HUD publication. Current source Chernarus player UI reads `SERVER_FPS_GUI`; `WFBE_VAR_SERVER_FPS` is a second dedicated publisher with no source Chernarus player-UI reader found. Modded/stale folders still contain `WFBE_VAR_SERVER_FPS` consumers, so future ops cleanup should either preserve it as compatibility or retire it deliberately with modded drift cleanup. | `Server/GUI/serverFpsGUI.sqf:6-7`, `Server/Module/serverFPS/monitorServerFPS.sqf:5-6`, `Client/Client_UpdateRHUD.sqf:113`, `Server/Init/Init_Server.sqf:578,595` |
| `IS_WEST_HQ_ALIVE` / `IS_EAST_HQ_ALIVE` | server → clients | HQ alive-state broadcast; see [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `HQ_WEST_MARKER_INFOS` / `HQ_EAST_MARKER_INFOS` | server → clients | HQ marker payload broadcast; see [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas) | `Server/Functions/Server_MHQRepair.sqf`, `Server/Functions/Server_OnHQKilled.sqf` |
| `SUPPLY_COMPENSATION_AMOUNT_EAST` / `SUPPLY_COMPENSATION_AMOUNT_WEST` | server → clients | AntiStack skill-difference supply compensation | `Server/Module/AntiStack/skillDiffCompensation.sqf` |
| `TEAM_WEST_TICKS_NO_PLAYERS` / `TEAM_EAST_TICKS_NO_PLAYERS` | common/server → clients | no-player supply-income stagnation counters | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf` |
| `MARKER_CREATION` | server → clients | map-marker creation channel | WASP/marker code |
| `SEND_MESSAGE` | mixed | **DR-46 direct-channel RCE surface.** The client receiver call-compiles network message text when payload flag index 3 says it is a multi-language message, and `Common_SendMessage.sqf` also compiles the same message text locally before broadcasting when that helper runs on a receiving side. The side filter and compile flag are payload-controlled. This bypasses PVF dispatcher hardening entirely. Fix by sending structured localization keys/args and resolving locally without compiling message text. | `Client/FSM/updateclient.sqf:10-12`, `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:23-33`, `Common/Functions/Common_SendMessage.sqf:22-38`; [Deep review DR-46](Deep-Review-Findings) |
| `REQUEST_SUPPLY_VALUE` / `SUPPLY_VALUE_REQUESTED` | client <-> server | supply-value request/response; the server derives the response value, but clients store it as mutable local `wfbe_supply_%side` cache and `Common_GetSideSupply` waits without a timeout before UI/economy gates consume it | `Common/Functions/Common_GetSideSupply.sqf:13-18,26-31,39-44`, `Server/Functions/Server_PV_RequestSupplyValue.sqf:1,8`, `Client/Functions/Client_ReceiveSupplyValue.sqf:1,7` |
| `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` / `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` | client ↔ server | launch-connect handshake (DR-37). The server stores side from a client-published player object and publishes boolean `true` back to the owner, but the client receiver stores the whole PVEH tuple in `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`; treat it as tuple-shaped truthiness until normalized. | `Client/Init/Init_Client.sqf:442-456`, `Server/Module/AntiStack/clientHasConnectedAtLaunch.sqf:1-16`, `Client/Module/AntiStack/hasConnectedAtLaunchACK.sqf:1-7` |
| `CLIENT_INIT_READY` | client → server | client-init-ready signal. Attack-wave code uses this as an explicit replay hook for current active wave details, separate from generic replicated waits and join ACK retry behavior. | `Client/Init/Init_Client.sqf:960-962`, `Server/PVFunctions/AttackWave.sqf:1-15` |
| `WFBE_C_PLAYER_OBJECT` | client → server | player-object publication for `WFBE_SE_PLAYERLIST`; source indexing is patched, but sender/UID validation and disconnect pruning/stale row cleanup remain open. The handler accepts `[playerObject, uid]` and supply mission player lookup later depends on this list. | `Client/Init/Init_Client.sqf:759-760`, `Server/Module/supplyMission/playerObjectsList.sqf:1-40`, `Server/Module/supplyMission/supplyMissionStarted.sqf:31-65` |
| `CBA_display_ingame_warnings` | global bootstrap broadcast | disables CBA in-game warnings during mission bootstrap. Low gameplay risk, but it is still a public variable and belongs in the BattlEye/publicVariable inventory. | `initJIPCompatible.sqf:24-25` |

### SEND_MESSAGE Direct Compile Branch Matrix

This is the branch/root route for DR-46. It is intentionally separate from the PVF dispatcher matrix because `SEND_MESSAGE` is a bare direct publicVariable channel with its own event handler.

| Scope checked 2026-06-06 | Receiver route | Helper / broadcast route | Practical meaning |
| --- | --- | --- | --- |
| Current source Chernarus `HEAD` `2cdf5fb8` and maintained Vanilla Takistan | Both roots register `"SEND_MESSAGE" addPublicVariableEventHandler` in `Client/FSM/updateclient.sqf:10-12`; both unpack payload indexes `0-3` in `Client/Functions/Client_onEventHandler_SEND_MESSAGE.sqf:15,18-21` and run `_messageText = call compile _messageText` at `:27` when the multi-language flag is true. | Both roots run `_messageText = call compile _messageText` in `Common/Functions/Common_SendMessage.sqf:26`, then publish `SEND_MESSAGE` via `missionNamespace setVariable` / `publicVariable` at `:37-38`. | P0 direct-PV RCE remains present in both maintained roots; a PVF dispatcher allowlist does not touch this channel. |
| Stable `origin/master` `2cdf5fb8` and Miksuu upstream `f532f706` | Same receiver registration and compile lines in both maintained roots. | Same helper compile and broadcast lines in both maintained roots. | No stable/upstream rescue exists for the current source shape. |
| `origin/perf/quick-wins` `0076040f` | Same receiver registration and compile lines in Chernarus and maintained Vanilla. | Same helper compile and broadcast lines in Chernarus and maintained Vanilla. | Perf branch fixes do not cover this security lane. |
| `origin/release/2026-06-feature-bundle` `7195b331` | Same receiver registration and compile lines in release Chernarus and release maintained Vanilla. | Same helper compile and broadcast lines in release Chernarus and release maintained Vanilla. | Current release head is still source-unpatched for DR-46; keep it in the P0 patch-ready queue. |

## Hardening note

For a real BattlEye `publicvariable.txt`, the default-deny whitelist must cover **both** tables — registered `WFBE_PVF_*` names and these direct channels — keeping `kickAFK`. But BattlEye is defense-in-depth only; the durable fix is server-side authority in the PVF handlers (DR-1), direct handler validation for authority channels (DR-41/DR-44) and removal of direct network-data compilation (`SEND_MESSAGE`, DR-46). See [Pending owner decisions](Pending-Owner-Decisions).

Dead-code scan note: [Dead/stale code register](Dead-Code-And-Stale-Code-Register#direct-public-variable-findings) owns cleanup classification for receiver-only or comment-only channels. Treat `wfbe_supply_temp_east/west` as dynamic `format` channels, not receiver-only dead code; treat old commented `WFBE_Request*` / `WFBE_LocalizeMessage` / `WFBE_ChangeScore` lines as migration residue unless a target branch proves otherwise.

## Continue Reading

Conventions: [Variable and naming conventions](Variable-And-Naming-Conventions) | Dispatch internals: [Networking](Networking-And-Public-Variables) | Findings: [Deep-review findings](Deep-Review-Findings)
