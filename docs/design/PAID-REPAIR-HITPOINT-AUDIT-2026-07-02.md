# Lane 120 Paid Repair Hitpoint Audit

Date: 2026-07-02
Target: `origin/claude/build84-cmdcon36`
Target SHA: `b1608b096eb4a02d7c213d794e22b8bc59df8df0`
Lane: 120 - V5 paid repair leaves hitpoints

## Verdict

Lane 120 is already fixed on the current live lane. The prompt row says paid repair only calls `setDammage 0` and can leave wheel or engine hitpoints broken, but the current `Client_SupportRepair.sqf` clears configured hitpoints after the scalar repair in both maintained roots.

No source patch is needed for this lane.

## Evidence

The maintained Chernarus repair worker now performs the scalar repair and then clears configured hitpoints:

- `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRepair.sqf:78` calls `_veh setDammage 0`.
- `.../Client_SupportRepair.sqf:79` documents why the extra pass exists: `setDammage` clears the global scalar, but config hitpoints also need clearing.
- `.../Client_SupportRepair.sqf:80` loads `CfgVehicles >> typeOf _veh >> HitPoints`.
- `.../Client_SupportRepair.sqf:81` checks the class exists and has entries.
- `.../Client_SupportRepair.sqf:82-85` iterates each configured hitpoint name and calls `_veh setHit [_hitName, 0]`.

The maintained Takistan mirror has the same anchors:

- `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRepair.sqf:78` calls `_veh setDammage 0`.
- `.../Client_SupportRepair.sqf:80` loads the vehicle `HitPoints` config.
- `.../Client_SupportRepair.sqf:81` checks the class/count.
- `.../Client_SupportRepair.sqf:82-85` clears each named hitpoint with `_veh setHit [_hitName, 0]`.

That means paid repair no longer relies only on `setDammage 0` on the current target.

## Scope

This audit is documentation-only. It does not change repair behavior, service GUI code, runtime defaults, generated mirror output, package artifacts, or live server state.

`Tools/LoadoutManager` was not run because no maintained Chernarus mission source changed.

## Recommended Disposition

Treat lane 120 as stale/resolved for `origin/claude/build84-cmdcon36`. If this row resurfaces, the regression check is:

```powershell
rg -n "setDammage 0|setHit|HitPoints|isClass _hitPoints|_hitCfg|_hitName" "Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/Functions/Client_SupportRepair.sqf" "Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/Functions/Client_SupportRepair.sqf"
```
