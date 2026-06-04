/*
	AI Commander - order executor.  feat/ai-commander. Server-side; runs every supervisor tick.
	Parameter: _this = side.

	Turns explicit Move/Patrol/Defend orders (set by a human commander via the Command Center, or by the
	AI) into real waypoints for AI-led teams. SetTeamMoveMode/SetTeamMovePos only store vars - nothing else
	issues waypoints for them, so this is the path that finally makes the command bar work.
	Idempotent: an unchanged order (wfbe_exec_sig) is not re-issued. "towns"/"" modes belong to AssignTowns.
*/
private ["_side","_logik","_teams","_team","_mode","_modeL","_goto","_sig","_prevSig","_wpType","_radius"];
_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {};
_teams = _logik getVariable "wfbe_teams";
if (isNil "_teams") exitWith {};
{
	_team = _x;
	if (!isPlayer (leader _team) && {({alive _x} count (units _team)) > 0}) then {
		_mode  = _team getVariable ["wfbe_teammode", "towns"];
		_modeL = toLower _mode;
		if (_modeL == "move" || _modeL == "patrol" || _modeL == "defense") then {
			_goto = _team getVariable ["wfbe_teamgoto", [0,0,0]];
			//--- A real destination only (array, not the [0,0,0] default).
			if (typeName _goto == "ARRAY" && {count _goto >= 2} && {((_goto select 0) != 0) || ((_goto select 1) != 0)}) then {
				_sig     = [_modeL, round (_goto select 0), round (_goto select 1)];
				_prevSig = _team getVariable ["wfbe_exec_sig", []];
				if (str _sig != str _prevSig) then {
					_wpType = "MOVE"; _radius = 50;
					if (_modeL == "patrol")  then {_wpType = "SAD";  _radius = 150};
					if (_modeL == "defense") then {_wpType = "HOLD"; _radius = 30};
					[_team, _goto, _wpType, _radius] Call AIMoveTo;
					_team setVariable ["wfbe_exec_sig", _sig];
					["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] team [%2] executing %3 order at %4.", _side, _team, _modeL, _goto]] Call WFBE_CO_FNC_LogContent;
					if (!isNil "WFBE_SE_FNC_AI_Com_LogAppend") then {[_side, "ORDER", _team, [_team, _modeL, _goto, _wpType, _radius]] Call WFBE_SE_FNC_AI_Com_LogAppend};
				};
			};
		} else {
			//--- Not an explicit order anymore - drop the signature so a later order always re-executes.
			_team setVariable ["wfbe_exec_sig", []];
		};
	};
} forEach _teams;
