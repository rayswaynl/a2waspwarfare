# Balance Asymmetries Reference

Date: 2026-07-02
Lane: fleet lane 187, docs-only reference
Base checked: `origin/claude/build84-cmdcon36` at `b1608b096`

## Scope

This is a source-cited reference for the current GUER and commander-economy
balance asymmetries on the live lane. It is intended as wiki seed material and
review context, but this branch does not publish wiki pages directly.

No mission source, generated mirrors, lobby defaults, economy constants, package
artifacts, or live runtime settings are changed here.

## Verdict

The current lane has several intentional-looking asymmetries worth documenting
before any balance retune:

- GUER checkpoint toll income can exceed the regular GUER stipend by a wide
  margin while a checkpoint remains uncleared.
- GUER tech kills are not halved by the bounty coefficient. The tech counter is
  incremented by exactly `+1` per eligible resistance-player kill; the `0.5`
  coefficient applies to cash bounty only.
- The "slower GUER tech" pressure comes from doubled kill-tier thresholds
  (`30/80/160`, formerly `15/40/80`) plus reduced kill cash, not from a direct
  fractional tech-kill multiplier.
- Playable GUER is not a normal upgrade-queue side. The GUE/CO_GUE upgrade
  tables are still useful parity references, but the player GUER lane is
  kill-tier plus depot pools.
- CO RU/US keep stricter late-game upgrade dependencies than the other faction
  upgrade files: `AIR 5` for ICBM and `GEAR 5` for Build Ammo.
- W1 War Chest is a modest cash-only wildcard at current start-funds values. It
  is not a supply fix and is often ineligible for AI commanders while their AI
  wallet remains above the rich gate.

## Source Anchors

| Topic | Source anchors |
| --- | --- |
| GUER stipend formula | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Server_GuerStipend.sqf:1-21`, `:76-107` |
| GUER excluded from normal side economy loop | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/FSM/updateresources.sqf:153` |
| GUER kill-tier constants | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:98-115` |
| GUER bounty coefficients | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:80-81`, `:1482` |
| GUER tech kill increment and cash bounty split | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/PVFunctions/RequestOnUnitKilled.sqf:104-152`, `:286-304` |
| GUER checkpoint toll/tax/clear math | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard_GUER.sqf:37-43`, `:264-278` |
| Checkpoint/player wallet receiver | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/PVFunctions/GuerVbiedBounty.sqf:1-20` |
| GUER upgrade fallback | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Functions/Common_GetSideUpgrades.sqf:7-16` |
| CO/GUE upgrade costs and links | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Config/Core_Upgrades/Upgrades_CO_RU.sqf:32-58`, `:104-109`; `Upgrades_CO_US.sqf:32-58`, `:104-109`; `Upgrades_GUE.sqf:24-28`, `:32-58`, `:104-109`; `Upgrades_CO_GUE.sqf:24-28`, `:32-58`, `:104-109` |
| Full ICBM/Build Ammo reachability audit | `docs/design/ICBM-BUILD-AMMO-TIER5-GATE-AUDIT-2026-07-02.md` |
| W1 wildcard deck weight, gate, and payout | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Server/Functions/AI_Commander_Wildcard.sqf:12-13`, `:328-336`, `:600-619` |
| Wildcard and start-funds constants | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:516-519`, `:1201-1208` |
| Late-game economy scale references | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Common/Init/Init_CommonConstants.sqf:512-514`, `:601`, `:623-624`, `:918-945`, `:1702-1704`; `Server/AI/Commander/AI_Commander_FundsSink.sqf:31-50` |

## GUER Stipend vs Checkpoint Toll

The regular GUER player economy is a stipend, not a normal commander/supply
economy. The stipend script exits unless `WFBE_C_GUER_PLAYERSIDE > 0`, then pays
each unique living GUER player group once per 60-second loop:

- Base rate: `150` cash per minute.
- Town-deficit bonus: `+10` cash per missing GUER-held town below the starting
  count.
- Cap: `baseRate * 3`, so `450` cash per minute.
- Recipient model: paid once per unique living GUER player group.

In formula form:

```text
rate = min(150 + ((startGuerTowns - currentGuerTowns) max 0) * 10, 450)
```

The normal `updateresources.sqf` side-income loop explicitly iterates
`WFBE_PRESENTSIDES - [resistance]`, so GUER is not running through the regular
WEST/EAST commander economy path.

The insurgent checkpoint toll uses different timing and scaling:

- Base toll: `WFBE_C_GUER_CP_TOLL`, default `250`.
- Tick cadence: every `30` seconds while the checkpoint is alive and uncleared.
- Tier scaling: `250 * (1 + tier)`.
- Recipient path: server broadcasts `GuerVbiedBounty` to resistance clients; the
  client receiver credits the local player's wallet through `ChangePlayerFunds`.

That means a single uncleared checkpoint pays the following gross toll stream to
eligible GUER recipients:

| GUER tier | Toll per 30s tick | Gross per minute |
| ---: | ---: | ---: |
| 0 | 250 | 500 |
| 1 | 500 | 1,000 |
| 2 | 750 | 1,500 |
| 3 | 1,000 | 2,000 |

Even tier 0 checkpoint income is above the deepest regular stipend cap
(`500/min` vs `450/min`). Higher tiers turn checkpoints into a much larger
temporary cash accelerant than the fallback stipend.

The toll also drains occupier supply by `60 * (1 + tier)` per 30-second tick and
grants `700 * (1 + tier)` supply to the clearing side if the checkpoint is wiped.
That makes the event a three-way pressure tool: GUER player cash, occupier supply
bleed, and counterplay reward.

## GUER Tech Kills vs Bounty Cash

`RequestOnUnitKilled.sqf` has two separate GUER paths:

- Tech progression: if a resistance player kills a WEST/EAST unit, the server
  sets `WFBE_GUER_PLAYER_KILLS = current + 1` and broadcasts it.
- Cash bounty: if the killer is a GUER WF team, the killed unit price is
  multiplied by a GUER-specific coefficient and paid to the killer group.

Current constants:

| Value | Constant | Source |
| ---: | --- | --- |
| 30 kills | `WFBE_C_GUER_KILLTIER_1` | vehicle tier 1 |
| 50 kills | `WFBE_C_GUER_VBIED_M113_KILLS` | M113 VBIED |
| 80 kills | `WFBE_C_GUER_KILLTIER_2` | vehicle tier 2 |
| 160 kills | `WFBE_C_GUER_KILLTIER_3` | vehicle tier 3 |
| 0.5 | `WFBE_C_GUER_KILL_BOUNTY_COEF` | normal GUER kill cash |
| 0.30 | `WFBE_C_GUER_IED_KILL_COEF` | IED-tagged GUER kill cash |
| 1 | `WFBE_C_UNITS_BOUNTY_COEF` | normal non-GUER unit bounty coefficient |

The important correction is that the `0.5` GUER bounty coefficient does not
multiply the tech counter. A valid GUER player kill counts as one tech kill.

The effective slowdown is therefore layered:

- Tech thresholds are doubled relative to the comments' old values
  (`15/40/80` became `30/80/160`).
- Kill cash is half the normal unit-price bounty, or `0.30` for IED-tagged kills.
- Reduced cash can indirectly slow purchases, but it does not make a 30-kill
  tech gate require 60 credited kills.

Playable GUER also differs from normal WEST/EAST upgrade play. `GetSideUpgrades`
returns the live GUER upgrade array if present, but falls back to a zero array so
callers do not error. Player GUER progression is driven by kill-tier and depot
pools, not by a conventional player commander upgrade queue.

## CO vs GUE Upgrade Dependencies

The existing tier-5 audit is the canonical source for full upgrade-file parity:

`docs/design/ICBM-BUILD-AMMO-TIER5-GATE-AUDIT-2026-07-02.md`

Summary for this balance reference:

- All maintained faction upgrade files make `AIR 5` and `GEAR 5` reachable.
- `Upgrades_CO_RU.sqf` and `Upgrades_CO_US.sqf` require `AIR 5` for both ICBM
  levels and `GEAR 5` for Build Ammo.
- The other nine faction files require `AIR 3` for both ICBM levels and
  `GEAR 2` for Build Ammo.

The cost rows add another CO-vs-GUE economy asymmetry visible in the checked
files:

| File family | Supply L1/L2/L3 | ICBM L1/L2 | Gear L1-L5 | Build Ammo | Unit cost modifier |
| --- | --- | --- | --- | --- | --- |
| CO US/RU sample | `2700/4800/8000` | `18000+10000 supply` / `49500+80000 supply` | `250/650/1200/2100/2400` | `750` gated by `GEAR 5` | `25000/50000` |
| GUE/CO_GUE sample | `2700/4800/6000` | same cash/supply row | same gear row | `750` gated by `GEAR 2` | costs present, feature disabled in enabled flags |

This branch does not decide whether the stricter CO RU/US gates are intended
late-game pacing or a parity drift. It only records that the gates are reachable
and asymmetrical.

## W1 War Chest Scale

W1 is labelled as a common War Chest card with deck weight `17`. The AI commander
wildcard worker is enabled by default and currently uses a 900-second interval
constant. W1 applies `round(FUNDS_START * 0.25)`.

Current start-funds constants:

| Side constant | Value | W1 amount |
| --- | ---: | ---: |
| `WFBE_C_ECONOMY_FUNDS_START_WEST` | 30,000 | 7,500 |
| `WFBE_C_ECONOMY_FUNDS_START_EAST` | 30,000 | 7,500 |
| `WFBE_C_ECONOMY_FUNDS_START_GUER` | 20,000 | 5,000 |

For human-commanded sides, W1 credits the commander team's `wfbe_funds`. For AI
commanders, W1 credits the AI commander wallet, but the draw is ineligible while
the AI wallet is at or above `2 * FUNDS_START`. With WEST/EAST start funds, that
gate is `60,000`; the AI commander start wallet is currently `200,000`.

So W1 is not an opener-scale windfall for AI commanders on the current lane. It
becomes eligible only after the AI wallet falls below the rich gate, and even
then the WEST/EAST payout is `7,500` cash. That is smaller than many late-game
cash costs and does not grant supply.

Reference scale:

| Reference | Current value | Source |
| --- | ---: | --- |
| WEST/EAST side start funds | 30,000 | `Init_CommonConstants.sqf:1203-1204` |
| W1 bonus at normal WEST/EAST start funds | 7,500 | `AI_Commander_Wildcard.sqf:603-604` |
| AI commander start funds | 200,000 | `Init_CommonConstants.sqf:1207` |
| Normal AI commander stipend | 6,000/min | `Init_CommonConstants.sqf:512-514` |
| Hard AI commander stipend | 9,000/min | `Init_CommonConstants.sqf:512-514` |
| AICOM wealth cap | 1,500,000 | `Init_CommonConstants.sqf:601` |
| Funds-sink threshold | 1,000,000 | `Init_CommonConstants.sqf:623-624`; `AI_Commander_FundsSink.sqf:31-50` |
| SATURATION TEL shot | 12,000 | `Init_CommonConstants.sqf:918` |
| FASCAM TEL shot | 14,000 | `Init_CommonConstants.sqf:924` |
| BUNKER BUSTER TEL shot | 18,000 | `Init_CommonConstants.sqf:935` |
| Carrier SCUD strike | 25,000 | `Init_CommonConstants.sqf:1702-1704` |
| Takistan buyable SCUD hull | 28,000 | `Init_CommonConstants.sqf:944-945` |
| ICBM L1 research | 18,000 cash + 10,000 supply | `Upgrades_CO_US.sqf:44` |
| ICBM L2 research | 49,500 cash + 80,000 supply | `Upgrades_CO_US.sqf:44` |
| Unit Cost Modifier | 25,000 then 50,000 cash | `Upgrades_CO_US.sqf:55` |

Some of these are scale references rather than always-active spenders; for
example, the funds sink is default-off unless its enable constant is raised.
The comparison still shows the W1 bonus is a commander-funds nudge, especially
for humans, not a replacement for the supply economy or a guaranteed late-game
unlock lever.

## Suggested Wiki Cross-Links

If this becomes wiki content, link it from:

- Economy / commander funds reference.
- GUER playable faction reference.
- Insurgent checkpoint and wildcard-event notes.
- Upgrade dependency or late-game tech reference.
- ICBM / Build Ammo tier-5 gate audit.

## Out of Scope

- Retuning GUER stipend, checkpoint toll, tax, clear reward, or kill thresholds.
- Changing GUER bounty coefficients.
- Normalizing CO RU/US upgrade links.
- Changing W1 War Chest eligibility, amount, interval, or deck weight.
- Editing `Parameters.hpp`, mission SQF/SQM/EXT/HPP source, generated mirrors,
  packaged artifacts, or live server settings.

## Verification

- Re-read the cited Chernarus source files on `origin/claude/build84-cmdcon36`.
- Confirmed the GUER tech counter increments by exactly one per eligible kill.
- Confirmed the GUER bounty coefficient is cash-only in the cited kill path.
- Confirmed checkpoint toll math, stipend math, W1 math, late-game economy scale
  references, and upgrade rows from source anchors.
- Confirmed this branch is docs-only. LoadoutManager was not run because no
  mission source or generated mirror changed.
