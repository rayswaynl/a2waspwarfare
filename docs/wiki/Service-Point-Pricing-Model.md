# Vehicle Service Point Pricing Model (rearm / repair / refuel / heal)

> Source-verified 2026-06-21 against master 0139a346. Paths relative to Missions/[55-2hc]warfarev2_073v48co.chernarus/ unless noted. Arma 2 OA 1.64.

The Vehicle Service Point menu (`Client/GUI/GUI_Menu_Service.sqf`) prices four services — **rearm, repair, refuel, heal** — for every friendly vehicle and crewman in support range. All four prices flow through one shared helper, `_martyServiceGetPrice`, which is also reused by the "service all" batch buttons and the per-unit "full service" button. This page documents exactly how each number is computed: the per-action formulas, the experimental proportional-rearm scaling, the ammo-fraction math behind it, the artillery exemption, the catalog-price source, and which charge paths skip the affordability guard.

This is the complementary reference to [Service Menu Affordability Guards](Service-Menu-Affordability-Guards), which documents only the debit-guard correctness bug — not how each price is computed.

## The shared pricing helper

Every price the menu shows comes from a single script-local lambda `_martyServiceGetPrice`, called as `[_veh,_action] Call _martyServiceGetPrice`, returning a rounded integer cost (Client/GUI/GUI_Menu_Service.sqf:28-78). It is dispatched purely on the `_action` string (`"HEAL"`, `"REFUEL"`, `"REPAIR"`, `"REARM"`); any other action returns `0` (Client/GUI/GUI_Menu_Service.sqf:77).

Two early structural rules:

| Rule | Source |
| --- | --- |
| `HEAL` is handled first and is the **only** action valid on a `Man` object | Client/GUI/GUI_Menu_Service.sqf:34-42 |
| After the HEAL branch, any `Man` returns `0` (vehicle-only services cannot price a soldier) | Client/GUI/GUI_Menu_Service.sqf:44 |
| Vehicle services read the unit's catalog array via `_get = missionNamespace getVariable (typeOf _veh)` | Client/GUI/GUI_Menu_Service.sqf:46-47 |

`_get select QUERYUNITPRICE` is the vehicle's purchase price from its per-classname query array; `QUERYUNITPRICE = 2` is the price index in that array (Common/Init/Init_CommonConstants.sqf:8). When the class has no query entry (`isNil "_get"`), each vehicle action falls back to a flat price rather than erroring.

## Per-action price formulas

All formulas are evaluated at menu-tick time (the dialog loops every 0.1 s) and re-shown live, so the displayed price tracks the vehicle's current damage / fuel / ammo state.

| Action | Formula | Fallback / zero cases | Source |
| --- | --- | --- | --- |
| **HEAL** (Man) | `round(getDammage _veh * WFBE_C_UNITS_SUPPORT_HEAL_PRICE)` | — | Client/GUI/GUI_Menu_Service.sqf:34-35 |
| **HEAL** (vehicle) | sum over `crew _veh` of `round(getDammage _x * WFBE_C_UNITS_SUPPORT_HEAL_PRICE)` for each **alive** crewman | dead crew contribute 0 | Client/GUI/GUI_Menu_Service.sqf:36-41 |
| **REFUEL** | `round(missingFuel * (price / WFBE_C_UNITS_SUPPORT_REFUEL_PRICE))` where `missingFuel = (fuel _veh - 1) * -1` | `0` if `fuel >= 1`; `200` if class unknown | Client/GUI/GUI_Menu_Service.sqf:49-53 |
| **REPAIR** | `round(getDammage _veh * (price / WFBE_C_UNITS_SUPPORT_REPAIR_PRICE))` | `0` if `getDammage <= 0`; `500` if class unknown | Client/GUI/GUI_Menu_Service.sqf:56-60 |
| **REARM** | `round(price / WFBE_C_UNITS_SUPPORT_REARM_PRICE)` (the **base price**, before proportional scaling) | `500` if class unknown | Client/GUI/GUI_Menu_Service.sqf:62-65 |

Here `price` is `_get select QUERYUNITPRICE` (the unit's catalog cost). Refuel and repair both scale the catalog price by the fraction of the resource missing; rearm is a flat fraction of catalog cost (then optionally proportionally reduced, see below). Heal is the only action priced off damage alone, independent of catalog cost.

### Pricing constants

| Constant | Value | Role | Source |
| --- | --- | --- | --- |
| `WFBE_C_UNITS_SUPPORT_HEAL_PRICE` | 125 | multiplier on per-target damage for heal | Common/Init/Init_CommonConstants.sqf:544 |
| `WFBE_C_UNITS_SUPPORT_REARM_PRICE` | 14 | catalog-price **divisor** for rearm base | Common/Init/Init_CommonConstants.sqf:546 |
| `WFBE_C_UNITS_SUPPORT_REFUEL_PRICE` | 16 | catalog-price divisor for refuel | Common/Init/Init_CommonConstants.sqf:548 |
| `WFBE_C_UNITS_SUPPORT_REPAIR_PRICE` | 2 | catalog-price divisor for repair | Common/Init/Init_CommonConstants.sqf:550 |
| `QUERYUNITPRICE` | 2 | index of price in the per-class query array | Common/Init/Init_CommonConstants.sqf:8 |

Because the constants are divisors, a **larger** number means a **cheaper** service: refuel (÷16) is the cheapest catalog fraction, repair (÷2) the most expensive. Worked example for a vehicle whose catalog price is 14000: full rearm base = `round(14000/14)` = **1000**; full repair at 100% damage = `round(14000/2)` = **7000**; full refuel from empty = `round(1 * 14000/16)` = **875**.

## Proportional rearm (WFBE_C_SUPPORT_REARM_PROPORTIONAL)

The rearm branch has an experimental refinement: instead of always charging the full base price, it can charge only for the ammo the vehicle is actually missing. The gate is `WFBE_C_SUPPORT_REARM_PROPORTIONAL`, which defaults to `1` (enabled) (Common/Init/Init_CommonConstants.sqf:581). The branch reads it with a `[..., 0]` default so a missing variable is treated as off (Client/GUI/GUI_Menu_Service.sqf:67).

When enabled, the base price computed above is scaled:

```
_frac      = _veh Call WFBE_CO_FNC_GetAmmoFraction;   // 0..1
_basePrice = round(_basePrice * ((1 - _frac) max 0.1));
```

(Client/GUI/GUI_Menu_Service.sqf:67-72)

| Behavior | Detail | Source |
| --- | --- | --- |
| Scaling factor | `(1 - ammoFraction)` — pay for what is missing | Client/GUI/GUI_Menu_Service.sqf:71 |
| Floor | `max 0.1` — a vehicle that is near-full still pays at least **10%** of base | Client/GUI/GUI_Menu_Service.sqf:71 |
| Artillery exemption | if the vehicle **is artillery**, proportional scaling is skipped entirely and it pays the full base price | Client/GUI/GUI_Menu_Service.sqf:68-69 |
| Gate default | `WFBE_C_SUPPORT_REARM_PROPORTIONAL = 1` | Common/Init/Init_CommonConstants.sqf:581 |

So a tank that has fired 40% of its magazines pays `round(base * (0.4 max 0.1))` = `round(base * 0.4)`; a tank that has fired nothing still pays the 10% floor; a self-propelled gun always pays full base regardless of how few rounds remain.

### Artillery detection

The exemption is decided by `([typeOf _veh, str sideJoined] Call IsArtillery) != -1` (Client/GUI/GUI_Menu_Service.sqf:68). `IsArtillery` (compiled at Common/Init/Init_Common.sqf:71) scans the per-side `WFBE_<side>_ARTILLERY_CLASSNAMES` table and returns the matching artillery-type **index**, or the sentinel `-1` when the class is not artillery (Common/Functions/Common_IsArtillery.sqf:5-12). Any non-`-1` index means "this is a gun → charge full rearm."

## The ammo-fraction helper

`WFBE_CO_FNC_GetAmmoFraction` (compiled at Common/Init/Init_Common.sqf:53) returns the current magazine load as a `0..1` fraction of full complement, where 0 = empty and 1 = full (Common/Functions/Common_GetAmmoFraction.sqf:5-10).

| Step | Detail | Source |
| --- | --- | --- |
| Null/dead guard | returns `0` (full price, fail-safe) if the vehicle is null or not alive | Common/Functions/Common_GetAmmoFraction.sqf:47 |
| Full complement | hull magazine count from `configFile >> CfgVehicles >> class >> "magazines"` **plus** each turret's magazine array from `WFBE_CO_FNC_GetVehicleTurretsGear` | Common/Functions/Common_GetAmmoFraction.sqf:57-65 |
| Per-class cache | the full total is cached once per class in `missionNamespace` under `Format["WFBE_AMMOFULL_%1", typeOf _veh]` so config is walked only once per class per session | Common/Functions/Common_GetAmmoFraction.sqf:50,53,66 |
| Degenerate guard | if the full total `<= 0` (config unreadable / no ammo entries) returns `0` → full price, safe | Common/Functions/Common_GetAmmoFraction.sqf:70 |
| Current count | `count (magazines _veh)` (hull) plus, per turret path, `count (_veh magazinesTurret <path>)` | Common/Functions/Common_GetAmmoFraction.sqf:73-79 |
| Result | `((current / full) min 1) max 0` — clamped to `0..1` | Common/Functions/Common_GetAmmoFraction.sqf:82 |

The two "degenerate → 0" guards are deliberately safe in the pricing direction: a `0` fraction makes `(1 - _frac)` equal `1`, so an unreadable vehicle pays full base price rather than a free rearm.

## Batch and full-service price aggregation

The menu's "all" buttons and the per-unit "full service" button aggregate the same per-action prices.

| Builder | What it prices | Source |
| --- | --- | --- |
| `_martyServiceBuildFull` | one vehicle's needed services: `["REPAIR","REFUEL","REARM","HEAL"]` for vehicles, `["HEAL"]` for a `Man`; sums each action whose individual price `> 0` and records which actions were charged | Client/GUI/GUI_Menu_Service.sqf:101-117 |
| `_martyServiceBuildBatch` | one action across **every** eligible unit in the list; de-duplicates by vehicle (`_seen`), skips dead and ineligible units, and sums each per-unit price `> 0` | Client/GUI/GUI_Menu_Service.sqf:120-150 |

Eligibility for the batch is `_martyServiceCanUse` → `_martyServiceBlockReason`: a vehicle is blocked (and excluded from the batch total) if it is destroyed, more than 2 m airborne, or moving faster than 20 (Client/GUI/GUI_Menu_Service.sqf:81-99). Infantry healing is never blocked by these movement rules (the `Man` early-out returns `""`).

The batch prices are refreshed every menu tick so the "all" buttons stay all-or-nothing (Client/GUI/GUI_Menu_Service.sqf:377-389), and the per-action totals are written to the ammo/repair/heal labels (Client/GUI/GUI_Menu_Service.sqf:391-393).

### Charge timing (pre-pay) — and the guard gap

Both "all" and "full service" charge **once up front**, then queue the per-unit service scripts with a 0.35 s stagger:

| Path | Affordability check before debit | Debit | Source |
| --- | --- | --- | --- |
| `_martyServiceStartBatch` | `if (_funds < _price) exitWith {...}` | `-_price Call ChangePlayerFunds` | Client/GUI/GUI_Menu_Service.sqf:164-168 |
| `_martyServiceStartFull` | `if (_funds < _price) exitWith {...}` | `-_price Call ChangePlayerFunds` | Client/GUI/GUI_Menu_Service.sqf:204-208 |

Pre-paying means the rearm bill is fixed at the instant the button is pressed, using the ammo fraction at that moment; firing during the rearm timer cannot change the price (this snapshot guarantee is documented at the top of Client/Functions/Client_SupportRearm.sqf:1-9).

The **single-unit** buttons, however, are inconsistent about the affordability guard. Each runs `if (...) then { -_price Call ChangePlayerFunds; Spawn SupportX }`:

| Single-unit action | Guard before debit | Source |
| --- | --- | --- |
| Rearm (MenuAction 1) | `if (_funds >= _rearmPrice)` — **guarded** | Client/GUI/GUI_Menu_Service.sqf:484 |
| Repair (MenuAction 2) | `if (_repairPrice > 0)` — **no funds check** (price-positive only) | Client/GUI/GUI_Menu_Service.sqf:496 |
| Refuel (MenuAction 3) | `if (_funds >= _refuelPrice)` — **guarded** | Client/GUI/GUI_Menu_Service.sqf:507 |
| Heal (MenuAction 5) | `if (_healPrice > 0)` — **no funds check** (price-positive only) | Client/GUI/GUI_Menu_Service.sqf:519 |

The repair and heal single-unit paths debit on a price-positive check alone, so they can drive funds negative if the button is somehow clicked while unaffordable — the button-enable logic (Client/GUI/GUI_Menu_Service.sqf:448-455) is the only thing normally preventing it. See [Service Menu Affordability Guards](Service-Menu-Affordability-Guards) for the full correctness analysis of this gap.

## What the price does NOT cover: service time

Pricing is fixed; the **time** a service takes is computed separately inside each `SupportX` worker and is not part of the bill. The workers apply a support-source coefficient (service point / depot / repair truck) and a class malus, then loop once per second. Repair, refuel, and heal additionally add the current damage/fuel deficit to the coefficient so worse-off vehicles take longer.

| Worker | Base time constant | Value | Source |
| --- | --- | --- | --- |
| Rearm | `WFBE_C_UNITS_SUPPORT_REARM_TIME` | 20 | Common/Init/Init_CommonConstants.sqf:547 |
| Repair | `WFBE_C_UNITS_SUPPORT_REPAIR_TIME` | 20 | Common/Init/Init_CommonConstants.sqf:551 |
| Refuel | `WFBE_C_UNITS_SUPPORT_REFUEL_TIME` | 10 | Common/Init/Init_CommonConstants.sqf:549 |
| Heal | `WFBE_C_UNITS_SUPPORT_HEAL_TIME` | 10 | Common/Init/Init_CommonConstants.sqf:545 |

Example rearm coefficients (multiplying `REARM_TIME` after rounding): repair truck nearby gives air ×3.4 / arty ×3 / heavy ×2.8 / light ×2.6; a service point gives the cheapest air ×1.9 / arty ×1.7 / heavy ×1.5 / light ×1.2 (Client/Functions/Client_SupportRearm.sqf:37-60). Repair/refuel/heal use their own coefficient tables and add the damage or fuel deficit (Client/Functions/Client_SupportRepair.sqf:28-51, Client/Functions/Client_SupportRefuel.sqf:29-52, Client/Functions/Client_SupportHeal.sqf:28-51).

## Range gating

A unit only appears in the priced service list if it is within range of a support source. The window is `WFBE_C_UNITS_SUPPORT_RANGE = 70` for service points and depots, and `WFBE_C_UNITS_REPAIR_TRUCK_RANGE = 40` for repair trucks (Common/Init/Init_CommonConstants.sqf:543,539). The menu collects each vehicle's nearby supports — service point, depot, repair truck, and repair-truck-built service points — before pricing it (Client/GUI/GUI_Menu_Service.sqf:284-317). The workers re-check this range every second and abort the service if no support remains in range or the vehicle goes more than 2 m airborne (e.g. Client/Functions/Client_SupportRearm.sqf:68-82).

## Continue Reading

- [Service Menu Affordability Guards](Service-Menu-Affordability-Guards) — the debit/affordability guard correctness bug across the single-unit and batch charge paths
- [Tactical Support Menu Player Guide](Tactical-Support-Menu-Player-Guide) — player-facing walkthrough of the service and support menus
- [Support, Specials and Tactical Modules Atlas](Support-Specials-And-Tactical-Modules-Atlas) — the wider support-action and tactical-module dispatch overview
- [Artillery Reference Per Faction](Artillery-Reference-Per-Faction) — the per-faction `WFBE_<side>_ARTILLERY_CLASSNAMES` tables behind the rearm artillery exemption
- [Kill and Score Pipeline](Kill-And-Score-Pipeline) — the bounty/score currency formulas (unrelated to service costs, for contrast)
