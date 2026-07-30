/* Client_SpectatorDirector.sqf
   WASP Spectator v3 director helpers for Arma 2 OA 1.64.
   Client-only target discovery: players, HQ teams, towns, and mobile HQ objects.
   No Display references, no serialization directive, and no A3-only array helpers.
*/

WFBE_CL_FNC_DirectorPosObject = {
	getPos _this
};

WFBE_CL_FNC_DirectorContactCount = {
	Private ["_origin","_radius","_originSide","_count","_unitSide"];
	_origin = _this select 0;
	_radius = _this select 1;
	_originSide = _this select 2;
	_count = 0;
	{
		if (!isNull _x && {alive _x}) then {
			_unitSide = side _x;
			if (_unitSide != _originSide) then {_count = _count + 1};
		};
	} forEach (_origin nearEntities [["Man"], _radius]);
	_count
};

WFBE_CL_FNC_DirectorPollTowns = {
	Private ["_oldData","_newData","_radius","_town","_units","_sides","_headcount","_unitSide","_current","_oldValue","_delta","_entry"];
	_oldData = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []];
	_newData = [];
	_radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_CONTEST_RADIUS", 200];
	{
		_town = _x;
		_units = _town nearEntities [["Man"], _radius];
		_sides = [];
		_headcount = 0;
		{
			if (!isNull _x && {alive _x}) then {
				_headcount = _headcount + 1;
				_unitSide = side _x;
				if !(_unitSide in _sides) then {_sides = _sides + [_unitSide]};
			};
		} forEach _units;
		_current = _town getVariable ["supplyValue", 0];
		_oldValue = _current;
		{
			_entry = _x;
			if ((_entry select 0) == _town) then {_oldValue = _entry select 1};
		} forEach _oldData;
		_delta = _current - _oldValue;
		_newData = _newData + [[_town, _current, _delta, count _sides, _headcount]];
	} forEach towns;
	WFBE_C_VAR_DirectorTownData = _newData;
	_newData
};

WFBE_CL_FNC_DirectorBuildPlayers = {
	Private ["_list","_contact","_score"];
	_list = [];
	{
		if (!isNil "_x") then {
			if (alive _x && {isPlayer _x} && {!(_x == player)}) then {
				_contact = [_x, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS", 100], side _x] Call WFBE_CL_FNC_DirectorContactCount;
				_score = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_BASE", 5]) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_CONTACT", 40]));
				_list = _list + [[name _x, _x, "PLAYER", WFBE_CL_FNC_DirectorPosObject, _score]];
			};
		};
	} forEach allUnits;
	_list
};

WFBE_CL_FNC_DirectorBuildTeams = {
	Private ["_list","_feed","_entry","_leader","_sid","_grp","_mySid","_reveal","_alive","_contact","_score","_label"];
	_list = [];
	_feed = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
	_mySid = missionNamespace getVariable ["WFBE_Client_SideID", -1];
	_reveal = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_REVEAL_ENEMY_HQ", 0]) > 0;
	{
		_entry = _x;
		if (typeName _entry == "ARRAY" && {count _entry >= 4}) then {
			_leader = _entry select 0;
			_sid = _entry select 1;
			_grp = _entry select 3;
			if (typeName _grp == "GROUP") then {
				_leader = leader _grp;
				if (!isNull _leader && {alive _leader} && {(_reveal || {_sid == _mySid})}) then {
					_alive = ({alive _x} count units _grp);
					_contact = [_leader, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TEAM_CONTACT_RADIUS", 150], side _leader] Call WFBE_CL_FNC_DirectorContactCount;
					_score = (_alive * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_SIZE", 3])) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_CONTACT", 60]));
					_label = Format ["TEAM %1 (%2/%3)", _sid, _alive, _contact];
					_list = _list + [[_label, _leader, "TEAM", WFBE_CL_FNC_DirectorPosObject, _score]];
				};
			};
		};
	} forEach _feed;
	_list
};

WFBE_CL_FNC_DirectorBuildTowns = {
	Private ["_list","_data","_town","_mix","_delta","_headcount","_score","_label"];
	_data = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []];
	if (count _data == 0) then {_data = Call WFBE_CL_FNC_DirectorPollTowns};
	_list = [];
	{
		_town = _x select 0;
		_mix = _x select 3;
		_delta = _x select 2;
		_headcount = _x select 4;
		_score = (_mix * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_CONTEST", 100])) + (((-_delta) max 0) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_TREND", 4])) + (_headcount * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_SIZE", 2]));
		_label = _town getVariable ["name", "Town"];
		_list = _list + [[_label, _town, "TOWN", WFBE_CL_FNC_DirectorPosObject, _score]];
	} forEach _data;
	_list
};

WFBE_CL_FNC_DirectorBuildHQs = {
	Private ["_list","_sides","_side","_reveal","_hq","_contact","_label","_score"];
	_list = [];
	_sides = [west, east, resistance];
	_reveal = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_REVEAL_ENEMY_HQ", 0]) > 0;
	{
		_side = _x;
		if (_reveal || {_side == side player}) then {
			_hq = _side Call WFBE_CO_FNC_GetSideHQ;
			if (!isNull _hq) then {
				_contact = [_hq, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_HQ_CONTACT_RADIUS", 250], _side] Call WFBE_CL_FNC_DirectorContactCount;
				_label = switch (_side) do {case west: {"WEST HQ"}; case east: {"EAST HQ"}; default {"GUER HQ"}};
				_score = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_HQ_BASE", 10]) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_HQ_UNDER_ATTACK", 150]));
				_list = _list + [[_label, _hq, "HQ", WFBE_CL_FNC_DirectorPosObject, _score]];
			};
		};
	} forEach _sides;
	_list
};

WFBE_CL_FNC_DirectorBuildActive = {
	Private ["_class"];
	_class = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorClass", "PLAYER"];
	switch (_class) do {
		case "TEAM": {Call WFBE_CL_FNC_DirectorBuildTeams};
		case "TOWN": {Call WFBE_CL_FNC_DirectorBuildTowns};
		case "HQ": {Call WFBE_CL_FNC_DirectorBuildHQs};
		default {Call WFBE_CL_FNC_DirectorBuildPlayers};
	}
};

WFBE_CL_FNC_DirectorCycleTarget = {
	Private ["_step","_list","_current","_index","_i","_entry"];
	_step = _this;
	_list = Call WFBE_CL_FNC_DirectorBuildActive;
	if (count _list == 0) exitWith {
		WFBE_C_VAR_SpectatorTarget = objNull;
		systemChat "[WASP] Director: no live targets in this class.";
	};
	_current = WFBE_C_VAR_SpectatorTarget;
	_index = -1;
	_i = 0;
	{
		if ((_x select 1) == _current) then {_index = _i};
		_i = _i + 1;
	} forEach _list;
	if (_index < 0) then {_index = 0} else {_index = (_index + _step + (count _list)) % (count _list)};
	_entry = _list select _index;
	WFBE_C_VAR_SpectatorTarget = _entry select 1;
	WFBE_C_VAR_SpectatorDirectorPosFn = _entry select 3;
	WFBE_C_VAR_SpectatorDirectorTargetLabel = _entry select 0;
	WFBE_C_VAR_SpectatorOrbitAngle = 0;
	systemChat Format ["[WASP] Director target: %1", _entry select 0];
};

WFBE_CL_FNC_DirectorPickNext = {
	Private ["_list","_current","_recent","_cooldown","_best","_bestScore","_entry","_target","_score","_skip","_chosen"];
	_list = Call WFBE_CL_FNC_DirectorBuildActive;
	if (count _list == 0) exitWith {[]};
	_current = WFBE_C_VAR_SpectatorTarget;
	_recent = missionNamespace getVariable ["WFBE_C_VAR_DirectorRecent", []];
	_cooldown = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_COOLDOWN_SEC", 45];
	_best = [];
	_bestScore = -1e9;
	{
		_entry = _x;
		_target = _entry select 1;
		_score = _entry select 4;
		_skip = false;
		{
			if ((_x select 0) == _target && {(time - (_x select 1)) < _cooldown}) then {_skip = true};
		} forEach _recent;
		if (!_skip && {_target != _current} && {_score > _bestScore}) then {
			_best = _entry;
			_bestScore = _score;
		};
	} forEach _list;
	if (count _best == 0) then {
		_bestScore = -1e9;
		{
			_entry = _x;
			_score = _entry select 4;
			if ((_entry select 1) != _current && {_score > _bestScore}) then {
				_best = _entry;
				_bestScore = _score;
			};
		} forEach _list;
	};
	if (count _best == 0) then {
		_best = _list select 0;
	};
	_best
};

WFBE_CL_FNC_DirectorLoopStart = {
	[] spawn {
		Private ["_next","_entry","_recent","_pollSec","_dwell","_recentKeep","_recentStart","_i"];
		diag_log "SPECTATE|v3|director-thread-start";
		while {missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false] && {!(missionNamespace getVariable ["WFBE_gameover", false])}} do {
			sleep 1;
			if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"] == "director" && {missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]}) then {
				_pollSec = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_POLL_SEC", 8];
				if ((time - (missionNamespace getVariable ["WFBE_C_VAR_DirectorLastTownPoll", 0])) >= _pollSec) then {
					Call WFBE_CL_FNC_DirectorPollTowns;
					WFBE_C_VAR_DirectorLastTownPoll = time;
				};
				_dwell = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorDwell", 20];
				if ((time - (missionNamespace getVariable ["WFBE_C_VAR_DirectorLastSwitch", 0])) >= _dwell || {isNull WFBE_C_VAR_SpectatorTarget} || {!alive WFBE_C_VAR_SpectatorTarget}) then {
					_next = Call WFBE_CL_FNC_DirectorPickNext;
					if (count _next > 0) then {
						_entry = _next;
						WFBE_C_VAR_SpectatorTarget = _entry select 1;
						WFBE_C_VAR_SpectatorDirectorPosFn = _entry select 3;
						WFBE_C_VAR_SpectatorDirectorTargetLabel = _entry select 0;
						WFBE_C_VAR_SpectatorOrbitAngle = 0;
						WFBE_C_VAR_DirectorLastSwitch = time;
						_recent = missionNamespace getVariable ["WFBE_C_VAR_DirectorRecent", []];
						_recent = _recent + [[_entry select 1, time]];
						if (count _recent > 6) then {
							_recentKeep = [];
							_recentStart = (count _recent) - 6;
							_i = 0;
							{
								if (_i >= _recentStart) then {_recentKeep = _recentKeep + [_x]};
								_i = _i + 1;
							} forEach _recent;
							_recent = _recentKeep;
						};
						WFBE_C_VAR_DirectorRecent = _recent;
						diag_log Format ["SPECTATE|v3|auto-pick|class=%1|target=%2|score=%3", missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorClass", "PLAYER"], _entry select 0, _entry select 4];
					};
				};
			};
		};
	};
};
