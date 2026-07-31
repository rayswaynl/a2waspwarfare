/*
	Set the side commander income-split percent (wfbe_commander_percent).
	Parameters:
		- Side.
		- Percent (scalar 0..WFBE_C_ECONOMY_INCOME_PERCENT_MAX).
		- Requesting player (commander leader).

	Authority: only the seated human commander leader may write the public split.
	Previously any client could public-setVariable the side logic field from the
	Economy menu (no commander gate), which the server income tick consumes.
*/

Private ["_side","_pct","_requester","_logik","_cmdTeam","_max"];

if (typeName _this != "ARRAY") exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected malformed payload type [%1].", typeName _this]] Call WFBE_CO_FNC_LogContent;
};
if ((count _this) < 3) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected short payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};

_side = _this select 0;
_pct = _this select 1;
_requester = _this select 2;

if (typeName _side != "SIDE") exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected non-side [%1].", typeName _side]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _pct != "SCALAR") exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected non-scalar percent [%1].", typeName _pct]] Call WFBE_CO_FNC_LogContent;
};
if (typeName _requester != "OBJECT" || {isNull _requester} || {!isPlayer _requester} || {!alive _requester}) exitWith {
	["WARNING", "RequestCommanderPercent.sqf: rejected invalid requester."] Call WFBE_CO_FNC_LogContent;
};
if (side (group _requester) != _side) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected requester side mismatch (player %1 vs payload %2).", side (group _requester), _side]] Call WFBE_CO_FNC_LogContent;
};

_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNull _logik) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected null side logic for %1.", _side]] Call WFBE_CO_FNC_LogContent;
};

_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
if (isNull _cmdTeam) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected - no commander team for side %1.", _side]] Call WFBE_CO_FNC_LogContent;
};
if (group _requester != _cmdTeam) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected non-commander requester [%1].", name _requester]] Call WFBE_CO_FNC_LogContent;
};
if (leader _cmdTeam != _requester) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected requester [%1] is not commander leader.", name _requester]] Call WFBE_CO_FNC_LogContent;
};
if (!isPlayer (leader _cmdTeam)) exitWith {
	["WARNING", Format ["RequestCommanderPercent.sqf: rejected - commander team for side %1 is not player-led.", _side]] Call WFBE_CO_FNC_LogContent;
};

_max = missionNamespace getVariable ["WFBE_C_ECONOMY_INCOME_PERCENT_MAX", 100];
if (typeName _max != "SCALAR") then {_max = 100};
if (_max < 0) then {_max = 0};
_pct = floor _pct;
if (_pct < 0) then {_pct = 0};
if (_pct > _max) then {_pct = _max};

_logik setVariable ["wfbe_commander_percent", _pct, true];
["INFORMATION", Format ["RequestCommanderPercent.sqf: side %1 commander percent set to %2 by [%3].", _side, _pct, name _requester]] Call WFBE_CO_FNC_LogContent;
