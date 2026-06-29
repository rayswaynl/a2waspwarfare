/*
	Create units for static defence.
	 Parameters:
		- Side
		- Groups
		- Spawn positions
		- Teams
		- Defence
		- Move In Gunner immidietly or not
*/

Private ["_built", "_builtveh", "_groups", "_perfActive", "_perfItemStart", "_perfScope", "_perfStart", "_position", "_positions", "_side", "_sideID", "_team", "_teams", "_town", "_town_teams", "_town_vehicles", "_unit"];

_side = _this select 0;
_groups = _this select 1;
_positions = _this select 2;
_team = _this select 3;
_sideID = (_side) call WFBE_CO_FNC_GetSideID;

_built = 0;
_builtveh = 0;
_teams = [];
// Marty: Performance Audit measures delegated resistance/base unit creation source.
_perfStart = diag_tickTime;
_perfActive = 0;

for '_i' from 0 to count(_groups)-1 do {
	//_position = _positions select _i;
	//_team = _teams select _i;

	["INFORMATION", Format["Common_CreateUnitForstaticForResBases.sqf: [%1] will create a team template %2 at %3", _side, _groups select _i,_positions]] Call WFBE_CO_FNC_LogContent;

	_sideID = (_side) Call GetSideID;
	_perfItemStart = diag_tickTime;
	_unit = [_groups select _i, _team select 0, _positions, _sideID] Call WFBE_CO_FNC_CreateUnit;
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_built  = _built + 1;

	[_teams, _team] call WFBE_CO_FNC_ArrayPush;

	_unit allowFleeing 0; //--- Make the units brave.
};

if (_built > 0) then {[str _side,'UnitsCreated',_built] call UpdateStatistics};

["INFORMATION", Format["Common_CreateUnitForstaticForResBases.sqf:  [%1] was activated witha total of [%3] units.", _side, _built]] Call WFBE_CO_FNC_LogContent;

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["create_resbase_units", _perfActive, Format["side:%1;groups:%2;units:%3;cycleMs:%4", _sideID, count _groups, _built, round ((diag_tickTime - _perfStart) * 1000)], _perfScope] Call PerformanceAudit_Record;
	};
};

[_teams]
