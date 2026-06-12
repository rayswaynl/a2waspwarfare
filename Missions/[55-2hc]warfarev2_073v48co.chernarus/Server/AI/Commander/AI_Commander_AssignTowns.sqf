/*
	AI Commander - send idle AI teams at the nearest uncaptured town.
	feat/ai-commander. Server-side worker.
	Parameter: _this = side.

	The "towns" team mode is otherwise dead infrastructure (nothing drives teams to
	towns), so this worker BOTH sets the mode and issues the waypoints itself, via the
	existing arc-approach planner (WFBE_C_AI_COMMANDER_USE_ARC_APPROACH=1) or the proven
	AIMoveTo fallback (=0).
*/

private ["_side","_sideID","_sideText","_logik","_teams","_uncaptured","_assigned","_team","_aliveCount","_mode","_goto","_needs","_avail","_target","_useArc","_humanCmd","_cmdTeam","_autonomous","_modeNow","_canDrive","_explicitMode","_gar","_garDead","_hqG","_ord","_spear","_spearT","_perTown"];

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
	//--- V0.6.5: wiped HC teams leave NULL groups in wfbe_teams (index-aligned registry,
	//--- entries must NOT be removed). getVariable on a null group returns nil even with
	//--- a default -> toLower nil threw here every tick and killed town assignment for
	//--- every team after the first null (live-round towns stuck at 0/0). Skip nulls.
	_aliveCount = 0;
	if (!isNull _team) then {_aliveCount = {alive _x} count (units _team)};
	if (_aliveCount > 0) then {
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
		//--- Owner call 2026-06-11: OFF by default - everything goes to the front.
		//--- Opt back in via WFBE_C_AI_COMMANDER_GARRISON = 1.
		if (((missionNamespace getVariable ["WFBE_C_AI_COMMANDER_GARRISON", 0]) > 0) && {!_humanCmd} && {!_explicitMode} && {_aliveCount > 0}) then {
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
					//--- V0.3: HC-resident teams get their orders via the public order variable.
					if (_team getVariable ["wfbe_aicom_hc", false]) then {
						_team setVariable ["wfbe_aicom_order", [((_team getVariable ["wfbe_aicom_order", [-1]]) select 0) + 1, "defense", getPos _hqG], true];
					};
					_logik setVariable ["wfbe_aicom_garrison", _team];
					_explicitMode = true; //--- now an explicit order; the executor drives it home
					["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] assigned as base garrison.", _sideText, _team]] Call WFBE_CO_FNC_AICOMLog;
				};
			};
		};
		if (!_explicitMode) then {
			_mode = _team getVariable ["wfbe_teammode", ""];
			_goto = _team getVariable ["wfbe_teamgoto", objNull];

			//--- V0.4.2 churn fix: orders are STICKY. Retarget only when the team has no
			//--- valid enemy-town target, the target resolved (we captured it), or the team
			//--- has been visibly stuck on the same order for 10+ min without progress.
			//--- Distance alone is NOT a reason - en-route teams keep their order.
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
							_ord = _team getVariable ["wfbe_aicom_townorder", []];
							if (count _ord < 3 || {(_ord select 0) != _goto}) then {
								//--- No bookkeeping yet (legacy order) or goto changed under us: book it
								//--- once without re-issuing waypoints; the stuck check takes over from here.
								_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos (leader _team)]];
							} else {
								if (time - (_ord select 1) > 600) then {
									if ((leader _team) distance (_ord select 2) < 200 && {(leader _team) distance _goto > 300}) then {
										_needs = true; //--- parked 10+ min far from the target: re-issue
									} else {
										//--- progressing (or arrived): refresh the breadcrumb
										_team setVariable ["wfbe_aicom_townorder", [_goto, time, getPos (leader _team)]];
									};
								};
							};
						};
					};
				};
			};

			if (_needs) then {
				//--- V0.5: concentrate on the strategy worker's spearhead targets first
				//--- (SPEARHEAD_PER_TOWN teams per town this pass), then spill over to
				//--- the classic nearest-uncaptured pick.
				_target = objNull;
				_spear = _logik getVariable ["wfbe_aicom_targets", []];
				_perTown = missionNamespace getVariable ["WFBE_C_AI_COMMANDER_SPEARHEAD_PER_TOWN", 3];
				{
					_spearT = _x;
					if (isNull _target && {!isNull _spearT}) then {
						if ((_spearT getVariable "sideID") != _sideID) then {
							if (({_x == _spearT} count _assigned) < _perTown) then {_target = _spearT};
						};
					};
				} forEach _spear;
				if (isNull _target) then {
					_avail = _uncaptured - _assigned;
					if (count _avail == 0) then {_avail = _uncaptured};
					_target = [leader _team, _avail] Call WFBE_CO_FNC_GetClosestEntity;
				};
				if (!isNil "_target") then {
					if (!isNull _target) then {
						[_team, "towns"] Call SetTeamMoveMode;
						[_team, _target] Call SetTeamMovePos;
						if (_team getVariable ["wfbe_aicom_hc", false]) then {
							//--- V0.3: HC-resident team - the HC driver issues the local waypoints;
							//--- server-side waypoint commands on remote groups are unreliable.
							_team setVariable ["wfbe_aicom_order", [((_team getVariable ["wfbe_aicom_order", [-1]]) select 0) + 1, "towns-target", getPos _target], true];
						} else {
							if (_useArc) then {
								[_team, _target] Call WFBE_SE_FNC_AI_SetTownAttackPath;
							} else {
								[_team, getPos _target, "SAD", 200] Call AIMoveTo;
							};
						};
						_assigned set [count _assigned, _target];
						_team setVariable ["wfbe_aicom_townorder", [_target, time, getPos (leader _team)]];
						["INFORMATION", Format ["AI_Commander_AssignTowns.sqf: [%1] team [%2] heading to attack town [%3].", _sideText, _team, _target getVariable ["name", "town"]]] Call WFBE_CO_FNC_AICOMLog;
					};
				};
			};
		};
	};
	}; //--- V0.6.5 null-team guard
} forEach _teams;
