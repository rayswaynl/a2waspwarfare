# PVF Send-Helper Contract Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This page documents the **sender side** of the public-variable function (PVF) layer: the four `Common_SendTo*` helpers that a caller invokes to "address a registered PVF handler" on another machine. Each helper takes a logical command payload, rewrites it into the wire form the receiver expects (`SRVFNC<Command>` / `CLTFNC<Command>`), and pushes it over the right public-variable transport (`publicVariable`, `publicVariableServer`, or `publicVariableClient`) — or, on a hosted (listen) server, short-circuits straight into the local dispatcher. The **receiver** half (`Server_HandlePVF` / `Client_HandlePVF`, the `Call Compile` dispatch surface, and the DR-1/DR-38 allowlist hardening) is documented separately in [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook); this page is its sender-contract companion and does not restate that hardening.

The helpers are exposed as `WFBE_CO_FNC_SendToClient`, `WFBE_CO_FNC_SendToClients`, and `WFBE_CO_FNC_SendToServer`, compiled in `Common/Init/Init_Common.sqf:157-159`. There is no public alias for the optimized server variant — it is swapped in behind `WFBE_CO_FNC_SendToServer` by a build-time branch (see [Build-Time Alias Selection](#build-time-alias-selection)).

## The Four Send Helpers

| Helper file | Compiled alias | Direction | Transport | Payload index rewritten |
| --- | --- | --- | --- | --- |
| `Common/Functions/Common_SendToClient.sqf` | `WFBE_CO_FNC_SendToClient` | server → one client | `publicVariableClient` (UID-targeted) | `0` (object → UID), `1` (func → `CLTFNC%1`) |
| `Common/Functions/Common_SendToClients.sqf` | `WFBE_CO_FNC_SendToClients` | any → all machines | `publicVariable` (broadcast) | `1` (func → `CLTFNC%1`) |
| `Common/Functions/Common_SendToServer.sqf` | `WFBE_CO_FNC_SendToServer` (Vanilla) | client → server | `publicVariable` | `0` (func → `SRVFNC%1`) |
| `Common/Functions/Common_SendToServerOptimized.sqf` | `WFBE_CO_FNC_SendToServer` (OA) | client → server | `publicVariableServer` | `0` (func → `SRVFNC%1`) |

All four share the same skeleton: read the logical function name out of a fixed payload index, overwrite that index (and for `SendToClient`, index `0` too) with the wire token, then either fire the public variable or, on a hosted server, `Spawn` the local handler directly.

### Payload shape and the logical-name rewrite

Callers pass an array whose head is the logical command name. The naming convention differs by direction:

- **Client-bound** payloads carry the command at index `1`; index `0` is the targeting object (or `nil` for `SendToClients`). The helper rewrites index `1` to `Format["CLTFNC%1",_func]` so the receiver resolves `CLTFNC<Command>`. See `Common_SendToClient.sqf:10,14` and `Common_SendToClients.sqf:10,12`.
- **Server-bound** payloads carry the command at index `0`. The helper rewrites index `0` to `Format["SRVFNC%1",_func]` so the receiver resolves `SRVFNC<Command>`. See `Common_SendToServer.sqf:10,12` and `Common_SendToServerOptimized.sqf:10,12`.

This rewrite is the contract the dispatcher depends on: legitimate traffic always names `SRVFNC*` or `CLTFNC*`, which is exactly the set the DR-1 allowlist fix is designed around (see [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook)). The remaining payload elements are the handler's own parameters, passed through untouched.

## Common_SendToClient — single-client UID targeting

`Common/Functions/Common_SendToClient.sqf` is the only helper that performs true unicast. It captures the machine id of the target before rewriting the payload, then rewrites the targeting slot to a persistent UID and uses `publicVariableClient` to deliver only to that machine.

| Concern | Source | Detail |
| --- | --- | --- |
| Inputs | `Common_SendToClient.sqf:9-11` | `_pvf = _this`; `_func = _pvf select 1`; `_id = owner (_pvf select 0)`. Index `0` is the target unit/object; `owner` resolves it to that client's network id for `publicVariableClient`. |
| Targeting rewrite | `:13` | `_pvf set [0, getPlayerUID (_pvf select 0)]` — the live object reference is replaced with the player's persistent UID before transmission (the object would not be meaningful or might be `objNull` on the receiver). |
| Function rewrite | `:14` | `_pvf set [1, Format["CLTFNC%1",_func]]`. |
| Remote path | `:16-17` | When `!isHostedServer`: `Call Compile Format ["WFBE_PVF_%1 = _pvf; _id publicVariableClient 'WFBE_PVF_%1';", _func]` — assigns the per-command channel variable and fires it only to `_id`. |
| Hosted path | `:18-20` | On a hosted (listen) server: `_pvf Spawn WFBE_CL_FNC_HandlePVF` runs the client dispatcher locally; then `if (isMultiplayer)` also re-broadcasts via `publicVariableClient` so remote clients still receive it. A pure single-player host skips the network fire. |

Typical current-stable-shaped call sites pass `leader X` (or `leader commanderTeam`) as the index-0 target, e.g. `Client/GUI/GUI_Menu_Command.sqf:336,344` (`"SetTask"` on current stable/B69/B74/naval-HVT; docs/source, Miksuu and perf still comment those sends), `Client/Module/CoIn/coin_interface.sqf:264,738` (`"Available"`), and the headless-delegation hand-offs `Server/AI/Commander/AI_Commander_Teams.sqf:328` and `Server/FSM/server_side_patrols.sqf:67` (`"HandleSpecial"` to a specific HC unit).

## Common_SendToClients — broadcast

`Common/Functions/Common_SendToClients.sqf` broadcasts the client PVF to every machine. It does no targeting rewrite — index `0` of the payload is left as-is (callers commonly pass `nil`, a side, or a UID that the *handler* filters on), and only the function name is rewritten.

| Concern | Source | Detail |
| --- | --- | --- |
| Inputs | `Common_SendToClients.sqf:9-10` | `_pvf = _this`; `_func = _pvf select 1`. No `owner`/UID capture. |
| Function rewrite | `:12` | `_pvf set [1, Format["CLTFNC%1",_func]]`. |
| Remote path | `:14-15` | When `!isHostedServer`: `WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1'` — un-targeted broadcast to all clients (and the server). |
| Hosted path | `:16-18` | On a hosted server: `_pvf Spawn WFBE_CL_FNC_HandlePVF` locally, then `if (isMultiplayer)` re-broadcasts via `publicVariable` for remote clients. |

Note the "UID at index 0" pattern in several callers — e.g. `Client/Functions/Client_FNC_Groups.sqf:161,206,244` (`"HandleSpecial"` group ops) and `Client/GUI/GUI_Menu_Team.sqf:99` (`"LocalizeMessage" FundsTransfer`) pass `getPlayerUID(...)` as the head. Because `SendToClients` is a true broadcast, every client receives the message and the receiving handler discards it if the embedded UID is not its own. When genuine unicast is wanted, `SendToClient` is the cheaper choice; this distinction is also noted in [Public variable channel index](Public-Variable-Channel-Index).

## Common_SendToServer / Common_SendToServerOptimized — server-bound

Both server helpers rewrite index `0` to `SRVFNC<Command>` and differ only in the public-variable command used on the remote path.

| Concern | `Common_SendToServer.sqf` | `Common_SendToServerOptimized.sqf` |
| --- | --- | --- |
| Inputs | `:9-10` `_pvf = _this`; `_func = _pvf select 0` | `:9-10` identical |
| Function rewrite | `:12` `_pvf set [0, Format["SRVFNC%1",_func]]` | `:12` identical |
| Remote path | `:14-15` `WFBE_PVF_%1 = _pvf; publicVariable 'WFBE_PVF_%1'` | `:14-15` `WFBE_PVF_%1 = _pvf; publicVariableServer 'WFBE_PVF_%1'` |
| Hosted path | `:16-18` `_pvf Spawn WFBE_SE_FNC_HandlePVF` (no re-fire) | `:16-18` identical |
| Header note | `:2` "Send a PVF to the server." | `:2` "Send a PVF to the server ([>1.62] needed for publicVariableServer)." |

The vanilla variant uses plain `publicVariable`, which broadcasts the channel variable to everyone (the server's PVEH then consumes it; other clients ignore an unregistered `SRVFNC*` channel). The optimized variant uses `publicVariableServer`, which sends the variable only to the server — strictly less traffic, but `publicVariableServer` requires Arma 2 OA build > 1.62, hence the version gate in the header comment and the build-time branch below. On the hosted path both just `Spawn WFBE_SE_FNC_HandlePVF` locally with no network re-fire (the server *is* this machine).

Server-bound calls are the request channel from clients, e.g. `Client/Action/Action_GuerVbiedDetonate.sqf:46` (`"RequestSpecial"`), `Client/Action/Action_RepairMHQ.sqf:35` (`"RequestMHQRepair"`), and `Client/Action/Action_ToggleMHQLock.sqf:15` (`"RequestVehicleLock"`).

## Build-Time Alias Selection

The three public aliases are assigned in `Common/Init/Init_Common.sqf:157-159`. Two of the three carry a `WF_A2_Vanilla` branch:

| Line | Assignment | Behavior |
| --- | --- | --- |
| `Init_Common.sqf:157` | `WFBE_CO_FNC_SendToClient = if !(WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_SendToClient.sqf"} else {{}};` | On OA → real `SendToClient`. On A2 vanilla → compiled to an empty no-op `{}`. `publicVariableClient`-style single-client targeting is OA-only here. |
| `Init_Common.sqf:158` | `WFBE_CO_FNC_SendToClients = Compile preprocessFileLineNumbers "Common\Functions\Common_SendToClients.sqf";` | Always the broadcast helper — no branch (broadcast `publicVariable` works on both A2 and OA). |
| `Init_Common.sqf:159` | `WFBE_CO_FNC_SendToServer = if (WF_A2_Vanilla) then {Compile preprocessFileLineNumbers "Common\Functions\Common_SendToServer.sqf"} else {Compile preprocessFileLineNumbers "Common\Functions\Common_SendToServerOptimized.sqf"};` | On A2 vanilla → plain-`publicVariable` `SendToServer`. On OA → the `publicVariableServer` `Optimized` variant. |

`WF_A2_Vanilla` is set in `initJIPCompatible.sqf:95-98`: it defaults to `false` and is flipped to `true` only inside an `#ifdef VANILLA` block, so the optimized OA path is the default build. The same flag gates other OA-only countermeasure helpers nearby (`Init_Common.sqf:156,160`), so the send-helper swap is one instance of a general "vanilla-safe vs OA-optimized" compile pattern rather than a one-off.

## The Hosted-Server Short-Circuit

Every helper branches on `isHostedServer`, defined in `initJIPCompatible.sqf:53`:

```sqf
isHostedServer = if (!isMultiplayer || (isServer && !isDedicated)) then {true} else {false};
```

So `isHostedServer` is true for both single-player and listen-server hosts (any machine that is the server but also runs a player). On those machines the send helpers skip the public-variable round-trip for the local consumer and `Spawn` the matching dispatcher directly — `WFBE_CL_FNC_HandlePVF` for client-bound, `WFBE_SE_FNC_HandlePVF` for server-bound. The client-bound helpers additionally guard the network re-fire with `if (isMultiplayer)` so that a true single-player host (where `isMultiplayer` is false) does no network I/O at all, while a listen server still reaches its remote clients. The server-bound helpers have no re-fire because there are no other servers to reach.

## Continue Reading

- [PVF dispatch implementation playbook](PVF-Dispatch-Implementation-Playbook) — the receiver/dispatcher half (`Server_HandlePVF` / `Client_HandlePVF`, `Call Compile`, DR-1/DR-38 allowlist hardening).
- [Public variable channel index](Public-Variable-Channel-Index) — the registered `WFBE_PVF_*` command set and the direct (non-dispatched) channels.
- [Networking and public variables](Networking-And-Public-Variables) — the broader transport/authority model these helpers sit inside.
- [LocalizeMessage chat notification router reference](LocalizeMessage-Chat-Notification-Router-Reference) — a concrete `CLTFNC` consumer reached through `SendToClients`.
- [Server authority migration map](Server-Authority-Migration-Map) — why transport direction is not authority, and the DR-55 sender-authentication lane.
