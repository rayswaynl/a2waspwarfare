# Supply Mission Authority Cleanup Playbook

This page is the implementation handoff for the `supply-mission-authority-cleanup` hardening lane. It covers the existing truck flow and PR #1 / `feat/supply-helicopter`, where supply helicopters, cash runs and interdiction rewards extend the same supply-mission trust model.

Scope: Chernarus source mission first, then generated mission propagation through `Tools/LoadoutManager` after code changes. Paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

Branch split: current `master` has the truck mission flow, client-stamped `SupplyFromTown`/`SupplyAmount`, duplicate-start tracking risk and no supply-vehicle `Killed` handler. PR #1 / `feat/supply-helicopter` adds `SupplyByHeli`, supply-heli class/upgrade gates, cash-run semantics and an interdiction `Killed` handler guarded by `wfbe_supply_killed_eh_set`. Keep those branch-specific mechanics separate when auditing or patching.

## Status

| Item | Status | Notes |
| --- | --- | --- |
| Truck supply mission map | Working but risky | Server tracks return-to-base, but start cargo facts are client-stamped. |
| PR #1 supply helicopters | Partial / PR-ready risk | Additive feature; current branch has a guarded interdiction `Killed` handler, but still needs loaded/tracking state, authority cleanup and Arma smoke before baseline merge. |
| Cooldown model | Partial | Pull-based JIP query is good, but casing and start-time race need cleanup. |
| Dead twin script | Abandoned | `supplyMissionActive.sqf` is compiled but no static caller was found. |
| Authority posture | Opportunity | Small server-owned record can improve integrity without redesigning all economy flows. |
| Command-center scan narrowing | Source and maintained Vanilla propagated; smoke pending | The 80-meter return-to-base scan now filters to `Base_WarfareBUAVterminal` in the live Chernarus and maintained Vanilla handlers; see [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing). |
| Player-object list lifecycle | Partial propagated patch; smoke pending | Row replacement indexing is fixed in Chernarus source and maintained Vanilla Takistan, but `WFBE_SE_PLAYERLIST` still has no disconnect pruning or stale object cleanup. |

## What Was Read

- `Client/Module/supplyMission/supplyMissionStart.sqf`
- `Server/Module/supplyMission/supplyMissionStarted.sqf`
- `Server/Module/supplyMission/supplyMissionCompleted.sqf`
- `Server/Module/supplyMission/isSupplyMissionActiveInTown.sqf`
- `Server/Module/supplyMission/supplyMissionActive.sqf`
- `Server/Module/supplyMission/supplyMissionTimerForTown.sqf`
- `Server/Module/supplyMission/playerObjectsList.sqf`
- `Common/Init/Init_Town.sqf`
- `Common/Init/Init_CommonConstants.sqf`
- `Server/Init/Init_Server.sqf`
- `Client/Init/Init_Client.sqf`
- `Client/Module/Skill/Skill_Apply.sqf`
- `Client/Module/supplyMission/townSupplyStatus.sqf`
- `Client/Module/supplyMission/supplyMissionCompletedMessage.sqf`
- `Client/Functions/Client_UIFillListBuyUnits.sqf`
- `Client/FSM/updatetownmarkers.sqf`
- Existing pages: [Supply mission architecture](Supply-Mission-Architecture), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1), [Economy authority first cut](Economy-Authority-First-Cut), [Hardening roadmap](Hardening-Implementation-Roadmap)

## What The Code Does

1. SpecOps action wiring runs `Client/Module/supplyMission/supplyMissionStart.sqf`; the action condition is local and checks town distance plus supply truck class in current `master`. PR #1 extends this gate to supply-heli classes/upgrades (`Client/Module/Skill/Skill_Apply.sqf`).
2. Mission start asks the server for town cooldown (`supplyMissionStart.sqf:6-7`), immediately reads local `supplyMissionCoolDownEnabled` (`:9-14`), then checks cursor target class/distance (`:16-32`).
3. Current `master` stamps authority-bearing object vars on the vehicle: `SupplyFromTown` and `SupplyAmount` (`supplyMissionStart.sqf:20-34`), then sends `WFBE_Client_PV_SupplyMissionStarted` (`:38-39`). PR #1 also stamps `SupplyByHeli`.
4. Current `master` server start handler records town cooldown as `LastSupplyMissionRun`, starts the town timer and loops while the vehicle is alive. PR #1 additionally adds a guarded `Killed` event handler to the vehicle for interdiction rewards (`origin/feat/supply-helicopter` `supplyMissionStarted.sqf:13-30`).
5. The live loop scans command-center terminals every 3 seconds with `nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 80]` (`supplyMissionStarted.sqf:41-45`). The later nearby-player/object lookup remains a broad 8-meter scan because it resolves occupants/player objects, not command centers.
6. On command-center proximity, the loop resolves a player through `WFBE_SE_PLAYERLIST`, nearby units and the vehicle leader/driver (`supplyMissionStarted.sqf:48-78`), then emits `WFBE_Server_PV_SupplyMissionCompleted` back to the server (`:80-82`).
7. Current `master` completion reads `SupplyAmount` and `SupplyFromTown` from the vehicle object (`supplyMissionCompleted.sqf:9-28`), pays side supply, clears amount/source vars and broadcasts the message. PR #1 extends completion to read `SupplyByHeli`, decide whether a heli cash run applies from server-side Supply upgrade 3 state, and pay commander team funds or side supply.
8. Client reward/score presentation is local after the completion broadcast. The pilot receives the reward through `ChangePlayerFunds` and score is requested with `RequestChangeScore` (`supplyMissionCompletedMessage.sqf:15-33`).

## Confirmed Findings

| Finding | Evidence | Why It Matters |
| --- | --- | --- |
| Client-stamped cargo is still authority-bearing. | Current `master`: `supplyMissionStart.sqf:20-34`; `supplyMissionCompleted.sqf:9-28`. PR #1 adds `SupplyByHeli`. | Server completion trusts the object vars for source and amount. PR #1 adds more reward surfaces on top of that trust. |
| The PR #1 interdiction handler is guarded, but not yet smoke-proven. | `origin/feat/supply-helicopter` `supplyMissionStarted.sqf:13-30` sets `wfbe_supply_killed_eh_set` before adding the `Killed` handler; the handler reads `SupplyAmount`, awards `WFBE_C_SUPPLY_INTERDICTION_CUT` once while amount is positive and clears `SupplyAmount`. | Earlier docs overstated a live stacking leak. Current PR code has a simple idempotency guard, but repeated load/death/reuse behavior still needs Arma smoke before merge. |
| Duplicate mission starts for the same vehicle are not explicitly guarded. | Current `master`: `supplyMissionStart.sqf:32-39`; `supplyMissionStarted.sqf:20-65`. PR #1 extends this with handler attachment. | A reused or rapidly reloaded vehicle can create parallel tracking loops; on PR #1 it can also attach repeated handlers unless state gates are added. |
| Cooldown key casing is inconsistent. | `Init_Town.sqf:35` seeds `lastSupplyMissionRun`; `isSupplyMissionActiveInTown.sqf:8` reads `LastSupplyMissionRun`; `supplyMissionStarted.sqf:8` writes `LastSupplyMissionRun`. | After the first start, the uppercase key exists; before that, the query path depends on nil behavior. Treat this as a source-confirmed mismatch and smoke-test after standardizing. |
| Cooldown response model is good but the start flow races it. | Request at `supplyMissionStart.sqf:6-7`, local read at `:9`, second server request at `:61`; receiver stores result at `townSupplyStatus.sqf:5-8`. | Keep the pull-based JIP pattern, but do not make the immediate local cache read the final authority decision. |
| Command-center scan was broader than needed. | `supplyMissionStarted.sqf:41-45` now uses `nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 80]` in Chernarus source and maintained Vanilla Takistan. | Source and maintained Vanilla are propagated; Arma 2 OA smoke and remaining authority/idempotency work are still open. |
| `supplyMissionActive.sqf` is a dead twin. | `Init_Server.sqf:81` compiles it; repository search found no static caller. Live PVEH is in `supplyMissionStarted.sqf:1-2`. The dead twin still carries older broad-scan logic. | Removes a second, similar implementation from future readers and avoids patching the wrong file. |
| `WFBE_SE_PLAYERLIST` lacks disconnect cleanup. | `playerObjectsList.sqf:11-35` updates by UID; `Server_OnPlayerDisconnected.sqf:1-175` never prunes it. | Source indexing is patched, but stale/deleted object rows can persist. Add UID cleanup on disconnect and skip/repair null rows before completion lookup. |
| Completion uses server-to-server public variable routing. | `supplyMissionStarted.sqf:81-82`; `supplyMissionCompleted.sqf:2`. | It works as a registered server PVEH, but an implementation patch can call a server function directly once the completion path is refactored. |

## Safe Implementation Shape

Recommended branch: `hardening/supply-mission-authority-cleanup`.

1. Add server-owned mission state before changing reward math.
   - On accepted start, set object vars such as `wfbe_supply_loaded`, `wfbe_supply_tracking`, `wfbe_supply_source_town`, `wfbe_supply_amount`, `wfbe_supply_by_heli`, `wfbe_supply_owner_uid` and, for PR #1, `wfbe_supply_killed_eh_id` or `wfbe_supply_killed_eh_set`.
   - Treat existing `SupplyFromTown`, `SupplyAmount` and `SupplyByHeli` as replicated display/compatibility state, not the authority record.

2. Guard idempotency.
   - Reject or no-op when a vehicle is already `wfbe_supply_loaded` or `wfbe_supply_tracking`.
   - Keep at most one `Killed` handler per loaded vehicle. PR #1 currently uses `wfbe_supply_killed_eh_set`; if future code needs removal/re-arm semantics, store the handler ID and remove it deliberately.
   - Clear loaded/tracking/handler state on completion, vehicle death and rejected invalid state.

3. Standardize cooldown.
   - Use one key, preferably `LastSupplyMissionRun` because live server code already reads/writes it.
   - Seed that same key in `Init_Town.sqf`.
   - Keep `supplyMissionCoolDownEnabled` as the client-visible marker/action affordance, not authority.
   - Make the server start handler re-check cooldown before accepting the mission.

4. Harden player-object lifecycle.
   - Keep the source-patched indexed replacement behavior.
   - Remove or mark the matching UID row in `WFBE_SE_PLAYERLIST` on disconnect.
   - Before completion lookup, ignore null/dead object refs and collapse duplicate UID rows rather than appending forever.

5. Recompute or validate cargo on the server.
   - Validate requester side from the player object, not only the payload side.
   - Verify the source town is non-null, friendly to the requester side and within the intended load radius of player/vehicle.
   - Verify vehicle class against `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES` and `WFBE_C_SUPPLY_VEHICLE_TYPES` on PR #1 (`Init_CommonConstants.sqf:173-178`).
   - Verify upgrade gate server-side with `WFBE_CO_FNC_GetSideUpgrades`.
   - Recompute amount from town `supplyValue`, `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER`, supply upgrade modifier and heli reward/cash-run modifiers.

6. Keep PR #1 reward semantics unless the owner asks for a design change.
   - Truck and light-heli non-cash completion should add side supply.
   - Heli upgrade-3 cash run should pay commander team funds when commander exists.
   - No-commander cash-run fallback to side supply is already coded and should remain unless redesigned.
   - Interdiction reward should pay once per loaded vehicle death.

7. Command-center detection narrowing is patched.
   - Source Chernarus and maintained Vanilla Takistan now use `["Base_WarfareBUAVterminal"]` for the live 80-meter command-center scan.
   - Keep the 3-second cadence unless a performance test proves a need to change it.

8. Retire the dead twin.
   - Remove the `WFBE_SE_FNC_SupplyMissionActive` compile binding from `Init_Server.sqf`, or leave an explicit comment that the file is retired.
   - Do not patch `supplyMissionActive.sqf` as the live implementation; it still contains the older broad-scan shape and should be retired or explicitly documented.

## Validation Plan

Source-only checks:

- Confirm every compile/init reference still resolves after retiring `supplyMissionActive.sqf`.
- Confirm the server start handler owns the final accept/reject decision.
- Confirm repeated start attempts cannot create duplicate loops; on PR #1, confirm the `wfbe_supply_killed_eh_set` guard prevents duplicate `Killed` handlers.
- Confirm `SupplyAmount` is cleared only after server-owned reward state has already been consumed.
- Confirm no code path still uses lowercase `lastSupplyMissionRun` after the casing cleanup.
- Done for scan sub-step: source Chernarus and maintained Vanilla Takistan command-center detection use one narrowed `["Base_WarfareBUAVterminal"]` 80-meter scan; `git diff --check` and Arma 2 OA smoke remain validation gates.
- Confirm `WFBE_SE_PLAYERLIST` has one row per active UID after join/reconnect/disconnect churn and no stale `objNull`/deleted rows are used for completion.

Hosted/dedicated smoke:

- Truck mission can be loaded, delivered and rewarded once.
- Same truck can run a second mission after cooldown; no duplicate delivery or duplicate-handler behavior.
- Attempting to load during cooldown is rejected by the server and reflected in client feedback.
- Tampered or stale `SupplyFromTown` / `SupplyAmount` object variables do not drive reward unless the server can validate them against active mission state.

PR #1 helicopter smoke:

- Non-supply helicopters do not show or complete the action.
- Supply helicopter loading requires Supply upgrade 2.
- Heli delivery at Supply upgrade 3 becomes a cash run.
- Heli upgrade-3 cash run pays commander team funds; no-commander fallback banks as side supply.
- Destroying a loaded enemy supply vehicle pays interdiction exactly once; repeated missions on the same vehicle reuse or preserve the guarded handler without duplicate awards.
- Air delivery still gives the pilot 25 percent reward/score bonus.

JIP/disconnect/HC smoke:

- JIP client queries cooldown on join and sees correct `[+SUPPLY]` marker suffix state.
- Starter disconnect does not orphan an already-loaded vehicle if another valid player delivers it.
- Disconnect/reconnect with the same UID replaces the player-object row and cannot complete through a stale old unit reference.
- HC presence should not change behavior; supply mission logic is server/client player flow, not HC-owned AI.

Generated mission validation:

- After mission source edits, run `Tools/LoadoutManager` from a valid `a2waspwarfare` checkout so Chernarus changes propagate to the vanilla generated mission where applicable.
- Re-check generated mission diff before publishing a gameplay patch.

## Handoff

Code owner:

- Implement this before merging PR #1 supply helicopters as baseline if the project wants public-server robustness.
- Start with loaded/tracking state and smoke the current PR #1 `Killed` handler guard; that is the smallest safety gate and unlocks the rest.
- Then standardize cooldown casing and add server-side accept/reject validation.
- Do not fold this into the broader economy authority migration; it is a separate logistics patch with its own tests.

Codex:

- Keep [Supply mission architecture](Supply-Mission-Architecture), [Current supply heli PR](Current-Work-Supply-Helicopters-PR1), [Hardening roadmap](Hardening-Implementation-Roadmap) and `agent-hardening-backlog.jsonl` linked to this page.
- When a code patch lands, update [Feature status](Feature-Status-Register), [Server authority map](Server-Authority-Migration-Map) and validation evidence.

Claude:

- If reviewing this patch independently, focus on contradictions in server ownership: any remaining path where client-stamped amount/source/side can influence reward without server recomputation.
- Also check Arma 2 OA-specific event-handler removal and `nearestObjects` class-filter behavior before declaring the implementation clean.

## Continue Reading

Previous: [Supply mission architecture](Supply-Mission-Architecture) | Next: [Current supply heli PR](Current-Work-Supply-Helicopters-PR1)

Main map: [Home](Home) | Fast path: [Quickstart](Quickstart-For-Humans-And-Agents) | Agent file: [`agent-context.json`](agent-context.json)
