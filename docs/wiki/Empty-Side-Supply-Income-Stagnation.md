# Empty-Side Supply Income Stagnation Ramp (per-tick decay that zeroes an unmanned side's town income)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

`WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers` is the throttle that progressively starves a side's **town supply income** while that side has zero live players. It is not a flat cutoff: each income tick that finds the side empty bumps a per-side counter, and the counter is converted into an ever-growing decrease percentage that linearly ramps the income payout down toward zero. A side with persisted database skill is exempt entirely. The function is registered from `Common/Init/Init_Common.sqf:171` and runs only on the positive-income path of `ChangeSideSupply` when that caller opts in.

## What Decays And What Does Not

Stagnation is gated by the **4th argument** (`_includeStagnation`) of `ChangeSideSupply`. The income tick is the only producer that passes `true`; every other supply credit passes `false` (or omits the argument), so those credits never decay even when the side is empty.

| Credit | 4th arg (`_includeStagnation`) | Stagnates? | Source |
| --- | --- | --- | --- |
| Town supply income tick | `true` | Yes | `Server/FSM/updateresources.sqf:87` |
| Supply-mission completion | `false` | No | `Server/Module/supplyMission/supplyMissionCompleted.sqf:40,43` |
| Logistics interdiction kill reward | `false` | No | `Server/Module/supplyMission/supplyMissionStarted.sqf:28` |
| Attack-wave activation debit | (3 args, omitted) | No | `Server/PVFunctions/AttackWave.sqf:40` |
| Anti-stack skill compensation | `_includeStagnation` (= `false`) | No | `Server/Module/AntiStack/skillDiffCompensation.sqf:27,70,128` |
| AI commander stipend / wildcard drops | `false` | No | `Server/AI/Commander/AI_Commander.sqf:217`; `Server/Functions/AI_Commander_Wildcard.sqf:542,1012` |

The gate lives in the common writer: stagnation runs only when the amount is positive **and** the flag is set. `Common/Functions/Common_ChangeSideSupply.sqf:16-18`:

```sqf
if (_amount > 0 && _includeStagnation) then {
	_amount = [_amount, _side] call WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers;
};
```

Note the argument-parse quirk in the same writer: `_includeStagnation` is read only when `count _this > 3`, and `_reason` is **also** gated on `count _this > 3` rather than `> 2`. `Common/Functions/Common_ChangeSideSupply.sqf:8-14`. So a strictly 4-argument caller is required to enable stagnation; the `AttackWave.sqf:40` 3-argument call cannot enable it and additionally loses its audit reason. That parse asymmetry is owner-page material for the [Side Team State Function Reference](Side-Team-State-Function-Reference), not new here.

## The Stagnation Ramp

When stagnation is enabled, the function receives `[_amount, _side]` and runs four phases. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:3-4`.

### 1. Persistence-DB skill early exit (the bypass)

Before counting players, the function queries saved per-side total skill from the persistence database (if that bridge exists). `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:14-24`. If the queried side has any saved skill (`> 0`), it returns the **unmodified** amount and never touches the no-player counter. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:26-36`:

```sqf
if (_side == west) then {
    if (_teamSkillWest > 0) exitWith { _amount; };
} else {
    if (_side == east) then {
        if (_teamSkillEast > 0) exitWith { _amount; };
    };
};
```

Consequence: **a side with saved DB skill never stagnates**, regardless of how long it sits empty. The ramp only ever bites a side that is both unmanned and has no persisted skill. (The skill query itself is the same `WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill` "REQUEST_SIDE_SKILL" lookup used by the anti-stack mechanic.)

### 2. Live-player census and tick accumulation

The function walks `allUnits`, keeps only `isPlayer` units whose `side` matches the target side, and counts them. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:38-47`. The counter is then advanced per side: empty → increment; populated → reset to zero. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:49-67`:

```sqf
if (_side == west) then {
    _teamWestPlayers = count _sidePlayers;
    if (_teamWestPlayers <= 0) then {
        TEAM_WEST_TICKS_NO_PLAYERS = TEAM_WEST_TICKS_NO_PLAYERS + 1;
        _supplyDecreasePercentage = TEAM_WEST_TICKS_NO_PLAYERS * SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER;
    } else {
        TEAM_WEST_TICKS_NO_PLAYERS = 0;
    };
} else { ... east mirror ... };
```

Both counters are then broadcast so clients can mirror them. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:69-70` (`publicVariable "TEAM_WEST_TICKS_NO_PLAYERS"` / `"TEAM_EAST_TICKS_NO_PLAYERS"`). A single returning player on the side resets that side's counter to `0`, instantly restoring full income on the next tick.

### 3. Clamp the decrease percentage to 0..1

The raw `ticks × multiplier` product is clamped: anything above `1` is forced to `1` (full income kill), anything below `0` to `0`. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:72-78`.

### 4. Apply only on the open interval (0, 1)

The reduction is applied **only** when the percentage is strictly between 0 and 1. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:80-83`:

```sqf
if ((_supplyDecreasePercentage > 0) && (_supplyDecreasePercentage < 1)) then {
    _amount = round(_amount * (1 - _supplyDecreasePercentage));
    [...] Call WFBE_CO_FNC_LogContent;
};
_amount
```

Mechanically important detail of the `< 1` strict upper bound: while `pct` is inside the open interval `(0,1)` the income is scaled down, but the moment `ticks × multiplier` reaches `1` (clamping `pct` to exactly `1.0`) the branch no longer fires and the function returns the **full, unmodified** `_amount`. So the ramp does not produce a literal zero payout — it scales income down to its harshest fractional value the tick *before* the product hits `1`, then disengages. At the default `0.10` multiplier that boundary is tick 10: ticks 1–9 scale income from 90% down to 10%, and tick 10 (and every tick after) returns full income untouched. Treat tick 10, not tick 11, as the behavioral boundary.

## Tunables

From `Common/Init/Init_CommonConstants.sqf`, under the `//--- Supply income stagnation when no players.` block.

| Constant | Value | Role | Source |
| --- | --- | --- | --- |
| `SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER` | `0.10` | Per-empty-tick increment to the decrease percentage (decimal fraction). | `Common/Init/Init_CommonConstants.sqf:580` |
| `TEAM_WEST_TICKS_NO_PLAYERS` | `0` | West empty-tick counter (runtime accumulator, broadcast). | `Common/Init/Init_CommonConstants.sqf:578` |
| `TEAM_EAST_TICKS_NO_PLAYERS` | `0` | East empty-tick counter (runtime accumulator, broadcast). | `Common/Init/Init_CommonConstants.sqf:579` |

There is no GUER (resistance) branch in the stagnation function; only `west` and `east` are handled. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:26-67`.

## Ramp Schedule (default multiplier 0.10)

`pct = ticks × 0.10`, clamped to `[0,1]`; payout multiplier is `1 - pct`, applied only while `pct` is strictly inside `(0,1)`. Computed from `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:53,72-83` and `Common/Init/Init_CommonConstants.sqf:580`.

| Empty ticks | Raw `pct` | Clamped `pct` | Payout factor | Effect on income |
| --- | --- | --- | --- | --- |
| 0 | 0.00 | 0.00 | 1.00 (guard off) | Full income |
| 1 | 0.10 | 0.10 | 0.90 | `round(amount × 0.90)` |
| 5 | 0.50 | 0.50 | 0.50 | `round(amount × 0.50)` |
| 9 | 0.90 | 0.90 | 0.10 | `round(amount × 0.10)` |
| 10 | 1.00 | 1.00 | (guard off, `pct < 1` false) | Returns full amount unmodified |
| 11+ | ≥1.10 | 1.00 | (guard off) | Returns full amount unmodified |

The harshest scaling is at tick 9 (90% off); at tick 10 and beyond the strict `< 1` guard disengages and the raw amount passes through. The audit log line reports `round(_supplyDecreasePercentage * 100)` as the percent and the post-scale amount, but only fires on the same `(0,1)` interval. `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:82`.

## Relationship To The Anti-Stack Mechanic

The [Anti-Stack Skill-Balance Mechanic](Anti-Stack-Skill-Balance-Mechanic) grants compensation supply to the weaker side, and it **defers** to this throttle by passing `_includeStagnation = false` on its `ChangeSideSupply` calls. `Server/Module/AntiStack/skillDiffCompensation.sqf:27,70,128`. So compensation credits are never decayed — only the per-town income tick is. Both subsystems share the same persistence-skill lookup (`WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill`, `"REQUEST_SIDE_SKILL"`), and the DB-skill early exit here is what makes a persisted-but-currently-empty side keep full income while still being eligible for anti-stack compensation.

## Practical Rules

| Rule | Why | Source |
| --- | --- | --- |
| Only the income tick stagnates. Do not assume any other supply credit decays for an empty side. | Stagnation is gated on the 4th arg; only `updateresources.sqf:87` passes `true`. | `Common/Functions/Common_ChangeSideSupply.sqf:16-18`; `Server/FSM/updateresources.sqf:87` |
| A side with saved DB skill never stagnates. | The skill `> 0` early exit returns the unmodified amount before any counter work. | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:26-36` |
| One returning player fully restores income next tick. | A populated side resets its counter to `0`, so `pct` drops back to `0`. | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:54-56,63-65` |
| Treat tick 10 (not 11) as the behavioral boundary at the default multiplier. | The `< 1` guard skips the multiply once `pct` clamps to `1`, returning full income. | `Common/Functions/Common_StagnateSupplyIncomeNoPlayers.sqf:72-83` |
| Keep stagnation reasoning separate from `ChangeSideSupply` arg-parse fixes. | `_includeStagnation` and `_reason` both gate on `count _this > 3`, an existing quirk. | `Common/Functions/Common_ChangeSideSupply.sqf:8-14` |

## Continue Reading

- [Anti-Stack Skill-Balance Mechanic](Anti-Stack-Skill-Balance-Mechanic)
- [Resource Income Tick Distribution Engine](Resource-Income-Tick-Distribution-Engine)
- [Side Team State Function Reference](Side-Team-State-Function-Reference)
- [Economy Towns And Supply](Economy-Towns-And-Supply)
- [Mission Tunable Constants Catalog](Mission-Tunable-Constants-Catalog)
