# Resource Income Tick Distribution Engine (updateresources.sqf)

> Source-verified 2026-06-23 against current stable/B74.1 `origin/master@f8a76de34` / `origin/claude/b74.1-aicom@f8a76de34`; B74.2 `origin/claude/b74.2-aicom@d472da6a` has no checked income-file delta. Paths are current source Chernarus unless noted. Arma 2 OA 1.64. Maintained Vanilla and B69/B74 branch differences are routed through [Economy, Towns And Supply](Economy-Towns-And-Supply#resource-income-branch-matrix).

`Server/FSM/updateresources.sqf` is the only loop that *grows* the WASP economy on a timer. Each interval it reads every present side's pooled town supply, gates the whole payout on a supply cap, branches the income by the configured income system (1/2/3/4), then writes three distinct sinks: **side supply** (the shared war resource), **per-team player paychecks** (`wfbe_funds`), and the **AI-commander treasury** (`wfbe_aicom_funds`). It is launched exactly once from current Chernarus `Server/Init/Init_Server.sqf:870` and maintained Vanilla `:857` (`[] ExecVM "Server\FSM\updateresources.sqf"`), and runs server-side for the whole match.

This page documents the per-tick algorithm and the money it writes. It does **not** own the constant values (defer to [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference)) or the open correctness debts — the supply-cap-suppresses-money concern and the income-system-4 display-vs-payout mismatch — which are tracked on [Economy, Towns And Supply](Economy-Towns-And-Supply).

## Loop setup (read once, outside the loop)

The header `private` declares the working scope (`updateresources.sqf:1`), then five config reads happen before `while {!gameOver}`:

| Local | Source | Read |
| --- | --- | --- |
| `_is` | `:3` | `WFBE_C_ECONOMY_INCOME_SYSTEM` (default `3`; current Chernarus `Init_CommonConstants.sqf:525`) |
| `_ii` | `:4` | `WFBE_C_ECONOMY_INCOME_INTERVAL` (default `60`s; current Chernarus `Init_CommonConstants.sqf:524`) |
| `_commander_enabled` | `:9` | `true` iff `WFBE_C_AI_COMMANDER_ENABLED > 0` |
| `_currency_system` | `:10` | `WFBE_C_ECONOMY_CURRENCY_SYSTEM` (0 = Funds+Supply, 1 = Funds-only; current Chernarus `Init_CommonConstants.sqf:516`) |
| `_supply_max_limit` | `:11` | `WFBE_C_ECONOMY_SUPPLY_MAX_TEAM_LIMIT` (default `50000`; current Chernarus `Init_CommonConstants.sqf:547`) |

Only when `_is == 3` are the coefficient/divisor read (`:15-18`): `_incomeCoef = WFBE_C_ECONOMY_INCOME_COEF` (default `8`; `Init_CommonConstants.sqf:319`) and `_divisor = WFBE_C_ECONOMY_INCOME_DIVIDED` (default `1.2`; `Init_CommonConstants.sqf:320`). For all other systems `_incomeCoef` stays `1` and `_divisor` stays `0` (`:7-8`).

The income-system options are documented inline at current Chernarus `Init_CommonConstants.sqf:525`: `1:Full`, `2:Half`, `3:Commander System`, `4:Commander System: Full`.

## Per-tick structure

```
while {!gameOver} do {
    compute _pcMult (B36.1 inverse-population AICOM multiplier)   // :27-33
    compose late-game time curve into _pcMult                     // :38-46
    {                                                              // forEach side
        _logik  = side Call GetSideLogic                          // :50
        _supply = side Call GetTownsSupply                        // :56
        compute B74.1 AICOM-only town-leader taper                // :57-67
        if (_supply < _supply_max_limit) then { ...payout... }    // :69  supply-cap gate
        if (_supply >= _supply_max_limit && ...) then { ...famine... } // :126 funds-famine branch
    } forEach (WFBE_PRESENTSIDES - [resistance])                  // :135  GUER excluded
    sleep ((_ii) Call GetSleepFPS)                                // :137-138
};
```

The side iteration is `forEach (WFBE_PRESENTSIDES - [resistance])` (`:135`). **GUER (resistance) is deliberately excluded** from the supply/commander economy — the trailing comment notes it gets a "funds-only stipend, no supply/commander economy." Per-side state is fetched via `_x Call WFBE_CO_FNC_GetSideLogic` (`:50`, the side-logic object holding `wfbe_teams`, `wfbe_commander_percent`, `wfbe_teams_count`, `wfbe_aicom_funds`) and the income basis via `_x Call WFBE_CO_FNC_GetTownsSupply` (`:56`).

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

Current Chernarus then composes a late-game time curve into `_pcMult` at `:38-46`. The default curve reads floor/ceil/start/window values, smoothsteps from `WFBE_C_AICOM_TIMECURVE_FLOOR` to `WFBE_C_AICOM_TIMECURVE_CEIL`, and multiplies the population-based `_pcMult` by `_tcMult`.

## The B74.1 AICOM-only town-leader taper

Current Chernarus computes `_aicomTaper` per side before the cap gate at `updateresources.sqf:57-67`. At or below `WFBE_C_AICOM_INCOME_TAPER_TOWNS` (default `8`, `Init_CommonConstants.sqf:264`) the taper is `1`; above that threshold, extra towns contribute only `WFBE_C_AICOM_INCOME_TAPER_RATE` (default `0.4`, `:265`) to AI-commander cash. The comments are explicit that this is AICOM-only: it is applied to `ChangeAICommanderFunds` at `:106` and `:130`, never to player paychecks or side supply. Maintained Vanilla current stable does not carry this taper in the checked income file.

## The supply-cap gate and income computation

Inside the side loop, the entire payout block is wrapped in `if (_supply < _supply_max_limit)` (`:69`). When the side's pooled town income is below the cap, `_income` is seeded (`:71`): `_income = _supply` for every system except 3, where `_income = round(_supply * _incomeCoef)`.

Then a `switch (_is)` adjusts `_income` and computes the commander/player split (`:73-83`):

| System | Source | `_income` / split formula |
| --- | --- | --- |
| 1 (Full) | (default seed) | `_income = _supply`; no split (paid whole to non-player-led teams) |
| 2 (Half) | `:74` | `_income = round(_income / 2)` |
| 3 (Commander) | `:76-77` | `_income_player = round(_income * ((100 - cmdPct)/100) / teamsCount)`; `_income_commander = round((_income * (cmdPct/100)) / _divisor) + _income_player` |
| 4 (Commander Full) | `:80-81` | `_income_player = round(_income * 1.5 * (100 - cmdPct)/100)`; `_income_commander = round((_income*1.5 - _income_player) * teamsCount) + _income_player` |

where `cmdPct = _logik getVariable "wfbe_commander_percent"`, `teamsCount = _logik getVariable "wfbe_teams_count"`, and `_divisor = WFBE_C_ECONOMY_INCOME_DIVIDED` (`1.2`). The system-4 `* 1.5` server multiplier (`:80-81`) is **not** mirrored by the client display getter `Client/Functions/Client_GetIncome.sqf:24-28`; that display-vs-payout mismatch is an open correctness debt owned by [Economy, Towns And Supply](Economy-Towns-And-Supply).

## Payout: the three money sinks

The payout block fires only when `_income > 0` (`:85`):

### 1. Side supply growth

`if (_currency_system == 0)` then current Chernarus calls `[_x, round(_supply * WFBE_C_ECONOMY_SUPPLY_INCOME_MULT), "...", true] Call ChangeSideSupply` (`:87`). The fourth argument `true` is `_includeStagnation`, which routes positive deltas through `WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers` before applying (`Common/Functions/Common_ChangeSideSupply.sqf:16-18`). Note the actual write is broadcast through the `wfbe_supply_temp_%1` temp public-variable channel, not a direct setVariable. In Funds-only currency (`_currency_system == 1`) this path is skipped entirely. Maintained Vanilla current stable keeps raw `_supply` at `updateresources.sqf:76`.

### 2. Per-team player paychecks

After resolving `_comTeam = _x Call WFBE_CO_FNC_GetCommanderTeam` (the side HQ group, `:89-90`), the loop iterates every team in `_logik getVariable "wfbe_teams"` (`:92-103`) and computes a `_paycheck` per team via `switch (_is)`:

| System | Source | `_paycheck` |
| --- | --- | --- |
| 3 / 4 | `:96-97` | `_income_player` when the team is **not** the commander team; `_income_commander` when it **is** (`_comTeam == _x`) |
| default (1/2) | `:98` | `_income` — but **only if** `!(isPlayer (leader _x))`, i.e. AI-led groups only |

Each non-zero paycheck is written with `[_x, _paycheck] Call WFBE_CO_FNC_ChangeTeamFunds` (`:101`), which does a broadcast `wfbe_funds` setVariable with the `true` global flag (`Common/Functions/Common_ChangeTeamFunds.sqf`). The `if !(isNil '_x')` guard at `:93` protects against stale entries in `wfbe_teams`. Contracts for `ChangeTeamFunds`/`wfbe_funds` are owned by [Side Team State Function Reference](Side-Team-State-Function-Reference).

### 3. AI-commander treasury

When the side has **no human-commander team**, or current Chernarus has `WFBE_C_AI_COMMANDER_HYBRID_REFILL > 0`, and `_commander_enabled` (`:105`), the treasury is credited `round(_income * _pcMult * _aicomTaper)` via `ChangeAICommanderFunds` (`:106`). `ChangeAICommanderFunds` writes `wfbe_aicom_funds += amount` on the side-logic object **without** any broadcast flag, so the treasury is server-local AI-only state (`Server/Functions/Server_ChangeAICommanderFunds.sqf:1-5`; read side `Server_GetAICommanderFunds.sqf:1`). Maintained Vanilla current stable keeps the older non-hybrid, non-tapered `round(_income * _pcMult)` shape at `updateresources.sqf:94-95`.

### Synthetic stipend (always inside the cap gate)

Separately, still inside `_supply < cap`, the AI commander gets an unconditional money drip even when town income is zero (`:110-115`): `[_x, WFBE_C_AI_COMMANDER_INCOME_STIPEND] Call ChangeAICommanderFunds` with default `25` (the fallback literal at `:114`). The V0.4.1 comment (`:110-112`) notes this keeps PvE fun on a near-empty server — "synthetic MONEY drip for the AI commander - never synthetic supply." Current Chernarus tier values are set in `Init_CommonConstants.sqf:208-210`; the `25` is only the in-loop getVariable default. Maintained Vanilla current stable keeps the non-hybrid stipend check at `updateresources.sqf:99-103`.

## The funds-famine over-cap branch

A second `if` runs **outside** the supply-cap gate (`:126-132`), firing when `_supply >= _supply_max_limit`, `_commander_enabled` is true, and either the side has no human commander or current Chernarus has hybrid refill enabled. Its purpose (comment `:119-125`): the cap gate correctly stops *supply* accumulation past the limit, but it also suppressed the AI commander's *funds* income and stipend — so when the AI hoarded supply past the cap, its funds drained to $0, it stopped buying units, and the war stalled (towns stopped changing hands; AI stuck around 8 towns all night). Funds are a separate currency from supply, so they are topped up here.

The branch recomputes `_income` the same way (`:127`, `_income = _supply` or `round(_supply*_incomeCoef)` for system 3), applies the system-2 halving (`:128`), then — when `_income > 0` — credits `round(_income * _pcMult * _aicomTaper)` (`:130`) and **always** adds the stipend (`:132`). It never synthesises supply. Maintained Vanilla current stable keeps the non-hybrid, non-tapered version at `:115-121`.

## Tick pacing

The loop sleeps `(_ii) Call GetSleepFPS` (`:137-138`). `WFBE_CO_FNC_GetSleepFPS` returns the raw delay when `diag_fps > 15`, and progressively **shortens** it as FPS drops (×0.85 / ×0.75 / ×0.70 / ×0.50 down to `diag_fps <= 5`) — `Common/Functions/Common_GetSleepFPS.sqf:5-9`. Because the 60s income interval doubles as a per-minute paycheck cadence, "per-tick == per-min" at full FPS; under load the income loop ticks *faster* (does more work while already stressed), which [AI Headless And Performance](AI-Headless-And-Performance) treats as a deliberate "avoid income stalls during lag" tradeoff, not an obvious bug.

## Producers this engine drives (summary)

| Sink | Writer | Lines | Condition |
| --- | --- | --- | --- |
| Side supply | `ChangeSideSupply` | `:87` | `_currency_system == 0`, `_income > 0`, under cap; Chernarus applies `WFBE_C_ECONOMY_SUPPLY_INCOME_MULT` |
| Player/AI-team funds | `WFBE_CO_FNC_ChangeTeamFunds` | `:101` | per team in `wfbe_teams`, non-zero paycheck |
| AICOM treasury (scaled) | `ChangeAICommanderFunds` | `:106`, `:130` | no human commander or Chernarus hybrid refill, `_commander_enabled`; Chernarus applies `_aicomTaper` |
| AICOM treasury (stipend) | `ChangeAICommanderFunds` | `:114`, `:132` | no human commander or Chernarus hybrid refill, `_commander_enabled` |

## Continue Reading

- [Economy, Towns And Supply](Economy-Towns-And-Supply) — the open correctness debts (supply-cap-suppresses-money, income-system-4 display mismatch) and the side-supply branch matrix.
- [AI Commander Tunable Constants Reference](AI-Commander-Tunable-Constants-Reference) — exact lines/defaults for every `WFBE_C_AICOM_INCOME_*`, `INCOME_MULT`, `INCOME_STIPEND` constant this loop applies.
- [Town Economy Getter Reference](Town-Economy-Getter-Reference) — `GetTownsSupply`/`GetTownsIncome` and the client `Client_GetIncome` readout split.
- [Side Team State Function Reference](Side-Team-State-Function-Reference) — `ChangeTeamFunds`/`wfbe_funds` and the side-logic seed list.
- [AI Commander Execution Loop Reference](AI-Commander-Execution-Loop-Reference) — the spend side of the treasury this engine fills.
