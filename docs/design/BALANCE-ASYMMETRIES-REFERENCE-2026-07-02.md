# Balance Asymmetries Reference - 2026-07-02

Lane 187 scope: document the current balance asymmetries on `claude/build84-cmdcon36`; do not retune them. This is a source-cited reference for future economy and GUER wiki work.

## Executive Summary

The current live-lane balance model is intentionally asymmetric:

| Area | Current shape | Source anchors |
| --- | --- | --- |
| GUER baseline income | GUER player groups receive a server stipend every 60 seconds: 150 funds/min plus 10 funds/min for each GUER-held town lost since round start, capped at 450 funds/min. | `Server/Server_GuerStipend.sqf:19-21`, `:77-94` |
| GUER checkpoint toll | The GUER checkpoint wildcard pays `250 * (1 + tier)` funds per 30-second tick to resistance clients while the checkpoint survives, while draining `60 * (1 + tier)` supply from the occupier. | `Server/Functions/AI_Commander_Wildcard_GUER.sqf:41-43`, `:265-277` |
| GUER kill-tech runway | GUER vehicle tiers are pure cumulative player kills. Defaults are 30/80/160, doubled from the older 15/40/80 comments, while normal GUER kill cash pays `unit price * 0.5` and IED-tagged kills pay `unit price * 0.30`. | `Common/Init/Init_CommonConstants.sqf:80-81`, `:108-110`; `Server/PVFunctions/RequestOnUnitKilled.sqf:110-152` |
| CO vs GUE Build Ammo dependency | CO_US and CO_RU require Gear 5 for Build Ammo; GUE and CO_GUE require Gear 2. | `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:109`, `Upgrades_CO_RU.sqf:109`, `Upgrades_GUE.sqf:109`, `Upgrades_CO_GUE.sqf:109` |
| CO vs GUE Supply L3 | CO_US and CO_RU price Supply L3 at 8000; GUE and CO_GUE price Supply L3 at 6000. | `Upgrades_CO_US.sqf:39`, `Upgrades_CO_RU.sqf:39`, `Upgrades_GUE.sqf:39`, `Upgrades_CO_GUE.sqf:39` |
| W1 War Chest scale | W1 has common-deck weight 17 and grants 25% of side start funds. With WEST/EAST start funds at 30000, the normal bonus is 7500, much smaller than late-game SCUD and economy-sink numbers. It is also zeroed for AI sides already above 2x side start funds, while human commanders remain eligible. | `Server/Functions/AI_Commander_Wildcard.sqf:13`, `:332-336`, `:600-619`; `Common/Init/Init_CommonConstants.sqf:1203-1207` |

## GUER Income Lanes

The baseline GUER player economy is a stipend, not a commander economy. `Server_GuerStipend.sqf` exits unless `WFBE_C_GUER_PLAYERSIDE > 0`, then pays each unique living GUER player group once per 60-second loop. The rate is:

```text
rate = min(150 + ((startGuerTowns - currentGuerTowns) max 0) * 10, 450)
```

That means a GUER group sitting at no town deficit gets 150 funds/minute; a deep deficit caps at 450 funds/minute. This is intentionally personal/team cash, not side supply and not an AI commander treasury. The normal `updateresources.sqf` economy explicitly excludes resistance from the WEST/EAST commander/supply loop.

The checkpoint toll is a burst lane layered on top of the stipend. The GUER wildcard file documents `WFBE_C_GUER_CP_TOLL` default 250 and applies it as `_toll = 250 * (1 + tier)` every 30 seconds while the checkpoint group is alive. Converted to per-minute pressure, that is:

| GUER tier | Toll per 30s | Cash/min while held |
| --- | ---: | ---: |
| 0 | 250 | 500 |
| 1 | 500 | 1000 |
| 2 | 750 | 1500 |
| 3 | 1000 | 2000 |

This is intentionally much hotter than the passive stipend, but it is conditional on drawing and holding the checkpoint event.

## Kill-Tech Compounding

GUER tech progression is no longer time-based. The server increments `WFBE_GUER_PLAYER_KILLS` by exactly 1 when a GUER player kills a WEST/EAST unit, and the stipend loop derives vehicle tier from the live kill total. The live defaults are 30, 80, and 160 kills in `Init_CommonConstants.sqf`.

The same kill event also pays the GUER team using a coefficient. Normal kills use `WFBE_C_GUER_KILL_BOUNTY_COEF = 0.5`; IED-tagged kills use `WFBE_C_GUER_IED_KILL_COEF = 0.30`. So the tech counter itself is 2x slower than the older 15/40/80 threshold comments, and the money earned along that kill runway is half-value for normal kills. Read this as two independent levers: kill events unlock vehicles, while the bounty coefficient controls how much usable cash the same events generate.

Playable GUER is still not a normal upgrade side: `Common_GetSideUpgrades.sqf:13` falls back to a zero upgrade array for GUER so callers do not error. The GUE/CO_GUE upgrade tables are still relevant for faction/config parity and AI-side references, but player GUER progression is kill-tier plus depot pools, not a conventional upgrade queue.

## Upgrade Table Asymmetries

The Combined Operations US/RU tables carry the stricter late-game Build Ammo dependency:

```text
CO_US / CO_RU Build Ammo dependency: [[WFBE_UP_GEAR,5]]
GUE / CO_GUE Build Ammo dependency: [[WFBE_UP_GEAR,2]]
```

The same CO pair also pays more for Supply L3:

```text
CO_US / CO_RU Supply costs: [[2700,0],[4800,0],[8000,0]]
GUE / CO_GUE Supply costs: [[2700,0],[4800,0],[6000,0]]
```

This is not a proposed fix. It is the current asymmetry to keep visible before any later balance-retune lane touches upgrade dependencies or prices.

## W1 War Chest Scale

W1 is labelled as a common War Chest card with weight 17. Its actual payout is `round(sideStartFunds * 0.25)`. On the current normal constants, WEST and EAST start funds are 30000, so W1 normally adds 7500.

That 7500 is meaningful for a human commander's team wallet, but it is modest against late-game commander and SCUD numbers:

| Reference | Current value | Source |
| --- | ---: | --- |
| WEST/EAST side start funds | 30000 | `Common/Init/Init_CommonConstants.sqf:1203-1204` |
| W1 bonus at normal start funds | 7500 | `AI_Commander_Wildcard.sqf:603-604` |
| AI commander start funds | 200000 | `Init_CommonConstants.sqf:1207` |
| Normal AI commander stipend | 6000/min | `Init_CommonConstants.sqf:512-514` |
| Hard AI commander stipend | 9000/min | `Init_CommonConstants.sqf:512-514` |
| AICOM wealth cap | 1500000 | `Init_CommonConstants.sqf:601` |
| Funds-sink threshold | 1000000 | `Init_CommonConstants.sqf:624`; `Server/AI/Commander/AI_Commander_FundsSink.sqf:46` |
| SATURATION TEL shot | 12000 | `Init_CommonConstants.sqf:918` |
| FASCAM TEL shot | 14000 | `Init_CommonConstants.sqf:924` |
| BUNKER BUSTER TEL shot | 18000 | `Init_CommonConstants.sqf:935` |
| Carrier SCUD strike | 25000 | `Init_CommonConstants.sqf:1703` |
| Takistan buyable SCUD hull | 28000 | `Init_CommonConstants.sqf:945` |
| SCUD research L1/L2 | 18000+10000, then 49500+80000 | `Common/Config/Core_Upgrades/Upgrades_CO_US.sqf:44` |

For AI commanders, W1 is also gated: if the side is not human-commanded and its AI treasury is already above `2 * WFBE_C_ECONOMY_FUNDS_START_<side>`, W1 becomes ineligible. With the current 30000 side-start constant, that gate is 60000; the AI commander start treasury is 200000. So W1 is mostly a human-commander boost or a comeback/low-treasury AI boost, not a late-game solution.

## Non-Changes

- No constants, params, upgrade arrays, wildcard weights, or economy behavior changed.
- No mission source changed, so LoadoutManager was not run.
- No `_MISSIONS.7z`, package, deployment, or live-server action is part of this lane.
