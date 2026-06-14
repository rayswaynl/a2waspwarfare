# AI Commander Autonomy Audit

This page is the source-backed audit for AI commander automation and autonomous logistics. Use it before reviving AI commander production, AI supply trucks, autonomous supply helicopters, or any code that assumes the mission already has a complete self-driving commander.

Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Verdict

Current `origin/master` AI commander support is **partial, not absent**:

- Real side-level AI commander state exists.
- AI commander funds are initialized and can receive income.
- The AI commander upgrade worker is compiled and can debit funds/supply when called.
- The server buy worker for AI production is compiled.

But the source audit did **not** find a live owner loop/FSM that starts full autonomous commander behavior, calls the upgrade worker on a cadence, produces units through `AIBuyUnit`, or sets `wfbe_aicom_running = true`.

Human commander state is live: vote/reassignment, commander-side economy controls, HQ/MHQ affordances and income split all run through the normal Warfare flow. Full autonomous commander behavior is the partial/latent part.

Autonomous supply trucks are still not revived, but current `origin/master` is now safe-disabled: the old `UpdateSupplyTruck` compile remains commented and the worker still references missing `Server\FSM\supplytruck.fsm`, but current `cf2a6d6a` initializes `wfbe_ai_supplytrucks` and logs a warning instead of spawning the missing worker in both maintained roots. Miksuu/perf still keep the older raw-spawn trap; see the matrix below.

`origin/feat/ai-commander` is the current branch-only revival attempt. It changes the status of the branch, not stable `master`: the branch adds a server-side commander supervisor, assignment workers, production worker and explicit order executor, but it is source-Chernarus-only and needs dedicated/JIP/Vanilla smoke before the wiki can call AI commander revived.

Separate concept note: [Quad AI Commander concept](Quad-AI-Commander) indexes `origin/codex/quad-ai-commander` head `d4e0fa38`. It is a future log/intel/context-store design sketch, not stable source behavior and not proof that AI commander autonomy is implemented.

## Branch Refresh - `feat/ai-commander`

Snapshot refreshed: 2026-06-04. Branch head `c20ce153` compares against `origin/master` `2cdf5fb8`. Diff from stable master is 9 Chernarus-source files, +416/-5; no `Missions_Vanilla` files are touched. The later cleanup series after `4dba060e` changes only the five AI commander scripts, adding 141 lines and removing 91 lines to avoid lazy condition blocks.

| Branch piece | Evidence | Meaning |
| --- | --- | --- |
| Phase-0 safety and economics | `585c3519`; `Rsc/Parameters.hpp:92-96`; `Common/Init/Init_CommonConstants.sqf:98-105`; `Server/Functions/Server_AI_Com_Upgrade.sqf:27,47,50`; `Server/Init/Init_Server.sqf:387-389` | Makes AI commander default-on in the lobby, adds new cadence/cap constants, fixes the funds/supply debit swap, and guards the old `UpdateSupplyTruck` nil-code spawn. The missing `supplytruck.fsm` is still not restored. |
| Supervisor and workers | `1a3e3def`; `Server/Init/Init_Server.sqf:49-54,630-631`; `Server/AI/Commander/AI_Commander.sqf:29-81` | Compiles and spawns one per-side supervisor that self-gates on AI commander enablement and live HQ state. |
| Upgrade cost lookup fix | `4c2abced`; `Server/Functions/Server_AI_Com_Upgrade.sqf:27` | Corrects AI upgrade cost indexing from 1-based order level to 0-based cost array index. |
| Hybrid co-op command | `4dba060e`; refreshed at `c20ce153`; `AI_Commander.sqf:42-78`; `AI_Commander_Execute.sqf:16-48`; `AI_Commander_AssignTowns.sqf:23-54,62-99` | Full mode runs economy only when no human commander exists; assist mode still executes explicit Move/Patrol/Defend orders and can auto-assign delegated AI teams while a human commander is present. |
| AI team production | `c20ce153`; `AI_Commander_Produce.sqf:18-21,77-90`; `Server/Init/Init_Server.sqf:10` | Produces under-strength AI teams through `AIBuyUnit` while respecting a per-side AI cap and AI commander funds. Review this alongside factory queue/token cleanup before merge. |
| Lazy-condition cleanup series | `b4b0333f`, `27d25a28`, `dbaf9150`, `4626c036`, `c20ce153`; files under `Server/AI/Commander/AI_Commander*.sqf` | Rewrites supervisor, town assignment, order executor, type assignment and production-worker condition paths into stepwise guards. This improves branch static/syntax readiness, but it does not change branch-only status, Vanilla propagation or smoke requirements. |

2026-06-04 branch scout clarification: the branch supervisor keeps running in assist mode with a human commander, but `wfbe_aicom_running` is deliberately used as the **full-command latch**, not a simple "commander brain exists" marker. `AI_Commander.sqf:43-49` sets it false while a human commander exists even though the executor/assist loop continues. Stable master still only initializes/clears this flag (`Init_Server.sqf:364-365`, `Server_VoteForCommander.sqf:54-57`, `Server_AssignNewCommander.sqf:11-14`) and has no source-proven supervisor.

Branch-only review risks:

- The branch changes gameplay defaults by setting `WFBE_C_AI_COMMANDER_ENABLED` default to `1` in `Rsc/Parameters.hpp:96`.
- It is source-Chernarus-only until LoadoutManager/Vanilla propagation is performed and reviewed.
- It revives AI commander production/order execution, but **does not** revive the old autonomous supply-truck FSM path; `UpdateSupplyTruck` remains commented and only guarded.
- It adds always-running per-side supervisors after `VoteForCommander` startup; smoke must prove exactly one supervisor per side, no duplicate loops after commander vote/revote and clean stop behavior after HQ death.
- The production worker uses `AIBuyUnit`; smoke must include AI team queue cleanup, insufficient funds, destroyed factory, full AI cap, vehicle/man production and human takeover of a team.
- Team-order setters remain state replication, not the scheduler by themselves. On the branch, `AI_Commander_Execute.sqf:19-32` is the explicit-order waypoint owner and uses `wfbe_exec_sig` idempotency; `AI_Commander_AssignTowns.sqf:38-48,65-78` separately retargets no-human or delegated/autonomous AI teams toward uncaptured towns.

### AI Upgrade Debit Branch Matrix

Checked 2026-06-14 against docs checkout `d4cfef80`, stable `origin/master` `cf2a6d6a`, Miksuu `b8389e74`, `origin/perf/quick-wins` `0076040f`, release `origin/release/2026-06-feature-bundle` `a96fdda2` and `origin/feat/upgrade-queue-stacking` `b061c905` in maintained Chernarus and Vanilla roots. The docs-checkout upgrade files are unchanged from the earlier `e785f1e9` upgrade-atlas anchor. The player upgrade menu treats upgrade cost tuples as `[supply, funds]`: docs checkout Chernarus reads supply/funds at `Client/GUI/GUI_UpgradeMenu.sqf:96-97` and debits client funds/side supply at `:158-159`; stable and upgrade-queue line drift is `:233-234,252-253`; release line drift is `:219,238-239`; Miksuu/perf line drift is `:206,226`. The AI worker validates with the same convention at `Server_AI_Com_Upgrade.sqf:34-36`.

| Branch / root | Evidence | Status |
| --- | --- | --- |
| Docs checkout `d4cfef80` Chernarus and maintained Vanilla | Both roots read `_cost` with raw `(_to_upgrade select 1)` at `Server_AI_Com_Upgrade.sqf:27`, validate side supply against `_cost select 0` and AI funds against `_cost select 1` at `:34-36`, then debit AI funds with `_cost select 0` and side supply with `_cost select 1` at `:47,50`. | Patch-ready in the docs/source checkout. AI upgrade revival should align debit order and review whether the AI_ORDER level should be converted to a zero-based cost index before enabling a scheduler. |
| Stable `origin/master` `cf2a6d6a` | Both maintained roots still use raw `(_to_upgrade select 1)` for `_cost` at `:27`, but debit AI funds with `_cost select 1` and side supply with `_cost select 0` at `:47,50`. | Stable carries the debit-order fix in both maintained roots, but does not include the branch-only cost-index fix. AI upgrade smoke remains required. |
| Miksuu `b8389e74` and `origin/perf/quick-wins` `0076040f` | Same maintained-root shape as the docs checkout: raw cost lookup at `:27`, validation at `:34-36`, swapped funds/supply debit at `:47,50`. | No upstream/perf rescue for the AI debit route. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` | Both maintained release roots still use raw `(_to_upgrade select 1)` for `_cost` at `:27`, but debit AI funds with `_cost select 1` and side supply with `_cost select 0` at `:47,50`. | Release matches stable for the debit-order fix in both maintained roots, but does not include the branch-only cost-index fix. AI upgrade smoke remains required. |
| `origin/feat/upgrade-queue-stacking` `b061c905` | Both maintained branch roots match stable/release for the AI worker: raw cost lookup remains at `:27`, while debit order uses AI funds `_cost select 1` and side supply `_cost select 0` at `:47,50`. | Queue UI work does not settle the AI-order cost-index question. Keep AI upgrade smoke separate from queue UI smoke. |
| `origin/feat/ai-commander` `c20ce153` | 2026-06-06 evidence: Chernarus subtracts one from the AI_ORDER level when reading `_cost` at `:27`, then debits funds with `_cost select 1` and supply with `_cost select 0` at `:47,50`. Maintained Vanilla on the same branch keeps the old raw lookup and swapped debit at `:27,47,50`. | Branch-only Chernarus fix. Do not call the feature branch Vanilla-propagated or release-ready until the maintained target is generated/reviewed and AI upgrade smoke proves cost lookup/debit behavior. |

Patch direction: for docs checkout, Miksuu and perf targets, port or recreate the stable/release debit-order fix first. For stable/release, decide whether to take the `feat/ai-commander` cost-index correction only after checking `WFBE_C_UPGRADES_*_AI_ORDER` levels against every side's cost arrays. Keep this separate from the larger autonomous-commander supervisor/production revival.

## What Exists

| Area | Source evidence | Meaning |
| --- | --- | --- |
| Mission parameter | `Rsc/Parameters.hpp:99-104` exposes `WFBE_C_AI_COMMANDER_ENABLED` with default `0`. | In the mission parameter UI, AI commander appears disabled by default. |
| Fallback constant | `Common/Init/Init_CommonConstants.sqf:91` sets `WFBE_C_AI_COMMANDER_ENABLED = 1` only if the variable is nil. | If the MP parameter path does not provide the variable, the fallback enables it. Do not confuse this with the parameter default. |
| Move interval constant | `Common/Init/Init_CommonConstants.sqf:96` defines `WFBE_C_AI_COMMANDER_MOVE_INTERVALS = 3600`. | A legacy cadence constant exists, but no source-read scheduler was found using it. |
| Supply truck max constant | `Common/Init/Init_CommonConstants.sqf:97` defines `WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX = 5`. | Old logistics sizing remains. |
| Side state | `Server/Init/Init_Server.sqf:364-365` initializes `wfbe_aicom_running = false` and `wfbe_aicom_funds`. | Side logic can hold AI commander runtime state. |
| Human commander stop hooks | `Server_VoteForCommander.sqf:48-57`, `Server_AssignNewCommander.sqf:11-14` clear `wfbe_aicom_running` when a player commander exists. | Player commander assignment is live and suppresses any future AI commander loop, but these hooks still do not prove an AI start path. |
| AI commander income | `Server/FSM/updateresources.sqf:67` adds income to AI commander funds when no player commander exists and AI commander is enabled. | AI commander money can grow without a player commander. |
| Upgrade worker compile | `Server/Init/Init_Server.sqf:48` compiles `WFBE_SE_FNC_AI_Com_Upgrade`. | The worker is available after server init. |
| Upgrade order data | `Common/Config/Core_Upgrades/Upgrades_*.sqf` define `WFBE_C_UPGRADES_%SIDE_AI_ORDER`; `Check_Upgrades.sqf:7-40` fills missing enabled upgrade levels. | AI upgrade preference data exists. |
| Upgrade worker behavior | `Server/Functions/Server_AI_Com_Upgrade.sqf:12-50` reads `WFBE_C_UPGRADES_%SIDE_AI_ORDER`, selects the first upgrade whose current level is below the target level, checks funds/supply and calls `WFBE_SE_FNC_ProcessUpgrade`. | The worker is real and deterministic, but needs a caller/owner cadence. It is upgrade-only, not base building, defense, factory or unit-buy AI. |
| Upgrade processing callee | `Server/Functions/Server_ProcessUpgrade.sqf:10-47,49-83` owns timing/state progression and artillery refresh side effects. | It does not create bases, defenses, factories or units; do not infer production behavior from the AI upgrade path. |
| AI buy worker compile | `Server/Init/Init_Server.sqf:10` compiles `AIBuyUnit = Server_BuyUnit.sqf`. | Server-side AI production helper exists. |
| AI buy worker behavior | `Server/Functions/Server_BuyUnit.sqf:1-180` queues, waits and creates units/vehicles for an AI team. | Useful if a future AI commander production loop intentionally calls it. |
| Stop hooks | `Server_VoteForCommander.sqf:54-57` and `Server_AssignNewCommander.sqf:11-14` clear `wfbe_aicom_running` when a player commander exists. | Stop/reset hooks exist, but they do not prove a start loop exists. |

## What Was Not Proven Live

| Missing/uncertain owner | Evidence | Development implication |
| --- | --- | --- |
| AI commander start loop | Source search found `wfbe_aicom_running` initialized and cleared, but not set to `true`. | Do not claim autonomous commander brain is live until a dynamic/runtime caller is proven. |
| AI commander upgrade scheduler | Source search found the worker compile and function body, but no static caller for `WFBE_SE_FNC_AI_Com_Upgrade` outside docs. `Init_Server.sqf:622` starts `WFBE_SE_FNC_VoteForCommander`, not the AI upgrade worker. | Reviving upgrades needs an explicit server-owned cadence and stop conditions. |
| AI unit production scheduler | `AIBuyUnit` is compiled, but source search found no static caller outside `Server_BuyUnit.sqf` itself. | AI commander unit production needs an intentional design, not just a docs claim. |
| AI commander movement scheduler | `WFBE_C_AI_COMMANDER_MOVE_INTERVALS` exists, but no audited source path uses it to move/command teams. | Treat movement autonomy as missing until a source owner is found or implemented. |

## Stable Master Order Plumbing

Mini-scout follow-up 2026-06-04 separated live order plumbing from missing autonomy:

- `Client/GUI/GUI_Menu_Command.sqf:19,270,298,305,428` exposes the human commander order surface and writes replicated team state.
- `Common_SetTeamMoveMode.sqf:8` and `Common_SetTeamMovePos.sqf:8` set `wfbe_teammode` / `wfbe_teamgoto`; they store intent, they do not execute missions by themselves.
- Waypoint execution lives in helpers such as `Server/AI/Orders/AI_MoveTo.sqf:13-17`, `AI_Patrol.sqf:14`, `AI_TownPatrol.sqf:23` and `Common_WaypointsAdd.sqf:18`.
- `Server_UpdateTeam.sqf:5` is shallow behavior randomization, not a full order scheduler.

The safe wording is therefore: stable master has usable order primitives and a human command UI, but no source-proven autonomous commander loop that schedules those primitives for the side.

Another dormant-looking primitive is `WFBE_SE_FNC_AI_SetTownAttackPath`. `Init_Server.sqf:45-47` compiles the attack-path helper and its safety helpers, but the current stable-master static scan found no live caller outside compile/docs. The helper itself removes existing team waypoints near the start (`Server_AI_SetTownAttackPath.sqf:18`) before attempting the longer arced path branch and later depot/camp waypoints (`:41,80-109`). If a future AI commander branch wires this function back into town orders, smoke the random and unsafe-path branches so a failed route attempt does not silently leave the team without useful waypoints.

Final mini-scout follow-up 2026-06-04 found one partial automation nuance worth preserving: newly spawned units can inherit an existing client-side map/waypoint destination. `Client_SendSpawnedUnitsToLeaderWaypoint.sqf:24-35,73-92` reads the last team-leader map order or current waypoint/expected destination and issues `commandMove` to spawned units; `Client_SetAttackWaveDetails.sqf:24-35,73-92` has the same shape for attack-wave units. This is order inheritance at spawn time, not a general server-side commander scheduler, and it depends on client-side stored map-order state such as `WFBE_CLIENT_LAST_TEAMLEADER_MAP_ORDER_*`.

Depth scout follow-up 2026-06-04 sharpened the meaning of the `wfbe_autonomous` group variable. `Common/Functions/Common_SetTeamAutonomous.sqf:8` only replicates the flag; the visible consumers found in source are commander-loss cleanup (`Client/FSM/updateclient.sqf:191-205`), the command-menu toggle (`Client/GUI/GUI_Menu_Command.sqf:364-389`) and AI respawn reset logic (`Server/AI/AI_SquadRespawn.sqf:102-109`, `Server/AI/AI_AdvancedRespawn.sqf:117-125`). In other words, "autonomous" means "do not reset this team's stored movement order on respawn" more than "run a live independent AI commander brain." Keep that distinction when designing AI commander revival or role-balance changes.

The same pass found two order-helper caveats:

- Behavior/formation knobs can be rewritten by movement helpers. `AI_MoveTo.sqf:6-17` and `AI_Patrol.sqf:7-18` set combat/behavior/formation/speed, then may call `UpdateTeam`; `AI_TownPatrol.sqf:26-30` randomizes the same properties directly before waypoints. Do not assume command-menu combo values are preserved after every server order helper runs.
- `Server/Functions/Server_UpdateTeam.sqf:4-8` chooses a formation using `round(random(count _formations -1))`. If uniform selection is intended, this is a small correctness bug candidate because edge entries get different probability than a `floor(random count _formations)` picker.

Resistance AI should stay split from main-side commander teams. `Server/AI/AI_Resistance.sqf:7-16` goes straight to `BIS_fnc_taskPatrol`, `AIWPAdd` or `AIPatrol`; west/east order helpers gate through `CanUpdateTeam` and `UpdateTeam` first. Document resistance behavior as town/occupation AI, not as proof that west/east commander-team autonomy is live.

## Broken AI Supply Truck Path

The old AI logistics path is config-gated latent breakage:

1. `Server/Init/Init_Server.sqf:37` comments out `UpdateSupplyTruck = Compile preprocessFile "Server\AI\AI_UpdateSupplyTruck.sqf";`.
2. The truck-supply + AI-commander branch still exists, but current `origin/master` `cf2a6d6a` does not spawn `UpdateSupplyTruck` there; both maintained roots initialize `wfbe_ai_supplytrucks` and log that legacy AI supply-truck logistics are disabled at `Init_Server.sqf:382-384`.
3. `Server/AI/AI_UpdateSupplyTruck.sqf:17` still calls `ExecFSM "Server\FSM\supplytruck.fsm"`.
4. `Server/FSM/` contains no `supplytruck.fsm`; the server FSM folder has `.sqf` loop scripts such as `server_town.sqf`, `updateresources.sqf` and `server_victory_threeway.sqf`.

Default posture nuance:

- `Common/Init/Init_CommonConstants.sqf:165` falls back to `WFBE_C_ECONOMY_SUPPLY_SYSTEM = 1`, automatic timed supply.
- `Rsc/Parameters.hpp:99+` gives the AI commander mission parameter default as `0`.
- Therefore the branch is normally avoided by mission parameters/fallbacks, but it is still a live config trap if an admin enables truck supply and AI commander behavior.

### AI Supply-Truck Branch Matrix

Branch route `ai-supply-truck-current-master-safe-disable-route` rechecked the maintained roots on 2026-06-13 after `origin/master` advanced to `cf2a6d6a`, Miksuu upstream to `b8389e74` and release to `a96fdda2`:

| Branch / root | Evidence | Status |
| --- | --- | --- |
| Current source Chernarus and maintained Vanilla, `origin/master` / local `master` `cf2a6d6a` | Both maintained roots still comment out `UpdateSupplyTruck` at `Server/Init/Init_Server.sqf:37`, then initialize `wfbe_ai_supplytrucks` and log-disable legacy AI supply-truck logistics at `:383-384` when truck supply and AI commanders are enabled. `Server/AI/AI_UpdateSupplyTruck.sqf:17` still references missing `Server\FSM\supplytruck.fsm`, but current master does not call it from this branch. | Safety shape is present in current master; autonomous logistics remain disabled/not revived. |
| Miksuu upstream `b8389e74` and `origin/perf/quick-wins` `0076040f` | Miksuu keeps the older raw spawn in both maintained roots at `Init_Server.sqf:382-383`. Perf also raw-spawns, with Chernarus at `:377-378` and Vanilla at `:382-383`. Both refs still have `AI_UpdateSupplyTruck.sqf:17` pointing at missing `Server\FSM\supplytruck.fsm`; no checked branch restores the FSM. | Branch-specific raw-spawn trap remains open outside current/release. |
| Historical stable `origin/master` `2cdf5fb8` / `89ae9dad` | Historical stable had the compile-comment plus gated raw-spawn shape before current master picked up the safe-disable. | Historical baseline only; do not use it as current-master evidence. |
| Release `origin/release/2026-06-feature-bundle` `a96fdda2` | Chernarus and maintained Vanilla match current master: compile commented at `Init_Server.sqf:37`, `wfbe_ai_supplytrucks` initialized and warning logged at `:383-384`, old worker still references missing `supplytruck.fsm` at `AI_UpdateSupplyTruck.sqf:17`. | Release and current master share the minimal safe-disable; neither revives autonomous logistics. |
| `origin/feat/ai-commander` `c20ce153` | Chernarus guards the spawn with `if (!isNil "UpdateSupplyTruck") then {[_side] Spawn UpdateSupplyTruck}` at `Init_Server.sqf:388-389`, but the compile remains commented and `supplytruck.fsm` remains absent. Maintained Vanilla on the same branch still has the raw `[_side] Spawn UpdateSupplyTruck` at `Init_Server.sqf:382-383`. | Branch-only partial guard. Do not treat the AI commander feature branch as a supply-truck revival or Vanilla propagation. |

Patch direction: current master already has the safety-only warning/disable shape in both maintained roots. Keep that shape when merging or rebasing branches, and only reopen the worker if a code owner designs or restores a verified server-owned supply-truck loop/FSM. Keep this separate from player-run supply helicopter work.

## Authority-Adjacent Commander Controls

Some commander-facing systems are live but still client-led. Keep them out of the autonomy revival lane unless the owner intentionally bundles server-authority work.

| Control | Evidence | Why it matters |
| --- | --- | --- |
| Commander income percent | `Client/GUI/GUI_Menu_Economy.sqf:24-27,74-79`; `Server/FSM/updateresources.sqf:36-43` | Client UI writes the commander percent that the server resource loop consumes. It needs sender/commander validation in the economy authority lane. |
| Upgrade requests | `Client/GUI/GUI_UpgradeMenu.sqf:137-171`; `Server/PVFunctions/RequestUpgrade.sqf:1-5`; `Server/Functions/Server_ProcessUpgrade.sqf:12-21` | The server owns the timer/state transition, but the live request still trusts client-side funds/dependency/level checks. |
| Commander team orders | `GUI_Menu_Command.sqf:252-306,425-428`; `Common_SetTeamMoveMode.sqf:8`; `Common_SetTeamMovePos.sqf:8`; `RequestTeamUpdate.sqf:3-25` | Team property updates have a real server PVF. Map-order variables are replicated group state, but no general executor was proven that turns `wfbe_teammode` / `wfbe_teamgoto` into waypoints. Do not treat this as an AI commander movement scheduler. |
| AI commander upgrade worker | `GUI_UpgradeMenu.sqf:163-164,206-226`; `Server_AI_Com_Upgrade.sqf:27,34-50`; [AI upgrade debit branch matrix](#ai-upgrade-debit-branch-matrix) | Docs checkout `d4cfef80` validates `[supply, funds]` costs like the player UI but deducts them swapped, taking supply cost from AI funds and funds cost from side supply. Stable/release fix debit order in both maintained roots; `feat/ai-commander` also fixes the cost-level lookup only in Chernarus. Fix/verify this before enabling a scheduler. |
| MHQ repair | `Client/Action/Action_RepairMHQ.sqf:5-35`; `Server/PVFunctions/RequestMHQRepair.sqf:1`; `Server/Functions/Server_MHQRepair.sqf:1-35` | Repair is client-debited and side-only when it reaches the server. |
| Commander specials and selling | `Client/GUI/GUI_Menu_Tactical.sqf:363-373,463-527`; `Client/GUI/GUI_Menu_Economy.sqf:104-150`; `Server/Functions/Server_HandleSpecial.sqf:55-64` | Paratroops, paradrops, UAV/ICBM paths, RespawnST and structure sale/refund all need role/side/funds/effect validation before public-server confidence. |

## Safe Revival Plan

### Minimal Safety Patch

Current master already follows this shape; use it as the baseline if a branch still has the raw spawn or if the owner does not want to revive autonomy yet:

1. Keep `UpdateSupplyTruck` disabled.
2. Initialize `wfbe_ai_supplytrucks` for compatibility, but do not spawn the missing worker.
3. Log one `WFBE_CO_FNC_LogContent` warning if truck supply + AI commanders is requested while legacy logistics are unavailable.
4. Update `agent-release-readiness.json` only if this becomes a source patch and generated propagation/smoke are pending.

Minimum smoke:

- Default mission parameters boot without AI logistics errors.
- Truck-supply + AI-commander config does not throw nil-code errors.
- No supply trucks are created unless the owner intentionally restores the worker.

### Full Revival

Use this only if autonomous commander/logistics is a real feature goal:

1. Define the owner model: one server loop per side, not client-side command behavior.
2. Decide whether `wfbe_aicom_running` is the lifecycle flag or replace it with clearer side-logic state.
3. Add a server-owned scheduler that:
   - starts only when no player commander owns the side;
   - calls `WFBE_SE_FNC_AI_Com_Upgrade` on a safe cadence;
   - calls production logic intentionally rather than relying on hidden dynamic calls;
   - stops cleanly when a player commander is assigned.
4. Either restore a verified supply-truck FSM or replace the old truck logic with a new SQF loop.
5. Keep PR #1 player-run supply helicopters separate until the owner explicitly designs autonomous heli behavior.
6. Define cleanup on HQ death, side elimination, vehicle death, commander assignment, AI commander disable and HC disconnect.

Minimum smoke:

- AI commander enabled with no player commander starts the server-owned AI loop exactly once per side.
- Assigning a player commander stops the loop for that side.
- AI upgrades advance only when funds/supply are sufficient and do not double-debit.
- AI production queues units through a known owner path and stops if a player takes the team.
- AI supply trucks or helicopters respect max counts, cleanup dead vehicles and do not depend on missing files.

## Do Not Do This

- Do not just uncomment `UpdateSupplyTruck`; it still calls a missing FSM.
- Do not build autonomous supply helicopters on top of `AI_UpdateSupplyTruck.sqf` without redesign.
- Do not describe `Server_BuyUnit.sqf` / `AIBuyUnit` as live AI commander production until a caller is proven or added.
- Do not treat the constants fallback as proof that the mission parameter default enables AI commanders.
- Do not mix the commander reassignment call-shape fix into autonomy revival without its own smoke; that bug has a separate playbook.

## Related Pages

- [AI, headless and performance](AI-Headless-And-Performance)
- [Server gameplay runtime atlas](Server-Gameplay-Runtime-Atlas)
- [Abandoned feature revival](Abandoned-Feature-Revival-Review)
- [Commander reassignment call shape](Commander-Reassignment-Call-Shape)
- [Current supply helicopter PR](Current-Work-Supply-Helicopters-PR1)
- [Factory and purchase systems atlas](Factory-And-Purchase-Systems-Atlas)

## Continue Reading

Previous: [AI, headless and performance](AI-Headless-And-Performance) | Next: [Headless delegation/failover](Headless-Delegation-And-Failover-Playbook)

Main map: [Home](Home) | Fast path: [Feature status](Feature-Status-Register) | Agent file: [`agent-context.json`](agent-context.json)
