# FOUND_REQUIRE_FACTORY Final-Pick No-Change Verification

<!-- GUIDE-REV: GR-2026-07-03a -->

Lane: Block M lane 337
Base checked: `origin/claude/build84-cmdcon36@fbf7afff960a0b3ef38e5e7505b6bab6ea31b373`
Verdict: no mission source change is needed.

## Finding

The lane prompt warned that `WFBE_C_AICOM_FOUND_REQUIRE_FACTORY` could still trust the
original `_chosen` bucket after W7 Veteran Company or FORCED-ARTY changed `_pick`.
The current Build84 source already handles this case: the gate initializes `_wantType`
from `_chosen`, then prefers `_storedTypes select _pick` after all final-pick mutations.

## Evidence

| Area | Source anchor | Result |
| --- | --- | --- |
| W7 Veteran Company | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:774-793` | W7 can replace `_pick` with `_w7BestIdx` or an anti-repeat reroll. |
| FORCED-ARTY override | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:795-799` | The forced artillery index is the last direct `_pick` override before later composition logic. |
| Factory gate | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:1029-1041` | The owned-factory gate runs after the final `_template` / price / funds setup. |
| Final-pick type lookup | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:1063-1070` | The comments explicitly name W7 / anti-repeat / FORCED-ARTY, and `_wantType` is overridden from `_storedTypes select _pick` when available. |
| Gate decision | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/AI/Commander/AI_Commander_Teams.sqf:1072-1102` | `_typeOK` and any factory re-anchor use `_wantType`, so matching follows the final selected template type. |

## Why This Is Docs-Only

Adding another derived variable near the gate would duplicate the existing guarded
lookup and add churn to `AI_Commander_Teams.sqf`. The current implementation already
matches the intended fix, including a comment that documents the exact W7 and
FORCED-ARTY cross-bucket case.

The fallback remains intentional: if `_storedTypes` is missing or the final `_pick`
is out of range, `_wantType` falls back to `_chosen`, then infantry. This preserves
the existing ship-safe behavior without changing live mission logic.

## Validation

- Read the current Chernarus source anchors for W7, FORCED-ARTY, the factory gate,
  and the final-pick `_storedTypes` lookup.
- Checked for an active lane 337 PR, matching remote branch, and wiki owner before
  claiming this no-change lane.
- No mission source files were edited.
- LoadoutManager was not run because this is a docs-only verification.

## Out Of Scope

- Changing W7 Veteran Company selection.
- Changing FORCED-ARTY priority.
- Changing `WFBE_C_AICOM_FOUND_REQUIRE_FACTORY` defaults or starvation safety.
- Editing `AI_Commander_Teams.sqf`.
