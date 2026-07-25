# RESULT — side-patrol registry authority replacement

Date: 2026-07-25
Branch: `codex/sidepatrol-registry-authority-20260725`
Draft PR: https://github.com/rayswaynl/a2waspwarfare/pull/1436

## Outcome

PR #1395’s two registry mutation defects and the missing town-proximity guard are
closed. Registry writes, row cleanup, slot reconciliation, cooldown repair, and convoy
settlement are server-owned. HC startup and each convoy payout use private one-shot
capabilities; payout is additionally bound to stable dispatch identity, live patrol
group/leader ownership, the real eligible truck, registered town proximity, cooldown,
and one payout per current town visit. Local-server patrols use server-only settlement.

No feature flags were added or armed. No live deployment, server restart, merge, or
box mutation was performed.

## Verification

- Side-patrol authority contract: PASS.
- Capability-helper authority contract: PASS.
- Diff-only SQF lint: PASS, 0 findings across 33 changed files.
- LoadoutManager mirror run and `--check`: PASS; Takistan/Zargabad drift none.
- Version-template test: PASS.
- CH/TK/ZG hashes: identical for all touched mission paths.
- `git diff --check`: PASS.
- Full lint pytest: 365 passed, 1 baseline failure in the unchanged case-floor test
  (origin/master has 54 dispatch labels; this branch has 55 after the new challenge
  case, while the stale floor remains 56).

The temporary `PR_BODY.md` was used only to create the draft PR and is not part of the
deliverable. `TASK.md` remains user-provided and untracked.

GUIDE-REV: `GR-2026-07-08a`
