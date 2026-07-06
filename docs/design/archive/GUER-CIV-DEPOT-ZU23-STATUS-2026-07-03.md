# GUER Civilian Depot / ZU-23 Dressing Status - 2026-07-03

Base checked: `origin/claude/build84-cmdcon36@b1608b096`.

Lane: fleet lane 12, docs-only split-status audit.

## Scope

Fleet lane 12 asks for two dormant-asset pieces from
`docs/design/UNUSED-ASSETS.md`:

- Row 5: cheap civilian-vehicle depot exposure for GUER players.
- Row 10: static ZU-23 / searchlight town dressing for contested or GUER towns.

This audit does not add or change mission source. It records the current split
between depot work that is already present and town-dressing work that remains a
future source lane.

## Verdict

Lane 12 is partially covered.

The GUER civilian depot source hook is already present on the current target in
Chernarus, Takistan, and Zargabad. It remains default-off through inline
`missionNamespace getVariable ["WFBE_C_GUER_CIVILIAN_DEPOT", 0]` checks.
Merged PR #161 introduced the source path, and open draft PR #361 adds the
matching lobby/constant exposure across all maintained roots.

The ZU-23/searchlight town-dressing half is not implemented as a dedicated
feature on the current target. ZU-23 and searchlight assets exist in pools,
defence lists, structures, and GUER air-defence code, but no scanned
`WFBE_C_*` flag or server/town script seeds contested/GUER towns with the
proposed static ZU-23 plus searchlight dressing.

Do not duplicate the depot work. Keep ZU-23 town dressing as a separate future
source lane, with explicit performance and daylight-server review.

## Coverage Table

| Prompt asset | Source proposal | Current status | Lane status |
| --- | --- | --- | --- |
| GUER civilian depot | `UNUSED-ASSETS.md` fast-win row 5 / lane prompt row: add cheap civilian transport vehicles to the GUER player depot. | Current root files append CIV/TKCIV transports behind `WFBE_C_GUER_CIVILIAN_DEPOT` inline fallback in Chernarus, Takistan, and Zargabad. PR #161 is merged; PR #361 exposes the flag in constants/parameters. | Covered for source hook; parameter exposure pending in PR #361. |
| Static ZU-23 / searchlight town dressing | `UNUSED-ASSETS.md:40` proposes contested/GUER town flavour with static ZU-23 and sweeping searchlights. | Assets exist, but no dedicated town-dressing flag/script was found. GUER defence configs also document prior static-count/server-FPS trimming. | Still open future source work. |

## Current Source Anchors

Civilian depot hook:

- `Root_GUE.sqf:189,194` in all three maintained roots appends Chernarus and
  Takistan civilian transports when `WFBE_C_GUER_CIVILIAN_DEPOT > 0`.
- `Root_TKGUE.sqf:171` in all three maintained roots appends TK civilian
  transports under the same flag.
- `Root_GUE_PlayerOverlay.sqf:51,66` in all three maintained roots applies the
  same flag to the player-facing GUER depot overlay.

ZU-23 / searchlight evidence:

- `UNUSED-ASSETS.md:40` defines the proposed static ZU-23/searchlight dressing.
- `Defenses_GUE.sqf:17-22` shows GUER static defences are currently stripped to
  ZU-23 only, with `SearchLight_Gue` removed for static-count/server-FPS relief.
- `Core_GUE.sqf`, `Groups_GUE.sqf`, and `Root_GUE.sqf` contain ZU-23 vehicle
  and defence assets, but those are roster/pool entries, not town-dressing
  placement logic.
- `rg` found searchlight and ZU-23 classnames in defence/structure/core lists,
  but no dedicated `TOWN_DRESS`, `DRESSING`, `WFBE_C_*ZU*`, or searchlight town
  dressing gate.

## Related PRs

PR #161: https://github.com/rayswaynl/a2waspwarfare/pull/161

- State: merged.
- Adds the default-off GUER civilian depot transport source path.
- Original lane-7 handoff explicitly excluded town dressing and ZU-23 work.

PR #361: https://github.com/rayswaynl/a2waspwarfare/pull/361

- State at audit time: open draft, base `claude/build84-cmdcon36`, CLEAN and
  MERGEABLE.
- Adds `WFBE_C_GUER_CIVILIAN_DEPOT = 0` registration and a lobby parameter row
  across Chernarus, Takistan, and Zargabad.
- Also carries a lane-31 GUER wave-depth parameter; review that as a separate
  lane concern.

## Review Notes

- Do not reopen the civilian-depot source path unless source review finds a
  concrete defect in the current root/overlay hooks.
- ZU-23 town dressing should be its own default-off lane. It likely needs a
  server-side town placement script or a town-init extension, not depot config.
- Keep `Server_GuerAirDef.sqf` separate unless the implementation deliberately
  reuses its placement/cleanup idioms. That file is not a town-dressing module.
- Searchlights need an explicit daylight-server decision. Several structure
  configs already comment that searchlights have zero value under permanent
  daylight settings.

## Verification

- `rg` confirmed the civilian-depot hooks in all three maintained roots.
- `gh pr view 161` confirmed PR #161 is merged.
- `gh pr view 361` / `gh pr diff 361` confirmed the open parameter follow-up.
- `gh pr list --state all --search "ZU-23 town dressing OR ZU23 OR Ural_ZU23"`
  found no current dedicated town-dressing source PR.
- `rg` confirmed ZU-23/searchlight assets and no dedicated town-dressing gate.
- This lane changed documentation only. No SQF/SQM/HPP/EXT mission files changed.
- LoadoutManager was not run because no mission source changed.
