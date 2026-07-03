# GUER Endgame Panel Status - 2026-07-03

## Scope

Lane 146 asks for a third-faction GUER panel on the end-of-round stats screen. This pass is
documentation-only because the current target source already carries the panel logic and title
controls behind a default-off flag.

No mission SQF, generated mirror, packaging, or live runtime settings are changed here. Adjacent
endgame work remains separate: PR #325 covers the lane 157 player summary, PR #364 covers victory
winner plumbing, and PR #375 covers victory-progress announcements.

## Current Source State

The feature flag exists in all maintained `Init_CommonConstants.sqf` copies and defaults off:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:1336`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Common/Init/Init_CommonConstants.sqf:1336`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Common/Init/Init_CommonConstants.sqf:1336`

`GUI_EndOfGameStats.sqf` reads that flag, narrows the existing side-panel width when enabled,
and fetches GUER/resistance counters from `WF_Logic`:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:12`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:13`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:27`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:28`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:29`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:30`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:31`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

When the flag is enabled, the script binds GUER counter/bar controls, lays them out as the third
column, and animates the same four stat families as EAST/WEST:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:72`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:73`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:74`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:75`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:77`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:79`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:90`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:175`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:254`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:257`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:261`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:265`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_EndOfGameStats.sqf:269`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

`Rsc/Titles.hpp` already includes the GUER controls in the `EndOfGameStats` resource and assigns
the GUER control idc range 90300-90307:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:633`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:648`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:649`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:744`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:745`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:750`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:783`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:789`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:822`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:828`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:861`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Rsc/Titles.hpp:867`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

## Status

No source follow-up is needed for the core lane 146 ask on the current target branch. The useful
remaining proof is runtime smoke with `WFBE_C_FIX_GUER_ENDGAME_STATS_PANEL = 1`: finish a round,
confirm the third GUER column appears, and confirm disabling the flag returns the older two-column
layout.

## Verification

- Confirmed the default-off flag in Chernarus, Takistan, and Zargabad constants.
- Confirmed GUER stats collection, control binding, layout, bar animation, and counter update
  anchors in Chernarus, Takistan, and Zargabad `GUI_EndOfGameStats.sqf`.
- Confirmed `Rsc/Titles.hpp` includes GUER endgame controls and idcs 90300-90307 in all maintained
  mission copies.
- Confirmed the three maintained `GUI_EndOfGameStats.sqf` files share one SHA-256 hash.
- Kept this pass documentation-only; LoadoutManager was not required because no mission source
  or generated mirror files changed.
