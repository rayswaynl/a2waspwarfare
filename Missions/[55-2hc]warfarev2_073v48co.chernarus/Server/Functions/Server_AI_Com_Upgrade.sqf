/*
	AI Commander Upgrade script.
	 Parameters:
		- Side.

	V0.6.7 UPGRADE QUEUE: when the affordability check fails the current head-of-program
	entry is kept (not dropped) and retried next cycle once supply has regrown.
	A debounced log (at most once per 5 min per side) prevents RPT spam.
	Supply reserve floor: never start an upgrade that would drop supply below
	WFBE_C_AICOM_SUPPLY_RESERVE (default 500) so base building / defense isn't starved.
	At most one upgrade start per call (unchanged behaviour).

	V0.6.8 SKIP-UNAFFORDABLE: the old picker grabbed only the FIRST unmet upgrade and,
	if it was unaffordable, stalled the whole research program (idle funds / starved supply
	for the rest of the match). Now we scan ALL unmet upgrades in program order and start
	the first AFFORDABLE one; only when NONE are affordable do we debounced-warn (reporting
	the head item, which is what's actually being waited on). Supply-reserve floor and the
	one-start-per-call behaviour are unchanged.
*/

Private["_can_upgrade","_cost","_funds","_level","_logik","_path","_side","_upgrade","_upgrades","_supplyReserve","_supply","_lastWarnKey","_lastWarnTime","_nowTime","_currency","_headUpgrade","_headCost","_chosen","_chosenCost"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

_path = missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_AI_ORDER", _side];
_upgrades = _logik getVariable "wfbe_upgrades";

//--- Supply reserve floor: do not start upgrades that would starve base building.
_supplyReserve = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_RESERVE", 500];

//--- Read economy state ONCE up front (the same funds/supply pool applies to every
//--- candidate this cycle, so there's no need to re-query per item).
_funds = _side Call GetAICommanderFunds;
_currency = missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM";
_supply = 0;
if (_currency == 0) then {_supply = _side Call WFBE_CO_FNC_GetSideSupply};

//--- V0.6.8 SKIP-UNAFFORDABLE: scan ALL unmet upgrades in program order. Remember the
//--- FIRST unmet one (the "head", for the warn message) and start the FIRST AFFORDABLE
//--- one. This prevents a single unaffordable head item from stalling the whole program.
_headUpgrade = -1;
_headCost = [];
_chosen = -1;
_chosenCost = [];

{
	_upgrade = _x select 0;
	_level = _x select 1;

	//--- Only consider unmet upgrades.
	if (_upgrades select _upgrade < _level) then {
		//--- V0.5.1: price by CURRENT level (researching level N+1 costs COSTS select N).
		//--- The old "select target level" was off by one: every research charged the
		//--- NEXT level's price (Heavy 1 demanded 4400 instead of 1200 - the round-3 stall).
		_cost = ((missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", _side]) select _upgrade) select (_upgrades select _upgrade);

		//--- Record the head (first unmet) item for the debounced warn.
		if (_headUpgrade < 0) then {
			_headUpgrade = _upgrade;
			_headCost = _cost;
		};

		//--- Affordability gate (reserve floor honoured): pick the first affordable one.
		if (_chosen < 0) then {
			_can_upgrade = false;
			if (_currency == 0) then {
				//--- Reserve gate: net supply after cost must stay >= _supplyReserve.
				if (_supply >= (_cost select 0) + _supplyReserve && _funds >= (_cost select 1)) then {_can_upgrade = true};
			} else {
				if (_funds >= (_cost select 1)) then {_can_upgrade = true};
			};

			if (_can_upgrade) then {
				_chosen = _upgrade;
				_chosenCost = _cost;
			};
		};
	};
} forEach _path;

//--- Roll on! (one start per call)
if (_chosen >= 0) then {
	_upgrade = _chosen;
	_cost = _chosenCost;
	["INFORMATION", Format ["Server_AI_Com_Upgrade.sqf: [%1] researching upgrade id %2 -> level %3 (supply %4, funds %5).", _side, _upgrade, (_upgrades select _upgrade) + 1, _cost select 0, _cost select 1]] Call WFBE_CO_FNC_AICOMLog;
	diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|UPGRADE_RESEARCHED|id" + str _upgrade + "-lvl" + str ((_upgrades select _upgrade) + 1));
	[_side, _upgrade, _upgrades select _upgrade, false] Spawn WFBE_SE_FNC_ProcessUpgrade;
	// Marty: Mirror the AI commander's active upgrade ID for client upgrade-menu status text.
	_logik setVariable ["wfbe_upgrading", true, true];
	_logik setVariable ["wfbe_upgrading_id", _upgrade, true];

	//--- Deduct.
	[_side,-(_cost select 1)] Call ChangeAICommanderFunds; //--- TR12: funds price is _cost select 1 (was select 0, the supply price).

	if (_currency == 0) then {
		[_side,-(_cost select 0),"AI commander tech upgrade.", false] Call ChangeSideSupply; //--- TR12: supply price is _cost select 0 (was select 1, the funds price).
	};
} else {
	//--- V0.6.7 UPGRADE QUEUE: nothing affordable this cycle -> keep program queued,
	//--- debounced warn only (reports the head item, which is what's being waited on).
	if (_headUpgrade >= 0) then {
		_nowTime = time;
		_lastWarnKey = Format ["wfbe_aicom_upg_warn_%1", _side];
		_lastWarnTime = missionNamespace getVariable [_lastWarnKey, -301];
		if (_nowTime - _lastWarnTime >= 300) then {
			missionNamespace setVariable [_lastWarnKey, _nowTime];
			["INFORMATION", Format ["Server_AI_Com_Upgrade.sqf: [%1] no affordable upgrade this cycle; head id %2 -> level %3 queued (needs supply %4+reserve %5 / funds %6) - will retry next cycle.", _side, _headUpgrade, (_upgrades select _headUpgrade) + 1, _headCost select 0, _supplyReserve, _headCost select 1]] Call WFBE_CO_FNC_AICOMLog;
		};
	};
};
