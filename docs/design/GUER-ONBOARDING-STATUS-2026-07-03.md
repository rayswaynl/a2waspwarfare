# GUER Onboarding Status - 2026-07-03

## Scope

Lane 150 asks for a GUER onboarding card explaining the playable resistance role: kill-gated
field tech, FOB tokens, and the harass-focused toolbox. This pass is documentation-only because
the current target source already contains that GUER-specific onboarding card in all maintained
mission copies.

No mission SQF, generated mirror, packaging, or live runtime settings are changed here. Adjacent
onboarding work remains separate: PR #257 covers broader onboarding coverage, and PR #394 covers
contextual first-time hints.

## Current Source State

`Common_Onboarding.sqf` is a client-only, once-per-session onboarding sequence. It self-gates on
`WFBE_C_ONBOARDING_ENABLE`, waits for a real alive player, and then detects playable GUER by
checking both `sideJoined in [resistance]` and `WFBE_C_GUER_PLAYERSIDE > 0`:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:34`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:40`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:53`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:56`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

The GUER card is explicitly marked as card 3 and is only shown when `_isGuer` is true:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:85`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:86`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Common_Onboarding.sqf:85`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Common_Onboarding.sqf:85`

The card title and body explain the core GUER differences:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:88`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:89`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Common_Onboarding.sqf:90`
- Same line anchors are present in the Takistan and Zargabad maintained copies.

Those lines cover:

- no standard commander upgrade queue for resistance players;
- kills unlocking field tech;
- destroyed enemy factories unlocking FOB truck options;
- action/buy menu entries for VBIED, mortar truck, and FOB truck plays;
- RHUD `Tech Kills` and `FOB` token rows.

The onboarding sequence is spawned from `Init_Client.sqf` in every maintained mission copy after
client init has completed:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf:1604`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Init/Init_Client.sqf:1608`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Init/Init_Client.sqf:1604`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Init/Init_Client.sqf:1604`

## Status

No source follow-up is needed for the core lane 150 ask on the current target branch. The useful
remaining proof is a first-spawn smoke as playable GUER with `WFBE_C_ONBOARDING_ENABLE` active:
confirm card 3 appears after the generic welcome/action-menu cards, and confirm WEST/EAST players
do not receive the GUER card.

## Verification

- Confirmed the playable-GUER gate and card text anchors in Chernarus, Takistan, and Zargabad.
- Confirmed `Init_Client.sqf` spawns the onboarding sequence in all maintained mission copies.
- Confirmed the three maintained `Common_Onboarding.sqf` files share one SHA-256 hash.
- Kept this pass documentation-only; LoadoutManager was not required because no mission source
  or generated mirror files changed.
