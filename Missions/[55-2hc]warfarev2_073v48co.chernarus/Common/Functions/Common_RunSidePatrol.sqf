/*
	Run one side patrol (Patrols upgrade): create the team and drive it until it dies.
	 Parameters: [ sideID, template (unit class array, resolved server-side from the
	               WFBE_<side>_PATROL_* pools), homeTown ]
	Runs on the SERVER or on a HEADLESS CLIENT (delegate-sidepatrol) - the whole
	lifecycle stays on the machine that created the group so waypoints keep locality.
	Slot bookkeeping (wfbe_side_patrols counter + WFBE_ACTIVE_PATROLS marker list)
	always lives on the server: direct Call when local, RequestSpecial from the HC.
*/

Private ["_sideID","_template","_homeTown","_side","_position","_retVal","_units","_vehicles","_team","_ldr","_target","_alive","_candidates"];

_sideID = _this select 0;
_template = _this select 1;
_homeTown = _this select 2;
_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

_position = ([getPos _homeTown, 100, 400] Call WFBE_CO_FNC_GetRandomPosition);
_position = [_position, 50] Call WFBE_CO_FNC_GetEmptyPosition;

_team = createGroup _side;
_retVal = [_template, _position, _side, true, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
_units = _retVal select 0;
_vehicles = _retVal select 1;
_team = _retVal select 2;

if (isNull _team || {((count _units) + (count _vehicles)) == 0}) exitWith {
	["WARNING", Format["Common_RunSidePatrol.sqf: [%1] patrol creation failed at [%2] - releasing the slot.", _side, _homeTown getVariable "name"]] Call WFBE_CO_FNC_LogContent;
	if (isServer) then {
		["sidepatrol-ended", _sideID, objNull] Call HandleSpecial;
	} else {
		["RequestSpecial", ["sidepatrol-ended", _sideID, objNull]] Call WFBE_CO_FNC_SendToServer;
	};
};

_team allowFleeing 0;
_team setVariable ["WFBE_SidePatrol", true, false];

_ldr = leader _team;
if (isServer) then {
	["sidepatrol-started", _sideID, _ldr] Call HandleSpecial;
} else {
	["RequestSpecial", ["sidepatrol-started", _sideID, _ldr]] Call WFBE_CO_FNC_SendToServer;
};

["INFORMATION", Format["Common_RunSidePatrol.sqf: [%1] patrol spawned at [%2] (%3 units, %4 vehicles).", _side, _homeTown getVariable "name", count _units, count _vehicles]] Call WFBE_CO_FNC_LogContent;

//--- Frontline gravitation: always head for the nearest town we do NOT own; when it
//--- flips to us (we helped cap it or a teammate did), pick the next one. If we own
//--- the whole map the patrol roams between our own towns.
_target = objNull;
_alive = true;
while {!WFBE_GameOver && _alive} do {
	_alive = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	if (_alive) then {
		if (isNull _target) then {
			_candidates = [];
			{if ((_x getVariable "sideID") != _sideID) then {_candidates = _candidates + [_x]}} forEach towns;
			if (count _candidates == 0) then {_candidates = + towns};
			_target = [leader _team, _candidates] Call WFBE_CO_FNC_GetClosestEntity;
			if (!isNull _target) then {
				[_team, getPos _target, 'MOVE', 25] Spawn WFBE_CO_FNC_WaypointSimple;
			};
		} else {
			if ((leader _team) distance _target < 200) then {
				if ((_target getVariable "sideID") == _sideID) then {
					_target = objNull; //--- Town is ours now: gravitate to the next frontline town.
				};
				//--- Still hostile/neutral: stay engaged; the town capture logic does the rest.
			};
		};
	};

	sleep 30;
};

//--- Patrol wiped: release the slot (the server also re-arms the spawn cooldown).
if (isServer) then {
	["sidepatrol-ended", _sideID, _ldr] Call HandleSpecial;
} else {
	["RequestSpecial", ["sidepatrol-ended", _sideID, _ldr]] Call WFBE_CO_FNC_SendToServer;
};

if (!isNull _team) then {deleteGroup _team};
