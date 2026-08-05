private["_capacity", "_clear", "_firstDelay", "_mapHalf", "_mapSize", "_maxPerCycle", "_scanCentre", "_scanRadius",
        "_perfActive", "_perfDeleted", "_perfDispatched", "_perfHeldAge", "_perfHeldProx", "_perfItemStart", "_perfMines", "_perfScanned",
        "_perfStart", "_perfWeaponholders", "_scanItems", "_timer", "_perfExtra",
        "_minAge", "_prox", "_proxHold", "_whAge", "_whFirst", "_whNear", "_whNearResult", "_whSkip"];

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

//--- BOOT-STALL GUARD (flag WFBE_C_DROPPEDITEMS_CLEANER_DEFER_FIRST, default 0 = HEAD behaviour).
//--- The first whole-island weaponholder sweep is IDENTICAL in radius (20000) and results to every
//--- later sweep, but when it fires early at ~90s it lands inside the boot/spawn storm where the
//--- server main thread is saturated, so the SAME scan measures ~6.5s wall (Performance Audit
//--- cleaner_droppeditems MAX_MS 6414-6583, scanned:0 deleted:0) vs ~48-115ms once the server has
//--- settled. The sibling whole-map cleaners (crater/ruins) never spike because their first sweep
//--- is floored to >=1800s. When this flag is >0, defer the first droppeditems sweep to the steady
//--- cadence (_timer) so pass 1 also runs on a settled server. Nothing is skipped: at ~90s the
//--- early sweep finds ZERO drops (no deaths yet), so deferring only shifts an empty scan.
if ((missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_DEFER_FIRST", 0]) > 0) then {
	if (_firstDelay < _timer) then {_firstDelay = _timer};
};

//--- Per-cycle deletion cap. Delete at most N this cycle and defer the rest to the next
//--- cycle, so a one-off debris spike cannot stall the server. The cooperative sleeps between
//--- deletes are preserved below.
_maxPerCycle = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_MAX_PER_CYCLE", 150];
if (_maxPerCycle < 1) then {_maxPerCycle = 150};

//--- Min age (seconds) a weaponholder must live before this cleaner may reap it. Without this a
//--- drop created 1s before a sweep has zero guaranteed loot window (mines_cleaner age-gates;
//--- bodies use BODIES_TIMEOUT; holders had neither). 0 = legacy immediate-reap.
_minAge = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_MIN_AGE", 120];
if (_minAge < 0) then {_minAge = 0};

//--- Player-proximity hold (metres). Mirror of WFBE_C_UNITS_BODIES_PROX for corpses: never pop a
//--- gear pile under a looting player's feet. 0 = off. Hold is capped by
//--- WFBE_C_DROPPEDITEMS_PROX_HOLD past min-age so a camper cannot pin residue forever.
_prox = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_PROX", 20];
if (_prox < 0) then {_prox = 0};
_proxHold = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_PROX_HOLD", 300];
if (_proxHold < 0) then {_proxHold = 0};

//--- PR #1718 fix (owner ruling 2026-08-05, flag WFBE_C_DROPPEDITEMS_HOLD_ENABLE default 0):
//--- the age/proximity hold above shipped ARMED with no opt-in, violating flag policy (every
//--- server held weaponholder piles >=120s, up to 420s under camping, with no off-switch).
//--- With the flag at 0, force both gate inputs to 0 so the ">0" checks below (_minAge>0 at the
//--- age gate, _prox>0 at the proximity gate) are never true - this reproduces the pre-#1718
//--- immediate-reap path byte-for-byte. 1 = arm the hold using the tuning values read above.
if ((missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_HOLD_ENABLE", 0]) <= 0) then {
	_minAge = 0;
	_prox = 0;
	_proxHold = 0;
};

//--- Whole-island scan anchor + radius (weaponholders only; ~20km covers the legacy Chernarus map).
_scanCentre = [7000, 7500, 0];
_scanRadius = 20000;
if ((missionNamespace getVariable ["WFBE_C_CLEANER_MAP_AWARE_ORIGINS", 0]) > 0) then {
	_mapSize = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
	if (_mapSize < 1) then {_mapSize = 15360};
	_mapHalf = _mapSize / 2;
	_scanCentre = [_mapHalf, _mapHalf, 0];
	_scanRadius = _mapSize * 0.72;
};

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
	_perfDispatched = 0;
	_perfHeldAge = 0;
	_perfHeldProx = 0;

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
		if (isNull _x) then {} else {
			_perfItemStart = diag_tickTime;
			_whSkip = false;

			//--- First-seen stamp (server-local). Age is measured across cleaner cycles so a holder
			//--- dropped just before a sweep still earns its min-age window on a later pass.
			_whFirst = _x getVariable "wfbe_wh_first_seen";
			if (isNil "_whFirst") then {
				_x setVariable ["wfbe_wh_first_seen", time];
				_whFirst = time;
			};
			_whAge = time - _whFirst;
			if (_minAge > 0 && {_whAge < _minAge}) then {
				_whSkip = true;
				_perfHeldAge = _perfHeldAge + 1;
			};

			//--- Proximity hold (capped). Bodies already do this; holders previously wiped mid-loot.
			if (!_whSkip && {_prox > 0}) then {
				_whNear = false;
				_whNearResult = 0;
				_whNearResult = [getPos _x, _prox] Call WFBE_CO_FNC_RealPlayersNear;
				if ((typeName _whNearResult) == "SCALAR" && {_whNearResult > 0}) then {_whNear = true};
				if (_whNear && {_whAge < (_minAge + _proxHold)}) then {
					_whSkip = true;
					_perfHeldProx = _perfHeldProx + 1;
				};
			};

			if (!_whSkip) then {
				//--- fable/cleanup-locality-2 (PVF-class hunt, CRITICAL): deleteVehicle on a NON-LOCAL object
				//--- silently no-ops in A2 OA - and weaponholders from PLAYER deaths are local to that player's
				//--- client, from HC-delegated AI deaths local to that HC. This cleaner was the ONLY cleanup
				//--- path for them and it counted every holder as "deleted" while the piles stayed forever.
				//--- Non-local holders now go to their owner via the TrashObject channel idiom - but through a
				//--- DEDICATED receiver case: holders are "alive", so the cleanup-trash-object case's !alive
				//--- gate can never pass them. Receiver re-checks local + reap stamp + isKindOf WeaponHolder.
				if (local _x) then {
					deleteVehicle _x;
					_perfDeleted = _perfDeleted + 1;
				} else {
					_x setVariable ["wfbe_trash_reap", true, true];
					[_x, "HandleSpecial", ["cleanup-weaponholder", _x]] Call WFBE_CO_FNC_SendToClient;
					_perfDispatched = _perfDispatched + 1;
				};
				_capacity = _capacity - 1;
				sleep 0.5;
			};
			_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
		};
	} forEach _clear;

	//--- Mines: NOT scanned here. mines_cleaner.sqf tracks every createMine via the global `mines`
	//--- array and age-gates deletion, so a scan here would be redundant. _perfMines stays 0 (the
	//--- EXTRA field is kept so the dashboard parse format is stable).

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfExtra = Format["scanned:%1;deleted:%2;weaponholders:%3;mines:%4;cap:%5;cycleMs:%6;dispatched:%7;heldAge:%8;heldProx:%9", _perfScanned, _perfDeleted, _perfWeaponholders, _perfMines, _maxPerCycle, round ((diag_tickTime - _perfStart) * 1000), _perfDispatched, _perfHeldAge, _perfHeldProx];
			["cleaner_droppeditems", _perfActive, _perfExtra, "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _timer;
};
