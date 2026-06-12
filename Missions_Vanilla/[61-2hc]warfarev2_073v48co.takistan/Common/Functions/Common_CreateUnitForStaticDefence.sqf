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

Private ["_assignedUnit", "_built", "_defence", "_diagEnabled", "_groups", "_manningInProgress", "_moveInGunner", "_perfActive", "_perfItemStart", "_perfScope", "_perfStart", "_position", "_positions", "_side", "_sideID", "_team", "_teamLeader", "_teams", "_unit"];

_side = _this select 0;
_groups = _this select 1;
_positions = _this select 2;
_team = _this select 3;
_defence = _this select 4;
_moveInGunner = _this select 5;
_sideID = (_side) call WFBE_CO_FNC_GetSideID;

_built = 0;
_teams = [];
_perfStart = diag_tickTime;
_perfActive = 0;
_diagEnabled = missionNamespace getVariable ["TownDefenseDiagnosticsEnabled", false];

if (isNull _defence) exitWith {
	["WARNING", Format["Common_CreateUnitForstaticDefence.sqf: [%1] skipped static defense creation because the defence object is null.", _side]] Call WFBE_CO_FNC_LogContent;
	[_teams]
};

if !(isNull (gunner _defence)) exitWith {
	["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf: [%1] skipped duplicate request for [%2], gunner already alive.", _side, typeOf _defence]] Call WFBE_CO_FNC_LogContent;
	[_teams]
};

_assignedUnit = _defence getVariable "WFBE_StaticDefenseAssignedUnit";
if (isNil "_assignedUnit") then {_assignedUnit = objNull};
if (!(isNull _assignedUnit) && !(alive _assignedUnit)) then {
	_defence setVariable ["WFBE_StaticDefenseAssignedUnit", objNull, true];
};
if (!(isNull _assignedUnit) && (alive _assignedUnit)) exitWith {
	[_assignedUnit] allowGetIn true;
	_assignedUnit assignAsGunner _defence;
	[_assignedUnit] orderGetIn true;
	if (_moveInGunner) then {_assignedUnit moveInGunner _defence};
	["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf: [%1] skipped duplicate request for [%2], assigned unit still alive.", _side, typeOf _defence]] Call WFBE_CO_FNC_LogContent;
	[_teams]
};

_manningInProgress = _defence getVariable "WFBE_StaticDefenseManningInProgress";
if (isNil "_manningInProgress") then {_manningInProgress = false};
if (_manningInProgress) exitWith {
	["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf: [%1] skipped duplicate request for [%2], manning already in progress.", _side, typeOf _defence]] Call WFBE_CO_FNC_LogContent;
	[_teams]
};
_defence setVariable ["WFBE_StaticDefenseManningInProgress", true, true];

for '_i' from 0 to count(_groups)-1 do {
	_position = _positions select _i;

	["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf: [%1] will create a team template %2 at %3", _side, _groups select _i, _position]] Call WFBE_CO_FNC_LogContent;

	_sideID = (_side) Call GetSideID;
	_perfItemStart = diag_tickTime;
	if (isNull _team || {(count units _team) == 0}) then {_team = createGroup _side};
	if ((count units _team) > 0) then {
		_teamLeader = leader _team;
		if (!(isNull _teamLeader) && {!local _teamLeader}) then {_team = createGroup _side};
	};

	if (isNull _team) then {
		["WARNING", Format["Common_CreateUnitForstaticDefence.sqf: [%1] failed to create a group for static gunner template %2 at %3", _side, _groups select _i, _position]] Call WFBE_CO_FNC_LogContent;
	} else {
		_unit = [_groups select _i, _team, _position, _sideID] Call WFBE_CO_FNC_CreateUnit;
		_perfActive = _perfActive + (diag_tickTime - _perfItemStart);

		if (isNull _unit) then {
			["WARNING", Format["Common_CreateUnitForstaticDefence.sqf: [%1] failed to create static gunner template %2 at %3", _side, _groups select _i, _position]] Call WFBE_CO_FNC_LogContent;
		} else {
			_built = _built + 1;
			_defence setVariable ["WFBE_StaticDefenseAssignedUnit", _unit, true];

			if (_diagEnabled) then {
				["TOWN_DEFENSE_DIAG", Format ["static_create_unit_result side:%1;template:%2;unitNull:%3;teamNull:%4;defense:%5;moveIn:%6;localServer:%7;hasInterface:%8", _side, _groups select _i, isNull _unit, isNull _team, typeOf _defence, _moveInGunner, isServer, hasInterface]] Call WFBE_CO_FNC_LogContent;
			};

			[_teams, _team] call WFBE_CO_FNC_ArrayPush;
			[_unit] allowGetIn true;
			_unit assignAsGunner _defence;
			[_unit] orderGetIn true;

			if(_moveInGunner)then{
				_unit moveInGunner _defence;
				[_unit,_defence] Spawn {
					Private ["_defence","_unit"];
					_unit = _this select 0;
					_defence = _this select 1;
					sleep 1;
					if (alive _unit && alive _defence && (gunner _defence != _unit)) then {
						_unit setPosATL (getPosATL _defence);
						[_unit] allowGetIn true;
						_unit assignAsGunner _defence;
						[_unit] orderGetIn true;
						_unit moveInGunner _defence;
						["WARNING", Format["Common_CreateUnitForstaticDefence.sqf: retried instant static manning for [%1].", typeOf _defence]] Call WFBE_CO_FNC_LogContent;
					};
					if (alive _unit && alive _defence && (gunner _defence == _unit)) then {
						_unit disableAI "MOVE";
						_unit setVariable ["WFBE_StaticDefenseSettled", true, true];
					};
				};
			}else{
				[_unit] allowGetIn true;
				//--- Walk-in boarding watchdog: an HC-local AI boarding a server-local
				//--- static silently stalls at the gun (walks there, never mounts). The
				//--- instant path retries; this path had nothing. 90s grace, then force.
				[_unit,_defence] Spawn {
					Private ["_defence","_unit","_deadline"];
					_unit = _this select 0;
					_defence = _this select 1;
					_deadline = time + 90;
					waitUntil {sleep 5; (time > _deadline) || {!alive _unit} || {isNull _defence} || {!alive _defence} || {gunner _defence == _unit}};
					if (alive _unit && {!isNull _defence} && {alive _defence} && {isNull (gunner _defence)}) then {
						[_unit] allowGetIn true;
						_unit assignAsGunner _defence;
						[_unit] orderGetIn true;
						sleep 10;
						if (alive _unit && {alive _defence} && {isNull (gunner _defence)}) then {
							_unit moveInGunner _defence;
							["WARNING", Format["Common_CreateUnitForstaticDefence.sqf: walk-in boarding stalled - forced gunner into [%1].", typeOf _defence]] Call WFBE_CO_FNC_LogContent;
						};
					};
				};
			};

			if (_diagEnabled) then {
				["TOWN_DEFENSE_DIAG", Format ["static_move_result side:%1;unit:%2;defense:%3;inDefense:%4;localServer:%5;hasInterface:%6", _side, typeOf _unit, typeOf _defence, vehicle _unit == _defence, isServer, hasInterface]] Call WFBE_CO_FNC_LogContent;
			};

			[group _unit, 175, getPos _defence] spawn WFBE_CO_FNC_RevealArea;
			_unit allowFleeing 0;
		};
	};
};

if (_built > 0) then {[str _side,'UnitsCreated',_built] call UpdateStatistics};

_defence setVariable ["WFBE_StaticDefenseManningInProgress", false, true];

["INFORMATION", Format["Common_CreateUnitForstaticDefence.sqf:  [%1] was activated with a total of [%2] units.", _side, _built]] Call WFBE_CO_FNC_LogContent;

if !(isNil "PerformanceAudit_Record") then {
	if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
		_perfScope = if (isServer && !hasInterface) then {"SERVER"} else {"CLIENT"};
		["create_static_defense_units", _perfActive, Format["side:%1;groups:%2;units:%3;moveIn:%4;cycleMs:%5", _sideID, count _groups, _built, _moveInGunner, round ((diag_tickTime - _perfStart) * 1000)], _perfScope] Call PerformanceAudit_Record;
	};
};

[_teams]
