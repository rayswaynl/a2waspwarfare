# Fast Travel QA - 2026-07-02

Base checked: `origin/claude/build84-cmdcon36@8e341a952`.

## Current reconciliation (2026-07-11)

The 2026-07-02 body below remains a historical snapshot based on `origin/claude/build84-cmdcon36@8e341a952`. Current facts were rechecked at `origin/master@bb79a88aa65f491a5c5d3d3d610c4e60237eb4b7` on 2026-07-11.

- **FT-1 - addressed on current master.** Commit `74fb226a3b70e4445b49c8813a46fda8802cde28` added a uniform flat-plus-distance destination gate at `Client/GUI/GUI_Menu_Tactical.sqf:317-326`, a click-time funds recheck at `:654-670`, a failed-recheck block at `:671-676`, and keeps deductions after the guard at `:693-702`.
- **FT-2 - separate and partially unresolved.** Marker text now uses `_feeTotal` at `GUI_Menu_Tactical.sqf:343-345`, but the support-list row still shows `$0` at `:116`.
- **Residual, not an FT-1 regression.** At line 662 the membership test uses `_x` while the list stores `vehicle _x`; a multi-crew vehicle can therefore be overcounted during the recheck, while the actual charger deduplicates vehicles at line 702. This reconciliation does not claim exact bill parity or complete pricing-QA closure.
- This is a documentation-only reconciliation; it makes no runtime or source behavior change.

Scope: fleet lane 59 refresh of the existing fast-travel QA pass. This pass stays docs-only because the actionable source fix is in `Client/GUI/GUI_Menu_Tactical.sqf`, which remains in the GUI avoid-list for fleet work.

## Summary

Fast travel is currently enabled by default in fee mode for dedicated parameter flow: `WFBE_C_GAMEPLAY_FAST_TRAVEL` offers `0,1,2` and defaults to `2` in `Rsc/Parameters.hpp:251-256`. The SQF fallback still sets `1` at `Common/Init/Init_CommonConstants.sqf:1311`, but that fallback is only used when the parameter was not injected. Fee-mode constants are defined at `Init_CommonConstants.sqf:1320-1325`:

- start range: `175`
- max range: `3500`
- per-km fee: `215`
- flat fee: `5000`
- per distinct vehicle surcharge: `2500`

## Current Flow Map

- Action exposure is funds-blind by design: `Client/FSM/updateavailableactions.fsm:207-215` requires fast travel enabled, command range, upgrade level, and a valid nearby start point.
- The tactical dialog builds destinations every 15 seconds once the fast-travel upgrade is present: `Client/GUI/GUI_Menu_Tactical.sqf:216-293`.
- Valid start points are deployed HQ, a fully held friendly town, or a nearby command center: `GUI_Menu_Tactical.sqf:225-248`.
- Valid destinations are towns, command centers, and the deployed HQ inside the max range but outside the start radius: `GUI_Menu_Tactical.sqf:250-291`.
- Button enablement only checks destination count and upgrade level for `Fast_Travel`: `GUI_Menu_Tactical.sqf:316-320`.
- Click execution picks the closest marker, deducts the flat+distance fee, then deducts the carried-vehicle fee per distinct vehicle: `GUI_Menu_Tactical.sqf:479-511`.

## Findings

| ID | Severity | Finding | Evidence | Suggested route |
| --- | --- | --- | --- | --- |
| FT-1 | P1 | Fee-mode destination availability can under-check the real price, then deduct the full price. A player can be offered an enabled fast-travel destination that they cannot afford once the flat fee and carried-vehicle surcharges are included. | The destination list snapshots funds only for fee mode, but only town destinations compare funds against the per-km portion: `GUI_Menu_Tactical.sqf:255-268`. Structure/base destinations skip that affordability check entirely because the check is inside `_x in towns`. The button also enables from destination count + upgrade level only at `GUI_Menu_Tactical.sqf:316-320`. The execute path later deducts flat fee plus distance fee at `GUI_Menu_Tactical.sqf:503-505`, then deducts the per-distinct-vehicle surcharge at `GUI_Menu_Tactical.sqf:508-511`, without a final affordability guard before any `ChangePlayerFunds` call. | When the GUI lane is clear, add a default-off flag such as `WFBE_C_FIX_FAST_TRAVEL_FEE_GUARD = 0`. Compute the total fee once from flat fee + distance fee + distinct vehicle fee, use that for destination gating when possible, and add a final click-time guard before deductions. |
| FT-2 | P2 | Fee marker text underreports fee-mode travel cost. | Fee markers use `_fee` at `GUI_Menu_Tactical.sqf:278-286`; that value is only the per-km fee for town destinations and can remain stale or zero for structure/base destinations. It never includes the flat `5000` fee or vehicle surcharge. The support-list price label also remains `$0` for the fast-travel row because `_addToListFee` seeds fast travel as zero at `GUI_Menu_Tactical.sqf:73-75` and the row label is set from `_currentFee` at `GUI_Menu_Tactical.sqf:311-312`. | Show at least the base+distance minimum in marker/list text, and leave vehicle surcharge explicit in the dialog/hint because vehicle membership is resolved at click time. |
| FT-3 | P3/context | The action icon is intentionally funds-blind, so the tactical dialog must be the affordability authority. | `Client/FSM/updateavailableactions.fsm:207-215` only checks fast travel mode, command range, upgrade level, and nearby base/camp/command-center state. It has no funds test. | This can remain unchanged if the tactical dialog correctly hides/blocks unaffordable destinations and the execute path has a final guard. |

## Non-Findings

- The dedicated parameter default and SQF fallback differ (`2` in `Parameters.hpp`, `1` in `Init_CommonConstants.sqf`). That is not changed here because dedicated parameter injection should win; changing the fallback would be behavioral churn outside this QA slice.
- All faction upgrade configs gate the fast-travel upgrade on `WFBE_C_GAMEPLAY_FAST_TRAVEL > 0` (`Common/Config/Core_Upgrades/Upgrades_*.sqf:18`). No missing faction reader was found.
- `WFBE_C_RESPAWN_MOBILE` shares nearby gameplay vocabulary but is not part of the fast-travel action path inspected here.

## Smoke Checklist For The Future Source Fix

Run these in a local hosted mission or controlled dedicated test after the GUI lane is available:

1. Set fast travel to fee mode, unlock the fast-travel upgrade, stand at a valid start point, and confirm the action icon appears.
2. With funds below `flat + distance`, confirm no destination can be executed and no funds are deducted.
3. With enough funds for `flat + distance` but not carried-vehicle surcharge, travel with a vehicle in group range and confirm execution is blocked before all deductions.
4. With enough funds for total cost, fast travel to a town, command center, and deployed HQ destination and confirm final funds equal starting funds minus total cost.
5. Confirm no marker/list price shows `$0` or per-km-only text in fee mode unless the computed total is truly zero.
6. Confirm free mode still exposes and executes the same destinations without any fee guard blocking the action.

## Future Source Fix Notes

Patch target once the GUI lane is available: `Client/GUI/GUI_Menu_Tactical.sqf`.

Recommended behavior behind a default-off flag:

1. Add `WFBE_C_FIX_FAST_TRAVEL_FEE_GUARD = 0` in the existing constants/parameter pattern.
2. In fee mode, compute base+distance cost for every destination type before marker/list insertion. Town, structure, and deployed-base destinations should use the same minimum-cost path.
3. At click time, build the distinct carried-vehicle list before deducting money, add `WFBE_C_GAMEPLAY_FAST_TRAVEL_VEH_FEE` per non-man vehicle, and compare the total against `Call GetPlayerFunds`.
4. If unaffordable, exit before all `ChangePlayerFunds` calls and show a short localized or existing-style hint.
5. Preserve Arma 2 OA SQF compatibility. Avoid A3-only syntax and avoid Boolean `==`/`!=` comparisons.

Out of scope for this docs-only PR: menu layout changes, stringtable work, parameter default changes, or generated Takistan output.
