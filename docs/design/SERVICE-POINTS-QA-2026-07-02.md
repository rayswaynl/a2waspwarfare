# Service Points QA - 2026-07-02

Lane: 60, service-points QA
Base checked: `origin/claude/build84-cmdcon36@11736873a`
Scope: docs-only QA report. The actionable source is in `Client/GUI/GUI_Menu_Service.sqf`, which is on the current fleet avoid-list for in-flight GUI work, so this lane records evidence and defers code edits.

## Summary

The current live lane has already fixed the stale affordability gap called out by older service-point notes: single repair/heal actions now check price and funds before debit, rearm/refuel check funds, and all-unit/full-service helpers re-check funds before charging.

One live edge remains: single-unit service actions rely on button enable state for context (`_canBeUsed`) and do not repeat that context check at action time before taking funds and spawning the worker. A stale `MenuAction` or fast state change can therefore debit the player, then the worker can fail because the vehicle/support is no longer valid.

## Findings

| ID | Severity | Finding | Evidence | Recommended follow-up |
| --- | --- | --- | --- | --- |
| SP-QA-01 | P2 | Single-unit service actions do not re-check service context before debit/spawn. | `GUI_Menu_Service.sqf` computes `_martyServiceBlockReason` / `_martyServiceCanUse` at lines 81-99 and refreshes `_canBeUsed` for button state at lines 413-454. The single action handlers at lines 483-524 only check price/funds before `ChangePlayerFunds` and `Spawn Support*`; they do not re-check `_canBeUsed` or `_blockReason`. Worker scripts can then fail after pre-pay when support is gone, the vehicle is dead, or the vehicle is airborne: `Client_SupportRearm.sqf:69-87`, `Client_SupportRepair.sqf:60-81`, `Client_SupportRefuel.sqf:61-79`, `Client_SupportHeal.sqf:60-73`. | In the GUI owner lane, re-evaluate context immediately before debit for each single action. Reject with the same block hint if destroyed/airborne/moving, and only then debit/spawn. Consider whether worker aborts after pre-pay should refund or remain an intentional service-risk design. |
| SP-QA-02 | P3 | Rearm/refuel can queue zero-price workers from the action branch. | Button enable logic requires `_rearmPrice > 0` and `_refuelPrice > 0` at lines 448 and 452, but the action handlers only require `_funds >= _rearmPrice` and `_funds >= _refuelPrice` at lines 485 and 508. Repair/heal already require `_price > 0` at lines 497 and 520. | Add `_rearmPrice > 0` and `_refuelPrice > 0` to the single-action branch guards when touching this file. This is not a money-loss bug, but it avoids noisy no-op service workers. |
| SP-QA-03 | Resolved/stale | The older repair/heal affordability-gap note is not live on this base. | Repair and heal button state requires price and funds at lines 450 and 454. Their single-action handlers require `_repairPrice > 0 && _funds >= _repairPrice` and `_healPrice > 0 && _funds >= _healPrice` at lines 497 and 520. Batch and full-service helpers re-read funds and exit before debit at lines 164-168 and 204-208. | Update or supersede stale service-point wiki/design notes after a GUI owner applies SP-QA-01/SP-QA-02, so reviewers do not chase already-fixed repair/heal affordability behavior. |

## Verified Non-Findings

- Batch and full-service flows do re-check current funds immediately before debit (`GUI_Menu_Service.sqf:164-168`, `204-208`).
- Support worker scripts do not change player funds. They only wait, validate support/vehicle state, and apply the service on success.
- `Client_SupportRefuel.sqf` already uses `getVariable ["stopped", false]`, avoiding the old unset-variable Boolean trap for vehicles that never toggled stealth mode.
- No server-authority closure was attempted in this lane. Client-side economy authority is broader design work and outside this report.

## Suggested Source Shape

When the GUI file is free to edit, keep the change small:

1. For each single action branch, recompute funds and service context immediately before `ChangePlayerFunds`.
2. Require both positive price and enough funds for all four single actions.
3. Reuse `_martyServiceBlockReason` for the user-facing rejection hint.
4. Decide explicitly whether post-debit worker failure should refund or stay as a pre-pay risk.

## Verification

- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only QA lane.
- The report was prepared against `origin/claude/build84-cmdcon36@11736873a`.
