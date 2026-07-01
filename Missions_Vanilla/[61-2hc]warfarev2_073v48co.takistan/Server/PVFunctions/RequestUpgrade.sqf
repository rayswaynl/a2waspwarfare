/*
	A client request an upgrade
*/

Private ["_args","_clink","_cmdTeam","_cost","_costs","_current","_dual","_enabled","_funds","_i","_levels","_linkNeeded","_links","_linksForLevel","_logic","_requester","_requestTeam","_side","_supply","_target","_times","_upgrade_id","_upgrade_isplayer","_upgrade_level","_upgrades"];

if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};

_args = _this;
if (count _args < 6) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected short payload [%1].", _args]] Call WFBE_CO_FNC_LogContent;
};

_side = _args select 0;
_upgrade_id = _args select 1;
_upgrade_level = _args select 2;
_upgrade_isplayer = _args select 3;
_requester = _args select 4;
_requestTeam = _args select 5;

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected non-side payload side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _upgrade_id != "SCALAR" || {_upgrade_id != floor _upgrade_id}) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected non-integer upgrade id [%1].", _upgrade_id]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _upgrade_level != "SCALAR" || {_upgrade_level != floor _upgrade_level}) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected non-integer upgrade level [%1].", _upgrade_level]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _upgrade_isplayer != "BOOL" || {!_upgrade_isplayer}) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected non-player upgrade request flag [%1].", _upgrade_isplayer]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _requester != "OBJECT" || {isNull _requester}) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected invalid requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _requestTeam != "GROUP" || {isNull _requestTeam}) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected invalid requester team [%1].", _requestTeam]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer _requester) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected non-player requester [%1].", _requester]] Call WFBE_CO_FNC_LogContent;
};
if (group _requester != _requestTeam) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected requester/team mismatch [%1/%2].", _requester, _requestTeam]] Call WFBE_CO_FNC_LogContent;
};
if (side _requestTeam != _side) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected requester side mismatch payload [%1] requester [%2].", _side, side _requestTeam]] Call WFBE_CO_FNC_LogContent;
};

_logic = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logic) exitWith {};

//--- RequestUpgrade is the player-commander path. Queue and AI commander upgrades call
//--- ProcessUpgrade directly, so bind client PVs to the human commander group.
_cmdTeam = _side Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _cmdTeam) exitWith {};
if (_requestTeam != _cmdTeam) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected requester team [%1] is not commander team [%2] for side %3.", _requestTeam, _cmdTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if (leader _cmdTeam != _requester) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected requester [%1] is not commander leader [%2] for side %3.", _requester, leader _cmdTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer (leader _cmdTeam)) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected - commander team for side %1 is not player-led.", _side]] Call WFBE_CO_FNC_LogContent;
};
if (side (leader _cmdTeam) != _side) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected - commander team side mismatch for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
};

if (_logic getVariable ["wfbe_upgrading", false]) exitWith {};

_enabled = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_ENABLED", str _side];
if (typeName _enabled != "ARRAY") exitWith {};
if (_upgrade_id < 0 || {_upgrade_id >= count _enabled}) exitWith {};
if !(_enabled select _upgrade_id) exitWith {};

_upgrades = _side Call WFBE_CO_FNC_GetSideUpgrades;
if (typeName _upgrades != "ARRAY") exitWith {};
if (_upgrade_id >= count _upgrades) exitWith {};
_current = _upgrades select _upgrade_id;
if (typeName _current != "SCALAR") exitWith {};

//--- The client sends its observed current level. Re-read it server-side and reject
//--- replayed, skipped-level or stale-start payloads before the timer worker starts.
if (_upgrade_level != _current) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected stale/skipped upgrade level id %1 payload %2 server %3.", _upgrade_id, _upgrade_level, _current]] Call WFBE_CO_FNC_LogContent;
};

_levels = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LEVELS", str _side];
if (typeName _levels != "ARRAY") exitWith {};
if (_upgrade_id >= count _levels) exitWith {};
if (typeName (_levels select _upgrade_id) != "SCALAR") exitWith {};
if (_current >= (_levels select _upgrade_id)) exitWith {};

_times = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_TIMES", str _side];
if (typeName _times != "ARRAY") exitWith {};
if (_upgrade_id >= count _times) exitWith {};
if (typeName (_times select _upgrade_id) != "ARRAY") exitWith {};
if (_current >= count (_times select _upgrade_id)) exitWith {};

_costs = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_COSTS", str _side];
if (typeName _costs != "ARRAY") exitWith {};
if (_upgrade_id >= count _costs) exitWith {};
if (typeName (_costs select _upgrade_id) != "ARRAY") exitWith {};
if (_current >= count (_costs select _upgrade_id)) exitWith {};
_cost = (_costs select _upgrade_id) select _current;
if (typeName _cost != "ARRAY" || {count _cost < 2}) exitWith {};
if (typeName (_cost select 0) != "SCALAR" || {typeName (_cost select 1) != "SCALAR"}) exitWith {};

_links = missionNamespace getVariable Format["WFBE_C_UPGRADES_%1_LINKS", str _side];
if (typeName _links != "ARRAY") exitWith {};
if (_upgrade_id >= count _links) exitWith {};
if (typeName (_links select _upgrade_id) != "ARRAY") exitWith {};
if (_current >= count (_links select _upgrade_id)) exitWith {};

_linksForLevel = (_links select _upgrade_id) select _current;
if (typeName _linksForLevel != "ARRAY") exitWith {};
_linkNeeded = false;
if (count _linksForLevel > 0) then {
	if (typeName (_linksForLevel select 0) == "ARRAY") then {
		for "_i" from 0 to (count _linksForLevel - 1) do {
			_clink = _linksForLevel select _i;
			_target = _clink select 0;
			if (_target < 0 || {_target >= count _upgrades} || {(_upgrades select _target) < (_clink select 1)}) exitWith {_linkNeeded = true};
		};
	} else {
		_target = _linksForLevel select 0;
		if (_target < 0 || {_target >= count _upgrades} || {(_upgrades select _target) < (_linksForLevel select 1)}) then {_linkNeeded = true};
	};
};
if (_linkNeeded) exitWith {};

_dual = (missionNamespace getVariable "WFBE_C_ECONOMY_CURRENCY_SYSTEM") == 0;
_funds = _cmdTeam Call WFBE_CO_FNC_GetTeamFunds;
if (_funds < (_cost select 1)) exitWith {
	["WARNING", Format ["RequestUpgrade.sqf: rejected unaffordable funds side %1 id %2 need %3 have %4.", _side, _upgrade_id, _cost select 1, _funds]] Call WFBE_CO_FNC_LogContent;
};
if (_dual) then {
	_supply = _side Call WFBE_CO_FNC_GetSideSupply;
	if (_supply < (_cost select 0)) exitWith {
		["WARNING", Format ["RequestUpgrade.sqf: rejected unaffordable supply side %1 id %2 need %3 have %4.", _side, _upgrade_id, _cost select 0, _supply]] Call WFBE_CO_FNC_LogContent;
	};
};

//--- Commit server-owned payment and running state only after every acceptance gate passes.
_logic setVariable ["wfbe_upgrading", true, true];
_logic setVariable ["wfbe_upgrading_id", _upgrade_id, true];
if (_dual) then {
	[_side, -(_cost select 0), "Player commander tech upgrade.", false] Call ChangeSideSupply;
};
[_cmdTeam, -(_cost select 1)] Call WFBE_CO_FNC_ChangeTeamFunds;
["INFORMATION", Format ["RequestUpgrade.sqf: accepted player commander upgrade side %1 id %2 -> level %3 (supply %4, funds %5).", _side, _upgrade_id, _current + 1, _cost select 0, _cost select 1]] Call WFBE_CO_FNC_LogContent;

_args Spawn WFBE_SE_FNC_ProcessUpgrade;
