# Resource Income Tick Distribution Engine (updateresources.sqf)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`Server/FSM/updateresources.sqf` is the only loop that *grows* the WASP economy on a timer. Each interval it reads every present side's pooled town supply, gates the whole payout on a supply cap, branches the income by the configured income system (1/2/3/4), then writes three distinct sinks: **side supply** (the shared war resource), **per-team player paychecks** (`wfbe_funds`), and the **AI-commander treasury** (`wfbe_aicom_funds`). It is launched exactly once, from `Server/Init/Init_Server.sqf:688` (`[] ExecVM "Server\FSM\updateresources.sqf"`), and runs server-side for the whole match.

This page documents the per-tick algorithm and the money it writes. It does **not** own the constant values (defer to [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference)) or the open correctness debts — the supply-cap-suppresses-money concern and the income-system-4 display-vs-payout mismatch — which are tracked on [Economy, Towns And Supply](Economy-Towns-And-Supply).

## Loop setup (read once, outside the loop)

The header `private` declares the working scope (`updateresources.sqf:1`), then five config reads happen before `while {!gameOver}`:

| Local | Source | Read |
| --- | --- | --- |
| `_is` | `:3` | `WFBE_C_ECONOMY_INCOME_SYSTEM` (default `3`; `Init_CommonConstants.sqf:313`) |
| `_ii` | `:4` | `WFBE_C_ECONOMY_INCOME_INTERVAL` (default `60`s; `Init_CommonConstants.sqf:312`) |
| `_commander_enabled` | `:9` | `true` iff `WFBE_C_AI_COMMANDER_ENABLED > 0` |
| `_currency_system` | `:10` | `WFBE_C_ECONOMY_CURRENCY_SYSTEM` (0 = Funds+Supply, 1 = Funds-only; `Init_CommonConstants.sqf:304`) |
| `_supply_max_limit` | `:11` | `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` (default `50000`; `Init_CommonConstants.sqf:323`) |

Only when `_is == 3` are the coefficient/divisor read (`:15-18`): `_incomeCoef = WFBE_C_ECONOMY_INCOME_COEF` (default `8`; `Init_CommonConstants.sqf:319`) and `_divisor = WFBE_C_ECONOMY_INCOME_DIVIDED` (default `1.2`; `Init_CommonConstants.sqf:320`). For all other systems `_incomeCoef` stays `1` and `_divisor` stays `0` (`:7-8`).

The income-system options are documented inline at `Init_CommonConstants.sqf:313`: `1:Full`, `2:Half`, `3:Commander System`, `4:Commander System: Full`.

## Per-tick structure

```
while {!gameOver} do {
    compute _pcMult (B36.1 inverse-population AICOM multiplier)   // :27-33
    {                                                              // forEach side
        _logik  = side Call GetSideLogic                          // :37
        _supply = side Call GetTownsSupply                        // :43
        if (_supply < _supply_max_limit) then { ...payout... }    // :45  supply-cap gate
        if (_supply >= _supply_max_limit && ...) then { ...famine... } // :102 funds-famine branch
    } forEach (WFBE_PRESENTSIDES - [resistance])                  // :111  GUER excluded
    sleep ((_ii) Call GetSleepFPS)                                // :113-114
};
```

The side iteration is `forEach (WFBE_PRESENTSIDES - [resistance])` (`:111`). **GUER (resistance) is deliberately excluded** from the supply/commander economy — the trailing comment notes it gets a "funds-only stipend, no supply/commander economy." Per-side state is fetched via `_x Call WFBE_CO_FNC_GetSideLogic` (`:37`, the side-logic object holding `wfbe_teams`, `wfbe_commander_percent`, `wfbe_teams_count`, `wfbe_aicom_funds`) and the income basis via `_x Call WFBE_CO_FNC_GetTownsSupply` (`:43`).

`WFBE_CO_FNC_GetTownsSupply` sums `supplyValue` across every town whose `sideID` matches the side (`Common/Functions/Common_GetTownsSupply.sqf:6-8`) — so `_supply` here is the side's **pooled town income basis**, not its current side-supply balance. That distinction is the root of the cap-guard debt flagged in [Economy, Towns And Supply](Economy-Towns-And-Supply).

## The B36.1 inverse-population AICOM multiplier (`_pcMult`)

Computed once per tick, before the side loop (`updateresources.sqf:27-33`). This scales the AI commander's **cash** income (never supply) *inversely* to live human player count — the team curve in `AI_Commander_Teams.sqf` fields the most squads at low pop, so the funding need is highest on a near-empty server (comment `:22-25`).

| Step | Source | Behavior |
| --- | --- | --- |
| Human count | `:28` | `_pcN2 = {isPlayer _x} count allUnits` |
| HC subtraction | `:29-30` | subtract live headless clients (`WFBE_HEADLESSCLIENTS_ID` with a non-null, alive leader), clamped `max 0`; mirrors `MonitorPlayerCount.sqf` |
| Base multiplier | `:31` | `_baseMult = WFBE_C_AI_COMMANDER_INCOME_MULT` (default `1.5`; tier-set by LEVEL — Easy 1.0 / Normal 1.5 / Hard 2.0, `Init_CommonConstants.sqf:172-174`) |
| Per-player bonus | `:32` | `+BONUS` per player **under** `WFBE_C_AICOM_INCOME_PC_REF` (default `10`). Bonus rate is valve-gated: `WFBE_C_AICOM_INCOME_PC_BONUS_VALVE` (`0.045`) when `WFBE_C_AICOM_BANKING_VALVE > 0`, else `WFBE_C_AICOM_INCOME_PC_BONUS` (`0.06`) |
| Clamp | `:33` | `_pcMult = _pcMult min WFBE_C_AICOM_INCOME_MULT_MAX` (default `3.0`, packed-server runaway guard) |

Formula (valve on, the live default): `_pcMult = 1.5 * (1 + 0.045 * ((10 - playerCount) max 0))`, clamped to `3.0`. At 0 players this is `1.5 * (1 + 0.045*10) = 1.5 * 1.45 = 2.175`; at 10+ players it collapses to the base `1.5`. The `:32` comment records that the original B36.1 form multiplied by `_pcN2` (boost *with* more players) and was **flipped** to `(REF - pc)` so income is highest at low pop. Constant values and their lines are owned by [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference).

## The supply-cap gate and income computation

Inside the side loop, the entire payout block is wrapped in `if (_supply < _supply_max_limit)` (`:45`). When the side's pooled town income is below the cap, `_income` is seeded (`:47`): `_income = _supply` for every system except 3, where `_income = round(_supply * _incomeCoef)`.

Then a `switch (_is)` adjusts `_income` and computes the commander/player split (`:49-59`):

| System | Source | `_income` / split formula |
| --- | --- | --- |
| 1 (Full) | (default seed) | `_income = _supply`; no split (paid whole to non-player-led teams) |
| 2 (Half) | `:50` | `_income = round(_income / 2)` |
| 3 (Commander) | `:52-53` | `_income_player = round(_income * ((100 - cmdPct)/100) / teamsCount)`; `_income_commander = round((_income * (cmdPct/100)) / _divisor) + _income_player` |
| 4 (Commander Full) | `:56-57` | `_income_player = round(_income * 1.5 * (100 - cmdPct)/100)`; `_income_commander = round((_income*1.5 - _income_player) * teamsCount) + _income_player` |

where `cmdPct = _logik getVariable "wfbe_commander_percent"`, `teamsCount = _logik getVariable "wfbe_teams_count"`, and `_divisor = WFBE_C_ECONOMY_INCOME_DIVIDED` (`1.2`). The system-4 `* 1.5` server multiplier (`:56-57`) is **not** mirrored by the client display getter `Client/Functions/Client_GetIncome.sqf:24-28`; that display-vs-payout mismatch is an open correctness debt owned by [Economy, Towns And Supply](Economy-Towns-And-Supply).

## Payout: the three money sinks

The payout block fires only when `_income > 0` (`:61`):

### 1. Side supply growth

`if (_currency_system == 0)` then `[_x, _supply, "...", true] Call ChangeSideSupply` (`:63`). The fourth argument `true` is `_includeStagnation`, which routes positive deltas through `WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers` before applying (`Common/Functions/Common_ChangeSideSupply.sqf:16-18`). Note the actual write is broadcast through the `wfbe_supply_temp_%1` temp public-variable channel (`Common_ChangeSideSupply.sqf:28-30`), not a direct setVariable. In Funds-only currency (`_currency_system == 1`) this path is skipped entirely.

### 2. Per-team player paychecks

After resolving `_comTeam = _x Call WFBE_CO_FNC_GetCommanderTeam` (the side HQ group, `:65-66`), the loop iterates every team in `_logik getVariable "wfbe_teams"` (`:68-79`) and computes a `_paycheck` per team via `switch (_is)`:

| System | Source | `_paycheck` |
| --- | --- | --- |
| 3 / 4 | `:72-73` | `_income_player` when the team is **not** the commander team; `_income_commander` when it **is** (`_comTeam == _x`) |
| default (1/2) | `:74` | `_income` — but **only if** `!(isPlayer (leader _x))`, i.e. AI-led groups only |

Each non-zero paycheck is written with `[_x, _paycheck] Call WFBE_CO_FNC_ChangeTeamFunds` (`:77`), which does a broadcast `wfbe_funds` setVariable with the `true` global flag (`Common/Functions/Common_ChangeTeamFunds.sqf`). The `if !(isNil '_x')` guard at `:69` protects against stale entries in `wfbe_teams`. Contracts for `ChangeTeamFunds`/`wfbe_funds` are owned by [Side Team State Function Reference](Side-Team-State-Function-Reference).

### 3. AI-commander treasury

When the side has **no human-commander team** (`isNull (_x Call WFBE_CO_FNC_GetCommanderTeam)`) and `_commander_enabled` (`:81`), the treasury is credited `round(_income * _pcMult)` via `[_x, round(_income * _pcMult)] Call ChangeAICommanderFunds` (`:82`). `ChangeAICommanderFunds` writes `wfbe_aicom_funds += amount` on the side-logic object **without** any broadcast flag, so the treasury is server-local AI-only state (`Server/Functions/Server_ChangeAICommanderFunds.sqf:1-5`; read side `Server_GetAICommanderFunds.sqf:1`). The accessors are registered in `Init_Server.sqf:29,34` and the variable is seeded to `WFBE_C_AI_COMMANDER_START_FUNDS` (200000) at side init (`Init_Server.sqf:443`).

### Synthetic stipend (always inside the cap gate)

Separately, still inside `_supply < cap`, the AI commander gets an unconditional money drip even when town income is zero (`:89-91`): `[_x, WFBE_C_AI_COMMANDER_INCOME_STIPEND] Call ChangeAICommanderFunds` with default `25` (the fallback literal at `:90`). The V0.4.1 comment (`:86-88`) notes this keeps PvE fun on a near-empty server — "synthetic MONEY drip for the AI commander - never synthetic supply." (The constant's tier-mapped value is `2000` on Normal via `Init_CommonConstants.sqf:174`; the `25` is only the in-loop getVariable default.)

## The funds-famine over-cap branch

A second `if` runs **outside** the supply-cap gate (`:102-109`), firing when `_supply >= _supply_max_limit` AND the side has no human commander AND `_commander_enabled`. Its purpose (comment `:95-101`): the cap gate correctly stops *supply* accumulation past the limit, but it also suppressed the AI commander's *funds* income and stipend — so when the AI hoarded supply past the cap, its funds drained to $0, it stopped buying units, and the war stalled (towns stopped changing hands; AI stuck around 8 towns all night). Funds are a separate currency from supply, so they are topped up here.

The branch recomputes `_income` the same way (`:103`, `_income = _supply` or `round(_supply*_incomeCoef)` for system 3), applies the system-2 halving (`:104`), then — when `_income > 0` — credits `round(_income * _pcMult)` (`:106`) and **always** adds the stipend (`:108`). It never synthesises supply.

## Tick pacing

The loop sleeps `(_ii) Call GetSleepFPS` (`:113-114`). `WFBE_CO_FNC_GetSleepFPS` returns the raw delay when `diag_fps > 15`, and progressively **shortens** it as FPS drops (×0.85 / ×0.75 / ×0.70 / ×0.50 down to `diag_fps <= 5`) — `Common/Functions/Common_GetSleepFPS.sqf:5-9`. Because the 60s income interval doubles as a per-minute paycheck cadence, "per-tick == per-min" at full FPS; under load the income loop ticks *faster* (does more work while already stressed), which [AI Headless And Performance](AI-Headless-And-Performance) treats as a deliberate "avoid income stalls during lag" tradeoff, not an obvious bug.

## Producers this engine drives (summary)

| Sink | Writer | Lines | Condition |
| --- | --- | --- | --- |
| Side supply | `ChangeSideSupply` | `:63` | `_currency_system == 0`, `_income > 0`, under cap |
| Player/AI-team funds | `WFBE_CO_FNC_ChangeTeamFunds` | `:77` | per team in `wfbe_teams`, non-zero paycheck |
| AICOM treasury (scaled) | `ChangeAICommanderFunds` | `:82`, `:106` | no human commander, `_commander_enabled` |
| AICOM treasury (stipend) | `ChangeAICommanderFunds` | `:90`, `:108` | no human commander, `_commander_enabled` |

## Continue Reading

- [Economy, Towns And Supply](Economy-Towns-And-Supply) — the open correctness debts (supply-cap-suppresses-money, income-system-4 display mismatch) and the side-supply branch matrix.
- [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference) — exact lines/defaults for every `WFBE_C_AICOM_INCOME_*`, `INCOME_MULT`, `INCOME_STIPEND` constant this loop applies.
- [Town Economy Getter Reference](Town-Economy-Getter-Reference) — `GetTownsSupply`/`GetTownsIncome` and the client `Client_GetIncome` readout split.
- [Side Team State Function Reference](Side-Team-State-Function-Reference) — `ChangeTeamFunds`/`wfbe_funds` and the side-logic seed list.
- [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference) — the spend side of the treasury this engine fills.
