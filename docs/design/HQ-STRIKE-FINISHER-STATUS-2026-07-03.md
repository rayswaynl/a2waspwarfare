# HQ-Strike Finisher Status - 2026-07-03

## Verdict

Fleet lane 82 is current-target present on `origin/claude/build84-cmdcon36@b1608b096eb4`.
The old prompt row says the HQ-strike finisher is dead because `AI_Commander_Strategy.sqf`
targets a nearby town instead of the enemy HQ. The current target no longer matches that
shape: the strategy code resolves the enemy HQ object, moves strikers to `getPos _enemyHQ`,
holds the strike mode, stages/masses strike teams, weights vehicle punch in the picker and
uses the base-overrun closure path to raze the enemy HQ when the strike succeeds.

No duplicate source patch is warranted from this lane.

## Source Proof

`B69 Patch A (core): HQ-strike finisher - order + gate + picker` is already in the target
history. `git merge-base --is-ancestor 35547c471 origin/claude/build84-cmdcon36` passes.
That patch originally added the HQ-strike order/gate/picker work; later current-target work
adds the absolute 12-town launch gate, sticky hold, staging mass, strike-commit guard and
base-overrun round closure.

The maintained roots are byte-identical for the two relevant source files:

| File family | Maintained roots | SHA-256 |
| --- | --- | --- |
| `Server/AI/Commander/AI_Commander_Strategy.sqf` | Chernarus, Takistan, Zargabad | `BEC4C40780D8C3440A7170C4059CFA741F581720F600BB91F652829DF57F8806` |
| `Common/Init/Init_CommonConstants.sqf` | Chernarus, Takistan, Zargabad | `0259B5AFC676AEC0397EE962AD6E4C8C9F72BB70329C6C0E6E4BC00138D7F29C` |

Representative anchors, identical across Chernarus, Takistan and Zargabad:

| Area | Current evidence |
| --- | --- |
| Launch telemetry | `AI_Commander_Strategy.sqf:733` logs `HQ_STRIKE|launched` with owned towns, gate and total towns. |
| Enemy-HQ destination | `AI_Commander_Strategy.sqf:743` sets `_strikeDest = getPos _enemyHQ`. |
| Release to enemy HQ | `AI_Commander_Strategy.sqf:783` calls `SetTeamMovePos` with `getPos _enemyHQ`, and `:785` publishes the HC order as `["goto", getPos _enemyHQ]`. |
| Staging/mass | `AI_Commander_Strategy.sqf:789` logs `STRIKE_STAGE_RELEASE` after enough bodies stage or timeout. |
| Picker quality | `AI_Commander_Strategy.sqf:846` documents the B69 vehicle-punch picker, so armour/attack-helis outrank raw infantry count. |
| Round closure | `AI_Commander_Strategy.sqf:934` damages the enemy HQ during the base-overrun closure path. |
| Tunables | `Init_CommonConstants.sqf:571-572`, `:599` and `:848-854` define the 12-town gate, strike cap fraction, sticky minimum hold, staging constants and strike-commit guard. |

## What Changed Since The Stale Prompt

The prompt's "dead finisher" diagnosis matched an older B69-roadmap state. The current target
contains multiple later fixes:

- The strike target is the enemy HQ object, not a nearest town.
- The launch gate is no longer the unreachable half-of-all-Chernarus-town count; the current
  absolute gate is `WFBE_C_AICOM_HQSTRIKE_MIN_TOWNS = 12`, with additional relative and stall
  override paths.
- Strike membership scales with live field teams via `WFBE_C_AICOM_HQSTRIKE_CAP_FRAC` instead
  of a flat tiny striker count.
- Strikers stage short of the HQ before release, so piecemeal arrivals are reduced.
- The closure path can raze the HQ and nearby structures when enough strikers control the base
  area.

The overnight loop notes also record a current-target soak where the full chain eventually
completed: capture, dominance, HQ strike, base overrun and victory.

## Out Of Scope

This lane intentionally does not change AICOM gameplay source. It also does not retune strike
thresholds, enable new lobby parameters, touch LoadoutManager output, package missions, deploy
to a live server or alter the open F2/F4/F7 AICOM behavior lanes. Any future work should be a
fresh runtime-retune lane backed by RPT evidence, not a reimplementation of lane 82.

## Validation

- `gh pr list --repo rayswaynl/a2waspwarfare --state all --limit 800` found no existing lane 82
  or HQ-strike-finisher PR.
- Wiki coordination had no active lane 82 claim before this pass.
- `git merge-base --is-ancestor 35547c471 origin/claude/build84-cmdcon36` passed.
- `git grep` verified the HQ-strike target, staging, picker, base-overrun and constants anchors
  in all three maintained roots.
- This PR is docs-only: `docs/design/HQ-STRIKE-FINISHER-STATUS-2026-07-03.md` plus `JOURNAL.md`.
