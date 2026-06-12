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

Private ["_built", "_builtveh", "_defence", "_groups", "_moveInGunner", "_perfActive", "_perfItemStart", "_perfScope", "_perfStart", "_position", "_positions", "_side", "_sideID", "_team", "_teams", "_townDefenderAI", "_town_vehicles", "_unit"];

_side = _this select 0;
_groups = _this select 1;
_positions = _this select 2;
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;
// Marty: Optional flag marks town static defender AI without affecting player/base defenses.
_townDefenderAI = if (count _this > 6) then {_this select 6} else {false};
_sideID = (_side) call WFBE_CO_FNC_GetSideID;

_built = 0;
_builtveh = 0;
_teams = [];
// Marty: Performance Audit measures delegated/static defense unit creation source.
_perfStart = diag_tickTime;
_perfActive = 0;

for '_i' from 0 to count(_groups)-1 do {
	_position = _positions select _i;
	//_team = _teams select _i;

	["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf: [%1] will create a team template %2 at %3", _side, _groups select _i,_position]] Call WFBE_CO_FNC_LogContent;

	_sideID = (_side) Call GetSideID;
	_perfItemStart = diag_tickTime;
	_unit = [_groups select _i, _team, _position, _sideID] Call WFBE_CO_FNC_CreateUnit;
	_perfActive = _perfActive + (diag_tickTime - _perfItemStart);
	_built  = _built + 1;

	// Marty: Mark delegated town static gunners for enemy-town activation filtering.
	if (_townDefenderAI) then {
		_unit setVariable ["WFBE_IsTownDefenderAI", true, true];
		(group _unit) setVariable ["WFBE_IsTownDefenderAI", true];
	};

	[_teams, _team] call WFBE_CO_FNC_ArrayPush;
	_unit assignAsGunner _defence;
	[_unit] orderGetIn true;

	if(_moveInGunner)then{
		_unit moveInGunner _defence
	}else{
		[_unit] allowGetIn true
	};

	[group _unit, 175, getPos _defence] spawn WFBE_CO_FNC_RevealArea;



	_unit allowFleeing 0; //--- Make the units brave.
};

if (_built > 0) then {[str _side,'UnitsCreated',_built] call UpdateStatistics};

["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf:  [%1] was activated witha total of [%3] units.", _side, _built]] Call WFBE_CO_FNC_LogContent;

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["create_static_defense_units", _perfActive, Format["side:%1;groups:%2;units:%3;moveIn:%4;cycleMs:%5", _sideID, count _groups, _built, _moveInGunner, round ((diag_tickTime - _perfStart) * 1000)], _perfScope] Call PerformanceAudit_Record;
	};
};

[_teams]
