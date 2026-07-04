# W20 Captured Cache Tier Text Audit

Date: 2026-07-02
Lane: fleet lane 153, stale-row audit
Base checked: `origin/claude/build84-cmdcon36@b2dbab5f3070c2bc8cacc79c06b9ca5ac20a2493`

## Scope

Fleet lane 153 says `AI_Commander_Wildcard.sqf` W20 raises a random support tier
but the announcement does not say which tier. This pass checks the current live
target and records whether a source patch is still needed.

No mission source, wildcard deck weights, runtime behavior, UI routing, generated
Takistan files, live deploy state, or package artifacts are changed here.

## Verdict

The lane is already fixed on the live target. When W20 Captured Cache applies,
the announcement names the selected support tier and the resulting level, for
example:

`Captured Cache - Paratroopers support reaches level 2`

The static `W20` entry in `_wNameMap` still contains the generic fallback text,
but that fallback is intentionally overwritten after the W20 apply block has
chosen a concrete tier.

## Evidence

Both maintained mission roots have the same implementation:

| Root | Evidence |
| --- | --- |
| Chernarus | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard.sqf:1278-1279` maps the chosen upgrade id to `Paratroopers`, `Supply Rate`, or `Gear`, then logs `support_tier=... new_level=...`. |
| Chernarus | `AI_Commander_Wildcard.sqf:1539` still has the generic `Captured Cache` fallback, but `:1548-1550` replaces `_wDesc` for applied W20 draws with `Format ["%1 support reaches level %2", _w20TierName, _w20NewUpgrades select _w20ChosenID]`. |
| Chernarus | `AI_Commander_Wildcard.sqf:1619-1629` sends `_wDesc` through the existing `LocalizeMessage` announcement path for human-side and AI-side draws. |
| Takistan | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Server/Functions/AI_Commander_Wildcard.sqf` has the same line shape at `:1278-1279`, `:1539`, `:1548-1550`, and `:1619-1629`. |

The important source flow is:

1. W20 selects one raisable support upgrade id.
2. `_w20TierName` converts that id to a player-readable support tier name.
3. `_wDesc` is first loaded from the generic wildcard name map.
4. Applied W20 draws overwrite `_wDesc` with the concrete tier and new level.
5. The final announcement formats `_wName` plus `_wDesc`.

Ineligible W20 draws do not have a chosen tier, so the tier-specific override is
correctly limited to `_result == "applied"`.

## Recommendation

Treat lane 153 as implemented. No source patch is recommended unless runtime
smoke later shows the `LocalizeMessage` popup itself is not reaching a client.

Useful smoke target: force or observe a W20 draw with at least one support tier
below max, then confirm the popup includes one of:

- `Paratroopers support reaches level N`
- `Supply Rate support reaches level N`
- `Gear support reaches level N`

## Verification

- Checked `origin/claude/build84-cmdcon36@b2dbab5f3070c2bc8cacc79c06b9ca5ac20a2493`.
- `rg` confirmed the W20 tier-name, detail-log, description override, and
  announcement send path in both maintained roots.
- `git diff --no-index` found no content diff between the Chernarus and Takistan
  `Server/Functions/AI_Commander_Wildcard.sqf` copies.
- This lane is docs-only; no SQF/SQM/HPP/EXT mission files changed.
- LoadoutManager was not run because no mission source changed.
