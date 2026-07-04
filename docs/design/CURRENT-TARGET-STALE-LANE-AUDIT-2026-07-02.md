# Current-Target Stale Lane Audit - 2026-07-02

Lane: 23, wiki knowledge mining.
Base checked: `origin/claude/build84-cmdcon36@b5667bd0aab7`.
Scope: docs-only source audit of prompt/wiki/brain rows that looked claimable during fleet scouting but are already live on the current target, already covered by an active/open lane, or narrowed to a different follow-up.

Use this as a skip list, not as a substitute for the shared brain. Before claiming any row here, re-check `agent-collaboration.json`, open PRs, and the current branch tip.

## Summary

The current live lane has absorbed a lot of older "quick win" work. Several rows still appear in prompt/wiki stores because those stores preserve historical evidence, but the source at `b5667bd0aab7` already contains the relevant fix. Future fleet passes should not re-open these as first-order source lanes unless the branch tip regresses.

## Stale Or Occupied Rows

| Row / area | Current target evidence | Fleet action |
| --- | --- | --- |
| Lane 54, LoadoutManager Takistan mirror guard | `Tools/LoadoutManager/Program.cs:11-13` dispatches `--check`, `--dry-run`, and `--check-takistan-mirror` into `MirrorDriftChecker.CheckTakistanMirror()`. `MirrorDriftChecker.cs:1-41` implements the generated-drift check and pass/fail messages. `README.md:68-78` documents the command. | Do not reclaim as "add mirror drift guard". Improvements should extend the existing checker or CI usage. |
| Lane 73, SEND_MESSAGE direct-compile RCE | `Client_onEventHandler_SEND_MESSAGE.sqf:29-42` and `Common_SendMessage.sqf:28-42` both resolve structured `[stringtableKey, formatArgs]` payloads with `localize` + `format`; the old `call compile _messageText` route is documented as removed. Coordination brain also had an active lane-73 status claim at scout time. | Do not dual-claim lane 73. If the active status lane closes, verify current source first; the direct compile defect is not present on this target. |
| Lane 74, side-supply underflow | `Common_ChangeSideSupply.sqf:24` publishes the raw signed amount. `Server_ChangeSideSupply.sqf:39-40` applies `_currentSupply + _amount` and floors negative totals to `0`. | Skip the underflow/windfall bug. Broader side-supply requester/server-authority design remains separate work. |
| Lane 94/95/96/104, AICOM aircraft helper cluster | `Common_AICOM_HeliTerrainGuard.sqf:60-67,143` exists and `Headless/Init/Init_HC.sqf:251` spawns it. `AI_Commander_Teams.sqf:322-353,433` has Aircraft Factory heli waivers and air minimum handling; `AI_Commander_Teams.sqf:1071-1095` relocates air teams, including helis, to held airfields. `AI_Commander_Produce.sqf:49-83` mirrors producer-side air gates and caps. | Treat these prompt rows as stale unless a new, source-backed aircraft behavior bug is found. Avoid broad AICOM source churn while multiple AICOM PRs are open. |
| Lane 118, ghost defenders after base area changes hands | `Server_HandleDefense.sqf:17,25-34` stamps and checks `WFBE_DefenseBaseArea`, then exits the re-manning loop when that base area changes ownership. | Skip the "foreign base defense keeps remanning" fix. New defense cleanup work should start from fresh repro evidence. |
| Lane 121, supply mission player list slot overwrite | `Server/Module/supplyMission/playerObjectsList.sqf:17-28` initializes `_i = 0` before the `forEach` and increments inside the loop, fixing the old always-slot-zero overwrite. | Skip the list-index bug. |
| Lane 123, patrol switch `SV == 60` nil gap | `Server_GetTownPatrol.sqf:19` uses `case (_sv >= 60): {"HEAVY"}` with a `wiki-wins` comment. | Skip the `> 60` switch fall-through row. |
| Lane 127, player-count monitor cadence / HC count | `Server/MonitorPlayerCount.sqf:17-21` subtracts live headless clients from the `isPlayer` allUnits count, floored at zero. `Server/MonitorPlayerCount.sqf:27` sleeps `300` seconds between checks after the initial delay. | Skip the "HCs count as humans / hot loop" row. |
| Lane 128, MHQ cash-repair reset | `Server_MHQRepair.sqf:48` resets `cashrepaired` to `false` after HQ rebuild. | Skip the "cash repair permanently disabled after rebuild" row. |
| Lane 133, HC town delegation random picker | `Init_Server.sqf:147` registers `WFBE_CO_FNC_PickLeastLoadedHC`. `Server_DelegateAITownHeadless.sqf:22-51` calls it once, then locally round-robins across live HCs from the lightest seed. `Server_PickLeastLoadedHC.sqf:56-69` counts load and random-breaks equal minima. | Skip the random delegation rewrite. Any new performance work should be a measured optimization, not a duplicate behavior fix. |
| Lane 134, territorial victory loser-as-winner | `server_victory_threeway.sqf:168-198` carries `_winSide` through endgame dispatch, winner state, WASPSTAT `ROUNDEND`, and `LogGameEnd`. | The exact loser-as-winner defect is not live on this target. Victory UX/reporting improvements should be separate. |
| Lane 135, camp-count divide-by-zero | `server_town.sqf:212-216` recomputes total camps through `WFBE_CO_FNC_GetTotalCamps` and only divides when `_totalCamps > 0`. | Skip the exact division-crash row. Helper semantics may still deserve design review, but this source site is guarded. |
| Service worker repair/heal/boat rows | `Client_SupportRepair.sqf:52,85` scales ships and clears individual hitpoint damage. `Client_SupportHeal.sqf:52-53,79` scales ships/men and heals men directly. `Client_SupportRearm.sqf:61` and `Client_SupportRefuel.sqf:53` scale ships like light vehicles. | Do not reopen the low-level worker rows. Remaining service-point work is the GUI/action-time context gap recorded in `docs/design/SERVICE-POINTS-QA-2026-07-02.md`. |

## Still Valid Follow-Up Buckets

These stale-row closures do not mean the surrounding systems are complete:

- Server-authoritative economy/PV hardening remains broader design work beyond the side-supply underflow fix.
- GUI-owner lanes still own the fast-travel fee guard and service-point action-time context checks in `FAST-TRAVEL-QA-2026-07-02.md` and `SERVICE-POINTS-QA-2026-07-02.md`.
- AICOM aircraft behavior should be tested through open AICOM PRs and runtime evidence, not broad prompt-row reclamation.
- Wiki/prompt hygiene should prefer status updates and ranked backlog docs over duplicate source PRs when the current target already has the fix.

## Verification Notes

- Source read only; no SQF, SQM, HPP, EXT, or generated mission files were changed.
- LoadoutManager was not run because this is a docs-only audit.
- Open PR and shared-brain state were refreshed before claiming; re-check both before acting on any row later.
