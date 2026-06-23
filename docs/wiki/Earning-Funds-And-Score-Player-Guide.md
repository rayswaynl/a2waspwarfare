# Earning Funds and Score Player Guide (how to get paid)

> Source-verified 2026-06-21 against master f8a76de34. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

This guide explains how a **player** earns money and score in WASP Warfare, and how to maximise your income. If you are brand new, read the [New player quickstart](New-Player-Quickstart-Guide) first.

## Two different currencies

| Currency | Who owns it | What it buys |
|----------|-------------|--------------|
| **Personal funds** | You, individually | Your gear, your vehicles, vehicle services. Tracked client-side (`Client/Functions/Client_ChangePlayerFunds.sqf`). |
| **Side supply** | The whole team | The commander's structures, upgrades and AI economy. Grown by captured-town income (`Common/Functions/Common_ChangeSideSupply.sqf`). |

The rewards below pay your **personal funds** unless noted. Side supply is the shared war chest the economy feeds automatically — see [Economy, towns and supply](Economy-Towns-And-Supply) and the [income-tick engine](Resource-Income-Tick-Distribution-Engine). You do not spend side supply directly as a soldier.

## How you earn personal funds

| Action | Reward | Source |
|--------|-------:|--------|
| Capture a town | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE` (`Common/Init/Init_CommonConstants.sqf:638`) |
| Assist a town capture | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE_ASSIST` (`:639`) |
| Capture-mission objective | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION` (`:640`) |
| Capture-mission assist | $2,000 | `WFBE_C_PLAYERS_BOUNTY_CAPTURE_MISSION_ASSIST` (`:641`) |
| Supply delivery | town supply value × 4 | `WFBE_C_PLAYERS_SUPPLY_TRUCKS_DELIVERY_FUNDS_COEF = 4` (`:662`) |
| Kill an enemy unit/vehicle | the kill target's **purchase price** × 1 | `WFBE_C_UNITS_BOUNTY = 1` (enabled, `:743`) · `WFBE_C_UNITS_BOUNTY_COEF = 1` (`:752`) |

### Kill bounties scale with the target's value

A kill pays you the **price the enemy paid to field that unit**, times the bounty coefficient (`WFBE_C_UNITS_BOUNTY_COEF = 1`, `Init_CommonConstants.sqf:752`). The bounty system must be enabled (`WFBE_C_UNITS_BOUNTY = 1`, `:743`) — it is on by default. The award is computed server-side in `Server/PVFunctions/RequestOnUnitKilled.sqf` (the `_bounty = (price) * WFBE_C_UNITS_BOUNTY_COEF` path) and pushed to you as an `AwardBounty` event. Practically: killing a cheap rifleman pays little; destroying an expensive tank or jet pays a lot. Anti-vehicle work is some of the best per-kill income in the game.

**GUER (insurgents)** earn kill bounties at a reduced rate — `WFBE_C_GUER_KILL_BOUNTY_COEF = 0.5` (`Init_CommonConstants.sqf:80`) — but credited to their team for WEST/EAST kills, bypassing the normal coefficient gate (`RequestOnUnitKilled.sqf:92`). See [GUER insurgent player economy](GUER-Insurgent-Player-Economy) for the resistance-specific money model.

## Score and rank (separate from money)

Kills also award **score**, which is independent of your funds and drives your in-game rank. When you neutralise an enemy, the server calls `WFBE_SE_FNC_AwardScorePlayer` to compute points by target type and adds them to your group leader's score (`Server/PVFunctions/RequestOnUnitKilled.sqf:218,225`). The full scoring formula, the kill-attribution window, and how vehicle/air/static kills are valued are in the [Kill and score pipeline](Kill-And-Score-Pipeline). Score earns you nothing to spend — it is bragging rights and rank.

## Where the money actually comes from (best to worst)

1. **Supply missions** — the most reliable steady income; a single delivery pays the town's supply value × 4. See the [Supply missions player guide](Supply-Mission-Player-Guide).
2. **Town captures** — $2,000 each (plus $2,000 if you assist), and they grow the side economy too, so this is almost always the right move.
3. **Anti-vehicle / anti-air kills** — big one-off payouts because the bounty equals the target's price.
4. **Infantry kills** — small but constant; they add up in a firefight.

Spend smart: you pay a respawn penalty when you die (a quarter of your gear's price by default — see the [New player quickstart](New-Player-Quickstart-Guide)), so bank income before splurging on a tank you will lose.

## Quick reference

| Income | Amount |
|--------|--------|
| Town capture / assist | $2,000 each |
| Capture-mission / assist | $2,000 each |
| Supply delivery | town supply value × 4 |
| Kill bounty | enemy unit's price × 1 (GUER × 0.5) |
| Kills also give | score (rank only, not spendable) |

## Continue Reading

- [New player quickstart](New-Player-Quickstart-Guide) — the full first-match walkthrough
- [Supply missions player guide](Supply-Mission-Player-Guide) — the steadiest income source
- [Kill and score pipeline](Kill-And-Score-Pipeline) — the exact scoring/bounty mechanics
- [Economy, towns and supply](Economy-Towns-And-Supply) — how side supply and town income work
- [GUER insurgent player economy](GUER-Insurgent-Player-Economy) — the resistance money model
