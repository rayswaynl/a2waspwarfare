# QoL Trio Player Hints Reference

> Provenance: verified 2026-06-21 against stable `master@0139a346`, Arma 2 OA 1.64, source mission `Missions/[55-2hc]warfarev2_073v48co.chernarus`.

This page owns the current client-side QoL trio hint layer: salvage payout toasts, upgrade unlock banners and the periodic advisor nudge. Deeper salvage authority, upgrade processing and purchase authority stay on their owner pages.

## Master Gates

| Gate | Default | Source | Effect |
| --- | ---: | --- | --- |
| `WFBE_C_QOL_TRIO` | `1` | `Common/Init/Init_CommonConstants.sqf:553-555` | Master switch for all three QoL hint features; `0` disables the salvage toast, upgrade banner and advisor loop. |
| `WFBE_C_QOL_ADVISOR_INTERVAL` | `300` | `Common/Init/Init_CommonConstants.sqf:553-555` | Advisor sleep/check interval in seconds; `0` disables the advisor. |
| Advisor compile | n/a | `Client/Init/Init_Client.sqf:178-182` | Compiles `Client_QOL_Advisor.sqf` into `WFBE_CL_FNC_QOL_Advisor`. |
| Advisor start | n/a | `Client/Init/Init_Client.sqf:404-409` | Spawns the advisor loop after common init is complete and after the client update FSM/actions are started. |

## Hint Surfaces

| Surface | Trigger | Client-visible output | Source |
| --- | --- | --- | --- |
| Salvage payout toast | `updatesalvage.sqf` has positive `_overAllCost` after the salvage pass and `WFBE_C_QOL_TRIO > 0`. | `hintSilent` payout line showing the salvaged amount. | `Client/FSM/updatesalvage.sqf:50-55` |
| Upgrade unlock banner | `WFBE_CL_FNC_Upgrade_Complete` runs for upgrade ids `0..3` while `WFBE_C_QOL_TRIO > 0`. | `hintSilent` banner naming the completed factory upgrade level and up to three newly unlocked unit labels. | `Client/Functions/Client_FNC_Special.sqf:192-235` |
| Upgrade completion sound | Same upgrade-complete handler, but sound is separately gated by `_upgrade_isplayer`. | `ARTY_cooldown_over` only plays for player-initiated upgrades, while the banner gate is independent of `_upgrade_isplayer`. | `Client/Functions/Client_FNC_Special.sqf:196-202,238-243` |
| Advisor unspent-funds nudge | The player is alive, the last purchase is older than one advisor interval, and funds are at least twice the cheapest light-factory vehicle price. | `hintSilent` nudge telling the player to visit a factory or the gear menu. | `Client/Functions/Client_QOL_Advisor.sqf:30-45,55-75` |
| Advisor commander Patrols nudge | Once per session, if the player is the commander, round time is over 900 seconds, the side holds at least 3 towns, and `WFBE_UP_PATROLS` is still level 0. | `hintSilent` commander tip to research Patrols. | `Client/Functions/Client_QOL_Advisor.sqf:77-90` |

## Purchase Timestamp Coupling

The advisor does not inspect factory queues directly. It reads `WFBE_QOL_LAST_PURCHASE_TIME`, which is initialized to `time` when the advisor starts so the first nudge waits a full interval. `Client/Functions/Client_QOL_Advisor.sqf:47-50`

The Buy Units menu stamps the same variable after it spawns the selected purchase request and debits funds, but only when `WFBE_C_QOL_TRIO > 0`. `Client/GUI/GUI_Menu_BuyUnits.sqf:163-169`

## Boundaries

| Boundary | Practical rule | Source |
| --- | --- | --- |
| Client-local UX | These features emit local `hintSilent` or sound feedback; they are not server authority checks. | `Client/FSM/updatesalvage.sqf:52-55`; `Client/Functions/Client_FNC_Special.sqf:229-235`; `Client/Functions/Client_QOL_Advisor.sqf:70-73` |
| Salvage authority | The salvage toast does not own salvage payout correctness or the existing `ChangePlayerfunds` casing debt. Route that through [Construction/CoIn](Construction-And-CoIn-Systems-Atlas#salvage-branch-matrix). | `Client/FSM/updatesalvage.sqf:50-55` |
| Upgrade economy | The banner reads side unit lists and labels after completion; upgrade purchase, supply/funds validation and queue state stay with [Upgrades/research](Upgrades-And-Research-Atlas). | `Client/Functions/Client_FNC_Special.sqf:204-235` |
| Feature flags | The two QoL constants are non-lobby hardcoded gates, indexed with the other experimental constants. | `Common/Init/Init_CommonConstants.sqf:553-555`; [Experimental feature-flag constants](Experimental-Feature-Flag-Constants-Reference#qol-trio-lines-553555) |

## Continue Reading

- [Experimental feature-flag constants](Experimental-Feature-Flag-Constants-Reference)
- [Player UI workflow](Player-UI-Workflow-Map)
- [Factory and purchase systems](Factory-And-Purchase-Systems-Atlas)
- [Upgrades and research](Upgrades-And-Research-Atlas)
- [Construction and CoIn systems](Construction-And-CoIn-Systems-Atlas)
