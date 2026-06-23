# Anti-Stack Skill-Balance Compensation and Join Gate (skill-tick hysteresis, supply compensation %, effective-skill join denial)

> Source-verified 2026-06-23 against master f8a76de3. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

## Overview

The anti-stack subsystem keeps the two playable sides balanced through two independent mechanisms that share the same DB skill source and the same master switch (`WFBE_C_ANTISTACK_ENABLED`, default `1`, `Common/Init/Init_CommonConstants.sqf:565`):

1. **Supply-compensation loop** — a server-only scheduled loop (`Server/Module/AntiStack/skillDiffCompensation.sqf`) that periodically grants free supply income to whichever side has the lower accumulated DB skill. It runs on a coarse 120 s outer cadence, enters a finer 60 s inner loop when a divergence threshold is crossed, and stays active until a separate **end** threshold is satisfied — a deliberate hysteresis band so compensation does not flicker on and off.
2. **Join gate** — a per-join decision (`Server/Module/AntiStack/compareTeamScores.sqf`, invoked from `Server/PVFunctions/RequestJoin.sqf`) that compares each side's *effective* skill (raw DB skill scaled by a player-count handicap) and **silently denies** a join that would put the joining player on the side that is already ahead. The denied player is bounced with a `Teamstack` chat message.

Both read side skill from the database via `WFBE_SE_FNC_CallDatabaseRequestSideTotalSkill` (`Server/Module/AntiStack/callDatabaseRequestSideTotalSkill.sqf`). This page documents the *formulas and lifecycle*; the DB transport itself is owned elsewhere (see [Continue Reading](#continue-reading)).

A third anti-stack-adjacent mechanism — the no-players supply-income stagnation throttle — interlocks with the compensation loop through the shared `ChangeSideSupply` call but is **out of scope here**; see [Empty-Side-Supply-Income-Stagnation](Empty-Side-Supply-Income-Stagnation). The compensation loop explicitly opts *out* of that throttle (see [The stagnation interlock](#the-stagnation-interlock)).

---

## Spawn and master gate

| Step | Source | Behavior |
|---|---|---|
| Compile gate flag | `Server/Init/Init_Server.sqf:1001` | `_antiStackEnabled = ((missionNamespace getVariable ["WFBE_C_ANTISTACK_ENABLED", 1]) == 1)` |
| Spawn loop | `Server/Init/Init_Server.sqf:1011` | `[] execVM "Server\Module\AntiStack\skillDiffCompensation.sqf"` — only inside `if (_antiStackEnabled)` at `Init_Server.sqf:1009` |
| Sibling loops | `Server/Init/Init_Server.sqf:1009-1010` | `countPlayerScores.sqf`, `monitorTeamToJoin.sqf` launched in the same block |
| Self-guard (direct `execVM`) | `skillDiffCompensation.sqf:4-6` | Hard `exitWith` + log if `WFBE_C_ANTISTACK_ENABLED == 0`, defending against a manual re-launch when the module is disabled |

The join gate's compiler is registered at `Server/Init/Init_Server.sqf:101` (`WFBE_SE_FNC_CompareTeamScores`), and the join PVF is registered through the public-variable name list at `Common/Init/Init_PublicVariables.sqf:16` (`RequestJoin`).

---

## Part 1 — Supply-compensation loop

`Server/Module/AntiStack/skillDiffCompensation.sqf`. Runs only on the server; `WFBE_GameOver` ends every loop.

### Outer cadence and skill-tick accumulation

The outer `while {!WFBE_GameOver}` loop sleeps **120 seconds** per iteration (`skillDiffCompensation.sqf:10`). Each iteration:

1. Pulls current side skill from the DB (`skillDiffCompensation.sqf:12-13`).
2. **Accumulates** it into running totals (`skillDiffCompensation.sqf:15-16`):
   ```sqf
   TEAM_SKILL_TICKS_WEST = TEAM_SKILL_TICKS_WEST + _teamSkillWest;
   TEAM_SKILL_TICKS_EAST = TEAM_SKILL_TICKS_EAST + _teamSkillEast;
   ```
   These accumulators are seeded to `0` at init (`Init_CommonConstants.sqf:566-567`) and reset to `0` after a compensation episode ends (`skillDiffCompensation.sqf:82-83` / `:140-141`).
3. Evaluates the **trigger** condition for each side (`skillDiffCompensation.sqf:18-19`): a side is the "stronger" side when its accumulated ticks exceed the other side's by more than `TEAM_SKILL_TICKS_DIFF_THRESHOLD` (`= 30`, `Init_CommonConstants.sqf:568`).

> Note: `TEAM_SKILL_TICKS_DIFF_THRESHOLD` is a **skill-tick accumulator** difference, *not* a player-count difference. The constants-catalog page historically mislabeled it as "Player-count diff at which compensation engages" — that role text is wrong. Player-count handicapping lives only in the join gate (Part 2).

### The hysteresis band (why compensation lingers)

The trigger and the end conditions use **different** thresholds, forming a hysteresis band:

| Condition | Threshold constant | Value | Source |
|---|---|---|---|
| **Enter** compensation (per side) | `TEAM_SKILL_TICKS_DIFF_THRESHOLD` | `30` | `Init_CommonConstants.sqf:568`; test `skillDiffCompensation.sqf:18-19` |
| **End** compensation (per side) | `TEAM_SKILL_TICKS_END_THRESHOLD` | `10` | `Init_CommonConstants.sqf:570`; test `skillDiffCompensation.sqf:48` / `:106` |

When the WEST trigger fires (`skillDiffCompensation.sqf:29`), the loop drops into a **nested `while`** (`skillDiffCompensation.sqf:31`) that keeps running until the weaker side (here EAST) has out-skilled WEST by more than the *end* threshold of `10`, accumulated tick-by-tick:

```sqf
_skillDiff = _teamSkillEast - _teamSkillWest;          // :36 (WEST branch)
if (_skillDiff < 0) then { _skillDiff = 0; };          // :38-40 — only positive catch-up counts
TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE = TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE + _skillDiff;   // :42
if (TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE > TEAM_SKILL_TICKS_END_THRESHOLD) then {              // :48
    _teamWestSkillTicksEndTriggerThresholdExceeded = true;
} ...
```

The end-trigger accumulator (`TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE` / `TEAM_EAST_…`) is zeroed at the top of each outer iteration (`skillDiffCompensation.sqf:24-25`) and only counts iterations in which the *weaker* side gained on the stronger side (negative diffs are floored to `0`). This means compensation persists until the lagging side has demonstrably caught up by `> 10` cumulative skill, not merely until the instantaneous gap closes — the lingering effect.

The EAST branch (`skillDiffCompensation.sqf:87-143`) is structurally identical with WEST/EAST swapped.

### Per-grant percentage formula

Inside the nested loop, every **60 seconds** (`skillDiffCompensation.sqf:77` / `:135`) the loop computes and applies a grant to the *weaker* side:

```sqf
_teamWestSupplyIncome = (west) call WFBE_CO_FNC_GetTownsSupply;                       // :54 (WEST stronger → EAST weaker)
_skillTicksDifference = _teamSkillWest - _teamSkillEast;                              // :56
_supplyCompensationPercentage = _skillTicksDifference * TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER * 100;  // :57
```

`TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER = 0.045` (`Init_CommonConstants.sqf:569`). The percentage is then clamped to `[0, 100]` (`skillDiffCompensation.sqf:59-65`):

```
pct = clamp( (skillStronger - skillWeaker) × 0.045 × 100 ,  0 , 100 )
```

So a raw skill-tick gap of `1` yields `4.5%`; the percentage saturates at `100%` once the gap reaches ≈ `22.2` (`1 / 0.045`).

The grant amount is a rounded fraction of the **stronger** side's town supply income (`skillDiffCompensation.sqf:67` / `:125`):

```sqf
_supplyCompensationAmount = round(_teamWestSupplyIncome * (_supplyCompensationPercentage / 100));
```

`WFBE_CO_FNC_GetTownsSupply` (registered `Common/Init/Init_Common.sqf:148`) supplies the per-tick town income figure used as the base. The grant is sized off the *stronger* side's income — the compensation scales with how much economy the lead side is actually producing.

### Grant application and PV publish

When the rounded amount is positive (`skillDiffCompensation.sqf:69` / `:127`), it is handed to the weaker side via `ChangeSideSupply`:

```sqf
[east, _supplyCompensationAmount, format ["Anti-stack skill difference compensation applied: ...", ...], _includeStagnation] Call ChangeSideSupply;   // :70 (grants to EAST)
SUPPLY_COMPENSATION_AMOUNT_EAST = _supplyCompensationAmount;   // :73
publicVariable "SUPPLY_COMPENSATION_AMOUNT_EAST";             // :75
```

The mirror EAST-stronger branch grants to WEST and publishes `SUPPLY_COMPENSATION_AMOUNT_WEST` (`skillDiffCompensation.sqf:128,131,133`). Both PV slots are seeded to `0` at init (`Init_CommonConstants.sqf:571-572`). Clients consume these published values for HUD display of active compensation.

| Direction | Stronger side | Weaker (granted) side | Income base read | PV published | Source lines |
|---|---|---|---|---|---|
| WEST ahead | WEST | EAST | `(west) call …GetTownsSupply` | `SUPPLY_COMPENSATION_AMOUNT_EAST` | `:54,67,70,73,75` |
| EAST ahead | EAST | WEST | `(east) call …GetTownsSupply` | `SUPPLY_COMPENSATION_AMOUNT_WEST` | `:112,125,128,131,133` |

When the end threshold is finally exceeded, the nested loop exits, an `INFORMATION` log line is emitted (`skillDiffCompensation.sqf:80` / `:138`), and both tick accumulators reset to `0` (`skillDiffCompensation.sqf:82-83` / `:140-141`), re-arming the outer trigger for a future divergence.

### The stagnation interlock

`ChangeSideSupply` (`Common/Functions/Common_ChangeSideSupply.sqf`) accepts an optional **4th argument** `_includeStagnation` (`Common_ChangeSideSupply.sqf:8-10`). When that flag is `true` and the amount is positive, the supply passes through the no-players decay throttle (`Common_ChangeSideSupply.sqf:16-18`):

```sqf
if (_amount > 0 && _includeStagnation) then {
    _amount = [_amount, _side] call WFBE_CO_FNC_StagnateSupplyIncomeNoPlayers;
};
```

The compensation loop sets `_includeStagnation = false` (`skillDiffCompensation.sqf:27`) and passes it as the 4th arg, so **compensation grants bypass the stagnation throttle** — a weaker, empty side still receives its full anti-stack catch-up. This is the only interlock between the two systems; the throttle's ramp formula and `TEAM_*_TICKS_NO_PLAYERS` accumulators are documented in [Empty-Side-Supply-Income-Stagnation](Empty-Side-Supply-Income-Stagnation) and are not repeated here.

---

## Part 2 — The join gate (effective-skill denial)

`Server/PVFunctions/RequestJoin.sqf` → `Server/Module/AntiStack/compareTeamScores.sqf`.

### When the gate runs

`RequestJoin.sqf` only reaches the skill check on a player's **true first join** of the match. Earlier branches handle returning players and team-swap protection:

| Branch | Source | Outcome |
|---|---|---|
| JIP record exists (`WFBE_JIP_USER…_TEAM_JOINED`) | `RequestJoin.sqf:17-29` | Allowed only if re-joining the same side; otherwise `Teamswap` denial |
| Launch-connect record exists (`WFBE_PLAYER_…_CONNECTED_AT_LAUNCH`) | `RequestJoin.sqf:33-44` | Same same-side check / `Teamswap` denial |
| No prior record → **first join** | `RequestJoin.sqf:46-68` | Runs the skill check (below) |

Inside the first-join branch, the module switch is re-checked (`RequestJoin.sqf:50-54`): if `WFBE_C_ANTISTACK_ENABLED == 0`, the skill check is skipped and the join is **allowed unconditionally** (team-swap protection still applies). Otherwise it reads both sides' skill and calls the gate (`RequestJoin.sqf:58-61`):

```sqf
_skillBLUFOR = [west, _uid] Call WFBE_SE_FNC_GetTeamScore;
_skillOPFOR  = [east, _uid] Call WFBE_SE_FNC_GetTeamScore;
_canJoin = [_side, _name, _uid, _player, _skillBLUFOR, _skillOPFOR] call WFBE_SE_FNC_CompareTeamScores;
```

### Player-count tiers and effective skill

`compareTeamScores.sqf` counts live players per side from `allUnits` (`compareTeamScores.sqf:20-30`), then **decrements the joining side's count by one** so the comparison reflects the team *before* this player lands (`compareTeamScores.sqf:32-38`). It then forms a signed player-count difference per side (`compareTeamScores.sqf:40-41`).

Effective skill = raw DB skill scaled up by a handicap coefficient, applied only to the side that has *more* players (`_playerNumberDifference… > 0`). The coefficient depends on the **combined** player count, giving small games a stronger correction:

| Combined players | Coefficient `_diffCoef` | Source |
|---|---|---|
| `< 8` | `playerDiff × PLAYER_NUMBER_DIFFERENCE_MODIFIER × 2` | `compareTeamScores.sqf:43-45` (BLUFOR), `:56-58` (OPFOR) |
| `< 12` (and ≥ 8) | `playerDiff × PLAYER_NUMBER_DIFFERENCE_MODIFIER × 1` | `compareTeamScores.sqf:47-49` (BLUFOR), `:60-62` (OPFOR) |
| `≥ 12` | `0` (no handicap) | `compareTeamScores.sqf:50-53` (BLUFOR), `:63-66` (OPFOR) |

`PLAYER_NUMBER_DIFFERENCE_MODIFIER = 0.15` (`Init_CommonConstants.sqf:573`). The effective skill is then:

```
effectiveSkill = rawSkill × (1 + _diffCoef)
```

(`compareTeamScores.sqf:45,49,58,62`). For example, in a `< 8`-player game where one side leads by 2 players, the more-populated side's skill is scaled by `1 + (2 × 0.15 × 2) = 1.6` — a 60% effective-skill penalty for being numerically stacked.

### The decision and the silent denial

The gate returns `_canJoin` (`compareTeamScores.sqf:87`). It denies the join when the **joining** side's effective skill would already exceed the other side's effective skill:

| Joining side | Denial test | Source |
|---|---|---|
| `west` | `_totalEffectiveSkillBLUFOR > _totalEffectiveSkillOPFOR` → `_canJoin = false` | `compareTeamScores.sqf:69-74` |
| `east` | `_totalEffectiveSkillOPFOR > _totalEffectiveSkillBLUFOR` → `_canJoin = false` | `compareTeamScores.sqf:76-82` |

On denial the player's group leader is sent a `Teamstack` localized message (`compareTeamScores.sqf:73` / `:80`) — keyed `STR_WF_CHAT_Teamstack` (`stringtable.xml:88`) — and an `INFORMATION` line is logged. This is a **silent** gate from the joining player's perspective: they simply cannot land on the stacking side and are informed via the `Teamstack` chat string; there is no kick or score change.

Back in `RequestJoin.sqf`, the verdict is returned to the client (`RequestJoin.sqf:73-81`) with a human-readable reason (`RequestJoin.sqf:63-67`: "joined the weaker team" vs "attempted to join the stronger team"). On allow, the join is persisted (`RequestJoin.sqf:86-90`): the JIP side variable is written and `WFBE_SE_FNC_CallDatabaseStoreSide` records the chosen side in the DB.

---

## Tunables (anti-stack block)

All declared in `Common/Init/Init_CommonConstants.sqf`, anti-stack block (lines 564-573).

| Constant | Default | Role | Source |
|---|---|---|---|
| `WFBE_C_ANTISTACK_ENABLED` | `1` (enabled) | Master switch for both the compensation loop and the join skill check | `Init_CommonConstants.sqf:565` |
| `TEAM_SKILL_TICKS_WEST` | `0` | WEST accumulated skill-tick total (runtime state) | `Init_CommonConstants.sqf:566` |
| `TEAM_SKILL_TICKS_EAST` | `0` | EAST accumulated skill-tick total (runtime state) | `Init_CommonConstants.sqf:567` |
| `TEAM_SKILL_TICKS_DIFF_THRESHOLD` | `30` | **Enter** threshold: skill-tick accumulator gap that arms compensation | `Init_CommonConstants.sqf:568` |
| `TEAM_SKILL_TICKS_COMPENSATION_MULTIPLIER` | `0.045` | Per-point multiplier in the compensation percentage formula | `Init_CommonConstants.sqf:569` |
| `TEAM_SKILL_TICKS_END_THRESHOLD` | `10` | **End** threshold: cumulative catch-up that ends compensation (hysteresis) | `Init_CommonConstants.sqf:570` |
| `SUPPLY_COMPENSATION_AMOUNT_WEST` | `0` | Last grant to WEST; published when EAST is stronger | `Init_CommonConstants.sqf:571` |
| `SUPPLY_COMPENSATION_AMOUNT_EAST` | `0` | Last grant to EAST; published when WEST is stronger | `Init_CommonConstants.sqf:572` |
| `PLAYER_NUMBER_DIFFERENCE_MODIFIER` | `0.15` | Per-player handicap factor in the join-gate effective-skill formula | `Init_CommonConstants.sqf:573` |

> Stagnation-throttle constants (`TEAM_WEST_TICKS_NO_PLAYERS`, `TEAM_EAST_TICKS_NO_PLAYERS`, `SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER`, `Init_CommonConstants.sqf:578-580`) sit in an adjacent block and belong to [Empty-Side-Supply-Income-Stagnation](Empty-Side-Supply-Income-Stagnation), not to this mechanic.

The end-trigger accumulators `TEAM_WEST_SKILL_TICKS_END_TRIGGER_VALUE` / `TEAM_EAST_SKILL_TICKS_END_TRIGGER_VALUE` are **not** pre-declared in the constants file; they are first assigned at the top of each outer loop iteration (`skillDiffCompensation.sqf:24-25`).

---

## Scope boundaries (what the owner pages do not cover)

- [Player-Join-Disconnect-And-AntiStack-Lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) owns the join/disconnect *lifecycle* and PV edges but treats skill comparison as a black box — it lists "AntiStack skill data when AntiStack is enabled" without the effective-skill formula or the player-count tiers documented here.
- [AntiStack-Database-Extension-Audit](AntiStack-Database-Extension-Audit) owns the **DB side** (the `callDatabase…` wrappers, extension transport, safe-shape fallbacks). It notes the system "can grant side-supply compensation when total team skill diverges" as a single bullet but does not own the compensation percentage formula, the hysteresis band, or the join-gate math.
- The DB return path used by both mechanisms (`callDatabaseRequestSideTotalSkill.sqf`, including its `0`-on-disabled and `[1,1]`-on-error fallbacks at `:5-7,67-70`) is that page's territory; this page treats side skill as an input scalar.

---

## File index

| File | Role |
|---|---|
| `Server/Module/AntiStack/skillDiffCompensation.sqf` | The 120 s/60 s compensation loop; hysteresis; percentage formula; PV publish |
| `Server/Module/AntiStack/compareTeamScores.sqf` | Join gate: player-count tiers, effective-skill comparison, `Teamstack` denial |
| `Server/PVFunctions/RequestJoin.sqf` | First-join dispatch into the gate; team-swap guards; disabled-mode bypass |
| `Server/Module/AntiStack/callDatabaseRequestSideTotalSkill.sqf` | DB read of per-side total skill (input to both mechanisms) |
| `Common/Functions/Common_ChangeSideSupply.sqf` | Supply-grant entry; `_includeStagnation` 4th-arg interlock |
| `Common/Init/Init_CommonConstants.sqf:564-573` | Anti-stack tunable block |
| `Server/Init/Init_Server.sqf:1009-1011` | Gated spawn of the compensation loop and siblings |

---

## Continue Reading

- [Empty-Side-Supply-Income-Stagnation](Empty-Side-Supply-Income-Stagnation) — the no-players supply decay throttle that the compensation loop deliberately bypasses (`_includeStagnation = false`); its `TICKS_NO_PLAYERS` ramp and `SUPPLY_INCOME_TICK_MODIFIER_MULTIPLIER`
- [Player-Join-Disconnect-And-AntiStack-Lifecycle](Player-Join-Disconnect-And-AntiStack-Lifecycle) — the join/disconnect lifecycle and PV edges that wrap the join gate; treats this page's skill comparison as a black box
- [AntiStack-Database-Extension-Audit](AntiStack-Database-Extension-Audit) — the DB extension wrappers, transport, and safe-shape fallbacks feeding side skill into both mechanisms
- [Mission-Tunable-Constants-Catalog](Mission-Tunable-Constants-Catalog) — value-catalog home of the anti-stack constants (note the corrected `TEAM_SKILL_TICKS_DIFF_THRESHOLD` role)
- [Economy-Towns-And-Supply](Economy-Towns-And-Supply) — town supply income (`GetTownsSupply`) and `ChangeSideSupply`, the economy base the compensation grant scales off
