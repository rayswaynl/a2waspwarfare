# Fast Travel QA - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@11736873a`.

Scope: fleet lane 24 rotating QA pass over the fast-travel flow. This pass is docs-only because the actionable source fix is in `Client/GUI/GUI_Menu_Tactical.sqf`, which is currently in the GUI avoid-list while the older Claude menu lane is still open.

## Summary

Fast travel is currently enabled by default in fee mode for dedicated parameter flow: `WFBE_C_GAMEPLAY_FAST_TRAVEL` offers `0,1,2` and defaults to `2` in `Rsc/Parameters.hpp:251-256`. The SQF fallback still sets `1` at `Common/Init/Init_CommonConstants.sqf:1139`, but that fallback is only used when the parameter was not injected. Fee-mode constants are defined at `Init_CommonConstants.sqf:1148-1153`:

- start range: `175`
- max range: `3500`
- per-km fee: `215`
- flat fee: `5000`
- per distinct vehicle surcharge: `2500`

## Findings

| ID | Severity | Finding | Evidence | Suggested route |
| --- | --- | --- | --- | --- |
| FT-1 | P1 | Fee-mode destination availability can under-check the real price, then deduct the full price. A player can be offered an enabled fast-travel destination that they cannot afford once the flat fee and carried-vehicle surcharges are included. | The destination list snapshots funds only for fee mode, but only town destinations compare funds against the per-km portion: `GUI_Menu_Tactical.sqf:245-256`. Structure/base destinations skip that affordability check entirely because the check is inside `_x in towns`. The execute path later deducts flat fee plus distance fee at `GUI_Menu_Tactical.sqf:492-494`, then deducts the per-distinct-vehicle surcharge at `GUI_Menu_Tactical.sqf:497-500`, without a final affordability guard before any `ChangePlayerFunds` call. | When the GUI lane is clear, add a default-off flag such as `WFBE_C_FIX_FAST_TRAVEL_FEE_GUARD = 0`. Compute the total fee once from flat fee + distance fee + distinct vehicle fee, use that for destination gating when possible, and add a final click-time guard before deductions. |
| FT-2 | P2 | Fee marker text underreports fee-mode travel cost. | Fee markers use `_fee` at `GUI_Menu_Tactical.sqf:267-275`; that value is only the per-km fee for town destinations and can remain stale or zero for structure/base destinations. It never includes the flat `5000` fee or vehicle surcharge. | Show at least the base+distance minimum in marker/list text, and leave vehicle surcharge explicit in the dialog/hint because vehicle membership is resolved at click time. |
| FT-3 | P3/context | The action icon is intentionally funds-blind, so the tactical dialog must be the affordability authority. | `Client/FSM/updateavailableactions.fsm:207-215` only checks fast travel mode, command range, upgrade level, and nearby base/camp/command-center state. It has no funds test. | This can remain unchanged if the tactical dialog correctly hides/blocks unaffordable destinations and the execute path has a final guard. |

## Non-Findings

- The dedicated parameter default and SQF fallback differ (`2` in `Parameters.hpp`, `1` in `Init_CommonConstants.sqf`). That is not changed here because dedicated parameter injection should win; changing the fallback would be behavioral churn outside this QA slice.
- All faction upgrade configs gate the fast-travel upgrade on `WFBE_C_GAMEPLAY_FAST_TRAVEL > 0` (`Common/Config/Core_Upgrades/Upgrades_*.sqf:18`). No missing faction reader was found.

## Future Source Fix Notes

Patch target once the GUI lane is available: `Client/GUI/GUI_Menu_Tactical.sqf`.

Recommended behavior behind a default-off flag:

1. Add `WFBE_C_FIX_FAST_TRAVEL_FEE_GUARD = 0` in the existing constants/parameter pattern.
2. In fee mode, compute base+distance cost for every destination type before marker/list insertion. Town, structure, and deployed-base destinations should use the same minimum-cost path.
3. At click time, build the distinct carried-vehicle list before deducting money, add `WFBE_C_GAMEPLAY_FAST_TRAVEL_VEH_FEE` per non-man vehicle, and compare the total against `Call GetPlayerFunds`.
4. If unaffordable, exit before all `ChangePlayerFunds` calls and show a short localized or existing-style hint.
5. Preserve Arma 2 OA SQF compatibility. Avoid A3-only syntax and avoid Boolean `==`/`!=` comparisons.

Out of scope for this docs-only PR: menu layout changes, stringtable work, parameter default changes, or generated Takistan output.
