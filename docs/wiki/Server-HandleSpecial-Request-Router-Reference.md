# Server_HandleSpecial Request Router Reference (RequestSpecial dispatcher)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Server_HandleSpecial.sqf` is the server's central special-request router. It is a single `switch` over the first element of the incoming payload (`_args select 0`), dispatching 27 distinct case labels that cover player/group bookkeeping, support specials (paradrops, UAV, ICBM, supply-truck respawn), upgrade sync, headless-client (HC) lifecycle, AI-commander team registry, side patrols, camp/HQ structures, object tracking, and the GUER player VBIED. Most cases are tiny state writes; a handful (`commandbar-cleanup-dead-unit`, `guer-vbied-detonate`, the paradrops) hand off to a `spawn`ed worker so the router thread stays cheap.

This page documents the **routing contract** — entry point, payload tuple shape per case, side effects, locality — that the scattered case-specific deep-dive pages (Side Patrol, ICBM, HC delegation, Group-Join) each cover only in part. For a single case's full mechanics, follow the Continue Reading links.

## Entry point and dispatch chain

A client raises a special request with `["RequestSpecial", [<case>, ...]] Call WFBE_CO_FNC_SendToServer`; the payload reaches this router by the PV round-trip below. There is no validation layer between the wrapper and the switch — the case label and tuple positions ARE the contract.

| Stage | Path | Behavior |
| --- | --- | --- |
| Client send | `Common/Functions/Common_SendToServer.sqf:12` | Wraps the request as `SRVFNCRequestSpecial` and either sets `WFBE_PVF_RequestSpecial` + `publicVariable` (dedicated) or spawns `WFBE_SE_FNC_HandlePVF` directly (hosted). |
| Server PVF | `Server/PVFunctions/RequestSpecial.sqf:1` | Entire file is `_this Spawn HandleSpecial;` — forwards the tuple into the router in a fresh thread. |
| Router compile | `Server/Init/Init_Server.sqf:37` | `HandleSpecial = Compile preprocessFile "Server\Functions\Server_HandleSpecial.sqf";` |
| Parser | `Server_HandleSpecial.sqf:1,3,5` | `Private['_args']; _args = _this; switch (_args select 0) do {...}` — the whole body is one switch; `_args select 0` is the case label, `_args select 1..N` the payload. |

Note the parser quirk: the router reads `_args` everywhere, but the `upgrade-sync` case mixes `_args select 1` with `_this select 2`/`_this select 3` (`Server_HandleSpecial.sqf:69-71`). Because `_args = _this` at line 3, both resolve to the same tuple today, so the mix is latent debt, not a live break.

## Player and group cases

| Case | Payload `_args` | Side effect / locality | Source |
| --- | --- | --- | --- |
| `update-teamleader` | `[_, _team, _leader]` | `_team setVariable ["wfbe_teamleader", _leader]` — records the team's leader group-var (no broadcast). Sent on kill and on client init. | `:6-12`; senders `Client/Functions/Client_OnKilled.sqf:64`, `Client/Init/Init_Client.sqf:371` |
| `group-query` | `[_, _group, _player, _side]` | Group-join handshake. If `leader _group` is a **player**, forwards `group-join-request` to that leader's client. If AI-led and `wfbe_uid` is nil (AI group), calls `WFBE_CO_FNC_ChangeUnitGroup` then sends `group-join-accept` to `_player`. Vanilla path uses `SendToClients` by UID, OA path uses `SendToClient` by object. | `:13-41`; sender `Client/Functions/Client_FNC_Groups.sqf:126,131` |
| `commandbar-cleanup-dead-unit` | `[_, _requester, _unit]` | Authoritative detach of a dead AI unit stuck in a leader's command bar on dedicated servers. `spawn`s a 75-line worker that validates (alive requester, dead non-player `_unit`, requester is its group leader), then loops up to 21 attempts (`for "_attempt" from 0 to 20`): if `local _unit`, `joinSilent grpNull`; else `setOwner (owner _requester)` and every 4th attempt re-sends `commandbar-force-dead-cleanup` to the requester client. Logs ACCEPTED / DETACHED / STILL_STUCK with re-entrancy guards. `sleep 0.25` between attempts. | `:138-214` |

## Support-special cases (handoff to spawned workers)

These cases are thin: they `spawn` a compiled worker bound in `Init_Server.sqf`. The worker owns the actual effect, fee log, and cleanup.

| Case | Payload | Dispatch | Worker bind | Source |
| --- | --- | --- | --- | --- |
| `Paratroops` | full `_args` | `_args spawn KAT_Paratroopers` | `Init_Server.sqf:47` → `Server\Support\Support_Paratroopers.sqf` | `:43-45` |
| `ParaVehi` | full `_args` | `_args spawn KAT_ParaVehicles` | `Init_Server.sqf:48` → `Support_ParaVehicles.sqf` | `:47-49` |
| `ParaAmmo` | full `_args` | `_args spawn KAT_ParaAmmo` | `Init_Server.sqf:46` → `Support_ParaAmmo.sqf` | `:51-53` |
| `uav` | full `_args` | `_args spawn KAT_UAV` | `Init_Server.sqf:49` → `Support_UAV.sqf` | `:63-65` |
| `RespawnST` | `[_, _side]` | Force-respawns that side's AI supply trucks: reads `wfbe_ai_supplytrucks` off the side logic, then `driver _x setDammage 1; _x setDammage 1` on each. Logs the forced respawn. | (inline) | `:55-61` |
| `ICBM` | `[_, _side, _base, _target, _playerTeam]` | Logs the nuke call, `exitWith` if `_target` null/dead, `waitUntil {!alive _target ...}`, then `[_base] Spawn NukeDammage`. `NukeDammage` is compiled client-side at `Client/Module/Nuke/ICBM_Init.sqf:13` from `damage.sqf`. | `:117-132` |

## Headless-client lifecycle and delegation cases

| Case | Payload | Side effect | Source |
| --- | --- | --- | --- |
| `connected-hc` | `[_, _hc]` | Registers a headless client. Reads `owner _hc` and `getPlayerUID _hc`; logs `HCSIDE|v1|connect`. If owner id `!= 0`: drops this UID's prior group from `WFBE_HEADLESSCLIENTS_ID`, prunes dead entries (null/dead leader), stores `WFBE_HEADLESS_<uid>` = `group _hc`, appends to the validated registry. Owner id `0` warns "server controlled". | `:406-435` |
| `hc-preseat` | `[_, [_name, _engineSide]]` | Pure RPT telemetry: `diag_log "HCSIDE|v1|preseat|name=...|engineSide=..."`. No gameplay effect. | `:393-398` |
| `hc-reseat-result` | `[_, [_name, _result, _sideNow]]` | Pure RPT telemetry: `diag_log "HCSIDE|v1|reseat|name=...|result=...|sideNow=..."`. | `:399-405` |
| `update-clientfps` | `[_, _uid, _fps]` | Updates `WFBE_AI_DELEGATION_<uid>` slot 0 with the reported client FPS (delegation load metric); no-op if the var is nil. | `:75-85` |
| `update-town-delegation` | `[_, _town, _teams, _vehicles]` (or legacy `[_, _town, _vehicles]`) | Town-AI delegation report. Back-compat: if `count _args > 3` reads teams+vehicles, else vehicles only. Adds non-duplicate `_teams` into `wfbe_town_teams`, appends `_vehicles` to `wfbe_active_vehicles`, logs `TOWN_AI_HC_CLEANUP`, then `spawn WFBE_SE_FNC_HandleEmptyVehicle` per vehicle and flags each `WFBE_Taxi_Prohib`. | `:86-116` |

## AI-commander team registry cases

These maintain `WFBE_ACTIVE_AICOM_TEAMS` (a `publicVariable`-broadcast list of `[leader, sideID, dir, team]` rows that clients draw as direction arrows) and the side-logic team accounting.

| Case | Payload | Side effect | Source |
| --- | --- | --- | --- |
| `aicom-team-created` | `[_, _sideID, _team]` | Decrements `wfbe_aicom_pending` (min 0), appends `_team` to side-logic `wfbe_teams`, and if leader exists pushes `[leader, sideID, getDir, team]` onto `WFBE_ACTIVE_AICOM_TEAMS` + `publicVariable`. Logs via `WFBE_CO_FNC_AICOMLog`. | `:215-238` |
| `aicom-team-ended` | `[_, _sideID, _team]` | Drops this team's arrow row (and null leftovers) and re-broadcasts. If `_team` null: just releases the pending slot. Else removes from `wfbe_teams`; if the team has 0 units clears `wfbe_persistent` so the 60s group GC reaps the empty husk (group-cap leak fix); clears `wfbe_aicom_garrison` if it matched. | `:239-273` |
| `aicom-team-heading` | `[_, [_team, _dir]]` | Patches the team's arrow heading: updates slot 2 only when the signed angle delta `> 7` deg, then `publicVariable` (PV-spam throttle). | `:277-302` |
| `aicom-vehicle-abandoned` | `[_, _veh]` | Enrolls an abandoned alive hull into the empty-vehicle collector by appending to `WF_Logic "emptyVehicles"` (the producer list, not the `emptyQueu` dedupe set), guarded against duplicates. The collector owns dedupe + delete timer. | `:310-328` |
| `aicom-heli-refunded` | `[_, _sideID, _cost]` | Refunds an off-map-flown empty transport's build cost to the side's AI-commander treasury via `[_rSide, _rCost] Call ChangeAICommanderFunds`, gated on `_rSide in [east,west,resistance] && _cost > 0`. | `:334-344` |

## Side-patrol cases

These maintain `WFBE_ACTIVE_PATROLS` (`[leader, sideID]` rows, same arrow-marker pattern as the aicom list).

| Case | Payload | Side effect | Source |
| --- | --- | --- | --- |
| `sidepatrol-started` | `[_, _sideID, _unit]` | Appends `[_unit, _sideID]` to `WFBE_ACTIVE_PATROLS` + `publicVariable`. | `:345-354` |
| `sidepatrol-ended` | `[_, _sideID, _unit]` | Releases the side-logic patrol slot (`wfbe_side_patrols` min 0), re-arms `wfbe_side_patrol_last = time`, drops the ended unit's row + null leftovers, re-broadcasts. | `:355-373` |
| `sidepatrol-convoy-stop` | `[_, _sideID, _town]` | Convoy reached a town: pays the owning side. Pool = `WFBE_C_PATROL_CONVOY_PAY` (default 750), split among alive same-side players, paid via `[_cSide, "BankPayout", [_cShare]] Call WFBE_CO_FNC_SendToClients`. | `:375-388` |

## Structure, tracking, and GUER cases

| Case | Payload | Side effect | Source |
| --- | --- | --- | --- |
| `process-killed-hq` | `[_, _hq]` | `(_args select 1) Spawn WFBE_SE_FNC_OnHQKilled` (bound `Init_Server.sqf:72`). | `:134-136` |
| `track-playerobject` | `[_, _uid, _object]` | Appends `_object` to `WFBE_CLIENT_<uid>_OBJECTS` (creating the list if nil, scrubbing `objNull`). Server-side ownership ledger of client-spawned objects. | `:436-449` |
| `repair-camp` | `[_, _logic, _repairSideID]` | Rebuilds a destroyed camp bunker. `exitWith` if `wfbe_camp_bunker` still alive; else `createVehicle` the `WFBE_C_CAMP` model at the logic with `WFBE_C_CAMP_RDIR` offset, attaches killed/handleDamage (`WFBE_C_CAMP_HEALTH_COEF`) EHs, stores it. If `sideID != _repairSideID`, flips `sideID` and sends `CampCaptured` to all clients. | `:450-473` |
| `guer-vbied-detonate` | `[_, _veh, _driver]` | GUER player suicide-VBIED. Gate-guarded (`WFBE_C_GUER_PLAYERSIDE > 0`, driver match, `side _driver == resistance`, `typeOf _veh == WFBE_C_GUER_VBIED_TYPE`). Spawns a worker that snapshots living WEST/EAST targets within `WFBE_C_GUER_VBIED_BLAST_RADIUS` (default 30), then `_veh setDamage 1` + 3x `"Sh_122_HE" createVehicle`, `sleep 4`, and pays the driver's GUER team `unitPrice * WFBE_C_GUER_KILL_BOUNTY_COEF` (default 0.5) per blast kill via `WFBE_CO_FNC_ChangeTeamFunds`. Unit price read at array index `QUERYUNITPRICE`. | `:484-524`; sender `Client/Action/Action_GuerVbiedDetonate.sqf` |

## Routing contract notes

| Observation | Detail | Source |
| --- | --- | --- |
| No central validation | The switch trusts the case label and tuple shape verbatim; per-case gates (e.g. GUER, aicom-heli side check) are the only guards. Hardening must happen inside each case. | `:5` (no pre-switch guard) |
| Every case runs in a spawned thread | `RequestSpecial.sqf` does `_this Spawn HandleSpecial`, so each request is already on its own thread before the switch; cases that `spawn` again (paradrops, commandbar cleanup, guer-vbied) do so to avoid blocking that thread on `sleep`/`waitUntil`. | `Server/PVFunctions/RequestSpecial.sqf:1` |
| Two broadcast list patterns | `WFBE_ACTIVE_AICOM_TEAMS` and `WFBE_ACTIVE_PATROLS` are both append-and-`publicVariable` arrow-marker registries with matching create/end/prune logic; clients consume them in `Client/FSM/updateaicommarkers.sqf`. | `:233`, `:352` |
| `upgrade-sync` mixed parser | Reads `_args select 1` then `_this select 2/3`; harmless today (`_args = _this`) but should be normalized to one payload shape. | `:67-73` |

## Continue Reading

- [Side-Patrol-Runtime-And-Convoy-Mechanics](Side-Patrol-Runtime-And-Convoy-Mechanics) — the `sidepatrol-*` cases in full (spawn cooldown, convoy payout).
- [ICBM-Authority-Playbook](ICBM-Authority-Playbook) — the `ICBM` case and the NukeDammage blast path.
- [Headless-Delegation-And-Failover-Playbook](Headless-Delegation-And-Failover-Playbook) — `connected-hc`, `update-town-delegation`, `update-clientfps` and HC registry hygiene.
- [Player-Squad-Group-Join-Protocol](Player-Squad-Group-Join-Protocol) — the `group-query` join handshake end to end.
- [Support-Specials-And-Tactical-Modules-Atlas](Support-Specials-And-Tactical-Modules-Atlas) — the paradrop/UAV support workers and their fee/cooldown gating.
