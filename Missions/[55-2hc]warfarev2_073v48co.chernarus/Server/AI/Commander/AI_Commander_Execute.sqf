/*
	AI Commander - order executor.  feat/ai-commander. Server-side; runs every supervisor tick.
	Parameter: _this = side.

	Turns explicit Move/Patrol/Defend orders (set by a human commander via the Command Center, or by the
	AI) into real waypoints for AI-led teams. SetTeamMoveMode/SetTeamMovePos only store vars - nothing else
	issues waypoints for them, so this is the path that finally makes the command bar work.
	Idempotent: an unchanged order is not re-issued. build83 uses a DISTANCE-GATED latch (wfbe_exec_lastmode/
	wfbe_exec_lastgoto) plus a per-team min re-issue interval (wfbe_exec_at) so quick clicks to nearby points
	neither drop nor double-lay waypoints. "towns"/"" modes belong to AssignTowns.
*/
private ["_side","_logik","_teams","_team","_mode","_modeL","_goto","_changed","_prevGoto","_prevMode","_orderDelta","_orderMinInt","_wpType","_radius","_aliveCount","_realGoto","_isHc","_hcMode","_hcSeq","_hcOrigin","_hcRoute","_laneJit","_slOrigin","_slHasVeh","_slRoute","_slWPs"]; //--- B67 +_isHc/_hcMode/_hcSeq; build83 distance-gated debounce +_changed/_prevGoto/_prevMode/_orderDelta/_orderMinInt
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
			_mode  = [_team, "wfbe_teammode", "towns"] Call WFBE_CO_FNC_GroupGetValue;
			_modeL = toLower _mode;
			if (_modeL == "move" || _modeL == "patrol" || _modeL == "defense") then {
				_goto = [_team, "wfbe_teamgoto", [0,0,0]] Call WFBE_CO_FNC_GroupGetValue;
				//--- A real destination only (array, not the [0,0,0] default).
				_realGoto = false;
				if (typeName _goto == "ARRAY") then {
					if (count _goto >= 2) then {
						if ((_goto select 0) != 0) then {_realGoto = true};
						if ((_goto select 1) != 0) then {_realGoto = true};
					};
				};
				if (_realGoto) then {
					//--- build83 SAFE executor debounce (order-wiring). The old exact change-signature latch
					//--- (str [mode, round x, round y]) treated two quick clicks to *slightly* different points as a
					//--- fresh order every tick: rounding to the same integer cell could DROP a real re-aim, while a
					//--- 1-2m nudge could DOUBLE-LAY a waypoint (start-stop stutter). Replace with a DISTANCE-GATED
					//--- latch: the order is CHANGED only when the mode changed OR the new goto moved farther than
					//--- WFBE_C_AICOM_ORDER_DELTA (default 80m) from the last committed goto. Plus a per-team minimum
					//--- re-issue interval WFBE_C_AICOM_ORDER_MININT (default 6s) so rapid clicks can't re-lay inside
					//--- the debounce window. Pure arithmetic + group-safe default reads (A2-OA 1.64 safe).
					//--- On-change-only and the HC-publish vs server-local branches below are otherwise unchanged.
					_prevMode    = [_team, "wfbe_exec_lastmode", ""] Call WFBE_CO_FNC_GroupGetValue;
					_prevGoto    = [_team, "wfbe_exec_lastgoto", [0,0,0]] Call WFBE_CO_FNC_GroupGetValue;
					_orderDelta  = missionNamespace getVariable ["WFBE_C_AICOM_ORDER_DELTA", 80];
					_orderMinInt = missionNamespace getVariable ["WFBE_C_AICOM_ORDER_MININT", 6];
					_changed = false;
					if (_modeL != _prevMode) then {_changed = true};
					if (!_changed && {(_goto distance _prevGoto) > _orderDelta}) then {_changed = true};
					//--- Per-team minimum re-issue interval: even a genuinely-changed order is held back if we
					//--- committed one for this team within the last _orderMinInt seconds (rapid double-click guard).
					//--- Never freezes a team: a real change simply re-lays on the next tick past the window; the
					//--- team keeps its current live waypoint meanwhile.
					if (_changed && {(time - ([_team, "wfbe_exec_at", -1e9] Call WFBE_CO_FNC_GroupGetValue)) < _orderMinInt}) then {_changed = false};
					if (_changed) then {
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
						//--- (seq bumped only on a CHANGED order, gated by the distance/interval latch above, so we never spam re-issues).
						//--- Mode mapping to the driver's vocab: human "defense" -> "defense" (driver HOLDs a tight SAD at pos);
						//--- "move"/"patrol" pass through to the driver's non-"defense"/non-"towns-target" branch = a
						//--- COMBAT/WEDGE assault SAD at pos (advance-and-engage, never idle). pos = the human-set goto array.
						//--- Server-local teams keep the AIMoveTo path below unchanged. WFBE_CO_FNC_GroupGetBool guards the
						//--- UNSET-on-group bool read (A2-OA "G1" trap).
						_isHc = [_team, "wfbe_aicom_hc", false] Call WFBE_CO_FNC_GroupGetBool;
						if (_isHc) then {
							_hcMode = if (_modeL == "defense") then {"defense"} else {_modeL}; //--- "move"/"patrol" pass through to the driver's assault-SAD branch.
							//--- build83 fold (console road-route, agent 06190dac): populate wfbe_aicom_route so the HC driver ROAD-MARCHES a long human MOVE leg instead of cutting cross-country (only AssignTowns used to fill this). Same >700m gate; the driver's own ground-vehicle gate keeps pure-infantry HC teams on the foot column.
							_hcOrigin = getPos (leader _team);
							_hcRoute = [];
							if ((_hcOrigin distance _goto) > 700) then {
								_laneJit = _team getVariable "wfbe_aicom_lanejit";
								if (isNil "_laneJit") then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]};
								_hcRoute = [_hcOrigin, _goto, _laneJit * 120, 8] Call WFBE_CO_FNC_BuildRoadRoute;
							};
							_team setVariable ["wfbe_aicom_route", _hcRoute, true]; //--- broadcast BEFORE the seq bump so the driver reads THIS order's route.
							_hcSeq = [_team] Call WFBE_CO_FNC_AICOMNextOrderSeq;
							_team setVariable ["wfbe_aicom_order", [_hcSeq, _hcMode, _goto], true];
							_team setVariable ["wfbe_exec_lastmode", _modeL];
							_team setVariable ["wfbe_exec_lastgoto", _goto];
							_team setVariable ["wfbe_exec_at", time];
							["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] HC team [%2] human %3 order published via wfbe_aicom_order #%4 at %5.", _side, _team, _modeL, _hcSeq, _goto]] Call WFBE_CO_FNC_AICOMLog;
						} else {
							_wpType = "MOVE"; _radius = 50;
							if (_modeL == "patrol")  then {_wpType = "SAD";  _radius = 150};
							if (_modeL == "defense") then {_wpType = "HOLD"; _radius = 30};
							//--- build83 fold (console road-route, agent 06190dac): a SERVER-LOCAL ground-vehicle team on a long leg (>700m) gets a road-node-snapped MOVE chain (same builder the AI-strategy town path uses) instead of a single cross-country AIMoveTo that A2 pathfinding stutters through; pure-infantry/short legs keep the direct AIMoveTo (driver does not road-lock foot squads).
							_slOrigin = getPos (leader _team);
							_slHasVeh = false;
							{ if (vehicle _x != _x && {alive (vehicle _x)} && {!((vehicle _x) isKindOf "Air")} && {canMove (vehicle _x)}) exitWith {_slHasVeh = true} } forEach (units _team);
							if (_slHasVeh && {(_slOrigin distance _goto) > 700}) then {
								_laneJit = _team getVariable "wfbe_aicom_lanejit";
								if (isNil "_laneJit") then {_laneJit = (random 2) - 1; _team setVariable ["wfbe_aicom_lanejit", _laneJit, true]};
								_slRoute = [_slOrigin, _goto, _laneJit * 120, 8] Call WFBE_CO_FNC_BuildRoadRoute;
								_team setBehaviour "AWARE"; _team setCombatMode "RED"; _team setFormation "COLUMN"; _team setSpeedMode "FULL";
								_slWPs = [];
								{ _slWPs = _slWPs + [[_x, "MOVE", 40, 30, [], [], ["AWARE","RED","","FULL"]]] } forEach _slRoute;
								_slWPs = _slWPs + [[_goto, _wpType, _radius, 30, [], [], ["AWARE","RED","COLUMN","FULL"]]];
								[_team, true, _slWPs] Call WFBE_CO_FNC_WaypointsAdd;
							} else {
								[_team, _goto, _wpType, _radius] Call AIMoveTo;
							};
							_team setVariable ["wfbe_exec_lastmode", _modeL];
							_team setVariable ["wfbe_exec_lastgoto", _goto];
							_team setVariable ["wfbe_exec_at", time];
							["INFORMATION", Format ["AI_Commander_Execute.sqf: [%1] team [%2] executing %3 order at %4%5.", _side, _team, _modeL, _goto, (if (_slHasVeh && {(_slOrigin distance _goto) > 700}) then {" via ROAD-MARCH"} else {""})]] Call WFBE_CO_FNC_AICOMLog;
						};
					};
				};
			} else {
				//--- Not an explicit order anymore - clear the debounce latch so a later order always re-executes
				//--- immediately (mode differs from "" -> _changed true; and the interval stamp is reset so the
				//--- min-interval guard can't swallow the first re-issue).
				_team setVariable ["wfbe_exec_lastmode", ""];
				_team setVariable ["wfbe_exec_lastgoto", [0,0,0]];
				_team setVariable ["wfbe_exec_at", -1e9];
			};
		};
	};
} forEach _teams;
