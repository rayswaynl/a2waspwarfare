# Lane 133 HC Delegate Load Audit - 2026-07-02

## Verdict

Lane 133 is already fixed in the current Build 88 base. No source change is needed.

The prompt item says `Server_DelegateAITownHeadless.sqf` picks an HC by pure random. Current Chernarus and Takistan source both call `WFBE_CO_FNC_PickLeastLoadedHC` instead. The remaining `random` inside `Server_PickLeastLoadedHC.sqf` is only a tie-breaker among equally loaded HCs, not the primary selection strategy.

## Current evidence

- `Server/Init/Init_Server.sqf:147` registers `WFBE_CO_FNC_PickLeastLoadedHC`.
- `Server/Functions/Server_PickLeastLoadedHC.sqf:2-25` documents the helper as the single source of truth for HC delegation and explicitly replaces the old blind random coin-flip.
- `Server/Functions/Server_PickLeastLoadedHC.sqf:31-71` reads live HCs, counts local/owned units, keeps the lowest load, and only randomizes ties.
- `Server/Functions/Server_DelegateAITownHeadless.sqf:22-29` hoists one least-loaded pick for the town batch instead of picking once per group.
- `Server/Functions/Server_DelegateAITownHeadless.sqf:42-54` seeds the batch from that HC and then round-robins through live HCs for the remaining groups.
- The same lines exist in the maintained Takistan root.

## Broader caller check

The current maintained roots route the main HC delegation sites through the same helper:

- `Server/FSM/server_side_patrols.sqf:272`
- `Server/AI/Commander/AI_Commander_Teams.sqf:1050`
- `Server/Functions/Server_DelegateAIStaticDefenceHeadless.sqf:25`
- `Server/Functions/AI_Commander_Wildcard.sqf` W6/W19/W23/W24 delegate paths

The remaining `select floor(random ...)` hits in `Server` are template, spawn, town, and equal-load tie choices, not the lane 133 HC delegate pick.

## Scope decision

This PR does not edit mission source. Reworking the picker would risk changing the current load-balancing behavior without a live defect. The useful action is to mark lane 133 stale against current base and keep the evidence near the prompt queue.

## Verification

- Checked active brain claims plus remote branch/open PR searches for lane 133, HC delegate random, and `PickLeastLoadedHC`; no owner or open PR was found.
- Grepped both maintained mission roots for `WFBE_CO_FNC_PickLeastLoadedHC`, `Server_DelegateAITownHeadless`, `delegate-townai`, and `select floor(random ...)`.
- Compared Chernarus and Takistan line-level evidence for the picker and town-delegation caller.
- No LoadoutManager mirror was run because the diff is docs-only.
