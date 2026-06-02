# AI Commander Autonomy Audit

This page is the source-backed audit for AI commander automation and autonomous logistics. Use it before reviving AI commander production, AI supply trucks, autonomous supply helicopters, or any code that assumes the mission already has a complete self-driving commander.

Paths are relative to `Missions/[55-2hc]warfarev2_073v48co.chernarus/`.

## Verdict

AI commander support is **partial, not absent**:

- Real side-level AI commander state exists.
- AI commander funds are initialized and can receive income.
- The AI commander upgrade worker is compiled and can debit funds/supply when called.
- The server buy worker for AI production is compiled.

But the source audit did **not** find a live owner loop/FSM that starts full autonomous commander behavior, calls the upgrade worker on a cadence, produces units through `AIBuyUnit`, or sets `wfbe_aicom_running = true`.

Human commander state is live: vote/reassignment, commander-side economy controls, HQ/MHQ affordances and income split all run through the normal Warfare flow. Full autonomous commander behavior is the partial/latent part.

Autonomous supply trucks are worse than partial: the old `UpdateSupplyTruck` compile is commented, the gated spawn remains, and the referenced `Server\FSM\supplytruck.fsm` file is absent.

## What Exists

| Area | Source evidence | Meaning |
| --- | --- | --- |
| Mission parameter | `Rsc/Parameters.hpp:92-97` exposes `WFBE_C_AI_COMMANDER_ENABLED` with default `0`. | In the mission parameter UI, AI commander appears disabled by default. |
| Fallback constant | `Common/Init/Init_CommonConstants.sqf:91` sets `WFBE_C_AI_COMMANDER_ENABLED = 1` only if the variable is nil. | If the MP parameter path does not provide the variable, the fallback enables it. Do not confuse this with the parameter default. |
| Move interval constant | `Common/Init/Init_CommonConstants.sqf:96` defines `WFBE_C_AI_COMMANDER_MOVE_INTERVALS = 3600`. | A legacy cadence constant exists, but no source-read scheduler was found using it. |
| Supply truck max constant | `Common/Init/Init_CommonConstants.sqf:97` defines `WFBE_C_AI_COMMANDER_SUPPLY_TRUCKS_MAX = 5`. | Old logistics sizing remains. |
| Side state | `Server/Init/Init_Server.sqf:364-365` initializes `wfbe_aicom_running = false` and `wfbe_aicom_funds`. | Side logic can hold AI commander runtime state. |
| Human commander stop hooks | `Server_VoteForCommander.sqf:48-57`, `Server_AssignNewCommander.sqf:11-14` clear `wfbe_aicom_running` when a player commander exists. | Player commander assignment is live and suppresses any future AI commander loop, but these hooks still do not prove an AI start path. |
| AI commander income | `Server/FSM/updateresources.sqf:67` adds income to AI commander funds when no player commander exists and AI commander is enabled. | AI commander money can grow without a player commander. |
| Upgrade worker compile | `Server/Init/Init_Server.sqf:48` compiles `WFBE_SE_FNC_AI_Com_Upgrade`. | The worker is available after server init. |
| Upgrade order data | `Common/Config/Core_Upgrades/Upgrades_*.sqf` define `WFBE_C_UPGRADES_%SIDE_AI_ORDER`; `Check_Upgrades.sqf:7-40` fills missing enabled upgrade levels. | AI upgrade preference data exists. |
| Upgrade worker behavior | `Server/Functions/Server_AI_Com_Upgrade.sqf:12-50` selects the next upgrade, checks funds/supply and calls `WFBE_SE_FNC_ProcessUpgrade`. | The worker is real, but needs a caller/owner cadence. |
| AI buy worker compile | `Server/Init/Init_Server.sqf:10` compiles `AIBuyUnit = Server_BuyUnit.sqf`. | Server-side AI production helper exists. |
| AI buy worker behavior | `Server/Functions/Server_BuyUnit.sqf:1-180` queues, waits and creates units/vehicles for an AI team. | Useful if a future AI commander production loop intentionally calls it. |
| Stop hooks | `Server_VoteForCommander.sqf:54-57` and `Server_AssignNewCommander.sqf:11-14` clear `wfbe_aicom_running` when a player commander exists. | Stop/reset hooks exist, but they do not prove a start loop exists. |

## What Was Not Proven Live

| Missing/uncertain owner | Evidence | Development implication |
| --- | --- | --- |
| AI commander start loop | Source search found `wfbe_aicom_running` initialized and cleared, but not set to `true`. | Do not claim autonomous commander brain is live until a dynamic/runtime caller is proven. |
| AI commander upgrade scheduler | Source search found the worker compile and function body, but no static caller for `WFBE_SE_FNC_AI_Com_Upgrade` outside docs. | Reviving upgrades needs an explicit server-owned cadence and stop conditions. |
| AI unit production scheduler | `AIBuyUnit` is compiled, but source search found no static caller outside `Server_BuyUnit.sqf` itself. | AI commander unit production needs an intentional design, not just a docs claim. |
| AI commander movement scheduler | `WFBE_C_AI_COMMANDER_MOVE_INTERVALS` exists, but no audited source path uses it to move/command teams. | Treat movement autonomy as missing until a source owner is found or implemented. |

## Broken AI Supply Truck Path

The old AI logistics path is config-gated latent breakage:

1. `Server/Init/Init_Server.sqf:36` comments out `UpdateSupplyTruck = Compile preprocessFile "Server\AI\AI_UpdateSupplyTruck.sqf";`.
2. `Server/Init/Init_Server.sqf:381-383` still spawns `UpdateSupplyTruck` when `WFBE_C_ECONOMY_SUPPLY_SYSTEM == 0` and `WFBE_C_AI_COMMANDER_ENABLED > 0`.
3. `Server/AI/AI_UpdateSupplyTruck.sqf:17` calls `ExecFSM "Server\FSM\supplytruck.fsm"`.
4. `Server/FSM/` contains no `supplytruck.fsm`; the server FSM folder has `.sqf` loop scripts such as `server_town.sqf`, `updateresources.sqf` and `server_victory_threeway.sqf`.

Default posture nuance:

- `Common/Init/Init_CommonConstants.sqf:161` falls back to `WFBE_C_ECONOMY_SUPPLY_SYSTEM = 1`, automatic timed supply.
- `Rsc/Parameters.hpp:92-97` gives the AI commander mission parameter default as `0`.
- Therefore the branch is normally avoided by mission parameters/fallbacks, but it is still a live config trap if an admin enables truck supply and AI commander behavior.

## Authority-Adjacent Commander Controls

Some commander-facing systems are live but still client-led. Keep them out of the autonomy revival lane unless the owner intentionally bundles server-authority work.

| Control | Evidence | Why it matters |
| --- | --- | --- |
| Commander income percent | `Client/GUI/GUI_Menu_Economy.sqf:24-27,74-79`; `Server/FSM/updateresources.sqf:36-43` | Client UI writes the commander percent that the server resource loop consumes. It needs sender/commander validation in the economy authority lane. |
| Upgrade requests | `Client/GUI/GUI_UpgradeMenu.sqf:137-171`; `Server/PVFunctions/RequestUpgrade.sqf:1-5`; `Server/Functions/Server_ProcessUpgrade.sqf:12-21` | The server owns the timer/state transition, but the live request still trusts client-side funds/dependency/level checks. |
| AI commander upgrade worker | `GUI_UpgradeMenu.sqf:139-159`; `Server_AI_Com_Upgrade.sqf:34-50` | The AI worker validates `[supply, funds]` costs like the player UI but appears to deduct them swapped, taking supply cost from AI funds and funds cost from side supply. Fix this before enabling a scheduler. |
| MHQ repair | `Client/Action/Action_RepairMHQ.sqf:5-35`; `Server/PVFunctions/RequestMHQRepair.sqf:1`; `Server/Functions/Server_MHQRepair.sqf:1-35` | Repair is client-debited and side-only when it reaches the server. |
| Commander specials and selling | `Client/GUI/GUI_Menu_Tactical.sqf:363-373,463-527`; `Client/GUI/GUI_Menu_Economy.sqf:104-150`; `Server/Functions/Server_HandleSpecial.sqf:55-64` | Paratroops, paradrops, UAV/ICBM paths, RespawnST and structure sale/refund all need role/side/funds/effect validation before public-server confidence. |

## Safe Revival Plan

### Minimal Safety Patch

Use this if the owner does not want to revive autonomy yet:

1. Keep `UpdateSupplyTruck` disabled.
2. Guard the gated server init branch with `!isNil "UpdateSupplyTruck"` before spawning it.
3. Log one `WFBE_CO_FNC_LogContent` warning if truck supply + AI commanders is requested but the worker is unavailable.
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
