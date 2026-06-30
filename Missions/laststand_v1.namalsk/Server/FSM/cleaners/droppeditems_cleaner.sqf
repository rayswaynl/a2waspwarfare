private["_capacity", "_clear", "_firstDelay", "_maxPerCycle", "_scanCentre", "_scanRadius",
        "_perfActive", "_perfDeleted", "_perfItemStart", "_perfMines", "_perfScanned",
        "_perfStart", "_perfWeaponholders", "_scanItems", "_timer", "_perfExtra"];

// AI-lane (Ray spec, B40 2026-06-16): full-island weaponholder sweep on a ~10-minute cadence.
// The first sweep runs EARLY (~90s) so no boot backlog forms.
// B40 changes:
//   - SALVAGE LOTTERY removed (Ray dropped it).
//   - The two 20km nearestObjects Mine/MineE scans (~230ms/cycle, measured deleting nothing) are
//     REMOVED: they were redundant with mines_cleaner.sqf, which already tracks EVERY script-placed
//     mine via the global `mines` array (DropRPG.sqf + Construction_StationaryDefense.sqf both do
//     `mines set [count mines, [_mine, time]]`) and age-gates deletion. NOTE: an allMines
//     replacement was tried and REVERTED - allMines is Arma-3-only and returns garbage in A2 OA.
//   Only the whole-island weaponholder scan (the real debris work) remains. No gameplay change
//   (mines still cleaned by mines_cleaner); per-cycle active cost drops from ~350ms to ~115ms.

//--- Cadence: effective interval ~600s. Floor at 300 keeps the legacy guard; default 600
//--- yields the ~10-minute cadence Ray asked for.
_timer = missionNamespace getVariable "WFBE_C_DROPPEDITEMS_CLEANER_TIME_PERIOD";
if (isNil "_timer") then {_timer = 600};
if (_timer < 300) then {_timer = 300};

//--- FIRST sweep runs EARLY so the very first ~10-minute backlog never accumulates.
_firstDelay = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_FIRST_DELAY", 90];
if (_firstDelay < 1) then {_firstDelay = 90};

//--- Per-cycle deletion cap. Delete at most N this cycle and defer the rest to the next
//--- cycle, so a one-off debris spike cannot stall the server. The cooperative sleeps between
//--- deletes are preserved below.
_maxPerCycle = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_MAX_PER_CYCLE", 150];
if (_maxPerCycle < 1) then {_maxPerCycle = 150};

//--- Whole-island scan anchor + radius (weaponholders only; ~20km covers the map).
_scanCentre = [7000, 7500, 0];
_scanRadius = 20000;

//--- For one class, return every matching object within the full-island radius of the centre.
_scanItems = {
	private ["_class"];
	_class = _this select 0;
	nearestObjects [_scanCentre, [_class], _scanRadius]
};

//--- FIRST sweep is EARLY; subsequent sweeps wait the full ~10-minute cadence at loop end.
sleep _firstDelay;

while {!WFBE_GameOver} do {
	// Marty: Performance Audit timing excludes the cooperative delete sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	_perfWeaponholders = 0;
	_perfMines = 0;

	//--- Shared per-cycle deletion budget. _capacity is the remaining number of objects we may
	//--- delete this cycle; leftovers wait for the next cycle.
	_capacity = _maxPerCycle;

	//--- Weaponholders: full-island scan (the real work - dropped weapons/gear left by deaths).
	_perfItemStart = diag_tickTime;
	_clear = ["weaponholder"] call _scanItems;
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfWeaponholders = count _clear;
	_perfScanned = _perfScanned + _perfWeaponholders;
	{
		if (_capacity <= 0) exitWith {};
		_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;_capacity = _capacity - 1;sleep 0.5;
	} forEach _clear;

	//--- Mines: NOT scanned here. mines_cleaner.sqf tracks every createMine via the global `mines`
	//--- array and age-gates deletion, so a scan here would be redundant. _perfMines stays 0 (the
	//--- EXTRA field is kept so the dashboard parse format is stable).

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfExtra = Format["scanned:%1;deleted:%2;weaponholders:%3;mines:%4;cap:%5;cycleMs:%6", _perfScanned, _perfDeleted, _perfWeaponholders, _perfMines, _maxPerCycle, round ((diag_tickTime - _perfStart) * 1000)];
			["cleaner_droppeditems", _perfActive, _perfExtra, "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _timer;
};
