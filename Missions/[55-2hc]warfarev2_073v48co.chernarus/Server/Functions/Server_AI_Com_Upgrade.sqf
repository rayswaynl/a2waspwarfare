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
*/

Private["_can_upgrade","_cost","_funds","_level","_logik","_path","_side","_to_upgrade","_upgrade","_upgrades","_supplyReserve","_supply","_lastWarnKey","_lastWarnTime","_nowTime"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

_path = missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_AI_ORDER", _side];
_upgrades = _logik getVariable "wfbe_upgrades";

//--- Supply reserve floor: do not start upgrades that would starve base building.
_supplyReserve = missionNamespace getVariable ["WFBE_C_AICOM_SUPPLY_RESERVE", 500];

//--- Get the existing content.
_to_upgrade = [];
{
	_upgrade = _x select 0;
	_level = _x select 1;

	if (_upgrades select _upgrade < _level) exitWith {_to_upgrade = _x};
} forEach _path;

//--- Found something to upgrade!
if (count _to_upgrade > 0) then {
	_upgrade = _to_upgrade select 0;
	//--- V0.5.1: price by CURRENT level (researching level N+1 costs COSTS select N).
	//--- The old "select target level" was off by one: every research charged the
	//--- NEXT level's price (Heavy 1 demanded 4400 instead of 1200 - the round-3 stall).
	_cost = ((missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", _side]) select _upgrade) select (_upgrades select _upgrade);

	//--- Validation.
	_can_upgrade = false;

	_funds = _side Call GetAICommanderFunds;
	if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
		_supply = _side Call WFBE_CO_FNC_GetSideSupply;
		//--- Reserve gate: net supply after cost must stay >= _supplyReserve.
		if (_supply >= (_cost select 0) + _supplyReserve && _funds >= (_cost select 1)) then {_can_upgrade = true};
	} else {
		if (_funds >= (_cost select 1)) then {_can_upgrade = true};
	};

	//--- V0.6.7 UPGRADE QUEUE: cannot afford -> keep entry queued, debounced warn only.
	if (!_can_upgrade) then {
		_nowTime = time;
		_lastWarnKey = Format ["wfbe_aicom_upg_warn_%1", _side];
		_lastWarnTime = missionNamespace getVariable [_lastWarnKey, -301];
		if (_nowTime - _lastWarnTime >= 300) then {
			missionNamespace setVariable [_lastWarnKey, _nowTime];
			["INFORMATION", Format ["Server_AI_Com_Upgrade.sqf: [%1] upgrade id %2 -> level %3 queued (cannot afford: needs supply %4+reserve %5 / funds %6) - will retry next cycle.", _side, _upgrade, (_upgrades select _upgrade) + 1, _cost select 0, _supplyReserve, _cost select 1]] Call WFBE_CO_FNC_AICOMLog;
		};
	};

	//--- Roll on!
	if (_can_upgrade) then {
		["INFORMATION", Format ["Server_AI_Com_Upgrade.sqf: [%1] researching upgrade id %2 -> level %3 (supply %4, funds %5).", _side, _upgrade, (_upgrades select _upgrade) + 1, _cost select 0, _cost select 1]] Call WFBE_CO_FNC_AICOMLog;
		diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|UPGRADE_RESEARCHED|id" + str _upgrade + "-lvl" + str ((_upgrades select _upgrade) + 1));
		[_side, _upgrade, _upgrades select _upgrade, false] Spawn WFBE_SE_FNC_ProcessUpgrade;
		// Marty: Mirror the AI commander's active upgrade ID for client upgrade-menu status text.
		_logik setVariable ["wfbe_upgrading", true, true];
		_logik setVariable ["wfbe_upgrading_id", _upgrade, true];

		//--- Deduct.
		[_side,-(_cost select 1)] Call ChangeAICommanderFunds; //--- TR12: funds price is _cost select 1 (was select 0, the supply price).

		if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
			[_side,-(_cost select 0),"AI commander tech upgrade.", false] Call ChangeSideSupply; //--- TR12: supply price is _cost select 0 (was select 1, the funds price).
		};
	};
};
