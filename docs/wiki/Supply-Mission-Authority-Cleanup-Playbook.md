# Supply Mission Authority Cleanup Playbook

This page is the implementation handoff for the `supply-mission-authority-cleanup` hardening lane. It covers the existing truck flow and PR #1 / `feat/supply-helicopter`, where supply helicopters, cash runs and interdiction rewards extend the same supply-mission trust model.

Scope: Chernarus source mission first, then generated mission propagation through `Tools/LoadoutManager` after code changes. Paths below are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Status

| Item | Status | Notes |
| --- | --- | --- |
| Truck supply mission map | Working but risky | Server tracks return-to-base, but start cargo facts are client-stamped. |
| PR #1 supply helicopters | Partial / PR-ready risk | Additive feature; needs loaded-state and `Killed` handler cleanup before baseline merge. |
| Cooldown model | Partial | Pull-based JIP query is good, but casing and start-time race need cleanup. |
| Dead twin script | Abandoned | `supplyMissionActive.sqf` is compiled but no static caller was found. |
| Authority posture | Opportunity | Small server-owned record can improve integrity without redesigning all economy flows. |
| Command-center scan narrowing | Source/Vanilla patched | The 80-meter return-to-base scan now filters to `Base_WarfareBUAVterminal`; see [Supply mission scan narrowing](Supply-Mission-Scan-Narrowing). |

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

1. SpecOps action wiring runs `Client/Module/supplyMission/supplyMissionStart.sqf`; the action condition is local and checks town distance plus supply truck or supply-heli class/upgrade gates (`Client/Module/Skill/Skill_Apply.sqf:62-73`).
2. Mission start asks the server for town cooldown (`supplyMissionStart.sqf:6-7`), immediately reads local `supplyMissionCoolDownEnabled` (`:9-14`), then checks cursor target class/distance (`:16-32`).
3. The client stamps authority-bearing object vars on the vehicle: `SupplyFromTown`, `SupplyByHeli` and `SupplyAmount` (`supplyMissionStart.sqf:34-46`), then sends `WFBE_Client_PV_SupplyMissionStarted` (`:50-51`).
4. The server start handler records town cooldown as `LastSupplyMissionRun` (`supplyMissionStarted.sqf:8`), adds a `Killed` event handler to the vehicle (`:10-25`), starts the town timer (`:35`) and loops while the vehicle is alive (`:37-86`).
5. The loop scans nearby objects every 3 seconds with `nearestObjects [(getPos _associatedSupplyTruck), [], 80]`, then filters for `Base_WarfareBUAVterminal` in script (`supplyMissionStarted.sqf:41-45`).
6. On command-center proximity, the loop resolves a player through `WFBE_SE_PLAYERLIST`, nearby units and the vehicle leader/driver (`supplyMissionStarted.sqf:48-78`), then emits `WFBE_Server_PV_SupplyMissionCompleted` back to the server (`:80-82`).
7. Completion reads `SupplyAmount`, `SupplyFromTown` and `SupplyByHeli` from the vehicle object (`supplyMissionCompleted.sqf:9-25`), decides whether a heavy-heli cash run applies from server-side upgrade state (`:26-27`), pays commander team funds or side supply (`:31-40`), clears only amount/source vars (`:41-42`) and broadcasts the message (`:48`).
8. Client reward/score presentation is local after the completion broadcast. The pilot receives the reward through `ChangePlayerFunds` and score is requested with `RequestChangeScore` (`supplyMissionCompletedMessage.sqf:15-33`).

## Confirmed Findings

| Finding | Evidence | Why It Matters |
| --- | --- | --- |
| Client-stamped cargo is still authority-bearing. | `supplyMissionStart.sqf:34-46`; `supplyMissionCompleted.sqf:9-25` | Server completion trusts the object vars for source and amount. PR #1 adds more reward surfaces on top of that trust. |
| The PR #1 `Killed` handler can stack on reused vehicles. | `supplyMissionStarted.sqf:10-25` adds a handler every start with no guard/removal. | Double payment is currently muted because the first handler clears `SupplyAmount` to zero, but handler leakage is real and future side effects would multiply. |
| Duplicate mission starts for the same vehicle are not explicitly guarded. | `supplyMissionStart.sqf:32-51`; `supplyMissionStarted.sqf:37-86` | A reused or rapidly reloaded vehicle can create parallel tracking loops and repeated handler attachment unless state gates are added. |
| Cooldown key casing is inconsistent. | `Init_Town.sqf:35` seeds `lastSupplyMissionRun`; `isSupplyMissionActiveInTown.sqf:8` reads `LastSupplyMissionRun`; `supplyMissionStarted.sqf:8` writes `LastSupplyMissionRun`. | After the first start, the uppercase key exists; before that, the query path depends on nil behavior. Treat this as a source-confirmed mismatch and smoke-test after standardizing. |
| Cooldown response model is good but the start flow races it. | Request at `supplyMissionStart.sqf:6-7`, local read at `:9`, second server request at `:61`; receiver stores result at `townSupplyStatus.sqf:5-8`. | Keep the pull-based JIP pattern, but do not make the immediate local cache read the final authority decision. |
| Command-center scan was broader than needed. | `supplyMissionStarted.sqf:41-45` now uses `nearestObjects [(getPos _associatedSupplyTruck), ["Base_WarfareBUAVterminal"], 80]`. | Source/Vanilla patched as a low-risk performance sub-step; remaining authority/idempotency work is still open. |
| `supplyMissionActive.sqf` is a dead twin. | `Init_Server.sqf:81` compiles it; repository search found no static caller. Live PVEH is in `supplyMissionStarted.sqf:1-2`. | Removes a second, similar implementation from future readers and avoids patching the wrong file. |
| Completion uses server-to-server public variable routing. | `supplyMissionStarted.sqf:81-82`; `supplyMissionCompleted.sqf:2`. | It works as a registered server PVEH, but an implementation patch can call a server function directly once the completion path is refactored. |

## Safe Implementation Shape

Recommended branch: `hardening/supply-mission-authority-cleanup`.

1. Add server-owned mission state before changing reward math.
   - On accepted start, set object vars such as `wfbe_supply_loaded`, `wfbe_supply_tracking`, `wfbe_supply_source_town`, `wfbe_supply_amount`, `wfbe_supply_by_heli`, `wfbe_supply_owner_uid` and, for PR #1, `wfbe_supply_killed_eh_id` or `wfbe_supply_killed_eh_set`.
   - Treat existing `SupplyFromTown`, `SupplyAmount` and `SupplyByHeli` as replicated display/compatibility state, not the authority record.

2. Guard idempotency.
   - Reject or no-op when a vehicle is already `wfbe_supply_loaded` or `wfbe_supply_tracking`.
   - Attach at most one `Killed` handler per loaded vehicle; if using handler IDs, remove the old handler before adding a new one.
   - Clear loaded/tracking/handler state on completion, vehicle death and rejected invalid state.

3. Standardize cooldown.
   - Use one key, preferably `LastSupplyMissionRun` because live server code already reads/writes it.
   - Seed that same key in `Init_Town.sqf`.
   - Keep `supplyMissionCoolDownEnabled` as the client-visible marker/action affordance, not authority.
   - Make the server start handler re-check cooldown before accepting the mission.

4. Recompute or validate cargo on the server.
   - Validate requester side from the player object, not only the payload side.
   - Verify the source town is non-null, friendly to the requester side and within the intended load radius of player/vehicle.
   - Verify vehicle class against `WFBE_C_SUPPLY_TRUCK_TYPES`, `WFBE_C_SUPPLY_HELI_TYPES_T2` and `WFBE_C_SUPPLY_HELI_TYPES_T3`.
   - Verify upgrade gate server-side with `WFBE_CO_FNC_GetSideUpgrades`.
   - Recompute amount from town `supplyValue`, `WFBE_C_ECONOMY_SUPPLY_MISSION_MULTIPLIER`, supply upgrade modifier and heavy-heli bonus.

5. Keep PR #1 reward semantics unless the owner asks for a design change.
   - Truck and light-heli non-cash completion should add side supply.
   - Heavy-heli upgrade-3 cash run should pay commander team funds when commander exists.
   - No-commander cash-run fallback to side supply is already coded and should remain unless redesigned.
   - Interdiction reward should pay once per loaded vehicle death.

6. Command-center detection narrowing is patched.
   - Source Chernarus and Vanilla Takistan now use `["Base_WarfareBUAVterminal"]` for the 80-meter command-center scan.
   - Keep the 3-second cadence unless a performance test proves a need to change it.

7. Retire the dead twin.
   - Remove the `WFBE_SE_FNC_SupplyMissionActive` compile binding from `Init_Server.sqf`, or leave an explicit comment that the file is retired.
   - Do not patch `supplyMissionActive.sqf` as the live implementation.

## Validation Plan

Source-only checks:

- Confirm every compile/init reference still resolves after retiring `supplyMissionActive.sqf`.
- Confirm the server start handler owns the final accept/reject decision.
- Confirm repeated start attempts cannot create duplicate loops or duplicate `Killed` handlers.
- Confirm `SupplyAmount` is cleared only after server-owned reward state has already been consumed.
- Confirm no code path still uses lowercase `lastSupplyMissionRun` after the casing cleanup.
- Done for scan sub-step: source/Vanilla command-center detection uses one narrowed `["Base_WarfareBUAVterminal"]` 80-meter scan; `git diff --check` passed.

Hosted/dedicated smoke:

- Truck mission can be loaded, delivered and rewarded once.
- Same truck can run a second mission after cooldown; no duplicate delivery or stacked handler behavior.
- Attempting to load during cooldown is rejected by the server and reflected in client feedback.
- Destroying a loaded enemy supply vehicle pays interdiction exactly once.

PR #1 helicopter smoke:

- Non-supply helicopters do not show or complete the action.
- Light supply helicopter requires Supply upgrade 2.
- Heavy supply helicopter requires Supply upgrade 3 and applies the 20 percent payload bonus.
- Heavy-heli upgrade-3 cash run pays commander team funds; no-commander fallback banks as side supply.
- Air delivery still gives the pilot 25 percent reward/score bonus.

JIP/disconnect/HC smoke:

- JIP client queries cooldown on join and sees correct `[+SUPPLY]` marker suffix state.
- Starter disconnect does not orphan an already-loaded vehicle if another valid player delivers it.
- HC presence should not change behavior; supply mission logic is server/client player flow, not HC-owned AI.

Generated mission validation:

- After mission source edits, run `Tools/LoadoutManager` from a valid `a2waspwarfare` checkout so Chernarus changes propagate to the vanilla generated mission where applicable.
- Re-check generated mission diff before publishing a gameplay patch.

## Handoff

Code owner:

- Implement this before merging PR #1 supply helicopters as baseline if the project wants public-server robustness.
- Start with loaded/tracking state and `Killed` handler idempotency; that is the smallest safety patch and unlocks the rest.
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