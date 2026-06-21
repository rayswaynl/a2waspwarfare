# Headless Client Init And Stat Loop

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted (other roots: Server/, Common/, Client/, WASP/, Headless/). Arma 2 OA 1.64.

This page documents the **boot pipeline** of a headless client (HC): how the engine role is detected, what `Init_HC.sqf` sets up before it announces itself, the post-boot watchers it leaves running, and the `HCSTAT` telemetry loop. For *what* the HC does after boot (AI delegation, topology, failover) see the delegation pages in Continue Reading — this page owns only the init/identity layer.

## Where The HC Boot Is Launched

HC identity is resolved once, early in the shared entrypoint, and the HC branch runs `Init_HC.sqf` at the end of the same file.

| Step | What happens | Source |
| --- | --- | --- |
| Detect role | `isHeadLessClient` = `Call Compile preprocessFileLineNumbers "Headless\Functions\HC_IsHeadlessClient.sqf"` | `initJIPCompatible.sqf:57` |
| Identity test | `! (hasInterface \|\| isDedicated)` — true only on a process that is neither a player nor the dedicated server | `Headless/Functions/HC_IsHeadlessClient.sqf:5` |
| Force verbose logging | HC sets `LOG_CONTENT_STATE = "ACTIVATED"` (its RPT is its only observable channel) | `initJIPCompatible.sqf:60` |
| Skip server JIP handlers | `onPlayerConnected`/`onPlayerDisconnected` are gated `... && !isHeadLessClient` | `initJIPCompatible.sqf:65` |
| Skip full client init | client init block gated `!isHeadLessClient && !isDedicated` (so `Init_Client.sqf` does **not** run on an HC) | `initJIPCompatible.sqf:74`, `:262` |
| Launch HC boot | `if (isHeadLessClient) then { execVM "Headless\Init\Init_HC.sqf" };` | `initJIPCompatible.sqf:275-277` |

Because `Init_Client.sqf` is skipped, two things a normal client would do are **not** done for the HC, and `Init_HC.sqf` has to compensate: parking the body in a deadspawn holding area, and `player allowDamage false` (see the body-protection row below).

## What Init_HC.sqf Sets Up (in order)

`Init_HC.sqf` is ~147 lines. It compiles the delegation receivers, then performs a side-reseat, a deadspawn park, registers with the server, and launches two long-lived loops.

| Order | Action | Detail | Source |
| --- | --- | --- | --- |
| 1 | Compile delegation receivers | `WFBE_CL_FNC_CleanupDelegatedTownAI`, `WFBE_CL_FNC_DelegateTownAI`, `WFBE_CL_FNC_DelegateAI`, `WFBE_CL_FNC_DelegateAIStaticDefence`, `WFBE_CL_FNC_HandlePVF` | `Init_HC.sqf:5-9` |
| 2 | Wait for server full init | fixed `sleep 20` ("just in case") | `Init_HC.sqf:14` |
| 3 | Wait for player object | `waitUntil {!isNull player}` — never run the reseat guard before the unit exists | `Init_HC.sqf:28` |
| 4 | Preseat telemetry | sends `["RequestSpecial",["hc-preseat",[name player, str (side group player)]]]` so the engine's raw auto-seat is server-visible **before** any reseat | `Init_HC.sqf:30` |
| 5 | Reseat to civilian | runs `WFBE_HC_FNC_ReseatCivilian` (bounded poll) unless already civilian | `Init_HC.sqf:97` |
| 6 | Reseat-result telemetry | sends `hc-reseat-result` with `done`/`skipped`/`failed` + current side | `Init_HC.sqf:99` |
| 7 | Park the body | `WFBE_HC_FNC_ParkDeadspawn` — only fires while civilian | `Init_HC.sqf:101` |
| 8 | Persistent reseat watcher | `[] Spawn {...}` 15s loop, re-reseats + re-parks + re-announces on a mission-restart re-grab | `Init_HC.sqf:112-126` |
| 9 | Register with server | `["RequestSpecial",["connected-hc", player]]` | `Init_HC.sqf:129` |
| 10 | Launch stat loop | `[] ExecVM "Headless\HC_StatLoop.sqf"` | `Init_HC.sqf:132` |
| 11 | Launch HC-local group GC | `[] ExecVM "Client\Functions\Client_GroupsGC.sqf"` | `Init_HC.sqf:146` |

### Why the reseat exists

A2 OA auto-seats the `-client` into a random free playable slot, and an HC reliably lands on a **synchronized WEST warfare slot** (`mission.sqm` id=229, sync 255). That makes the HC a phantom WEST player: it inflates BLUFOR team balance + vote quorum and permanently resets the empty-server WEST supply-stagnation timer. `forceHeadlessClient=1` is an **A3-only** attribute and is inert in A2 OA, so the fix is done in script — `WFBE_HC_FNC_ReseatCivilian` (`Init_HC.sqf:35-60`, invoked at `:97`); the rationale is documented in the comment block at `Init_HC.sqf:16-27`.

`WFBE_HC_FNC_ReseatCivilian` (`Init_HC.sqf:35-60`) is a bounded poll: while `side group player != civilian` and within the deadline, it `createGroup civilian` (raw, **not** the WFBE wrapper, so the infra group stays off the per-side group-cap/GC sweep — `Init_HC.sqf:42`), retries up to 5 times if the ~144 civilian group cap returns `grpNull`, then `[player] joinSilent _g` and waits 2s for the membership change to replicate before the connect notify. It returns `"done"`/`"failed"`. **Invariant:** each HC must be the sole member (hence leader) of its own fresh group so `owner(leader(group))` stays distinct per HC and delegation never collapses onto a single HC (`Init_HC.sqf:20-24`).

### Body protection + deadspawn park

`WFBE_HC_FNC_ParkDeadspawn` (`Init_HC.sqf:76-92`) guards on `side group player == civilian` (`:77`), sets `player allowDamage false` + `player setCaptive true` (unkillable + non-hostile — this replaces the `Init_Client.sqf` damage-off the HC never ran, `Init_HC.sqf:83-84`), and `setPos`es the body into `GuerTempRespawnMarker` — the centre deadspawn marker inside the H-barrier ring (`Init_HC.sqf:85-88`). It is keyed on `player` (not `name=="HC"`) so HC1 and HC2 run it identically. Order invariant: reseat-to-civilian always runs **first**, so the park never runs against a WEST/EAST grouping.

### Persistent reseat watcher

A one-shot reseat exits permanently the moment the HC first reaches civilian, but an in-place **mission restart** (a 2nd MISSINIT on the same process) re-seats every still-connected client and the HC lands back on WEST id=229 — invisible to the one-shot loop. The watcher (`Init_HC.sqf:112-126`) runs for the whole session: every 15s, if `side group player != civilian`, it re-reseats (30s budget), emits `hc-reseat-result` tagged `rewatch:`, re-parks, and re-announces `connected-hc` so the server re-resolves `group _hc` onto the fresh civ group.

## HC_StatLoop.sqf — HCSTAT Telemetry

`HC_StatLoop.sqf` (~24 lines) runs only on HCs (launched from `Init_HC.sqf:132`). It ships HC load to the server once per minute.

| Aspect | Value | Source |
| --- | --- | --- |
| HC id | `format ["HC-%1", netId player]` — netId is network-unique per HC slot; `profileName` is undefined on HCs and `owner player` returns 0 (both HCs would collapse to HC0) | `HC_StatLoop.sqf:16`, `:6-8` |
| Local unit count | `{local _x} count allUnits` | `HC_StatLoop.sqf:19` |
| Local group count | `{local (leader _x)} count allGroups` — A2 `local` takes an OBJECT only; a group arg throws, so the leader is used as proxy | `HC_StatLoop.sqf:21` |
| Payload sent | `["HCStat", [_hcId, round diag_fps, _units, _groups]] Call WFBE_CO_FNC_SendToServer` | `HC_StatLoop.sqf:22` |
| Interval | `sleep 60` | `HC_StatLoop.sqf:23` |
| Exit | none — `while {true}` (runs for the whole session) | `HC_StatLoop.sqf:18` |

### Server-side sink

`HCStat` is a registered server-command public variable (`Common/Init/Init_PublicVariables.sqf:27`). The server handler validates the payload (`typeName == "ARRAY"`, `count >= 4`, `_name` is a STRING — a malformed payload must never throw inside a PVF, `Server/PVFunctions/HCStat.sqf:11-18`) and emits one machine-parseable line:

`HCSTAT|v1|<name>|fps=<n>|units=<n>|groups=<n>|t=<min>` (`Server/PVFunctions/HCStat.sqf:20`).

A comment notes the server/generator relabels the `HC-<netId>` ids to `HC1`/`HC2` by sort order (`HC_StatLoop.sqf:15`); the relabel itself lives in out-of-mission tooling, not in the mission scripts.

## Server-Side Boot Telemetry Sinks

The three boot-time `RequestSpecial` payloads land in `Server_HandleSpecial.sqf` and emit `HCSIDE` diagnostic lines (so "did an HC land on WEST this boot, and did the script fix it" is directly observable on the server RPT — the `diag_log` emit lines are `Server_HandleSpecial.sqf:397`, `:404`, `:413`; the rationale comment is at `:389-392`).

| Payload | Server line emitted | Source |
| --- | --- | --- |
| `hc-preseat` | `HCSIDE\|v1\|preseat\|name=..\|engineSide=..` | `Server/Functions/Server_HandleSpecial.sqf:393-398` |
| `hc-reseat-result` | `HCSIDE\|v1\|reseat\|name=..\|result=..\|sideNow=..` | `Server/Functions/Server_HandleSpecial.sqf:399-405` |
| `connected-hc` | `HCSIDE\|v1\|connect\|uid=..\|owner=..\|side=..`, then registry update (drop stale UID group, prune dead, append `group _hc` if `owner != 0`) | `Server/Functions/Server_HandleSpecial.sqf:406-434` (connect line `:413`; append `:430-431`) |

## HC-Local Group Reaper

`Init_HC.sqf:146` launches `Client/Functions/Client_GroupsGC.sqf` on the HC. Its start gate is broadened to run on a player client **or** a headless client via `WFBE_GC_IsHC = isMultiplayer && {!isServer} && {!hasInterface}` (`Client_GroupsGC.sqf:24-25`); the dedicated server is excluded (it has `server_groupsGC.sqf`). It reaps client-LOCAL empty, non-persistent, non-player, non-town-tracked groups once per 60s (`Client_GroupsGC.sqf:38`), tagging lines `HC-<netId>` to line up with HCSTAT (`Client_GroupsGC.sqf:30-32`). This closes an HC-local empty-group leak toward the 144/side cap: an HC owns ~12-16 delegated groups whose self-reap no-ops while dead-but-uncollected corpses still sit in `units _team` (`Init_HC.sqf:134-145`). Launched **after** the reseat so `group player` already resolves to the civilian infra group it must protect.

## Continue Reading

- [Headless Client Scaling And Topology](Headless-Client-Scaling-And-Topology) — delegation modes, the offload ceiling, running a 2nd HC.
- [AI Runtime And HC Loop Map](AI-Runtime-HC-Loop-Map) — the full server/HC runtime loop table and delegation map.
- [Headless Delegation And Failover Playbook](Headless-Delegation-And-Failover-Playbook) — payloads, callbacks, disconnect/orphan behaviour.
- [Mission Entrypoints And Lifecycle](Mission-Entrypoints-And-Lifecycle) — the `initJIPCompatible.sqf` role split this boot path branches from.
- [Networking And Public Variables](Networking-And-Public-Variables) — the `RequestSpecial`/`SendToServer` PVF channel the HC telemetry rides on.
