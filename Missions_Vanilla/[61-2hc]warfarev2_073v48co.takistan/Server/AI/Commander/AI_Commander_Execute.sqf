/*
	AI Commander - order executor.  feat/ai-commander. Server-side; runs every supervisor tick.
	Parameter: _this = side.

	Turns explicit Move/Patrol/Defend orders (set by a human commander via the Command Center, or by the
	AI) into real waypoints for AI-led teams. SetTeamMoveMode/SetTeamMovePos only store vars - nothing else
	issues waypoints for them, so this is the path that finally makes the command bar work.
	Idempotent: an unchanged order (wfbe_exec_sig) is not re-issued. "towns"/"" modes belong to AssignTowns.
*/
private ["_side","_logik","_teams","_team","_mode","_modeL","_goto","_sig","_prevSig","_wpType","_radius","_aliveCount","_realGoto"];
_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};
{
	_team = _x;
	//--- V0.6.5/V0.7 parity: wiped HC teams leave NULL groups in wfbe_teams (index-aligned
	//--- registry - entries are nulled, not removed). In A2 OA, getVariable [name,default] on a
	//--- null group returns nil (NOT the default) and units/leader on a null group misbehave, which
	//--- threw + killed the sibling workers until they were guarded. Execute was the lone team-loop
	//--- worker still missing the guard; match AssignTypes/AssignTowns/Produce/Strategy and skip nulls.
	_aliveCount = 0;
	if (!isNull _team) then {_aliveCount = {alive _x} count (units _team)};
	if (!isNull _team && {!isPlayer (leader _team)}) then {
		if (_aliveCount > 0) then {
			_mode  = _team getVariable ["wfbe_teammode", "towns"];
			_modeL = toLower _mode;
			if (_modeL == "move" || _modeL == "patrol" || _modeL == "defense") then {
				_goto = _team getVariable ["wfbe_teamgoto", [0,0,0]];
				//--- A real destination only (array, not the [0,0,0] default).
				_realGoto = false;
				if (typeName _goto == "ARRAY") then {
					if (count _goto >= 2) then {
						if ((_goto select 0) != 0) then {_realGoto = true};
						if ((_goto select 1) != 0) then {_realGoto = true};
					};
				};
				if (_realGoto) then {
					_sig     = [_modeL, round (_goto select 0), round (_goto select 1)];
					_prevSig = _team getVariable ["wfbe_exec_sig", []];
					if (str _sig != str _prevSig) then {
						_wpType = "MOVE"; _radius = 50;
						if (_modeL == "patrol")  then {_wpType = "SAD";  _radius = 150};
						if (_modeL == "defense") then {_wpType = "HOLD"; _radius = 30};
						[_team, _goto, _wpType, _radius] Call AIMoveTo;
						_team setVariable ["wfbe_exec_sig", _sig];
						["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] team [%2] executing %3 order at %4.", _side, _team, _modeL, _goto]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			} else {
				//--- Not an explicit order anymore - drop the signature so a later order always re-executes.
				_team setVariable ["wfbe_exec_sig", []];
			};
		};
	};
} forEach _teams;
