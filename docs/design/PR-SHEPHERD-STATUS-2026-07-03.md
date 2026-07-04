# PR Shepherd Status - 2026-07-03

Lane: 25, PR SHEPHERD (fleet self-service)

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Scope: docs-only status on the PRs named by the fleet prompt and the later #133 shepherd closeout. No old branches were retargeted, closed, reopened, rebased, or force-pushed by this pass.

## Current State

The prompt's lane-25 action list is stale. As of the 2026-07-03 check, the named PRs are no longer an open shepherd queue.

| PR | Current state | Resolution |
| --- | --- | --- |
| #140, stringtable localization gaps | MERGED, 2026-07-02T12:41:39Z | The formerly dirty stringtable follow-up is folded into `claude/build84-cmdcon36`. |
| #144, deadcode consistency sweep | MERGED, 2026-07-02T12:39:09Z | Folded. Later lane-8 status work should not reopen its stale `22005` cleanup. |
| #146, stale defense comments | MERGED, 2026-07-02T12:39:19Z | Folded. Later lane-8 status work confirms `Defenses_*.sqf` itself is still live-loaded. |
| #148, TK egress map bounds | MERGED, 2026-07-02T12:39:29Z | Folded into the live lane. |
| #149, client UX duplicate title IDD | MERGED, 2026-07-02T12:39:38Z | Folded into the live lane. |
| #150, tactical ammo status localization | MERGED, 2026-07-02T12:39:49Z | Folded into the live lane. |
| #153, salvage payout helper casing | CLOSED, 2026-07-02T12:50:07Z | Repaired once for no-flag casing, then closed because Arma 2 SQF identifiers are case-insensitive and there was no functional salvage-payout bug. |
| #135, release identity/static gate | CLOSED, 2026-07-02T12:50:06Z | Closed as superseded/regressive after the live lane advanced beyond the old release identity. |
| #133, cmdcon35 placement static gate | CLOSED, 2026-07-02T13:03:12Z | Closed as superseded because the payload was already carried by the command-center release branch / PR #125 route. |

## Routing

No direct lane-25 branch mutation remains:

- Do not retarget the prompt-listed #140/#144/#146/#148/#149/#150 set again; those PRs are merged.
- Do not reopen #153 as a correctness fix; the owner closeout says the casing difference is behaviorally identical in Arma 2 SQF.
- Do not reopen #135 or #133; both were explicitly closed as superseded.
- If future shepherding is needed, start from a fresh GitHub open-PR query instead of the stale prompt list.

This note intentionally makes no source or wiki content changes beyond this repository status record.
