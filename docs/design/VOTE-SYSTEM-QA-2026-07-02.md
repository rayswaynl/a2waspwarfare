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

## Delta findings (codex-fable-c second-pass, 2026-07-02)

Independent lane-24 re-sweep of the same subsystem; the original sweep's prune finding and
`WFBE_C_FIX_VOTE_LIST_PRUNE` flag were re-derived independently and are NOT repeated here
(the flag is registered at `Init_CommonConstants.sqf:1154` — no action needed). Two new
verified findings:

### Low-Med: vote-list color update indexes by ROW POSITION, not stored team index
`Client/GUI/GUI_VoteMenu.sqf` (~line 146, per-0.05s update loop): the name and vote-count
lines correctly resolve `_value = lnbValue [500100,[_i,0]]` and use `WFBE_Client_Teams
select _value`, but the "has voted" color check immediately below uses
`(WFBE_Client_Teams select _i) getVariable "wfbe_vote"` — `_i` is the ROW index.
Consequences when row order diverges from team-index order (possible after prune/append
cycles): (a) the amber voted-highlight can color the wrong row (cosmetic); (b) if `_i`
lands on a nil slot of `WFBE_Client_Teams`, `nil getVariable` throws an RPT error every
tick — the same failure family the B74.2.5 primitive gate comment above this loop documents.
Fix candidate (one line, flag-gate with the existing prune flag after smoke): use `_value`
and guard nil, mirroring the prune branch's `_value >= 0 && {_value < count(WFBE_Client_Teams)}` idiom.
Smoke: three player teams voting, force a mid-vote prune (one leader disconnects), watch
row colors + client RPT.

### Low: commander reassignment confirm can send objNull while primitive rows show
`Client/GUI/GUI_Commander_VoteMenu.sqf:54-57`: confirming while the dialog still shows
JIP primitive rows resolves `_storedIndex < 0` → `objNull` → `RequestNewCommander` with
objNull. Server-side this falls back to AI commander (probably acceptable), but the UI
does not distinguish "roster not live yet" from "AI Commander", so an early-JIP commander
can hand off to AI by accident. Options: disable confirm until live handover, or render
primitive rows visually read-only. No code change shipped; UX call for the owner.
