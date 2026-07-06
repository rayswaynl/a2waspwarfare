# Service Enemy Vehicles Status

Date: 2026-07-03
Lane: 80
Target branch: `claude/build84-cmdcon36`

## Verdict

The lane-80 V17 service-menu fallback is already side-filtered on the current target branch.

The prompt's risky path is the repair-truck fallback that scans vehicles within 100m of the nearest repair truck and appends them to the service target list. Current source still has that broad class scan, but it only appends vehicles whose current side is the player's side or civilian.

## Current target evidence

The maintained roots all carry the same repair-truck fallback shape:

- Chernarus: `Missions/[55-2hc]warfarev2_073v48co.chernarus/Client/GUI/GUI_Menu_Service.sqf:342-349`
- Takistan: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.takistan/Client/GUI/GUI_Menu_Service.sqf:342-349`
- Zargabad: `Missions_Vanilla/[61-2hc]warfarev2_073v48co.zargabad/Client/GUI/GUI_Menu_Service.sqf:342-349`

The relevant current lines are:

```sqf
_checks = (getPos player) nearEntities[_typeRepair, missionNamespace getVariable "WFBE_C_UNITS_REPAIR_TRUCK_RANGE"];
if (count _checks > 0) then {
	_repair = _checks select 0;
	_vehi = ((getPos _repair) nearEntities[["Car","Motorcycle","Tank","Air","Ship","StaticWeapon"],100]) - [_repair];
	{
		if (!(_x in _effective) && {side _x in [sideJoined, civilian]}) then {
			_effective = _effective + [_x];
			_nearSupport set [_i,[_repair]];
```

That means same-side vehicles and civilian vehicles can be appended from the repair-truck scan, but enemy-side vehicles are not appended by this source path.

The appended `_effective` list then feeds both single-target and all-unit service actions:

- Batch prices are built from `_effective` at `GUI_Menu_Service.sqf:378-381`.
- All-unit `REARM`, `REPAIR`, `REFUEL`, and `HEAL` actions use those batches at `GUI_Menu_Service.sqf:536-554`.
- The selected-vehicle full-service path uses `_effective`/`_nearSupport` at `GUI_Menu_Service.sqf:557-560`.

So the side filter applies before the target can reach the current menu service action plumbing.

## Runtime nuance

This is a source-status verdict, not a live-engine proof for every possible empty or captured vehicle state. If an originally enemy vehicle reports `side _x` as `civilian` after being emptied or captured, the current source would allow it through because civilian is explicitly permitted. That may be intentional for neutral/stolen vehicles, but the exact runtime side behavior should be smoked in-engine before calling V17 behavior fully proven.

## Related open work

Open draft PR #380 (`fable/client-qol-batch2`) currently touches `GUI_Menu_Service.sqf` in Chernarus, Takistan, and Zargabad for adjacent client-QOL work. Open draft PR #293 covers service-point QA but does not edit `GUI_Menu_Service.sqf`.

Because `GUI_Menu_Service.sqf` is also on the tonight-avoid list, this lane intentionally makes no source edits. If a future source change is still wanted, re-check PR #380 first and treat it as a hot-file rebase/review lane.

## Lane boundary

No mission source changed, no generated mirror changed, and LoadoutManager was not run. This note records that the direct V17 enemy-side fallback is already source-filtered on the current target and preserves the remaining runtime-smoke nuance.
