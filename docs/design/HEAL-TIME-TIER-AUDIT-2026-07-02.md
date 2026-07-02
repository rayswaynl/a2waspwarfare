# Heal Time Tier Audit - 2026-07-02

Lane: 125, V10 heal time ignores tier
Base checked: `origin/claude/build84-cmdcon36@f9b00d5ff2`
Scope: docs/source audit only. No mission source, service-menu behavior, generated Takistan files, live deploy, or package artifacts are changed here.

## Summary

The prompt row is stale on the current live target. `Client_SupportHeal.sqf` already applies support-type heal-time coefficients to infantry in both maintained roots.

The current implementation:

- initializes `_airCoef`, `_artCoef`, `_heaCoef`, and `_ligCoef` from the nearby support type;
- scales Air, StaticWeapon, Tank, Car/Motorcycle, Ship, and Man heal time before the progress hint is shown;
- treats infantry as light-vehicle scale via `_ligCoef + getDammage _veh`;
- keeps the final damage reset path intact for infantry and vehicle crews.

No source patch is recommended in this lane. The current target already prevents Man-class healing from falling through to a flat base time.

## Evidence Table

| Path | Evidence | Result |
| --- | --- | --- |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportHeal.sqf:24-44` | Initializes support-type coefficients and adjusts them for repair truck, depot, or service point support. | Heal time has tier/source coefficients available before class scaling. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportHeal.sqf:48-53` | Scales Air, StaticWeapon, Tank, Car/Motorcycle, Ship, and Man; the Man branch uses `_ligCoef + getDammage _veh`. | Infantry healing no longer ignores the support tier coefficient. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportHeal.sqf:56` | The healing hint uses the computed `_healTime`. | Player-visible progress reflects the scaled time. |
| `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportHeal.sqf:79-82` | Final success path still repairs Man directly and vehicle hull/crew separately. | Heal completion behavior remains intact. |
| `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportHeal.sqf:24-44,48-53,56,79-82` | Same coefficient, Man/Ship scaling, hint, and completion paths. | Takistan mirror is already covered. |

## Non-Findings

- This audit does not retune heal-time coefficient values.
- This audit does not change repair, rearm, refuel, EASA, service-point discovery, or GUI service-menu affordability behavior.
- This audit does not evaluate every service worker row; it only closes the lane-125 Man heal-time coefficient example.

## Suggested Smoke

Optional in-game smoke for a later owner run:

1. Damage an infantry unit and start healing near each support source: repair truck, depot, and service point.
2. Confirm the displayed healing time differs by support source instead of always using the base time.
3. Let the heal complete and confirm the infantry damage is cleared.

## Verification

- `rg` confirmed coefficient initialization and support-source coefficient values in both maintained roots.
- `rg` confirmed the `Ship` and `Man` class-scaling branches in both maintained roots.
- `rg` confirmed the computed `_healTime` feeds the healing hint before the wait loop.
- Source read only; no SQF/SQM/HPP/EXT files were changed.
- LoadoutManager was not run because this is a docs-only audit.
