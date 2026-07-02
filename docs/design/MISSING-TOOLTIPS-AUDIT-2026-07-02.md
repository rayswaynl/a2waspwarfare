# Missing Tooltips Audit - 2026-07-02

Lane: 159, missing tooltips sweep
Base checked: `origin/claude/build84-cmdcon36@ca278c4bc7`
Scope: docs/source audit only. No mission source, generated Takistan files, live deploy, or package artifacts are changed here.

## Summary

The prompt row is stale on the current live target. The two named controls already have tooltip attributes in both maintained mission roots:

- `CA_Send` in `WFBE_TransferMenu` explains that the selected amount is sent to the highlighted player.
- `CA_Cancel_Queue` in the buy-units menu explains that it cancels and refunds the most recent queued unit order.

No source patch is recommended for this lane. Adding another tooltip change would only churn already-correct UI source.

## Evidence Table

| Path | Evidence | Result |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:522,529` | `CA_Send` exists and has `tooltip = "Send the selected amount to the highlighted player";`. | Transfer-menu send button is already covered. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Rsc/Dialogs.hpp:522,529` | Same `CA_Send` class and tooltip string. | Takistan mirror is already covered. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Dialogs.hpp:1795,1803` | `CA_Cancel_Queue` exists and has `tooltip = "Cancel and refund the most recent queued unit order";`. | Buy-queue cancel button is already covered. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Rsc/Dialogs.hpp:1795,1803` | Same `CA_Cancel_Queue` class and tooltip string. | Takistan mirror is already covered. |

## Non-Findings

- This audit does not prove every button in `Rsc/Dialogs.hpp` has a tooltip; it only closes the exact lane-159 examples named by the fleet prompt.
- No stringtable migration is needed for this stale-row audit. The current literal tooltip strings already ship in both maintained roots.
- No layout, IDC, action, queue refund, or transfer-menu behavior changed here.

## Verification

- `rg` confirmed the `CA_Send` class and tooltip in both maintained roots.
- `rg` confirmed the `CA_Cancel_Queue` class and tooltip in both maintained roots.
- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only audit.
