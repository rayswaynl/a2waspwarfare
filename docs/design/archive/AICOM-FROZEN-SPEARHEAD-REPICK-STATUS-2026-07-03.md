# AICOM Frozen Spearhead Re-pick Status Audit - 2026-07-03

Lane: fleet lane 92, docs-only status audit
Base checked: `origin/claude/build84-cmdcon36@b1608b096eb4a02d7c213d794e22b8bc59df8df0`

## Scope

The prompt row asks for frozen-spearhead re-pick: when a side keeps aiming at
the same primary front town without closing distance for several strategy
ticks, blacklist that stalled primary briefly and force the spearhead picker to
choose the next-best eligible town.

This pass checks current target-branch source and records status only. It
does not edit mission source because the relevant implementation lives in
`AI_Commander_Strategy.sqf`, which is a hot/open-PR AICOM surface.

## Verdict

Lane 92 is already implemented on the checked target.

The implementation is default-on strategy behavior rather than a separate
feature flag. It also deliberately uses a better progress signal than raw
`distFront`: it tracks the best approach distance of committed offense teams to
the current primary town. That avoids false stalls while a town is being
contested or while no team has actually committed to the primary yet.

One caveat: only the blacklist cooldown is centralized in
`Init_CommonConstants.sqf` as `WFBE_C_AICOM_BLACKLIST_COOLDOWN = 600`. The
minimum gain and stall-evaluation thresholds are live through
`missionNamespace getVariable` fallbacks in Strategy:
`WFBE_C_AICOM_REPICK_MIN_GAIN` defaults to `150`, and
`WFBE_C_AICOM_REPICK_STALL_EVALS` defaults to `4`. Adding central constants for
those two knobs would be a tuning/cleanup follow-up, not a missing behavior
fix.

## Evidence

| Surface | Current target evidence | Status |
| --- | --- | --- |
| Side-level blacklist | `AI_Commander_Strategy.sqf:132-152` prunes `wfbe_aicom_spearhead_bl`, excludes live blacklist towns from candidates, and clears the blacklist if it would empty the candidate set. | Present |
| Progress memory | `AI_Commander_Strategy.sqf:216-230` documents spearhead re-pick and reads `WFBE_C_AICOM_REPICK_MIN_GAIN`, `WFBE_C_AICOM_REPICK_STALL_EVALS`, and `WFBE_C_AICOM_BLACKLIST_COOLDOWN`. | Present |
| False-positive guard | `AI_Commander_Strategy.sqf:231-238` tracks `_anyCommitted`; `:262-277` accrues stall only when a committed offense team exists. | Present |
| Stall detector | `AI_Commander_Strategy.sqf:255-275` resets progress memory on primary change, resets stall count on meaningful approach gain, and marks stalled when the consecutive count reaches the threshold. | Present |
| Same-tick re-pick | `AI_Commander_Strategy.sqf:279-362` blacklists the frozen primary, rebuilds candidates minus the live blacklist, re-runs the same scorer, reseeds the new-primary progress baseline, and logs `AICOMSTAT|v1|SPEARHEAD_REPICK`. | Present |
| Cooldown constant | `Common/Init/Init_CommonConstants.sqf:1019` in Chernarus, Takistan, and Zargabad defines `WFBE_C_AICOM_BLACKLIST_COOLDOWN = 600`. | Present |
| Design context | `docs/design/AICOM-UNIT-BEHAVIOR-FABLE.md:132-135` notes the existing sticky-order/committed-mass precedent and why additive journey-commit/hysteresis work was needed around live front churn. | Documented context |

## Maintained-Root Parity

`AI_Commander_Strategy.sqf` has the same SHA-256 hash in all three maintained
mission roots:

| File | SHA-256 in Chernarus/Takistan/Zargabad |
| --- | --- |
| `AI_Commander_Strategy.sqf` | `BEC4C40780D8C3440A7170C4059CFA741F581720F600BB91F652829DF57F8806` |

Compact scan counts also match across all three roots:

| Root | `SPEARHEAD RE-PICK` | `wfbe_aicom_spearhead_bl` | `wfbe_aicom_spear_bestapproach` | `wfbe_aicom_spear_stallcount` | `WFBE_C_AICOM_REPICK_MIN_GAIN` | `WFBE_C_AICOM_REPICK_STALL_EVALS` | `WFBE_C_AICOM_BLACKLIST_COOLDOWN` | `_anyCommitted` | `SPEARHEAD_REPICK` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Chernarus | 2 | 7 | 4 | 5 | 1 | 1 | 1 | 6 | 1 |
| Takistan | 2 | 7 | 4 | 5 | 1 | 1 | 1 | 6 | 1 |
| Zargabad | 2 | 7 | 4 | 5 | 1 | 1 | 1 | 6 | 1 |

## BI Command References

The relevant Arma 2 OA command family is the standard object variable,
distance, time, and logging API used by the existing code:

- https://community.bistudio.com/wiki/getVariable
- https://community.bistudio.com/wiki/setVariable
- https://community.bistudio.com/wiki/distance
- https://community.bistudio.com/wiki/time
- https://community.bistudio.com/wiki/diag_log
- https://community.bistudio.com/wiki/Category:Arma_2:_Operation_Arrowhead:_Scripting_Commands

## Recommendation

Treat lane 92 as implemented on `claude/build84-cmdcon36`. Do not re-open
source work for frozen-spearhead re-pick unless a later soak shows the current
fallback thresholds need tuning.

If tuning becomes necessary, coordinate a small AICOM source lane that either
changes the fallback values in Strategy or surfaces
`WFBE_C_AICOM_REPICK_MIN_GAIN` and `WFBE_C_AICOM_REPICK_STALL_EVALS` beside the
existing blacklist cooldown constant. That would be a deliberate behavior
change, not a status-audit fix.

## Verification

- Read `CLAUDE.md` and `JOURNAL.md` before the audit.
- Scanned lane 92 prompt text, active wiki claims, recent events, and open PRs
  before claiming the lane.
- Scanned spearhead blacklist, progress-memory, stall-detection, same-tick
  re-pick, and `SPEARHEAD_REPICK` telemetry anchors across Chernarus,
  Takistan, and Zargabad.
- Verified `AI_Commander_Strategy.sqf` has matching SHA-256 hashes across all
  maintained roots.
- Verified this lane is docs-only; no SQF/SQM/HPP/EXT files changed.
- LoadoutManager was not run because no mission source changed.
