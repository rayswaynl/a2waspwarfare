# Recycle Backlog Status - 2026-07-02

Lane: 50, recycle-backlog execution/status
Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3`
Scope: WF-menu QoL / recycle-dead-features backlog rows from the 2026-06-03 run, checked against the current target checkout. This pass is docs-only because the two safe recycle mechanics are already present, while the remaining rows are stale, branch-only, or need owner design before source revival.

## Summary

The current target already carries the two actionable AI recycle mechanisms:

- AI commander structure recycle/BaseSell is compiled, configured, and armed for the current branch.
- Failed-journey/zombie team recycle is implemented through a latched `wfbe_aicom_recycle` flag and a player-safe disband request.

The abandoned-feature rows should not be blindly re-enabled. Autonomous AI supply trucks still depend on a missing `Server\FSM\supplytruck.fsm` and are explicitly safe-disabled. MASH deploy/marker relay and the old town `TaskSystem` are removed or commented residue in the maintained Chernarus root. The wiki-recorded WF-menu ops-console branch is not present as current source payload in this checkout or as a current remote head under that historical branch name.

## Backlog Verdicts

| Row | Current target verdict | Evidence | Action |
| --- | --- | --- | --- |
| AI commander redundant structure recycle/BaseSell | Implemented in current target. The worker is compiled and gated by constants, with `WFBE_C_AICOM_BASE_SELL_ENABLE = 1`, a 120 second interval, stranded-old-base preference, refund fraction, and redundant-type threshold. | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:582-590`; `Server/Init/Init_Server.sqf:39-40`; `Server/AI/Commander/AI_Commander_BaseSell.sqf:12-18,25-27,39-48,64-83,85-97`. | No lane-50 source change. Runtime release proof should watch `BASE_SELL`, refund, live-count decrement, protected HQ/CommandCenter skip, and no sale during relocation. |
| Failed-journey/zombie team recycle | Implemented in current target. Failed journeys latch `wfbe_aicom_recycle`; the producer consumes it only outside combat and with no player within 500 m, then requests the existing disband path without the command bypass. | `Common/Init/Init_CommonConstants.sqf:856`; `Server/AI/Commander/AI_Commander_AssignTowns.sqf:160-171,343-351,433-440,455-462,519-525`; `Server/AI/Commander/AI_Commander_Produce.sqf:109-124`. | No lane-50 source change. Runtime release proof should watch `RECYCLE_FLAG`, `TEAM_RECYCLE requested`, player-proximity vetoes, and replacement founding behavior. |
| Autonomous AI supply trucks | Not revived. The legacy worker still references a missing FSM, while server init initializes `wfbe_ai_supplytrucks` and logs that the old logistics path is disabled. | `Server/Init/Init_Server.sqf:50,729-731`; `Server/AI/AI_UpdateSupplyTruck.sqf:11-17`; no tracked `Server/FSM/supplytruck.fsm`; wiki `Abandoned-Feature-Revival-Review.md:11,93-122`; wiki `Feature-Status-Register.md:150,265`. | Keep disabled. A real feature needs a server-owned logistics loop or verified FSM, cleanup/accounting design, and dedicated smoke. Do not uncomment the worker. |
| MASH deploy / marker relay | Removed from the current maintained Chernarus root, with only residues. Officer skill explicitly says MASH deploy was removed; maintained-root `Client/Module/MASH` and `Server/Module/MASH` paths are absent. | `Client/Module/Skill/Skill_Apply.sqf:43-46`; no tracked `Client/Module/MASH` or `Server/Module/MASH`; wiki `Abandoned-Feature-Revival-Review.md:9,23-59`; wiki `Feature-Status-Register.md:144-155`. | Owner decision. Revive only with server-held marker records, unique IDs, delete cleanup, side filtering, and JIP resend. Otherwise clean/annotate residues deliberately. |
| Old town TaskSystem | Dormant residue, not a live task feature. The compile and town hooks are commented, and `Client/Functions/Client_TaskSystem.sqf` is absent in this checkout. Commander Objective Ping is a separate path and should not be counted as this old town loop. | `Client/Init/Init_Client.sqf:156,1307-1308`; `Client/PVFunctions/TownCaptured.sqf:38-39,86-89`; no tracked `Client/Functions/Client_TaskSystem.sqf`; wiki `Abandoned-Feature-Revival-Review.md:12`; wiki `Feature-Status-Register.md:154,179`. | Leave deferred. If rebuilt, treat it as a new JIP-safe task UX feature with spam/notification smoke; otherwise remove or annotate the stale comments in a small cleanup lane. |
| WF-menu ops-console/QoL reskin | Wiki-recorded branch-only UI/theme work, not current target source. The historical plan file is absent here and current remote lookup did not expose `feat/wf-menu-ops-console`; only unrelated current menu work is open. | no tracked `docs/superpowers/plans/2026-06-03-wf-menu-ops-console.md`; wiki `Feature-Status-Register.md:123`; wiki `agent-release-readiness.json:1251-1273`; current `git ls-remote --heads origin feat/wf-menu-ops-console` returned no head. | Do not implement in lane 50. If recovered, handle as a separate UI branch review with Arma 2 OA visual smoke, path/case checks, Chernarus parity, and coordination with active `GUI_Menu*.sqf` lanes. |

## Notes For Follow-Up

- This checkout exposes only `Missions/[55-2hc]warfarev2_073v48co.chernarus`; no Takistan mission root is present to mirror for a docs-only lane.
- No mission source, dialogs, SQF, SQM, HPP, parameters, or generated package output is changed by this report.
- The only safe near-term source cleanup candidates are comment/residue annotations for old `TaskSystem` or MASH, but those should be separate low-risk lanes because they touch client init/PV surfaces.
- Runtime release wording for BaseSell and team recycle still needs live Arma smoke. This report only establishes current source status and backlog routing.
