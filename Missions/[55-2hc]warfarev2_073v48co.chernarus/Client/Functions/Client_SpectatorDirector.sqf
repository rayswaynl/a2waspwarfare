/* Client_SpectatorDirector.sqf
   WASP Spectator v3 director helpers for Arma 2 OA 1.64.
   Client-only target discovery: players, HQ teams, towns, and mobile HQ objects.
   No Display references, no serialization directive, and no A3-only array helpers.
   v4 streaming pass (design: docs/plans/2026-07-31-spectator-v4-streaming-design.md):
   town picks hard-gated to active fights (belligerent side mix + 45s hot linger),
   tiered auto-pick (contact > units > wide establishing), adaptive aim slew.
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
	Private ["_oldData","_newData","_radius","_town","_units","_sides","_headcount","_unitSide","_current","_oldValue","_delta","_entry","_contact","_hot","_hotSet","_hotIdx","_hotFound","_linger"];
	_oldData = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []];
	_newData = [];
	_radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_CONTEST_RADIUS", 200];
	_linger = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_LINGER_SEC", 45];
	_hotSet = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownHot", []];
	{
		_town = _x;
		_units = _town nearEntities [["Man"], _radius];
		_sides = [];
		_headcount = 0;
		{
			if (!isNull _x && {alive _x}) then {
				_unitSide = side _x;
				//--- v4: belligerents only - a parked CIV caster body or neutral crew must not fake a contest.
				if (_unitSide in [west, east, resistance]) then {
					_headcount = _headcount + 1;
					if !(_unitSide in _sides) then {_sides = _sides + [_unitSide]};
				};
			};
		} forEach _units;
		_current = _town getVariable ["supplyValue", 0];
		_oldValue = _current;
		{
			_entry = _x;
			if ((_entry select 0) == _town) then {_oldValue = _entry select 1};
		} forEach _oldData;
		_delta = _current - _oldValue;
		_contact = ((count _sides) - 1) max 0;
		//--- v4 hot linger: a contested town stays fight-pickable for TOWN_LINGER_SEC after
		//--- the last enemy leaves/dies, so a pausing firefight does not flicker the shot.
		if (_contact > 0) then {
			_hotFound = false;
			_hotIdx = 0;
			{
				if (!isNil "_x") then {
					if ((_x select 0) == _town) then {_hotSet set [_hotIdx, [_town, time]]; _hotFound = true};
				};
				_hotIdx = _hotIdx + 1;
			} forEach _hotSet;
			if (!_hotFound) then {
				_hotSet = _hotSet + [[_town, time]];
				diag_log Format ["SPECTATE|v4|town-hot|state=on|town=%1", _town getVariable ["name", "Town"]];
			};
		};
		_hot = (_contact > 0);
		if (!_hot) then {
			{
				if (!isNil "_x") then {
					if ((_x select 0) == _town && {(time - (_x select 1)) < _linger}) then {_hot = true};
				};
			} forEach _hotSet;
		};
		_newData = _newData + [[_town, _current, _delta, count _sides, _headcount, _contact, _hot]];
	} forEach towns;
	WFBE_C_VAR_DirectorTownData = _newData;
	WFBE_C_VAR_DirectorTownHot = _hotSet;
	_newData
};

WFBE_CL_FNC_DirectorBuildPlayers = {
	Private ["_list","_contact","_score"];
	_list = [];
	{
		if (!isNil "_x") then {
			if (alive _x && {isPlayer _x} && {(side _x) != civilian} && {!(_x == player)} && {!((name _x) in (missionNamespace getVariable ["WFBE_C_HC_NAMES", []]))}) then { //--- HC bodies are isPlayer-true and CIV humans are caster bodies; never offer either (owner 2026-07-30 + 2026-08-01)
				_contact = [_x, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS", 100], side _x] Call WFBE_CL_FNC_DirectorContactCount;
				_score = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_BASE", 10]) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_CONTACT", 1000]));
				if (_contact == 0) then {_score = _score - (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_IDLE_PENALTY", 250])};
				//--- v5: an AFK/idle body (stationary, no contact) is the worst possible shot - keep it
				//--- selectable as a last resort but never over anything that moves or fights.
				if (_contact == 0 && {(speed _x) < 1}) then {_score = _score * 0.25};
				_list = _list + [[name _x, _x, "PLAYER", WFBE_CL_FNC_DirectorPosObject, _score, _contact]];
			};
			//--- v5 hotfix (owner live repro m0801e: "blufor and guer never show on the spectator cam"):
			//--- the only non-player sources were AICOM TEAM entries from a registry that is SERVER-scoped,
			//--- so a spectating client saw no BLUFOR/OPFOR AI at all, and GUER was never pooled anywhere.
			//--- Derive squads client-locally instead: every AI group LEADER of a fighting side, scored by
			//--- the same contact logic as players (lower base, so humans win ties). GUER leaders class as
			//--- GUER, west/east as TEAM (keeps them in the tier-2 build-up pool).
			if (alive _x && {!(isPlayer _x)} && {_x == (leader (group _x))} && {(side _x) != civilian} && {!((name _x) in (missionNamespace getVariable ["WFBE_C_HC_NAMES", []]))}) then {
				_contact = [_x, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS", 100], side _x] Call WFBE_CL_FNC_DirectorContactCount;
				_score = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_AI_BASE", 6]) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_PLAYER_CONTACT", 1000]));
				if (_contact == 0) then {_score = _score - (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_IDLE_PENALTY", 250])};
				if (_contact == 0 && {(speed _x) < 1}) then {_score = _score * 0.25};
				if ((side _x) == resistance) then {
					_list = _list + [[Format ["GUER squad (%1)", {alive _x} count (units (group _x))], _x, "GUER", WFBE_CL_FNC_DirectorPosObject, _score, _contact]];
				} else {
					_list = _list + [[Format ["%1 squad (%2)", side _x, {alive _x} count (units (group _x))], _x, "TEAM", WFBE_CL_FNC_DirectorPosObject, _score, _contact]];
				};
			};
		};
	} forEach allUnits;
	_list
};

WFBE_CL_FNC_DirectorBuildTeams = {
	Private ["_list","_feed","_entry","_leader","_sid","_grp","_alive","_contact","_score","_label"];
	_list = [];
	_feed = missionNamespace getVariable ["WFBE_ACTIVE_AICOM_TEAMS", []];
	{
		_entry = _x;
		if (typeName _entry == "ARRAY" && {count _entry >= 4}) then {
			_leader = _entry select 0;
			_sid = _entry select 1;
			_grp = _entry select 3;
			if (typeName _grp == "GROUP") then {
				_leader = leader _grp;
				if (!isNull _leader && {alive _leader}) then {
					_alive = ({alive _x} count units _grp);
					_contact = [_leader, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TEAM_CONTACT_RADIUS", 150], side _leader] Call WFBE_CL_FNC_DirectorContactCount;
					_score = (_alive * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_SIZE", 2])) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TEAM_CONTACT", 1000]));
					if (_contact == 0) then {_score = _score - (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_IDLE_PENALTY", 250])};
					_label = Format ["TEAM %1 (%2/%3)", _sid, _alive, _contact];
					_list = _list + [[_label, _leader, "TEAM", WFBE_CL_FNC_DirectorPosObject, _score, _contact]];
				};
			};
		};
	} forEach _feed;
	_list
};

WFBE_CL_FNC_DirectorBuildTowns = {
	Private ["_list","_data","_town","_contact","_hot","_delta","_headcount","_score","_label"];
	_data = missionNamespace getVariable ["WFBE_C_VAR_DirectorTownData", []];
	if (count _data == 0) then {_data = Call WFBE_CL_FNC_DirectorPollTowns};
	_list = [];
	{
		_town = _x select 0;
		_delta = _x select 2;
		_headcount = _x select 4;
		_contact = _x select 5;
		_hot = _x select 6;
		//--- v4 hard gate (owner 2026-07-31: town cams only on active fights): only HOT
		//--- towns (live contest or inside the linger window) keep the contact-driven score
		//--- and a nonzero pick-contact field. Cold towns keep a small size/trend score so
		//--- they remain available as WIDE establishing shots but can never win an action pick.
		if (_hot) then {
			_score = (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_CONTEST", 1000])) + (((-_delta) max 0) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_TREND", 10])) + (_headcount * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_SIZE", 2]));
			if (_contact == 0) then {_contact = 1}; //--- linger-hot counts as fight-adjacent for tier 1.
		} else {
			_score = (((-_delta) max 0) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_TREND", 10])) + (_headcount * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_TOWN_SIZE", 2]));
			_contact = 0;
		};
		_label = _town getVariable ["name", "Town"];
		_list = _list + [[_label, _town, "TOWN", WFBE_CL_FNC_DirectorPosObject, _score, _contact]];
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
				_score = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_HQ_BASE", 15]) + (_contact * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_HQ_UNDER_ATTACK", 1000]));
				if (_contact == 0) then {_score = _score - (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_W_IDLE_PENALTY", 250])};
				_list = _list + [[_label, _hq, "HQ", WFBE_CL_FNC_DirectorPosObject, _score, _contact]];
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

WFBE_CL_FNC_DirectorBuildAll = {
	Private ["_list"];
	_list = (Call WFBE_CL_FNC_DirectorBuildPlayers) + (Call WFBE_CL_FNC_DirectorBuildTeams) + (Call WFBE_CL_FNC_DirectorBuildTowns) + (Call WFBE_CL_FNC_DirectorBuildHQs);
	_list
};

WFBE_CL_FNC_DirectorShotType = {
    Private ["_entry","_target","_class","_contact","_radius"];
    _entry = _this;
    _target = _entry select 1;
    _class = _entry select 2;
    _contact = 0;
    if ((_class == "PLAYER" || {_class == "TEAM"}) && {!isNull _target} && {alive _target}) then {
        _radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS", 100];
        if (_class == "TEAM") then {_radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TEAM_CONTACT_RADIUS", 150]};
        _contact = [_target, _radius, side _target] Call WFBE_CL_FNC_DirectorContactCount;
    };
    if ((_class == "TOWN") || {_class == "HQ"}) then {
        "WIDE"
    } else {
        if (_contact > 0) then {"TIGHT"} else {"MEDIUM"}
    }
};

WFBE_CL_FNC_DirectorShotBounds = {
    Private ["_type","_minDwell","_maxDwell","_fovMin","_fovMax"];
    _type = _this;
    _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MIN_DWELL", 1.5];
    _maxDwell = _minDwell;
    _fovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MIN", 0.5];
    _fovMax = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_FOV_MAX", 0.65];
    switch (_type) do {
        case "BASE": {
            _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_BASE_MIN_DWELL", 6];
            _maxDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_BASE_MAX_DWELL", 9];
            _fovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MIN", 0.8];
            _fovMax = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MAX", 0.95];
        };
        case "WIDE": {
            _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_MIN_DWELL", 4];
            _maxDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_MAX_DWELL", 7];
            _fovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MIN", 0.8];
            _fovMax = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_WIDE_FOV_MAX", 0.95];
        };
        case "TIGHT": {
            _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MIN_DWELL", 3];
            _maxDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_MAX_DWELL", 6];
            _fovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MIN", 0.35];
            _fovMax = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_FOV_MAX", 0.5];
        };
        case "MEDIUM": {
            _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_MIN_DWELL", 4];
            _maxDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_MAX_DWELL", 7];
        };
    };
    if (_minDwell < (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MIN_DWELL", 1.5])) then {
        _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MIN_DWELL", 1.5];
    };
    if (_maxDwell < _minDwell) then {_maxDwell = _minDwell};
    [_minDwell, _maxDwell, _fovMin, _fovMax]
};

WFBE_CL_FNC_DirectorPickEstablish = {
    Private ["_list","_entry","_best","_bestScore","_current","_score"];
    _list = (Call WFBE_CL_FNC_DirectorBuildTowns) + (Call WFBE_CL_FNC_DirectorBuildHQs);
    _current = WFBE_C_VAR_SpectatorTarget;
    _best = [];
    _bestScore = -1e9;
    {
        _entry = _x;
        _score = _entry select 4;
        if ((_entry select 1) != _current && {_score > _bestScore}) then {
            _best = _entry;
            _bestScore = _score;
        };
    } forEach _list;
    if (count _best == 0) then {
        _bestScore = -1e9;
        {
            _entry = _x;
            _score = _entry select 4;
            if (_score > _bestScore) then {
                _best = _entry;
                _bestScore = _score;
            };
        } forEach _list;
    };
    _best
};

WFBE_CL_FNC_DirectorPickBase = {
    Private ["_list","_friendlyHQ","_entry","_best"];
    _list = Call WFBE_CL_FNC_DirectorBuildHQs;
    _friendlyHQ = (side player) Call WFBE_CO_FNC_GetSideHQ;
    _best = [];
    {
        _entry = _x;
        if ((_entry select 1) == _friendlyHQ) then {_best = _entry};
    } forEach _list;
    _best
};

WFBE_CL_FNC_DirectorAimPoint = {
    Private ["_target","_class","_center","_radius","_contact","_active","_previous","_dir","_distance","_aim","_shotType","_shotRadius"];
    _target = _this select 0;
    _class = _this select 1;
    _center = _this select 2;
    _active = false;
    _previous = WFBE_C_VAR_DirectorEngagementActive;
    if ((_class == "PLAYER" || {_class == "TEAM"}) && {!isNull _target} && {alive _target}) then {
        if ((_target != WFBE_C_VAR_DirectorContactTarget) || {(time - WFBE_C_VAR_DirectorLastContactScan) >= 1}) then {
            _radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PLAYER_CONTACT_RADIUS", 100];
            if (_class == "TEAM") then {_radius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TEAM_CONTACT_RADIUS", 150]};
            _contact = [_target, _radius, side _target] Call WFBE_CL_FNC_DirectorContactCount;
            WFBE_C_VAR_DirectorEngagementActive = (_contact > 0);
            WFBE_C_VAR_DirectorContactTarget = _target;
            WFBE_C_VAR_DirectorLastContactScan = time;
        };
        _active = WFBE_C_VAR_DirectorEngagementActive;
    };
    _aim = _center;
    if (_active) then {
        _dir = getDir _target;
        _shotType = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorShotType", "MEDIUM"];
        _shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TIGHT_RADIUS", 8];
        if (_shotType == "MEDIUM") then {_shotRadius = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MEDIUM_RADIUS", 18]};
        //--- fix (v3.2 review): cap the look-ahead bias to the shot's own standoff radius so the aim point
        //--- stays near the subject; the flat 150m distance put the aim ~150m past a 8-18m-radius camera,
        //--- pitching the shot nearly level instead of down at the engaged unit.
        _distance = (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ENGAGEMENT_AIM_DISTANCE", 150]) min (_shotRadius * 0.5);
        _aim = [
            (_center select 0) + (_distance * sin _dir),
            (_center select 1) + (_distance * cos _dir),
            (_center select 2) + 1.5
        ];
    };
    if (_active) then {
        if (!_previous) then {diag_log Format ["SPECTATE|v3|engagement|state=on|class=%1", _class]};
    } else {
        if (_previous) then {diag_log Format ["SPECTATE|v3|engagement|state=off|class=%1", _class]};
    };
    WFBE_C_VAR_DirectorEngagementActive = _active;
    _aim
};

WFBE_CL_FNC_DirectorAimStep = {
    Private ["_camPos","_oldAim","_wantAim","_dt","_allowCut","_oldDx","_oldDy","_newDx","_newDy","_oldRange","_newRange","_oldDir","_newDir","_delta","_panRate","_maxSlew","_cutAngle","_factor","_stepDir","_result"];
    _camPos = _this select 0;
    _oldAim = _this select 1;
    _wantAim = _this select 2;
    _dt = _this select 3;
    _allowCut = _this select 4;
    _oldDx = (_oldAim select 0) - (_camPos select 0);
    _oldDy = (_oldAim select 1) - (_camPos select 1);
    _newDx = (_wantAim select 0) - (_camPos select 0);
    _newDy = (_wantAim select 1) - (_camPos select 1);
    _oldRange = sqrt ((_oldDx ^ 2) + (_oldDy ^ 2));
    _newRange = sqrt ((_newDx ^ 2) + (_newDy ^ 2));
    _result = _wantAim;
    if (_oldRange > 0.01 && {_newRange > 0.01}) then {
        _oldDir = ((_oldDx atan2 _oldDy) + 360) % 360;
        _newDir = ((_newDx atan2 _newDy) + 360) % 360;
        _delta = _newDir - _oldDir;
        if (_delta > 180) then {_delta = _delta - 360};
        if (_delta < -180) then {_delta = _delta + 360};
        //--- v4 adaptive slew: fast while far off-axis, ease-out near the frame (was a flat
        //--- 8 deg/s that sprinting targets outran); the cut threshold now gates only true breaks.
        _panRate = (((abs _delta) * (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PAN_EASE", 6])) max (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PAN_MIN_DEG_PER_SEC", 25])) min (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PAN_MAX_DEG_PER_SEC", 240]);
        _maxSlew = _panRate * _dt;
        _cutAngle = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_PAN_CUT_DEG", 35];
        if (abs _delta > _cutAngle && {_allowCut}) then {
            if (!WFBE_C_VAR_DirectorAimHardCut) then {
                diag_log Format ["SPECTATE|v3|aim-cut|delta=%1|threshold=%2", round (abs _delta), _cutAngle];
            };
            WFBE_C_VAR_DirectorAimHardCut = true;
        } else {
            WFBE_C_VAR_DirectorAimHardCut = false;
            if (_maxSlew > 0 && {abs _delta > _maxSlew}) then {
                _factor = _maxSlew / (abs _delta);
                _stepDir = _oldDir + (_delta * _factor);
                _result = [
                    (_camPos select 0) + (_oldRange * sin _stepDir),
                    (_camPos select 1) + (_oldRange * cos _stepDir),
                    (_oldAim select 2) + (((_wantAim select 2) - (_oldAim select 2)) * _factor)
                ];
            };
        };
    };
    _result
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
    Private ["_list","_current","_recent","_cooldown","_best","_bestScore","_entry","_target","_score","_skip","_pinned","_currentEntry","_currentScore","_bestAlt","_bestAltScore","_repeatMargin","_hysteresisMargin","_pool","_tier","_currentInPool"];
    _pinned = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorPinned", false];
    if (_pinned) then {_list = Call WFBE_CL_FNC_DirectorBuildActive} else {_list = Call WFBE_CL_FNC_DirectorBuildAll};
    if (count _list == 0) exitWith {[]};
    //--- v4 tiering (owner 2026-07-31: town cams only on active fights; hybrid idle):
    //--- tier 1 = live-contact entries (hot towns carry contact >= 1, cold towns 0);
    //--- tier 2 = players/teams (build-up footage when nothing fights);
    //--- tier 3 = the full list (quiet towns/HQ = WIDE establishing shots only).
    _pool = [];
    {
        if (!isNil "_x") then {if ((_x select 5) > 0) then {_pool = _pool + [_x]}};
    } forEach _list;
    _tier = 1;
    if (count _pool == 0) then {
        _tier = 2;
        {
            if (!isNil "_x") then {if ((_x select 2) == "PLAYER" || {(_x select 2) == "TEAM"}) then {_pool = _pool + [_x]}};
        } forEach _list;
    };
    if (count _pool == 0) then {_tier = 3; _pool = _list};
    WFBE_C_VAR_DirectorPool = _pool; //--- v5 hotfix: cut-site shot list reads this global; _list is Private to this function.
    WFBE_C_VAR_DirectorLastPickTier = _tier;
    _current = WFBE_C_VAR_SpectatorTarget;
    _recent = missionNamespace getVariable ["WFBE_C_VAR_DirectorRecent", []];
    _cooldown = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_COOLDOWN_SEC", 45];
    _repeatMargin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_REPEAT_SCORE_MARGIN", 0.5];
    _hysteresisMargin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_HYSTERESIS_MARGIN", 0.2];
    _currentEntry = [];
    _currentScore = -1e9;
    {
        _entry = _x;
        if ((_entry select 1) == _current) then {
            _currentEntry = _entry;
            _currentScore = _entry select 4;
        };
    } forEach _list;
    _currentInPool = false;
    {
        if (!isNil "_x") then {if ((_x select 1) == _current) then {_currentInPool = true}};
    } forEach _pool;
    //--- fix (v3.2 review): loop1 finds the best candidate that clears BOTH cooldown and the
    //--- hysteresis margin (the switch-worthy pick). _bestAlt tracks the best candidate that
    //--- only clears cooldown (ignoring hysteresis) - the true runner-up used below to decide
    //--- whether to hold on the current target or force a repeat-margin switch. The old
    //--- fallback loop re-scanned ignoring cooldown AND hysteresis on every hysteresis skip
    //--- (not just when cooldown blocked everything), which silently defeated both mechanisms.
    _best = [];
    _bestScore = -1e9;
    _bestAlt = [];
    _bestAltScore = -1e9;
    {
        _entry = _x;
        _target = _entry select 1;
        _score = _entry select 4;
        if (_target != _current) then {
            _skip = false;
            {
                if ((_x select 0) == _target && {(time - (_x select 1)) < _cooldown}) then {_skip = true};
            } forEach _recent;
            if (!_skip) then {
                if (_score > _bestAltScore) then {
                    _bestAlt = _entry;
                    _bestAltScore = _score;
                };
                if ((_currentScore <= 0 || {_score >= (_currentScore * (1 + _hysteresisMargin))}) && {_score > _bestScore}) then {
                    _best = _entry;
                    _bestScore = _score;
                };
            };
        };
    } forEach _pool;
    if (count _best == 0 && {count _bestAlt == 0}) then {
        //--- genuinely nothing survives cooldown at all; ignore cooldown rather than get stuck.
        _bestScore = -1e9;
        {
            _entry = _x;
            _target = _entry select 1;
            _score = _entry select 4;
            if (_target != _current) then {
                if (_score > _bestScore) then {
                    _best = _entry;
                    _bestScore = _score;
                };
            };
        } forEach _pool;
    };
    if (count _best == 0 && {count _currentEntry > 0} && {_currentInPool}) then {
        if (count _bestAlt == 0) then {
            _best = _currentEntry;
        } else {
            if (_bestAltScore > _currentScore) then {
                //--- a rival outscores current but not by the hysteresis margin; hold - this is
                //--- exactly what hysteresis exists to do, do not let repeat-margin re-litigate it.
                _best = _currentEntry;
            } else {
                //--- current is the top scorer outright; spec item C only allows repeating it
                //--- when it clears the runner-up by the repeat margin, else force a switch.
                if (_currentScore >= (_bestAltScore * (1 + _repeatMargin))) then {
                    _best = _currentEntry;
                } else {
                    _best = _bestAlt;
                };
            };
        };
    };
    _best
};

WFBE_CL_FNC_DirectorLoopStart = {
    [] spawn {
        Private ["_next","_entry","_recent","_recentKeep","_recentStart","_i","_pinned","_oldClass","_now","_autoDelta","_pollSec","_shotAge","_minDwell","_maxDwell","_dwell","_shotType","_bounds","_forcedType","_forcedEstablish","_baseDue","_forceEstablish","_target","_subject","_subjectFovMin"];
        _now = time;
        diag_log "SPECTATE|v3|director-thread-start";
        while {missionNamespace getVariable ["WFBE_C_VAR_SpectatorActive", false] && {!(missionNamespace getVariable ["WFBE_gameover", false])}} do {
            sleep 1;
            if (missionNamespace getVariable ["WFBE_C_VAR_SpectatorMode", "free"] == "director" && {missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorAuto", false]}) then {
                _autoDelta = time - _now;
                _now = time;
                if (_autoDelta < 0) then {_autoDelta = 0};
                WFBE_C_VAR_DirectorAutoTime = WFBE_C_VAR_DirectorAutoTime + _autoDelta;
                _pollSec = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_TOWN_POLL_SEC", 8];
                if ((time - (missionNamespace getVariable ["WFBE_C_VAR_DirectorLastTownPoll", 0])) >= _pollSec) then {
                    Call WFBE_CL_FNC_DirectorPollTowns;
                    WFBE_C_VAR_DirectorLastTownPoll = time;
                };
                _minDwell = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MIN_DWELL", 1.5];
                if (WFBE_C_VAR_SpectatorDirectorShotMinDwell > _minDwell) then {_minDwell = WFBE_C_VAR_SpectatorDirectorShotMinDwell};
                _maxDwell = WFBE_C_VAR_SpectatorDirectorShotMaxDwell;
                if (_maxDwell < _minDwell) then {_maxDwell = _minDwell};
                _dwell = (WFBE_C_VAR_SpectatorDirectorDwell max _minDwell) min _maxDwell;
                //--- v5 (owner 2026-08-01: "active town or fight and it skips to an afk unit... after 3
                //--- seconds"): a shot that had NO contact at cut time only deserves a glance - cap its
                //--- dwell so the next pick (which prefers tier-1 live contact) happens within ~3s. Shots
                //--- WITH contact keep their full dwell.
                if ((missionNamespace getVariable ["WFBE_C_VAR_DirectorCurContact", 0]) == 0) then {
                    _dwell = _dwell min (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_IDLE_DWELL_SEC", 3]);
                };
                _shotAge = WFBE_C_VAR_DirectorAutoTime - WFBE_C_VAR_DirectorLastSwitch;
                if (isNull WFBE_C_VAR_SpectatorTarget || {_shotAge >= _dwell}) then {
                    if (WFBE_C_VAR_DirectorReturnPending) then {
                        WFBE_C_VAR_SpectatorDirectorClass = WFBE_C_VAR_DirectorReturnClass;
                        WFBE_C_VAR_DirectorReturnPending = false;
                    };
                    _next = [];
                    _forcedType = "";
                    _forcedEstablish = false;
                    _baseDue = (WFBE_C_VAR_DirectorAutoTime - WFBE_C_VAR_DirectorLastBaseCheck) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_BASE_CHECK_SEC", 420]);
                    if (_baseDue) then {
                        WFBE_C_VAR_DirectorLastBaseCheck = WFBE_C_VAR_DirectorAutoTime;
                        _next = Call WFBE_CL_FNC_DirectorPickBase;
                        if (count _next > 0) then {
                            _forcedType = "BASE";
                            _forcedEstablish = true;
                        };
                    };
                    if (count _next == 0) then {
                        _forceEstablish = (WFBE_C_VAR_DirectorAutoTime - WFBE_C_VAR_DirectorLastEstablish) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_ESTABLISH_FLOOR_SEC", 120]);
                        if (_forceEstablish) then {
                            _next = Call WFBE_CL_FNC_DirectorPickEstablish;
                            if (count _next > 0) then {_forcedEstablish = true};
                        };
                    };
                    if (count _next == 0) then {_next = Call WFBE_CL_FNC_DirectorPickNext};
                    if (count _next > 0) then {
                        _entry = _next;
                        _pinned = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorPinned", false];
                        _oldClass = missionNamespace getVariable ["WFBE_C_VAR_SpectatorDirectorClass", "PLAYER"];
                        if (_pinned && {_forcedEstablish}) then {
                            WFBE_C_VAR_DirectorReturnClass = _oldClass;
                            WFBE_C_VAR_DirectorReturnPending = true;
                        };
                        if (!_pinned || {_forcedEstablish}) then {WFBE_C_VAR_SpectatorDirectorClass = _entry select 2};
                        WFBE_C_VAR_SpectatorTarget = _entry select 1;
                        WFBE_C_VAR_SpectatorDirectorPosFn = _entry select 3;
                        WFBE_C_VAR_SpectatorDirectorTargetLabel = _entry select 0;
                        //--- v5 P3b (spec 7a): the pool is scored every poll and everything but the
                        //--- winner was thrown away. Keep the top runners-up so the caster HUD can show
                        //--- what it is passing over ("shot list"), and record WHY this cut happened so
                        //--- the caster can narrate the director instead of guessing.
                        WFBE_C_VAR_DirectorShotList = [];
                        {
                            if ((count WFBE_C_VAR_DirectorShotList) < 3 && {(_x select 1) != (_entry select 1)}) then {
                                WFBE_C_VAR_DirectorShotList = WFBE_C_VAR_DirectorShotList + [[_x select 0, _x select 2, _x select 5]];
                            };
                        //--- v5 HOTFIX (owner live repro m0801e: "pans 5 degrees resets", dirt-cam): _list is
                        //--- Private to the pick functions - referencing it here threw "Undefined variable _list"
                        //--- EVERY cut, and the A2 error abort skipped the rest of this block, so DirectorLastSwitch
                        //--- was never stamped -> the dwell clock never reset -> a cut every poll: orbit angle reset
                        //--- ~every second and every 5th rapid cut was an eyes-cam slammed into the ground.
                        } forEach (missionNamespace getVariable ["WFBE_C_VAR_DirectorPool", []]);
                        WFBE_C_VAR_DirectorCutReason = "ESTABLISH";
                        if ((_entry select 5) > 0) then {WFBE_C_VAR_DirectorCutReason = "CONTACT"};
                        WFBE_C_VAR_DirectorCurContact = _entry select 5; //--- v5: idle-dwell cap reads this.
                        //--- v5 P3b: every Nth cut becomes a first-person look at the subject. Man only -
                        //--- a vehicle eyePos sits inside the hull and renders as a black frame.
                        WFBE_C_VAR_DirectorCutCount = (missionNamespace getVariable ["WFBE_C_VAR_DirectorCutCount", 0]) + 1;
                        WFBE_C_VAR_DirectorEyesUntil = 0;
                        if ((missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_EYES_EVERY", 5]) > 0) then {
                            if ((WFBE_C_VAR_DirectorCutCount % (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_EYES_EVERY", 5])) == 0 && {!isNull (_entry select 1)} && {(_entry select 1) isKindOf "Man"} && {alive (_entry select 1)}) then {
                            WFBE_C_VAR_DirectorEyesUntil = time + (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_EYES_SEC", 6]);
                            WFBE_C_VAR_DirectorCutReason = "POV";
                            diag_log Format ["SPECTATE|v5|eyes-cut|target=%1|sec=%2", _entry select 0, missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_EYES_SEC", 6]];
                            };
                        };
                        WFBE_C_VAR_SpectatorOrbitAngle = 0;
                        _shotType = _entry Call WFBE_CL_FNC_DirectorShotType;
                        if (_forcedType != "") then {_shotType = _forcedType};
                        _bounds = _shotType Call WFBE_CL_FNC_DirectorShotBounds;
                        _target = _entry select 1;
                        _subject = vehicle _target;
                        _subjectFovMin = 0;
                        if (!(_subject isKindOf "Man")) then {
                            _subjectFovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_VEH_FOV_MIN", 0.55];
                            if (_subject isKindOf "Air") then {_subjectFovMin = missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_AIR_FOV_MIN", 0.45]};
                        };
                        WFBE_C_VAR_SpectatorDirectorShotType = _shotType;
                        WFBE_C_VAR_SpectatorDirectorShotMinDwell = _bounds select 0;
                        WFBE_C_VAR_SpectatorDirectorShotMaxDwell = _bounds select 1;
                        WFBE_C_VAR_SpectatorDirectorTargetFov = (((_bounds select 2) + (_bounds select 3)) / 2) max _subjectFovMin;
                        WFBE_C_VAR_DirectorContactTarget = objNull;
                        WFBE_C_VAR_DirectorLastContactScan = 0;
                        WFBE_C_VAR_DirectorEngagementActive = false;
                        if ((time - WFBE_C_VAR_SpectatorLastManualZoom) >= (missionNamespace getVariable ["WFBE_C_SPECTATOR_DIRECTOR_MANUAL_ZOOM_LOCK_SEC", 10])) then {
                            WFBE_C_VAR_SpectatorFov = WFBE_C_VAR_SpectatorDirectorTargetFov;
                        };
                        WFBE_C_VAR_DirectorLastSwitch = WFBE_C_VAR_DirectorAutoTime;
                        if ((_shotType == "WIDE") || {_shotType == "BASE"}) then {
                            WFBE_C_VAR_DirectorLastEstablish = WFBE_C_VAR_DirectorAutoTime;
                        };
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
                        if (_forcedType == "BASE") then {
                            diag_log Format ["SPECTATE|v3|base-checkin|target=%1|shot=%2|hold=%3", _entry select 0, _shotType, _bounds select 1];
                        };
                        if (!_pinned || {(_entry select 2) != _oldClass} || {_forcedEstablish}) then {
                            diag_log Format ["SPECTATE|v3|auto-pick|class=%1|target=%2|score=%3|shot=%4|fov=%5|dwell=%6|transition=cut|pooled=1|tier=%7", _entry select 2, _entry select 0, _entry select 4, _shotType, WFBE_C_VAR_SpectatorDirectorTargetFov, _bounds select 1, missionNamespace getVariable ["WFBE_C_VAR_DirectorLastPickTier", 1]];
                        } else {
                            diag_log Format ["SPECTATE|v3|auto-pick|class=%1|target=%2|score=%3|shot=%4|fov=%5|dwell=%6|transition=cut|tier=%7", _entry select 2, _entry select 0, _entry select 4, _shotType, WFBE_C_VAR_SpectatorDirectorTargetFov, _bounds select 1, missionNamespace getVariable ["WFBE_C_VAR_DirectorLastPickTier", 1]];
                        };
                    };
                };
            } else {
                _now = time;
            };
        };
    };
};
