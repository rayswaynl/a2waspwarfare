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
| Supply player object list | `Server/Module/supplyMission/playerObjectsList.sqf:1-29` maintains `WFBE_SE_PLAYERLIST` for supply mission lookup; Chernarus source and maintained Vanilla Takistan now keep the update index outside the loop, but disconnect cleanup still does not prune stale rows. |
| AFK intersection | `Client/Module/AFKkick/monitorAFK.sqf:24+`, `Client/Module/AFKkick/handleKeys.sqf:11+`, `Server/Module/afkKick/initAFKkickHandler.sqf:9+`. |

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

When the join request path is skipped at launch, the client instead publishes `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH = player`. The server records `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH = side _player` and ACKs the owner with `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`.

For JIP/reconnect, `Server_OnPlayerConnected.sqf` waits for server init, matches groups by UID in `playableUnits`, assigns `wfbe_uid` and `wfbe_teamleader`, and creates or updates the `WFBE_JIP_USER%UID` session record.

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

## AntiStack Persistence

AntiStack enabled mode stores join side, samples score frequently, flushes periodically, and persists score diff on disconnect. Disabled mode avoids the score DB save on disconnect, but first-join side-swap protection and launch-side signals still influence join decisions.

Disconnect persistence is currently fire-and-forget: `Server_OnPlayerDisconnected.sqf:151-176` calls the DB wrappers but does not act on failure return codes. If the extension is slow, missing or malformed, a disconnect can look clean in mission flow while persistence silently fails.

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

## AFK Kick Intersection

AFK enforcement is client-local: the client timer publishes `AFKthresholdExceededName` and calls `failMission "END1"`. The server handler logs the name. It does not independently validate that the reported name/UID belongs to the publicVariable sender.

For public hosting, treat AFK as a client UX kick plus BattlEye/logging signal, not a fully server-authoritative enforcement model.

## Patch-Ready Findings

| Finding | Evidence | Patch shape |
| --- | --- | --- |
| `WFBE_SE_PLAYERLIST` update index bug | Source Chernarus and maintained Vanilla Takistan now have `_i = 0` before the loop at `playerObjectsList.sqf:17`. | Source and maintained Vanilla propagated; smoke reconnect/JIP replacement. Disconnect removal/update behavior for stale UID rows remains patch-ready. |
| Disconnect delete-then-`setPos` contradiction | `Server_OnPlayerDisconnected.sqf:102` deletes `_old_unit`; `:122` later calls `_old_unit setPos`. | Decide whether the unit should be deleted or relocated, then keep only one behavior. Verify in RPT because deleted-object `setPos` behavior may be engine-sensitive. |
| Stale supply player rows | `playerObjectsList.sqf:31-35` appends when no valid match updates; `Server_OnPlayerDisconnected.sqf` does not remove `WFBE_SE_PLAYERLIST` rows. | Add UID-based disconnect cleanup and ignore/null-prune stale object refs before supply completion lookup. |
| Stale disconnect cleanup race | `Server_OnPlayerDisconnected.sqf:128-129` clears `wfbe_uid` / `wfbe_teamleader` after a 0.5-second delay. | Before clearing, confirm the variables still match the disconnecting UID and old player object. |
| Raw lifecycle ACK names are global | Lifecycle ACK/request names above are not UID-scoped. | Use payload arrays or UID-scoped state; validate owner/player when Arma 2 OA gives enough context. |
| Join and launch ACK retries are unbounded | `Init_Client.sqf:416-430` resends `RequestJoin` every 30-second warning cycle until `WFBE_P_CANJOIN`; `:442-456` repeats `WFBE_CLIENT_HAS_CONNECTED_AT_LAUNCH` until `WFBE_P_HAS_CONNECTED_AT_LAUNCH_ACK`. | Add bounded retry/backoff and a clear degraded-server message/log path so missing PV handlers do not leave clients in an endless retry loop. |
| Launch-connect side signal is client-pushed | `clientHasConnectedAtLaunch.sqf:1-15` records side from the client-published player object and owner-targets the ACK. | Validate sender/UID/side/object consistency before storing `WFBE_PLAYER_%UID_CONNECTED_AT_LAUNCH`; log mismatches once per UID. |
| AntiStack disconnect writes are unchecked | `Server_OnPlayerDisconnected.sqf:151-176` calls store-side/score wrappers and ignores return codes. | Log failures, consider one bounded retry and expose degraded persistence in the AntiStack audit/performance state. |
| AFK PV trusts a name string | `AFKthresholdExceededName` carries the client-reported name. | Send `[player, uid, name]` or derive from owner where possible; log mismatches rather than trusting the string. |

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

Previous: [Lifecycle wait-chain](Lifecycle-Wait-Chain) | Next: [AntiStack database extension audit](AntiStack-Database-Extension-Audit)

Main map: [Home](Home) | Feature triage: [Feature status](Feature-Status-Register) | PV inventory: [Public variable channel index](Public-Variable-Channel-Index)
