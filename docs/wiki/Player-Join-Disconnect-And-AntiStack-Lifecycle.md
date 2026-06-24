# Player Join Disconnect And AntiStack Lifecycle

This page maps how a player enters, reconnects, leaves and gets persisted in the Chernarus source mission. It complements [Lifecycle wait-chain](Lifecycle-Wait-Chain), [AntiStack database extension audit](AntiStack-Database-Extension-Audit), [Networking and public variables](Networking-And-Public-Variables) and [Respawn/death lifecycle](Respawn-And-Death-Lifecycle-Atlas).

## Scope And Source Files

Source mission: `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

| Area | Source refs |
| --- | --- |
| Engine connection hooks | `initJIPCompatible.sqf:60-66` registers spawned `onPlayerConnected` and `onPlayerDisconnected` handlers. |
| Client join request | `Client/Init/Init_Client.sqf:410-456` sends/retries `RequestJoin`; `:759-760` sends player-object registration; `:960-962` sends `CLIENT_INIT_READY`. |
| PV registration | `Common/Init/Init_PublicVariables.sqf:16` registers `RequestJoin`; the client `HandleSpecial` path carries join answers. |
| Join authorization | `Server/PVFunctions/RequestJoin.sqf:10-89` checks stored team, launch-side and AntiStack skill before sending `join-answer` and storing side. |
| Connect bookkeeping | `Server/Functions/Server_OnPlayerConnected.sqf:41+` creates or updates `WFBE_JIP_USER%UID`, funds, `wfbe_uid` and `wfbe_teamleader`. |
| Disconnect cleanup | `Server/Functions/Server_OnPlayerDisconnected.sqf:31-175` deletes client objects, restores AI/group state, saves funds, clears commander/delegation and writes AntiStack side/score state. |
| Launch-side raw PV | `Server/Module/AntiStack/clientHasConnectedAtLaunch.sqf:1+` records `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH`. |
| Supply player object list | `Server/Module/supplyMission/playerObjectsList.sqf:1-29` maintains `WFBE_SE_PLAYERLIST` for supply mission lookup; on current master the update index still resets *inside* the loop (`_i = 0;` at `:18`, the first statement in the `forEach` at `:17`) so reconnect always overwrites slot 0 — see the Patch-Ready Findings row — and disconnect cleanup still does not prune stale rows. |
| AFK intersection | `Client/FSM/updateclient.sqf:28-31,117-160`, `Client/Module/AFKkick/monitorAFK.sqf:24-30`, `Client/Module/AFKkick/handleKeys.sqf:11-15`, `Server/Module/afkKick/initAFKkickHandler.sqf:9-12`, `BattlEyeFilter/publicvariable.txt:1-2`. |

## Identity Model

The audited server paths use UID as the durable key, player/group objects as the live team ownership surface, and owner IDs for targeted replies/locality. Player names are log labels, not authority keys, and no `profileName` use was found in the scoped lifecycle paths.

| Identity key | Main use | Source evidence |
| --- | --- | --- |
| UID | JIP records, previous side, funds, disconnect persistence, AntiStack score/list storage. | `Server_OnPlayerConnected.sqf:27,42,65,70,79,93,101`; `Server_OnPlayerDisconnected.sqf:39,48,125,128,129,133,157,164,170,174,175` |
| Group/object | Team leader ownership, object cleanup, commander/delegation cleanup and special-request context. | `Server_OnPlayerConnected.sqf:45,56,64-66`; `Server_OnPlayerDisconnected.sqf:32,45,57,68,79,93,102,117,125,128,129` |
| Owner | Targeted ACKs, supply-value replies and locality changes. | `clientHasConnectedAtLaunch.sqf:4,15`; `Server_PV_RequestSupplyValue.sqf:4,8`; `Server_SetLocalityOwner.sqf:10,13` |

This is why reconnect hardening should re-check UID and object identity at the point of cleanup, not only at the start of `Server_OnPlayerDisconnected.sqf`.

## Join Paths

The client derives `sideJoined` from `side player` early in `Client/Init/Init_Client.sqf`. If teamswap protection is active and mission time is past the early-launch grace window, the client sends `RequestJoin` and waits up to repeated 30-second cycles for `WFBE_P_CANJOIN`.

When the join request path is skipped at launch, the client instead publishes `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH = player`. The server records `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH = side _player` and ACKs the owner with `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`. The client ACK receiver stores the full public-variable event tuple (`_this`) into `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`, not only the boolean payload, so consumers that only need truthiness work but future code should not assume the variable is a plain bool (`Client/Module/AntiStack/hasConnectedAtLaunchACK.sqf:1-7`).

For JIP/reconnect, `Server_OnPlayerConnected.sqf` waits for server init, matches groups by UID in `playableUnits`, assigns `wfbe_uid` and `wfbe_teamleader`, and creates or updates the `WFBE_JIP_USER%UID` session record.

## Branch Intel - B745 Primitive Roster JIP

`origin/claude/b745@b996bcb3` adds a source-Chernarus-only primitive team-roster path for late joiners whose side `wfbe_teams` group-object array is slow, empty or broken on the client. This is branch-only evidence from the included `4d16fad70` batch; no matching `WFBE_JIP_ROSTER_PRIMS`, `ROSTER-PUSH` or `CLIENTROSTER` symbols were found in current stable `origin/master@f8a76de34`, current B74.2 `origin/claude/b74.2-aicom@21b62b04`, `miksuu/master@b8389e74` or the maintained Vanilla Takistan checked paths.

| Surface | B745 source evidence | What to verify before promotion |
| --- | --- | --- |
| Server connect push | `Server_OnPlayerConnected.sqf:70-80` re-broadcasts side-logic `wfbe_teams` for the joining owner; `:82-113` builds a side-keyed primitive payload `[count, rows]` and sends `WFBE_JIP_ROSTER_%1` with `publicVariableClient`. Rows are `[leaderName, isPlayer, funds, groupId]`; WEST/EAST only because GUER has no commander-vote menu. | Dedicated late-join/reconnect under heavy AI load must show the targeted roster push in server RPT and no stale/wrong-side payload on the other side. |
| Early client receiver | `initJIPCompatible.sqf:225-247` installs WEST/EAST public-variable handlers before the B56 `wfbe_teams` wait and before `Init_Client`; `:248-266` polls once for a payload that arrived before handler install, then stores `WFBE_JIP_ROSTER_PRIMS` / `WFBE_JIP_ROSTER_COUNT`. | Join before and after team registration; prove the receiver or poll-adopt path fires before the vote menu opens. |
| Client safe empty state | `Client/Init/Init_Client.sqf:284` defaults `clientTeams` to `[]` instead of nil so broken JIP clients avoid `forEach nil` in vote/marker loops and can still take the primitive-roster path. | RPT should stay clean for missing `WFBE_%1TEAMS`; funds/markers/vote UI must recover once live groups arrive, not stay permanently primitive. |
| Vote UI consumer | `GUI_VoteMenu.sqf:10-35,75-99,119-125` and `GUI_Commander_VoteMenu.sqf:10-32,69-91` render primitive names until live player-led groups exist, then rebuild from real team indexes. | Smoke both vote menus; primitive rows should not blank out, should not be pruned within one tick, and should hand over to live team rows before treating selected player rows as normal vote/reassign targets. |

## Slot And Side Surfaces

Side identity is split across several layers. Do not treat any one of them as the whole authority model:

| Surface | Evidence | Meaning |
| --- | --- | --- |
| Playable slots | `mission.sqm` playable unit blocks. | Engine/editor side selection and slot availability. |
| Client side cache | `Client/Init/Init_Client.sqf:5-9,221-223` | The client sets `sideJoined` / side text from `side player`. |
| Server team objects | `Server/Init/Init_Server.sqf:465-501` | Server groups/teams carry `wfbe_side`, UID and teamleader state. |
| Join gate | `Server/PVFunctions/RequestJoin.sqf:17-89` | Team-swap and AntiStack checks decide accepted side for JIP/reconnect. |

## Team Identity And Teamswap Guards

`RequestJoin.sqf` is the main teamswap gate. It checks:

- `WFBE_JIP_USER%UID_TEAM_JOINED`, which records a previously accepted side.
- `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH`, which records the launch-side signal.
- AntiStack skill data when AntiStack is enabled.

Successful joins store both `WFBE_JIP_USER%UID_TEAM_JOINED` and `STORE_SIDE`. The handler is mostly idempotent, but repeated client retries can still duplicate logs and database writes because the server handler does not explicitly de-duplicate in-flight requests.

## Disconnect Cleanup

`Server_OnPlayerDisconnected.sqf` sleeps for 0.5 seconds, then:

- Deletes `WFBE_CLIENT_%UID_OBJECTS`.
- Finds the player team by `wfbe_uid`.
- Restores the player unit to the original group if needed.
- Saves funds into `WFBE_JIP_USER%UID`.
- Clears `wfbe_uid` and `wfbe_teamleader`.
- Clears AI delegation and commander state when the disconnecting team owned those roles.
- Stores AntiStack score diff and `STORE_SIDE NONE` when AntiStack persistence is enabled.

The sleep gives Arma time to settle disconnect state, but it also creates a race window. A fast reconnect for the same UID can overlap with stale cleanup, so future hardening should confirm the team variables still match the disconnecting UID before clearing them.

Commander disconnect is intentionally only a cleanup edge here. The commander ownership, UI reaction and no-auto-reassignment caveat live in [Commander/HQ lifecycle](Commander-HQ-Lifecycle-Atlas).

## AntiStack Persistence

AntiStack enabled mode stores join side, samples score frequently, flushes periodically, and persists score diff on disconnect. Disabled mode avoids the score DB save on disconnect, but first-join side-swap protection and launch-side signals still influence join decisions.

Disconnect persistence is currently fire-and-forget: `Server_OnPlayerDisconnected.sqf:151-176` calls the DB wrappers but does not act on failure return codes. If the extension is slow, missing or malformed, a disconnect can look clean in mission flow while persistence silently fails.

The periodic player-list flush prefers confirmed join side from `WFBE_JIP_USER%UID_TEAM_JOINED`. If that does not exist but a launch-side record exists, the current code uses the launch record only as an existence check and sends current `side _x`, not the stored `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH` value (`AntiStack/flushLoop.sqf:32-40`). That distinction matters for teamswap/side-audit fixes.

Use [AntiStack database extension audit](AntiStack-Database-Extension-Audit) for the wrapper return-shape risks and external `A2WaspDatabase` dependency. This page owns the lifecycle edges around when those calls happen.

## Raw Public Variable Edges

Several lifecycle signals use global variable names rather than UID-scoped variable names:

- `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`
- `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH`
- `WFBE_C_PLAYER_OBJECT`
- `AFKthresholdExceededName`
- `CLIENT_INIT_READY`

Owner-targeted sends reduce some blast radius, but the names themselves are shared. Future hardening should prefer UID/payload-scoped values where possible and validate sender/player ownership in handlers.

The launch-connect path is especially important because the client publishes a player object through `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH`, and the shipped BattlEye filter only covers `kickAFK`. Treat launch-side storage as client-pushed until the handler validates sender/UID/side/object consistency.

BattlEye asymmetry is deliberate in the shipped tree: `BattlEyeFilter/publicvariable.txt` contains only `5 "kickAFK"`, while `AFKthresholdExceededName`, `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` and `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK` are unfiltered mission public variables. Do not describe the included filter as broad lifecycle hardening.

## AFK Kick Intersection

AFK enforcement is client-local and currently has two live paths:

- The client FSM path reads `WFBE_C_AFK_TIME`, whose current Chernarus parameter default is 15 minutes (`Rsc/Parameters.hpp:44-48`). `updateclient.sqf` converts it to seconds, marks `WASP_AFK`, warns players during the final 10 minutes, switches to per-30-second hints while more than 120 seconds remain, then per-tick second hints under 120 seconds. When elapsed inactivity exceeds the threshold it logs locally and publishes `kickAFK`, which the in-repo BattlEye publicVariable rule is expected to kick (`Client/FSM/updateclient.sqf:28-31,117-160`; `BattlEyeFilter/publicvariable.txt:1-2`).
- The older AFKkick module is also started by client init (`Init_Client.sqf:256-264`). It uses keypresses to reset a minute counter, publishes `AFKthresholdExceededName` and calls `failMission "END1"` after `WFBE_CO_VAR_AFKkickThreshold = 30` minutes (`monitorAFK.sqf:19-30`). The server handler only logs the reported name (`initAFKkickHandler.sqf:9-12`).

For public hosting, treat AFK as client UX plus BattlEye/logging signals, not a fully server-authoritative enforcement model. The dual-path shape is also a maintenance risk: future cleanup should decide whether the old `AFKthresholdExceededName`/`failMission` path is still wanted or whether the BattlEye `kickAFK` path should be the single owner.

## Patch-Ready Findings

| Finding | Evidence | Patch shape |
| --- | --- | --- |
| `WFBE_SE_PLAYERLIST` update index bug | `playerObjectsList.sqf:17` opens the forEach block (`{`); line 18 `_i = 0;` is the first statement inside it — the index resets every iteration in both Chernarus and Vanilla Takistan on master. `_arrayPosMatch` is always 0 when a UID match is found, so reconnect always overwrites slot 0 rather than the correct slot. | Move `_i = 0` to before the `{…} forEach` block (after `_arrayPosMatch = 0;` on line 9). Apply to both Chernarus and Vanilla Takistan. Smoke: reconnect/JIP replacement must update the correct slot. Stale UID row removal/update remains a separate patch. |
| Disconnect delete-then-`setPos` contradiction | `Server_OnPlayerDisconnected.sqf:102` deletes `_old_unit`; `:122` later calls `_old_unit setPos`. | Decide whether the unit should be deleted or relocated, then keep only one behavior. Verify in RPT because deleted-object `setPos` behavior may be engine-sensitive. |
| Stale supply player rows | `playerObjectsList.sqf:31-35` appends when no valid match updates; `Server_OnPlayerDisconnected.sqf` does not remove `WFBE_SE_PLAYERLIST` rows. | Add UID-based disconnect cleanup and ignore/null-prune stale object refs before supply completion lookup. |
| Stale disconnect cleanup race | `Server_OnPlayerDisconnected.sqf:128-129` clears `wfbe_uid` / `wfbe_teamleader` after a 0.5-second delay. | Before clearing, confirm the variables still match the disconnecting UID and old player object. |
| Raw lifecycle ACK names are global | Lifecycle ACK/request names above are not UID-scoped. | Use payload arrays or UID-scoped state; validate owner/player when Arma 2 OA gives enough context. |
| Launch ACK stores the event tuple | `hasConnectedAtLaunchACK.sqf:4-6` assigns `_this` to `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`, while `clientHasConnectedAtLaunch.sqf:13-15` publishes boolean `true` as the payload. | Normalize the ACK receiver to `_this select 1` or document tuple truthiness wherever it is consumed. |
| Join and launch ACK retries are unbounded | `Init_Client.sqf:416-430` resends `RequestJoin` every 30-second warning cycle until `WFBE_P_CANJOIN`; `:442-456` repeats `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` until `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`. | Add bounded retry/backoff and a clear degraded-server message/log path so missing PV handlers do not leave clients in an endless retry loop. |
| Launch-connect side signal is client-pushed | `clientHasConnectedAtLaunch.sqf:1-15` records side from the client-published player object and owner-targets the ACK. | Validate sender/UID/side/object consistency before storing `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH`; log mismatches once per UID. |
| Player-list flush does not reuse stored launch side | `flushLoop.sqf:32-40` sends confirmed `WFBE_JIP_USER%UID_TEAM_JOINED` when present, otherwise checks for a launch record and sends current `side _x`. | Decide whether the DB player list should represent confirmed accepted side, current engine side or stored launch side, then make the fallback explicit. |
| AntiStack disconnect writes are unchecked | `Server_OnPlayerDisconnected.sqf:151-176` calls store-side/score wrappers and ignores return codes. | Log failures, consider one bounded retry and expose degraded persistence in the AntiStack audit/performance state. |
| AFK has two active client-local enforcement paths | `Init_Client.sqf:256-264` starts the older `monitorAFK.sqf` path, while `updateclient.sqf:28-31,117-160` also runs the parameterized `kickAFK` BattlEye path. | Pick one canonical AFK owner or deliberately document the two-stage policy. If keeping both, align thresholds, warning cadence, logging and disconnect validation. |
| AFK PV trusts a name string | `AFKthresholdExceededName` carries the client-reported name and `kickAFK` carries a client-formatted name string. | Send `[player, uid, name]` or derive from owner where possible; log mismatches rather than trusting the string. |

## Validation Checklist

- First join with teamswap protection enabled and disabled.
- Launch players on both sides; verify launch-side ACK is owner-specific.
- Temporarily suppress the join/launch server reply in a test copy; verify clients get bounded diagnostics instead of an infinite retry loop.
- Fast disconnect/reconnect with the same UID; confirm no stale cleanup clears the new team record.
- Supply mission player-object list updates the matching UID row after reconnect; stale-entry removal is still a separate hardening task.
- Commander disconnect clears commander state exactly once.
- AntiStack enabled/disabled disconnect paths both avoid wrapper errors.
- AntiStack enabled disconnect path reports DB write failure instead of silently treating it as success.
- Launch-connect spoof attempt with mismatched object/side is ignored and logged.
- AFK timeout logs the correct player and cannot be spoofed by another client.

## Continue Reading

Previous: [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Next: [AntiStack database extension audit](AntiStack-Database-Extension-Audit)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | PV inventory: [Public variable channel index](Public-Variable-Channel-Index)
