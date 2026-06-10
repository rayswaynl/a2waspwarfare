/*
	AI Commander - send idle AI teams at the nearest uncaptured town.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	The "towns" team mode is otherwise dead infrastructure (nothing drives teams to
	towns), so this worker BOTH sets the mode and issues the waypoints itself, via the
	existing arc-approach planner (WFBE_C_AI_COMMANDER_USE_ARC_APPROACH=1) or the proven
	AIMoveTo fallback (=0).
*/

private ["_side","_sideID","_sideText","_logik","_teams","_uncaptured","_assigned","_team","_aliveCount","_mode","_goto","_needs","_avail","_target","_useArc","_humanCmd","_cmdTeam","_autonomous","_modeNow","_canDrive","_explicitMode","_gar","_garDead","_hqG"];

_side = _this;
_sideID = (_side) Call WFBE_CO_FNC_GetSideID;
_sideText = str _side;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};

_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};

//--- Hybrid: when a human commands this side, only auto-assign DELEGATED (autonomous) teams.
_cmdTeam = (_side) Call WFBE_CO_FNC_GetCommanderTeam;
_humanCmd = false;
if (!isNull _cmdTeam) then {
	if (isPlayer (leader _cmdTeam)) then {_humanCmd = true};
};

//--- OA-safe filter: towns not owned by this side.
_uncaptured = [];
{ if ((_x getVariable "sideID") != _sideID) then {_uncaptured set [count _uncaptured, _x]} } forEach towns;
if (count _uncaptured == 0) exitWith {};

_useArc = (missionNamespace getVariable "WFBE_C_AI_COMMANDER_USE_ARC_APPROACH") > 0;
_assigned = [];

{
	_team = _x;
	_aliveCount = {alive _x} count (units _team);
	_autonomous = _team getVariable ["wfbe_autonomous", false];
	_modeNow = toLower (_team getVariable ["wfbe_teammode", "towns"]);
	_canDrive = false;
	_explicitMode = false;
	if (_modeNow == "move") then {_explicitMode = true};
	if (_modeNow == "patrol") then {_explicitMode = true};
	if (_modeNow == "defense") then {_explicitMode = true};

	//--- Drive only if AI-controllable (no human, or human delegated this team) AND the executor doesn't own it.
	if (_aliveCount > 0) then {
		if (!isPlayer (leader _team)) then {
			if (!_humanCmd) then {_canDrive = true};
			if (_autonomous) then {_canDrive = true};
		};
	};

	if (_canDrive) then {
		//--- V0.2: hold one team back as the base garrison (full-auto only) - a captured
		//--- base must not be left open while every team marches at towns.
		if (!_humanCmd && {!_explicitMode} && {_aliveCount > 0}) then {
			_gar = _logik getVariable ["wfbe_aicom_garrison", grpNull];
			_garDead = true;
			if (!isNull _gar) then {
				if (({alive _x} count (units _gar)) > 0) then {_garDead = false};
			};
			if (_garDead) then {
				_hqG = (_side) Call WFBE_CO_FNC_GetSideHQ;
				if (!isNull _hqG) then {
					[_team, "defense"] Call SetTeamMoveMode;
					[_team, getPos _hqG] Call SetTeamMovePos;
					_logik setVariable ["wfbe_aicom_garrison", _team];
					_explicitMode = true; //--- now an explicit order; the executor drives it home
					["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] assigned as base garrison.", _sideText, _team]] Call WFBE_CO_FNC_LogContent;
				};
			};
		};
		if (!_explicitMode) then {
			_mode = _team getVariable ["wfbe_teammode", ""];
			_goto = _team getVariable ["wfbe_teamgoto", objNull];

			//--- Needs a (re)target unless it is actively heading at a still-enemy town and not idling far from it.
			_needs = false;
			if (_mode == "towns" || _mode == "") then {
				if (typeName _goto != "OBJECT") then {
					_needs = true;
				} else {
					if (isNull _goto) then {
						_needs = true;
					} else {
						if ((_goto getVariable "sideID") == _sideID) then {
							_needs = true;
						} else {
							if ((leader _team) distance _goto > 1500) then {_needs = true};
						};
					};
				};
			};

			if (_needs) then {
				_avail = _uncaptured - _assigned;
				if (count _avail == 0) then {_avail = _uncaptured};
				_target = [leader _team, _avail] Call WFBE_CO_FNC_GetClosestEntity;
				if (!isNil "_target") then {
					if (!isNull _target) then {
						[_team, "towns"] Call SetTeamMoveMode;
						[_team, _target] Call SetTeamMovePos;
						if (_useArc) then {
							[_team, _target] Call WFBE_SE_FNC_AI_SetTownAttackPath;
						} else {
							[_team, getPos _target, "SAD", 200] Call AIMoveTo;
						};
						_assigned set [count _assigned, _target];
						["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] heading to attack town [%3].", _sideText, _team, _target getVariable ["name", "town"]]] Call WFBE_CO_FNC_LogContent;
					};
				};
			};
		};
	};
} forEach _teams;
