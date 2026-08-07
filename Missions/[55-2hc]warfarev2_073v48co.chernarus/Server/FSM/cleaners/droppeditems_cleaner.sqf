private["_capacity", "_clear", "_firstDelay", "_gridX", "_gridY", "_mapHalf", "_mapSize", "_maxPerCycle", "_scanCentre", "_scanRadius",
        "_perfActive", "_perfDeleted", "_perfDispatched", "_perfHeldAge", "_perfHeldProx", "_perfItemStart", "_perfMines", "_perfScanned",
        "_perfSliceMax", "_perfSlices", "_perfStart", "_perfWeaponholders", "_scanCell", "_scanCellHalf", "_scanForClass", "_scanGrid",
        "_scanOrigins", "_scanResult", "_scanSliced", "_scanSliceRadius", "_scanSliceSleep", "_timer", "_perfExtra",
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

//--- Configured first delay. The phase guard below may raise it to the steady cadence.
_firstDelay = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_FIRST_DELAY", 90];
if (_firstDelay < 1) then {_firstDelay = 90};

//--- FIRST-SWEEP PHASE GUARD (registered default 1; inline fallback 0). This originally moved the
//--- empty ~90s scan out of the boot/spawn storm. Current Chernarus RPTs prove the deferred 10m scan
//--- still costs 2.5-2.8s while FPS is healthy immediately beforehand, so this changes phase only;
//--- it does not bound the synchronous nearestObjects query. The opt-in path below instead bounds
//--- each query's spatial scope and yields between them for a controlled test-server A/B.
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
_mapSize = missionNamespace getVariable ["WFBE_BOUNDARIESXY", 15360];
if (_mapSize < 1) then {_mapSize = 15360};
if ((missionNamespace getVariable ["WFBE_C_CLEANER_MAP_AWARE_ORIGINS", 0]) > 0) then {
	_mapHalf = _mapSize / 2;
	_scanCentre = [_mapHalf, _mapHalf, 0];
	_scanRadius = _mapSize * 0.72;
};

//--- perf/droppeditems-sliced-scan (draft, default OFF): the legacy 20km nearestObjects call is a
//--- repeatable 2.5-2.8s single-frame hitch on Chernarus even when empty and after the 10m defer.
//--- The opt-in path covers the official map square with a 3x3 grid of half-cell-diagonal circles,
//--- deduplicates overlaps, and yields between queries. Flag OFF retains the exact legacy query.
_scanSliced = (missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_SLICED_SCAN", 0]) > 0;
_scanSliceSleep = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_CLEANER_SLICE_SLEEP", 0.05];
if (_scanSliceSleep < 0.01) then {_scanSliceSleep = 0.05};
_scanGrid = 3;
_scanOrigins = [];
if (_scanSliced) then {
	_scanCell = _mapSize / _scanGrid;
	_scanCellHalf = _scanCell / 2;
	_scanSliceRadius = sqrt ((_scanCellHalf * _scanCellHalf) + (_scanCellHalf * _scanCellHalf)) + 1;
	for "_gridX" from 0 to (_scanGrid - 1) do {
		for "_gridY" from 0 to (_scanGrid - 1) do {
			_scanOrigins set [count _scanOrigins, [_scanCellHalf + (_gridX * _scanCell), _scanCellHalf + (_gridY * _scanCell), 0]];
		};
	};
};

//--- Return [unique objects, measured active seconds, max slice seconds, slice count]. Cooperative
//--- scan sleeps are deliberately outside the active segments; cycleMs below remains wall time.
_scanForClass = {
	private ["_class", "_scanActive", "_scanItems", "_scanObject", "_scanOrigin", "_scanSlice", "_scanSliceDt", "_scanSliceMax", "_scanSliceStart", "_scanSlices"];
	_class = _this select 0;
	_scanItems = [];
	_scanActive = 0;
	_scanSliceMax = 0;
	_scanSlices = 0;
	if (_scanSliced) then {
		{
			_scanOrigin = _x;
			_scanSliceStart = diag_tickTime;
			_scanSlice = nearestObjects [_scanOrigin, [_class], _scanSliceRadius];
			{
				_scanObject = _x;
				if (!(_scanObject in _scanItems)) then {
					_scanItems set [count _scanItems, _scanObject];
				};
			} forEach _scanSlice;
			_scanSliceDt = diag_tickTime - _scanSliceStart;
			_scanActive = _scanActive + _scanSliceDt;
			if (_scanSliceDt > _scanSliceMax) then {_scanSliceMax = _scanSliceDt};
			_scanSlices = _scanSlices + 1;
			if (_scanSlices < count _scanOrigins) then {sleep _scanSliceSleep;};
		} forEach _scanOrigins;
	} else {
		_scanSliceStart = diag_tickTime;
		_scanItems = nearestObjects [_scanCentre, [_class], _scanRadius];
		_scanSliceDt = diag_tickTime - _scanSliceStart;
		_scanActive = _scanSliceDt;
		_scanSliceMax = _scanSliceDt;
		_scanSlices = 1;
	};
	[_scanItems, _scanActive, _scanSliceMax, _scanSlices]
};

//--- Wait the configured/phase-guarded first delay; later sweeps use the cadence at loop end.
sleep _firstDelay;

while {!WFBE_GameOver} do {
	// Marty: Performance Audit active timing excludes cooperative scan and delete sleeps below.
	_perfStart = diag_tickTime;
	_perfActive = 0;
	_perfScanned = 0;
	_perfDeleted = 0;
	_perfWeaponholders = 0;
	_perfMines = 0;
	_perfDispatched = 0;
	_perfHeldAge = 0;
	_perfHeldProx = 0;
	_perfSliceMax = 0;
	_perfSlices = 0;

	//--- Shared per-cycle deletion budget. _capacity is the remaining number of objects we may
	//--- delete this cycle; leftovers wait for the next cycle.
	_capacity = _maxPerCycle;

	//--- Weaponholders: full-island scan (the real work - dropped weapons/gear left by deaths).
	_scanResult = ["weaponholder"] call _scanForClass;
	_clear = _scanResult select 0;
	_perfActive = _perfActive + (_scanResult select 1);
	_perfSliceMax = _scanResult select 2;
	_perfSlices = _scanResult select 3;
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
			};
			_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
			if (!_whSkip) then {sleep 0.5;};
		};
	} forEach _clear;

	//--- Mines: NOT scanned here. mines_cleaner.sqf tracks every createMine via the global `mines`
	//--- array and age-gates deletion, so a scan here would be redundant. _perfMines stays 0 (the
	//--- EXTRA field is kept so the dashboard parse format is stable).

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfExtra = Format["scanned:%1;deleted:%2;weaponholders:%3;mines:%4;cap:%5;cycleMs:%6;dispatched:%7;heldAge:%8;heldProx:%9;slices:%10;sliceMaxMs:%11", _perfScanned, _perfDeleted, _perfWeaponholders, _perfMines, _maxPerCycle, round ((diag_tickTime - _perfStart) * 1000), _perfDispatched, _perfHeldAge, _perfHeldProx, _perfSlices, round (_perfSliceMax * 1000)];
			["cleaner_droppeditems", _perfActive, _perfExtra, "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _timer;
};
