/*
	AI Commander Upgrade script.
	 Parameters:
		- Side.
*/

Private["_can_upgrade","_cost","_funds","_level","_logik","_path","_side","_to_upgrade","_upgrade","_upgrades"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;

_path = missionNamespace getVariable Format ["WFBE_C_UPGRADES_%1_AI_ORDER", _side];
_upgrades = _logik getVariable "wfbe_upgrades";

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
	_cost = ((missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", _side]) select _upgrade) select ((_to_upgrade select 1) - 1); //--- fix: COSTS[upgrade] is 0-indexed by level; the AI_ORDER level is 1-based (matches Client_FNC_Special.sqf:116/122 _level-1). Raw level over-indexed by one -> nil -> "_cost undefined" crash at line 34 on top-level upgrades.
	
	//--- Validation.
	_can_upgrade = false;
	
	_funds = _side Call GetAICommanderFunds;
	if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
		if ((_side Call WFBE_CO_FNC_GetSideSupply) >= (_cost select 0) && _funds >= (_cost select 1)) then {_can_upgrade = true};
	} else {
		if (_funds >= (_cost select 1)) then {_can_upgrade = true};
	};
	
	//--- Roll on!
	if (_can_upgrade) then {
		[_side, _upgrade, _upgrades select _upgrade, false] Spawn WFBE_SE_FNC_ProcessUpgrade;
		// Marty: Mirror the AI commander's active upgrade ID for client upgrade-menu status text.
		_logik setVariable ["wfbe_upgrading", true, true];
		_logik setVariable ["wfbe_upgrading_id", _upgrade, true];
		
		//--- Deduct.
		[_side,-(_cost select 1)] Call ChangeAICommanderFunds; //--- fix: debit the FUNDS cost (was _cost select 0, the supply cost; cost array is [supply,funds]).
		
		if ((missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0) then {
			[_side,-(_cost select 0),"AI commander tech upgrade.", false] Call ChangeSideSupply; //--- fix: debit the SUPPLY cost (was _cost select 1, the funds cost).
		};
		if (!isNil "WFBE_SE_FNC_AI_Com_LogAppend") then {[_side, "UPGRADE", "Server_AI_Com_Upgrade", [_upgrade, (_upgrades select _upgrade), (_to_upgrade select 1), (_cost select 0), (_cost select 1)]] Call WFBE_SE_FNC_AI_Com_LogAppend};
	};
};
