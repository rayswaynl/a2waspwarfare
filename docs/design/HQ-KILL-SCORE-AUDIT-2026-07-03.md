# HQ Kill Score Audit - 2026-07-03

Lane: fleet lane 77, SG2 / DR-50
Base checked: `origin/claude/build84-cmdcon36@b1608b096`

## Scope

The fleet prompt flags the old HQ-kill score exploit where
`Server_OnHQKilled.sqf` paid the killer twice on clean enemy HQ kills and still
paid score for friendly/teamkill HQ destruction.

This pass checks the current target's HQ-kill scoring path across the three
maintained roots:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad`

No mission source, generated mirror output, live runtime settings, package
artifacts, bounty values, score coefficients, or HQ-kill side effects are
changed here.

## Verdict

Lane 77 is already fixed on the current target.

`Server_OnHQKilled.sqf` computes the canonical HQ score as:

`_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF`

With `WFBE_C_BUILDINGS_SCORE_COEF = 3`, that remains 900 score. The handler now
computes `_teamkill` before scoring and only awards `_points` when `!_teamkill`.
The old second hard-coded 900-point award block has been removed, with an inline
DR-50 comment recording that clean enemy HQ kills pay `_points` once and
teamkills pay nothing.

The later `HeadHunterReceiveBounty` message still carries `30000`, but that is
the existing bounty/message payload. It is not a second `RequestChangeScore` or
`SRVFNCREQUESTCHANGESCORE` award.

## Evidence Table

| Surface | Evidence | Result |
| --- | --- | --- |
| Canonical score value | `Server/Functions/Server_OnHQKilled.sqf:23` sets `_points = 30000 / 100 * WFBE_C_BUILDINGS_SCORE_COEF`; `Common/Init/Init_CommonConstants.sqf:1483` keeps `WFBE_C_BUILDINGS_SCORE_COEF = 3`. | The intended HQ score remains 900. |
| Teamkill classification | `Server/Functions/Server_OnHQKilled.sqf:66` computes `_teamkill = if (side _killer == _side) then {true} else {false};` before the score award. | The score branch has the same-side result available before paying. |
| Single score award | `Server/Functions/Server_OnHQKilled.sqf:71-77` documents the DR-50 fix and gates both server-local and relay scoring paths with `if (!_teamkill) then`. | Clean enemy HQ kills receive one `_points` award; friendly/teamkill HQ kills receive no score. |
| Teamkill and bounty messaging | `Server/Functions/Server_OnHQKilled.sqf:90-96` sends the teamkill message on `_teamkill` and the `HeadHunterReceiveBounty` message on clean kills. | The remaining `30000` payload is message/bounty text, not another score award. |
| Removed duplicate block | `Server/Functions/Server_OnHQKilled.sqf:116-118` states that the duplicate "award 900 on non-teamkill" block was removed and that the single canonical award is `_points`, paid once only when `!_teamkill`. | The old double-score shape is gone from the current handler. |
| Maintained-root parity | The same anchors are present in Chernarus, Takistan, and Zargabad, and `git diff --no-index` reports no handler differences between Chernarus and the two Vanilla roots. | The fix is propagated across the maintained mission roots. |

## Out Of Scope

PR #336 (`codex/dr20-hq-kill-idempotency`) owns the nearby DR-20 duplicate
relay/idempotency issue in `Server_OnHQKilled.sqf`. This audit deliberately does
not stack a competing source edit on that file.

This audit also does not change HQ-kill bounty cash/message values, score
coefficient balance, base-fall smoke/sting behavior, HQ wall cleanup, victory
logic, or any JIP/headless-client enrollment flow.

## Verification

- `rg` confirmed `_points`, `_teamkill`, and the `if (!_teamkill) then` score
  gate in Chernarus, Takistan, and Zargabad.
- `rg` confirmed `WFBE_C_BUILDINGS_SCORE_COEF = 3` in all three roots, making
  the canonical `_points` value 900.
- `rg` confirmed the old duplicate "award 900 on non-teamkill" block is present
  only as the removal comment, not as a live `_score = 900` award.
- `rg` confirmed the remaining `HeadHunterReceiveBounty` `30000` payload is not
  paired with a second `RequestChangeScore` / `SRVFNCREQUESTCHANGESCORE` call.
- `git diff --no-index` confirmed Chernarus/Takistan and Chernarus/Zargabad
  parity for `Server_OnHQKilled.sqf`.
- This PR is docs-only. LoadoutManager was not run because no mission source or
  generated mirror source changed.
