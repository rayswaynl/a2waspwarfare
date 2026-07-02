# Vote System QA Sweep - 2026-07-02

Lane 24 scope: vote and commander-vote flow on the live lane `claude/build84-cmdcon36`.

## Finding: forward row deletion can leave stale vote candidates

`GUI_VoteMenu.sqf` and `GUI_Commander_VoteMenu.sqf` both maintain their live team list by iterating vote-list rows from top to bottom and deleting rows whose stored team index no longer points at a player-led team. In Arma list controls, deleting row N shifts row N+1 into row N. The loop then increments, so adjacent stale rows can leave one stale row behind.

Impact:

- Round-start vote menu can keep a non-player/stale team row visible after two adjacent rows stale together.
- Commander vote menu can keep a stale commander candidate selectable until a later refresh catches it.
- A stale stored team index may also outlive the current `WFBE_Client_Teams` shape.

Patch:

- Added default-off `WFBE_C_FIX_VOTE_LIST_PRUNE`.
- When enabled, both vote dialogs prune from bottom to top and guard stored row indexes before reading `WFBE_Client_Teams`.
- Default `0` preserves the existing forward-delete behavior until graded.

## Checked But Not Changed

- `RequestClaimCommander.sqf` already guards null side logic, AI-commander lock, occupied human commander seat, player-led claimant, and same-side claimant.
- `RequestNewCommander.sqf` already has a separate `WFBE_C_SEC_HARDENING` cross-side assignment guard. This sweep did not widen that security lane.
- The primitive JIP roster gates in both vote dialogs deliberately skip live pruning while rows are placeholders; this sweep preserves that behavior.
