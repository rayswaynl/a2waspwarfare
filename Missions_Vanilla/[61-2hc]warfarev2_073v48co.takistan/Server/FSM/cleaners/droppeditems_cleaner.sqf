private["_capacity", "_clear", "_firstDelay", "_maxPerCycle", "_scanCentre", "_scanRadius",
        "_perfActive", "_perfDeleted", "_perfItemStart", "_perfMines", "_perfMineE", "_perfScanned",
        "_perfStart", "_perfWeaponholders", "_scanItems", "_timer",
        "_lotteryOn", "_cashMin", "_cashMax", "_humans", "_winner", "_amount", "_winnerName", "_lotMsg", "_perfExtra"];

// AI-lane (Ray spec 2026-06-16): SIMPLE full-island sweep on a ~10-minute cadence.
// The prior active-area SCOPING pass has been DISCARDED. We keep the FULL whole-island
// nearestObjects scan for the three debris classes but run it only every ~10 minutes,
// with the FIRST sweep run EARLY (~90s) so no 10-minute boot backlog ever forms (that is
// what avoids the multi-second boot-freeze WITHOUT distance/active-area scoping).

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

//--- SALVAGE LOTTERY (Ray's repurpose of the old "Lucky Salvage" wildcard). After every
//--- cleanup sweep, ONE random online HUMAN player is awarded a random cash amount and a
//--- server-wide announcement fires. Default ON; cash range + on/off are config-tunable.
_lotteryOn = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_SALVAGE_LOTTERY", 1];
_cashMin   = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_SALVAGE_CASH_MIN", 5000];
_cashMax   = missionNamespace getVariable ["WFBE_C_DROPPEDITEMS_SALVAGE_CASH_MAX", 15000];
if (_cashMin < 0) then {_cashMin = 5000};
if (_cashMax < _cashMin) then {_cashMax = _cashMin};

//--- Whole-island scan anchor + radius (legacy centred-island sweep; ~20km covers the map).
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
	_perfMineE = 0;

	//--- Shared per-cycle deletion budget across all three classes. _capacity is the remaining
	//--- number of objects we may delete this cycle; leftovers wait for the next cycle.
	_capacity = _maxPerCycle;

	_perfItemStart = diag_tickTime;
	_clear = ["weaponholder"] call _scanItems;
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfWeaponholders = count _clear;
	_perfScanned = _perfScanned + _perfWeaponholders;
	{
		if (_capacity <= 0) exitWith {};
		_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;_capacity = _capacity - 1;sleep 0.5;
	} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = ["Mine"] call _scanItems;
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfMines = count _clear;
	_perfScanned = _perfScanned + _perfMines;
	{
		if (_capacity <= 0) exitWith {};
		_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;_capacity = _capacity - 1;sleep 0.5;
	} forEach _clear;

	_perfItemStart = diag_tickTime;
	_clear = ["MineE"] call _scanItems;
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_perfMineE = count _clear;
	_perfScanned = _perfScanned + _perfMineE;
	{
		if (_capacity <= 0) exitWith {};
		_perfItemStart = diag_tickTime;deleteVehicle _x;_perfActive = _perfActive + (diag_tickTime - _perfItemStart);_perfDeleted = _perfDeleted + 1;_capacity = _capacity - 1;sleep 0.5;
	} forEach _clear;

	//--- ---------------------------------------------------------------------------------
	//--- SALVAGE LOTTERY: pick ONE random online HUMAN player, award random cash, announce.
	//--- ---------------------------------------------------------------------------------
	_winner = objNull;
	_amount = 0;
	_winnerName = "";
	if (_lotteryOn > 0) then {
		//--- Enumerate real human players. EXCLUDE headless clients and the server:
		//---   - side filter (west/east) drops HCs (they sit civilian) and any non-combatant,
		//---   - explicit HC-leader exclusion via the live HC registry (belt-and-suspenders),
		//---   - the dedicated server is not in playableUnits, so it is excluded naturally.
		_humans = [];
		{
			if (isPlayer _x && {alive _x} && {(side _x) in [west, east]}) then {
				_humans set [count _humans, _x];
			};
		} forEach playableUnits;
		//--- Remove any unit that is the leader of a registered live headless client group.
		{
			if (!isNull _x && {!isNull (leader _x)}) then {_humans = _humans - [leader _x]};
		} forEach (missionNamespace getVariable ["WFBE_HEADLESSCLIENTS_ID", []]);

		if (count _humans > 0) then {
			_winner = _humans select (floor (random (count _humans)));
			//--- Random cash in the configured range, rounded to whole funds.
			_amount = _cashMin + floor (random ((_cashMax - _cashMin) + 1));
			_winnerName = name _winner;
			//--- GRANT to the winner's team funds. In WASP a player's spendable money is the
			//--- wfbe_funds on his GROUP; ChangeTeamFunds adds to it and setVariable's it PUBLIC
			//--- (Common_ChangeTeamFunds.sqf:8 -> setVariable [...,true]) so the client HUD updates.
			//--- Same fund path the W1 War Chest human payout and the AI-team kill bounty use
			//--- (RequestOnUnitKilled.sqf:211 -> [_killer_group, _bounty] Call ChangeTeamFunds).
			[group _winner, _amount] Call ChangeTeamFunds;
			//--- Broadcast to ALL clients. Reuse the existing server->all announce path: the
			//--- "Wildcard" LocalizeMessage case (Client\PVFunctions\LocalizeMessage.sqf:163)
			//--- prints select-1 verbatim via CommandChatMessage to everyone. nil target = all.
			_lotMsg = Format ["Salvage Lottery: %1 recovered $%2 from the battlefield salvage!", _winnerName, _amount];
			[nil, "LocalizeMessage", ["Wildcard", _lotMsg]] Call WFBE_CO_FNC_SendToClients;
		};
	};

	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			_perfExtra = Format["scanned:%1;deleted:%2;weaponholders:%3;mines:%4;mineE:%5;cap:%6;cycleMs:%7;lotteryWinner:%8;lotteryAmount:%9", _perfScanned, _perfDeleted, _perfWeaponholders, _perfMines, _perfMineE, _maxPerCycle, round ((diag_tickTime - _perfStart) * 1000), if (_winnerName != "") then {_winnerName} else {"none"}, _amount];
			["cleaner_droppeditems", _perfActive, _perfExtra, "SERVER"] Call PerformanceAudit_Record;
		};
	};

	sleep _timer;
};
