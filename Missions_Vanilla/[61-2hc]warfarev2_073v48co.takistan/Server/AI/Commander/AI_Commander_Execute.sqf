/*
	AI Commander - order executor.  feat/ai-commander. Server-side; runs every supervisor tick.
	Parameter: _this = side.

	Turns explicit Move/Patrol/Defend orders (set by a human commander via the Command Center, or by the
	AI) into real waypoints for AI-led teams. SetTeamMoveMode/SetTeamMovePos only store vars - nothing else
	issues waypoints for them, so this is the path that finally makes the command bar work.
	Idempotent: an unchanged order (wfbe_exec_sig) is not re-issued. "towns"/"" modes belong to AssignTowns.
*/
private ["_side","_logik","_teams","_team","_mode","_modeL","_goto","_sig","_prevSig","_wpType","_radius","_aliveCount","_realGoto","_isHc","_hcMode","_hcSeq","_hcOrigin","_hcRoute","_laneJit","_slOrigin","_slHasVeh","_slRoute","_slWPs"]; //--- B67 +_isHc/_hcMode/_hcSeq; road-march +_hcOrigin/_hcRoute/_laneJit (HC) +_slOrigin/_slHasVeh/_slRoute/_slWPs (server-local)
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
						//--- COMMAND CONSOLE telemetry (claude-gaming 2026-06-28): one machine-parseable line per NEWLY-
						//--- committed direct order (the war-room's per-team task path). Previously the direct path was
						//--- invisible to ORDERS telemetry, so a working order looked identical to a dropped one in logs
						//--- (part of why ORDERS(war-room) read 0 even when teams were tasked). Count these to see the path bite.
						diag_log ("AICOM2|v1|ORDER|war-room-task|" + str _side + "|" + str (round (time / 60)) + "|mode=" + _modeL + "|goto=" + str [round (_goto select 0), round (_goto select 1)]);
						//--- B67 HC-ORDER PATH (full-send hybrid commander, item #5 / part 3): an HC-delegated team's units
						//--- are LOCAL to the headless client, so server-side AIMoveTo/waypoint commands on them are
						//--- unreliable - the HC driver (Common_RunCommanderTeam) acts ONLY on the public wfbe_aicom_order
						//--- group var, never on wfbe_teammode/wfbe_teamgoto. A human commander's order (set via
						//--- SetTeamMoveMode/SetTeamMovePos -> those two vars) was therefore INERT on HC teams. So when this
						//--- team is HC-resident, ALSO publish wfbe_aicom_order with the driver's [seq, mode, pos] contract
						//--- (seq bumped only on a CHANGED order, gated by the _sig latch above, so we never spam re-issues).
						//--- Mode mapping to the driver's vocab: human "defense" -> "defense" (driver HOLDs a tight SAD at pos);
						//--- "move"/"patrol" pass through to the driver's non-"defense"/non-"towns-target" branch = a
						//--- COMBAT/WEDGE assault SAD at pos (advance-and-engage, never idle). pos = the human-set goto array.
						//--- Server-local teams keep the AIMoveTo path below unchanged. WFBE_CO_FNC_GroupGetBool guards the
						//--- UNSET-on-group bool read (A2-OA "G1" trap).
						_isHc = [_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool;
						if (_isHc) then {
							_hcMode = if (_modeL == "defense") then {"defense"} else {_modeL}; //--- "move"/"patrol" pass through to the driver's assault-SAD branch.
							//--- ROAD-MARCH (war-room console DIRECT order): the HC driver (Common_RunCommanderTeam)
							//--- road-marches a ground-vehicle team on a long leg ONLY when it can read a road-node chain
							//--- from wfbe_aicom_route - but until now ONLY AssignTowns populated that var, so a human
							//--- console order left it stale/empty and the driver cut cross-country. Compute the SAME road-
							//--- node chain here (server-side, off this team's leader) and broadcast it so the driver lays
							//--- road waypoints on the long leg exactly like an AI-strategy town order. Gate on the same
							//--- >700m long-leg threshold AssignTowns uses; the driver still applies its own ground-vehicle
							//--- gate, so pure-infantry HC teams keep the FOOT FAST-TRANSIT column (unchanged).
							_hcOrigin = getPos (leader _team);
							_hcRoute = [];
							if ((_hcOrigin distance _goto) > 700) then {
								_laneJit = _team getVariable "wfbe_aicom_lanejit";
								if (isNil "_laneJit") then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]};
								_hcRoute = [_hcOrigin, _goto, _laneJit * 120, 8] Call WFBE_CO_FNC_BuildRoadRoute;
							};
							_team setVariable ["wfbe_aicom_route", _hcRoute, true]; //--- broadcast BEFORE the order seq bump so the driver reads THIS order's route when it processes the new seq.
							//--- A2: groups do not support the [name,default] getVariable form - plain get + isNil for the seq read.
							_hcSeq = _team getVariable "wfbe_aicom_order";
							_hcSeq = if (isNil "_hcSeq" || {count _hcSeq < 1}) then {0} else {(_hcSeq select 0) + 1};
							_team setVariable ["wfbe_aicom_order", [_hcSeq, _hcMode, _goto], true];
							_team setVariable ["wfbe_exec_sig", _sig];
							["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] HC team [%2] human %3 order published via wfbe_aicom_order #%4 at %5.", _side, _team, _modeL, _hcSeq, _goto]] Call WFBE_CO_FNC_AICOMLog;
						} else {
							_wpType = "MOVE"; _radius = 50;
							if (_modeL == "patrol")  then {_wpType = "SAD";  _radius = 150};
							if (_modeL == "defense") then {_wpType = "HOLD"; _radius = 30};
							//--- ROAD-MARCH (war-room console DIRECT order): a SERVER-LOCAL team's units are local to the
							//--- server, so lay waypoints here directly. Previously this was a SINGLE cross-country MOVE/SAD/
							//--- HOLD (AIMoveTo -> one AIWPAdd waypoint, radius/clear) that A2 OA pathfinding stutters through
							//--- on multi-km legs. Mirror the HC driver's road-march: a GROUND-VEHICLE team on a long leg
							//--- (>700m) gets a road-node-snapped MOVE chain (WFBE_CO_FNC_BuildRoadRoute - the same builder the
							//--- AI-strategy town path uses) ending in this order's mode waypoint. Pure-infantry / short legs
							//--- keep the direct AIMoveTo (the driver deliberately does not road-lock foot squads).
							_slOrigin = getPos (leader _team);
							_slHasVeh = false;
							{ if (vehicle _x != _x && {alive (vehicle _x)} && {!((vehicle _x) isKindOf "Air")} && {canMove (vehicle _x)}) exitWith {_slHasVeh = true} } forEach (units _team); //--- any group member crewing a movable ground hull = a convoy that should road-march.
							if (_slHasVeh && {(_slOrigin distance _goto) > 700}) then {
								_laneJit = _team getVariable "wfbe_aicom_lanejit";
								if (isNil "_laneJit") then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]};
								_slRoute = [_slOrigin, _goto, _laneJit * 120, 8] Call WFBE_CO_FNC_BuildRoadRoute;
								//--- Road-march posture on the group, then road nodes as COLUMN MOVEs and the mode waypoint at _goto.
								_team setBehaviour "AWARE"; _team setCombatMode "RED"; _team setFormation "COLUMN"; _team setSpeedMode "FULL";
								_slWPs = [];
								{ _slWPs = _slWPs + [[_x, "MOVE", 40, 30, [], [], ["AWARE","RED","","FULL"]]] } forEach _slRoute;
								_slWPs = _slWPs + [[_goto, _wpType, _radius, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]];
								[_team, true, _slWPs] Call WFBE_CO_FNC_WaypointsAdd;
								["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] team [%2] executing %3 order at %4 via ROAD-MARCH (%5 road nodes).", _side, _team, _modeL, _goto, count _slRoute]] Call WFBE_CO_FNC_AICOMLog;
							} else {
								[_team, _goto, _wpType, _radius] Call AIMoveTo;
								["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] team [%2] executing %3 order at %4.", _side, _team, _modeL, _goto]] Call WFBE_CO_FNC_AICOMLog;
							};
							_team setVariable ["wfbe_exec_sig", _sig];
						};
					};
				};
			} else {
				//--- Not an explicit order anymore - drop the signature so a later order always re-executes.
				_team setVariable ["wfbe_exec_sig", []];
			};
		};
	};
} forEach _teams;
