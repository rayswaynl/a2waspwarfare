# GUER Depot And ZU-23 Status - 2026-07-03

Lane: 12, GUER civilian depot + ZU-23 town dressing

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Scope: docs-only routing/status note. No mission source, generated mirror, package artifact, or live server was changed.

## Verdict

Do not open a duplicate source PR for lane 12 from this pass.

The GUER civilian depot half is already implemented in source and is currently being exposed through open draft PR #361. The ZU-23 town-static half is also source-present through the existing town-defense kind system: placed town defense logics ask for `AA`, GUER's town defense table resolves `AA` to `ZU23_Gue`, and the server town-defense path spawns and mans those statics for resistance-held town defense episodes.

The remaining distinction is wording: the current source provides combat town AA statics, not a new ambient/daylight prop-dressing layer. A future ambience lane would need a separate owner decision, count budget, and placement design.

## Current Source Path

| Surface | Evidence | Status |
| --- | --- | --- |
| Civilian depot backend | `Common/Config/Core_Root/Root_GUE_PlayerOverlay.sqf:51-54`, `:66-80`, and `:94-99` gate extra civilian vehicles behind `WFBE_C_GUER_CIVILIAN_DEPOT` and rebuild `WFBE_GUERDEPOTUNITS`. `Root_GUE.sqf:186-195` re-seeds the same player depot pool after the AI roster load. | Source-present in maintained roots. |
| Civilian depot lobby exposure | Current base has no `WFBE_C_GUER_CIVILIAN_DEPOT` hit in `Rsc/Parameters.hpp` or `Common/Init/Init_CommonConstants.sqf`. Open draft PR #361 adds the missing lobby row and isNil seed. | Route review to #361. |
| Prior depot source PR | Merged PR #161 added the default-off backend and explicitly left constants registration and ZU-23/town dressing out of scope. | Merged; do not duplicate. |
| ZU-23 town defense class | `Common/Config/Defenses/Defenses_GUE.sqf:16-29` strips GUER statics down to `ZU23_Gue`, assigns kind `AA`, and registers it through `Config_Defenses_Towns.sqf`. | Source-present. |
| Placed town slots | `mission.sqm` in Chernarus, Takistan, and Zargabad already contains town defense logics with `wfbe_defense_kind` including `AA` (examples: Chernarus `mission.sqm:575`, Takistan `mission.sqm:276`, Zargabad `mission.sqm:82`). | Existing town-defense slots can resolve to GUER ZU-23. |
| Spawn and manning path | `Server_SpawnTownDefense.sqf:15-31` resolves `WFBE_%1_Defenses_%2` from the logic kind and `:40-47` creates the static. `server_town.sqf:364-380` respawns resistance defenses after recapture; `server_town_ai.sqf:295-299` mans defenses during activation; `Server_OperateTownDefensesUnits.sqf:72-103` creates and seats gunners. | Source-present. |
| GUER ZU-23 vehicles | `Root_GUE.sqf:60-84` and `Root_TKGUE.sqf:63-75` include ZU-23 truck variants in medium/heavy GUER patrol compositions. | Separate from static town-defense path, already present. |

## Routing

Review PR #361 for the host-visible `WFBE_C_GUER_CIVILIAN_DEPOT` parameter/constant exposure. It also owns the GUER wave-depth parameter rows and should not be shadowed by a second lane-12 source PR.

Treat the ZU-23 town-static request as covered by current combat town-defense source unless the owner specifically wants a new ambient dressing system. If that future ambience work happens, keep it daylight-only, count-limited, and separate from `SearchLight_*` rows because the current source already filters searchlights as permanent-daylight/no-function clutter in the structure lists.

No LoadoutManager run is needed for this status note.
