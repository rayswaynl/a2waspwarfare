# Death Text Status - 2026-07-03

## Scope

Lane 144 asks for a "Killed by" death text check on the client death flow. This pass is
documentation-only: the maintained mission copies already carry the death text source path, so
no mission SQF, generated mirror, packaging, or runtime setting changes are included here.

## Current Source State

`Client_OnKilled.sqf` initializes the death message with a fallback:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_OnKilled.sqf:13`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_OnKilled.sqf:13`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_OnKilled.sqf:13`

When the killed event supplies a player killer, the client formats the message as
`Killed by %1.` with the killer player name:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_OnKilled.sqf:27`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_OnKilled.sqf:27`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_OnKilled.sqf:27`

For non-player killers, it resolves the killer vehicle display name and formats the same
`Killed by %1.` text:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_OnKilled.sqf:37`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_OnKilled.sqf:37`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_OnKilled.sqf:37`

The final display call is shared across the maintained copies:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_OnKilled.sqf:104`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_OnKilled.sqf:104`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_OnKilled.sqf:104`

## Status

No source follow-up is needed for the basic lane 144 death text ask. Nearby death-camera work
continues to live separately, so this note intentionally does not mix camera behavior with the
existing text display path.

## Verification

- Confirmed the fallback, player-killer, vehicle-killer, and `titleText` anchors in Chernarus.
- Confirmed the same anchors in the Takistan and Zargabad maintained vanilla mission copies.
- Kept this pass documentation-only; LoadoutManager was not required because no mission source
  or generated mirror files changed.
