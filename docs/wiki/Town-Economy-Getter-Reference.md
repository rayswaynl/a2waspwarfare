# Town-Economy Getter Reference

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

Four small `Common_GetTowns*` / `Common_GetTotalSupplyValue` functions read the per-side aggregate state of the global `towns` array. They drive the server income tick, the client economy HUD, the AntiStack supply compensation, and the three-way victory check. All four share the same skeleton: take a side, convert it to a numeric side id via `GetSideID`, then `forEach towns` filtering on each town's `sideID` variable. They differ only in what they accumulate (a count, a raw supply sum, or a coefficient-weighted income). This page tables each function's contract and call sites. For the prose economy narrative see [Economy-Towns-And-Supply](Economy-Towns-And-Supply); this page is the function-contract counterpart.

## Shared data contract

Every getter depends on the same three pieces of global state, all set up before these functions are ever called.

| Element | Where set | Notes |
| --- | --- | --- |
| `towns` (global array) | `Common/Init/Init_Town.sqf:165` (`towns = towns + [_town]`) | The array these getters `forEach` over. |
| town `"sideID"` variable | `Common/Init/Init_Town.sqf:87` (default `WFBE_DEFENDER_ID`) | Numeric owner id; compared against the converted side. (Camps inherit a same-named `sideID` at `:116`, but camps are never added to `towns` — only `_town` is, at `:165` — so the getters never read it.) |
| town `"supplyValue"` variable | `Common/Init/Init_Town.sqf:88` | Per-town supply weight summed by the supply/income getters. (Camps inherit a same-named `supplyValue` at `:119` from the town's value, but are not in `towns`, so the getters never read it.) |
| `GetSideID` (dependency) | `Common/Functions/Common_GetSideID.sqf:7-13` | Maps `west/east/resistance/civilian` → `WFBE_C_*_ID`, else `-1`. Registered at `Common/Init/Init_Common.sqf:41`. |

Because the filter is `(_x getVariable "sideID") == <converted side>`, passing a side whose id is `-1` (anything outside the four known sides) yields a zero/empty result rather than an error.

## Function contracts

| Function | Source | Registered (Init_Common.sqf) | Argument | Returns | Behavior |
| --- | --- | --- | --- | --- | --- |
| `GetTownsHeld` | `Common/Functions/Common_GetTownsHeld.sqf:1-8` | `:64` (bare name `GetTownsHeld`) | a side (`_this`) | town count (number) | Converts side via `GetSideID:4`, then `forEach towns:6` increments `_held` by 1 for each town whose `"sideID"` matches. Pure count, ignores `supplyValue`. |
| `GetTownsSupply` | `Common/Functions/Common_GetTownsSupply.sqf:1-10` | `:147` (alias `WFBE_CO_FNC_GetTownsSupply` only — **no bare `GetTownsSupply`**) | a side (`_this`) | summed supply (number) | Converts side via `GetSideID:3`, then `forEach towns:6-8` sums `supplyValue` of matching towns into `_income`. |
| `GetTotalSupplyValue` | `Common/Functions/Common_GetTotalSupplyValue.sqf:1-13` | `:63` (bare name `GetTotalSupplyValue`) | a side (`_this`, stored in `_side`) | summed supply (number) | Same accumulation as `GetTownsSupply` (`GetSideID:4`, `forEach towns:7-11` summing `supplyValue` into `_totalSupply`). Functionally a duplicate of `GetTownsSupply` under a different registered name. |
| `GetTownsIncome` | `Common/Functions/Common_GetTownsIncome.sqf:1-18` | `:65` (bare name `GetTownsIncome`) | a side (`_this`) | income (number) | Converts side via `GetSideID:2`. Reads `WFBE_C_ECONOMY_INCOME_SYSTEM:5`; if it is `3`, also reads `WFBE_C_ECONOMY_INCOME_COEF:7`. Then `forEach towns:9-16`: for matching towns, `case 3` adds `supplyValue * _incomeCoef:12`, the `default` adds raw `supplyValue:13`. |

### Notes on the duplicate pair and the coefficient branch

- **`GetTownsSupply` vs `GetTotalSupplyValue`** compute the identical sum (per-side total of town `supplyValue`). They differ only in registration: `GetTotalSupplyValue` is exposed bare (`Init_Common.sqf:63`) and `GetTownsSupply` is exposed only as `WFBE_CO_FNC_GetTownsSupply` (`Init_Common.sqf:147`). There is no bare `GetTownsSupply` global and no `WFBE_CO_FNC_GetTotalSupplyValue` alias, so callers reach for whichever name is in scope.
- **`GetTownsIncome`'s `case 3` branch** is the only place these getters multiply by a coefficient. `WFBE_C_ECONOMY_INCOME_SYSTEM` defaults to `3` (Commander System) and `WFBE_C_ECONOMY_INCOME_COEF` defaults to `8`, both set at `Common/Init/Init_CommonConstants.sqf:313,319`. So by default `GetTownsIncome` returns `8x` the raw supply sum, whereas under any other income system it returns the raw sum (matching `GetTownsSupply`).

## Call sites

Verified live callers (excludes the `Init_Common.sqf` registrations and the function files themselves).

| Caller | Source:line | Function used | Purpose |
| --- | --- | --- | --- |
| Server income tick | `Server/FSM/updateresources.sqf:43` | `WFBE_CO_FNC_GetTownsSupply` | `_supply = (_x) Call ...`; raw town supply feeds the per-tick income calc (coefficient applied locally at `:47` when income system `== 3`). |
| AntiStack compensation | `Server/Module/AntiStack/skillDiffCompensation.sqf:54,112` | `WFBE_CO_FNC_GetTownsSupply` | West/East town supply used to scale the skill-difference compensation. |
| Three-way victory | `Server/FSM/server_victory_threeway.sqf:16` | `GetTownsHeld` | `_towns = (_x) Call GetTownsHeld`; per-side town count contributes to the victory/elimination check. |
| Client income readout | `Client/Functions/Client_GetIncome.sqf:5` | `GetTownsIncome` | `_income = (_side) Call ...`; coefficient-weighted income then split per income system (cases 2/3/4) for the client display. |
| Economy menu | `Client/GUI/GUI_Menu_Economy.sqf:58,227` | `GetTownsIncome` | `(sideJoined) Call GetTownsIncome` for the slider baseline and income-pool dashboard. |
| Economy menu (held count) | `Client/GUI/GUI_Menu_Economy.sqf:229` | `GetTownsHeld` | Inline `(sideJoined Call GetTownsHeld)` for the "Towns held: %3 / %4" line. |
| Main menu dashboard | `Client/GUI/GUI_Menu.sqf:48,49` | `GetTownsHeld`, `GetTotalSupplyValue` | `_townsHeld` (guarded by `_townsTotal > 0`) and `_totalSupplyValue = sideJoined Call GetTotalSupplyValue`. |
| QoL advisor nudge | `Client/Functions/Client_QOL_Advisor.sqf:80` | `GetTownsHeld` | `_townsHeld = sideJoined Call GetTownsHeld`; gates the "research Patrols" nudge at 3+ towns held. |

Note the bare-name/alias split in practice: server-side callers (`updateresources`, `skillDiffCompensation`) use `WFBE_CO_FNC_GetTownsSupply`, while client and victory callers use the bare `GetTownsHeld` / `GetTownsIncome` / `GetTotalSupplyValue` names.

## Continue Reading

- [Economy-Towns-And-Supply](Economy-Towns-And-Supply)
- [Economy-Authority-First-Cut](Economy-Authority-First-Cut)
- [Towns-Camps-And-Capture-Atlas](Towns-Camps-And-Capture-Atlas)
- [Side-Team-State-Function-Reference](Side-Team-State-Function-Reference)
- [Victory-And-Endgame-Atlas](Victory-And-Endgame-Atlas)
