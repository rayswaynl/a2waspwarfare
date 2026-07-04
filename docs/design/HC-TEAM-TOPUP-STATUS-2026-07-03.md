# HC Team Top-Up Status - 2026-07-03

Lane: 97, HC team top-up

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Scope: source-backed status only. No mission source, generated mirror, package artifact, deploy, HC architecture, or AICOM behavior was changed.

## Verdict

Do not open a duplicate source lane just to wire `AI_Commander_HCTopUp.DRAFT.sqf`.

The current live source already has a separate top-up/refit path built around `wfbe_aicom_topup_req`. It does not use the old draft worker as its primary path. The draft file should remain a boundary note unless a future owner deliberately redesigns HC merge/top-up ownership and smoke-tests it in-game.

## Live Source Path

| Surface | Current evidence | Status |
| --- | --- | --- |
| Automatic dispatcher | `Server/AI/Commander/AI_Commander_Produce.sqf:128-183` finds understrength non-COMBAT teams that are rallying or parked near own HQ/towns, charges AI commander funds, and publishes `wfbe_aicom_topup_req` plus `wfbe_aicom_topup_stamp`. | Source-present. |
| Driver-local consumer | `Common/Functions/Common_RunCommanderTeam.sqf:2255-2289` reads `[count, posArray, classArray]`, defers while a player is within 300 m, creates up to 4 units through `WFBE_CO_FNC_CreateUnit`, clears complete or malformed requests, and emits `AICOMSTAT|v1|EVENT|...|TOPUP_DONE`. | Source-present; runtime proof token is `TOPUP_DONE`. |
| Human commander refit | `Server/Functions/Server_HandleSpecial.sqf:603-644` validates the requesting human commander, side, team index, cooldown, class list and funds, then uses the same `wfbe_aicom_topup_req` consumer path. | Source-present. |
| Runtime knobs | `Common/Init/Init_CommonConstants.sqf:857-860` defines all-team service/refit admission and the top-up unit cost, cooldown and human-commander discount. | Source-present and default-on for the current top-up/refit path. |
| Founding context | `Common/Init/Init_CommonConstants.sqf:985-992` records the older B57 note: founding size helps, but the real fix is a reinforcement/top-up pass. | Historical context now matched by live source. |

## Draft Worker Boundary

`Server/AI/Commander/AI_Commander_HCTopUp.DRAFT.sqf` is still present and still should not be treated as ordinary dead code:

- Its header says `DRAFT / NOT WIRED` and describes an older server-worker plus HC-consumer design (`AI_Commander_HCTopUp.DRAFT.sqf:1-37`).
- Its internal flags are `WFBE_C_AICOM_HC_TOPUP_ENABLE` and `WFBE_C_AICOM_HC_MERGE_ENABLE` (`AI_Commander_HCTopUp.DRAFT.sqf:45-51`), which are distinct from the live `wfbe_aicom_topup_req` producer/consumer path.
- `Server/AI/Commander/AI_Commander.sqf:414-428` only calls `WFBE_SE_FNC_AI_Com_HCTopUp` behind a nil guard.
- `Server/Init/Init_Server.sqf:64-75` compiles the normal AICOM worker functions and does not compile `AI_Commander_HCTopUp.DRAFT.sqf`; `rg` finds no live compile assignment for `WFBE_SE_FNC_AI_Com_HCTopUp`.

That means the `WFBE_C_AICOM_HC_TOPUP_ENABLE = 1` constant at `Init_CommonConstants.sqf:1075` does not by itself activate the draft file. The active top-up behavior is the request variable path above.

## Routing

Treat lane 97 as source-present, smoke-pending rather than source-missing:

1. For runtime validation, inspect RPTs for `AICOMSTAT|v1|EVENT|...|TOPUP_DONE` and `AICOM2|v1|ORDER|aicom-refit`.
2. If a future lane wants to compile the draft worker, split it into a new source PR with explicit merge/top-up ownership, flag semantics, and HC locality proof.
3. Do not delete `AI_Commander_HCTopUp.DRAFT.sqf` from generic dead-code work; it remains useful history and a risky HC/AICOM boundary.

No LoadoutManager run is needed for this status note.
