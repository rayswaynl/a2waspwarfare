# Lane 126 Boat Service Ship Branch Audit

Date: 2026-07-02
Target: `origin/claude/build84-cmdcon36`
Target SHA: `b1608b096eb4a02d7c213d794e22b8bc59df8df0`
Lane: 126 - V11 boats skip service

## Verdict

Lane 126 is already fixed on the current live lane. The prompt row says the four single-unit support workers miss the `Ship` class, but the current Chernarus source and maintained Takistan mirror already route boats through light-vehicle timing branches for repair, heal, refuel, and rearm.

No source patch is needed for this lane.

## Evidence

The maintained Chernarus source has explicit `Ship` handling in all four support workers:

| Service | File anchor | Current behavior |
| --- | --- | --- |
| Repair | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRepair.sqf:52` | `_repTime` scales by `_ligCoef + getDammage _veh` for `Ship`. |
| Heal | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportHeal.sqf:52` | `_healTime` scales by `_ligCoef + getDammage _veh` for `Ship`. |
| Refuel | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRefuel.sqf:53` | `_refTime` scales by `_ligCoef + (1 - fuel _veh)` for `Ship`. |
| Rearm | `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRearm.sqf:61` | `_rearmTime` scales by `_ligCoef` for `Ship`. |

The maintained Takistan mirror has the same `Ship` branches:

| Service | File anchor |
| --- | --- |
| Repair | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRepair.sqf:52` |
| Heal | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportHeal.sqf:52` |
| Refuel | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRefuel.sqf:53` |
| Rearm | `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRearm.sqf:61` |

Each branch carries the same "wiki-wins" note: boats previously fell through all `isKindOf` branches and now scale like light vehicles. That directly satisfies the lane's stated missing-class problem.

## Scope

This audit is documentation-only. It does not change support behavior, service GUI code, runtime defaults, generated mirror output, package artifacts, or live server state.

`Tools/LoadoutManager` was not run because no maintained Chernarus mission source changed.

## Recommended Disposition

Treat lane 126 as stale/resolved for `origin/claude/build84-cmdcon36`. If this row resurfaces, the regression check is:

```powershell
rg -n -e "isKindOf 'Ship'" -e '_repTime|_healTime|_refTime|_rearmTime' "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRepair.sqf" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportHeal.sqf" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRefuel.sqf" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRearm.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRepair.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportHeal.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRefuel.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRearm.sqf"
```
