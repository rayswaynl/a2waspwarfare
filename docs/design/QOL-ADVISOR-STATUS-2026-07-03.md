# QOL Advisor Status - 2026-07-03

## Scope

Lane 158 asks for QOL Advisor expansion covering new-commander, EASA, economy-slider,
and supply-delivery nudges. This pass is documentation-only: the current target source already
contains those advisor branches, so no mission SQF, generated mirror, packaging, or live runtime
settings are changed here.

## Current Source State

The advisor source names the lane 158 expansion directly and lists the four added reminder
families:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:19`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_QOL_Advisor.sqf:19`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_QOL_Advisor.sqf:19`

The first-time commander reminder fires once for the side commander after the opening orientation
window:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:70`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_QOL_Advisor.sqf:70`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_QOL_Advisor.sqf:70`

The economy-slider reminder reports the current commander income share:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:78`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_QOL_Advisor.sqf:78`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_QOL_Advisor.sqf:78`

The EASA reminder is gated to an EASA-capable vehicle while the EASA module is active:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:102`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:106`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_QOL_Advisor.sqf:102`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_QOL_Advisor.sqf:102`

The supply-delivery reminder checks the player's vehicle or cursor target against side supply
truck and supply helicopter type lists, then distinguishes loaded and empty cargo:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:117`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:131`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:133`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_QOL_Advisor.sqf:117`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_QOL_Advisor.sqf:117`

The older unspent-funds advisor branch remains after the one-shot tips, so the expansion does not
remove the original nudge:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:140`
- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_QOL_Advisor.sqf:173`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_QOL_Advisor.sqf:173`
- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/Functions/Client_QOL_Advisor.sqf:173`

## Wiring

All maintained copies compile and spawn the advisor from `Init_Client.sqf`:

- `Client/Init/Init_Client.sqf:259` compiles `Client_QOL_Advisor.sqf`.
- `Client/Init/Init_Client.sqf:863` spawns `WFBE_CL_FNC_QOL_Advisor`.

The shared QoL toggle and interval are present in all maintained `Init_CommonConstants.sqf`
copies:

- `WFBE_C_QOL_TRIO` at line 1515.
- `WFBE_C_QOL_ADVISOR_INTERVAL` at line 1516.

## Status

No source follow-up is needed for the core lane 158 ask on the current target branch. Adjacent
open work remains separate: PR #282 covers EASA-for-AI documentation, PR #380 covers other client
QoL batch items, and PR #386 covers the economy transaction ticker.

## Suggested Smoke

- As side commander, wait past 5 minutes and confirm the commander-basics hint appears once.
- Stay commander past 10 minutes and confirm the economy-slider hint reports the current share.
- Enter an EASA-capable aircraft with the EASA module active and confirm the EASA service-point
  hint appears once.
- Enter or look at a side supply vehicle, both empty and loaded if possible, and confirm the
  pickup/delivery hint text.

## Verification

- Confirmed all lane 158 advisor anchors in Chernarus, Takistan, and Zargabad.
- Confirmed the three `Client_QOL_Advisor.sqf` files have identical SHA-256 hashes.
- Confirmed compile/spawn wiring and QoL constants in all maintained mission copies.
- Kept this pass documentation-only; LoadoutManager was not required because no mission source
  or generated mirror files changed.
