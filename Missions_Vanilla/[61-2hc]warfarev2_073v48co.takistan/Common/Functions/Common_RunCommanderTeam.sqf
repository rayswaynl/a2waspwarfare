/*
	Run one AI-commander combat team: create it and execute the brain's orders locally.
	feat/ai-commander V0.3. Runs on a HEADLESS CLIENT (delegate-aicom-team) or on the
	server as fallback - the whole team lifecycle stays on the creating machine so
	waypoints keep locality (the proven side-patrol pattern).

	 Parameters: [ sideID, template (unit class array), spawnPos ]

	The server brain communicates through ONE public group variable:
	  wfbe_aicom_order = [seq, mode, pos]   (mode: "towns-target" | "defense")
	The driver applies an order once per seq bump: MOVE to pos, SAD on arrival
	(towns-target) or a tight defensive SAD at pos (defense). Team wipe releases
	the slot via aicom-team-ended.
*/

Private ["_townOrderArr","_chkVeh","_sideID","_template","_pos","_side","_team","_retVal","_units","_vehicles","_ldr","_alive","_order","_seq","_lastSeq","_mode","_dest","_arrived",
         "_captureDone","_townObj","_townCamps","_campObj","_campRange",
         "_liveUnits","_dismounted","_veh","_u","_settleTimeout","_hasCargo","_skillSend"];

_sideID = _this select 0;
_template = _this select 1;
_pos = _this select 2;
_side = (_sideID) Call WFBE_CO_FNC_GetSideFromID;

_pos = [_pos, 30, 120] Call WFBE_CO_FNC_GetRandomPosition;
_pos = [_pos, 40] Call WFBE_CO_FNC_GetEmptyPosition;

_team = [_side, "aicom"] Call WFBE_CO_FNC_CreateGroup;
_retVal = [_template, _pos, _side, true, _team, true, 90] call WFBE_CO_FNC_CreateTeam;
_units = _retVal select 0;
_vehicles = _retVal select 1;
_team = _retVal select 2;

if (isNull _team || {((count _units) + (count _vehicles)) == 0}) exitWith {
	["WARNING", Format ["Common_RunCommanderTeam.sqf: [%1] team creation failed - releasing the slot.", _side]] Call WFBE_CO_FNC_AICOMLog;
	if (isServer) then {
		["aicom-team-ended", _sideID, grpNull] Call HandleSpecial;
	} else {
		["RequestSpecial", ["aicom-team-ended", _sideID, grpNull]] Call WFBE_CO_FNC_SendToServer;
	};
};

_team allowFleeing 0;

//--- W7 "Veteran Company" skill boost: optional 4th delegate arg (0/absent = default skill). Only the
//--- AICOM-Teams HC dispatch (delegate-aicom-team) sends it (0.85 when the veteran flag was set, else 0);
//--- the W6/W19 server-local 3-arg calls omit it, so guard on count. AI-only; _units are local on the
//--- founding HC/server. typeName guard (not A3 isEqualType) keeps this A2 OA safe. [needs live verification]
if (count _this > 3) then {
	_skillSend = _this select 3;
	if (typeName _skillSend == "SCALAR" && {_skillSend > 0}) then {
		{_x setSkill _skillSend} forEach _units;
	};
};
_team setVariable ["wfbe_aicom_hc", true, true];   //--- brain: do not Produce/waypoint this one directly.
_team setVariable ["wfbe_queue", [], false];

if (isServer) then {
	["aicom-team-created", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-created", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] commander team spawned (%2 units, %3 vehicles).", _side, count _units, count _vehicles]] Call WFBE_CO_FNC_AICOMLog;

//--- HC locality note: this file is spawned exclusively via delegate-aicom-team ->
//--- HandleSpecial.sqf on the Headless Client (AI_Commander_Teams.sqf line 171).
//--- The created group is local to the HC for its entire lifetime, so waypoints,
//--- doMove, assignAsCargo, and orderGetIn all execute with correct locality here.

//--- Order-execution loop: apply each new order seq from the server brain.
_lastSeq = -1;
_arrived = false;
_captureDone = false;     //--- guard: run dismount-capture phase only once per order
_alive = true;
while {!WFBE_GameOver && _alive} do {
	_alive = if (count ((units _team) Call WFBE_CO_FNC_GetLiveUnits) == 0 || isNull _team) then {false} else {true};

	if (_alive) then {
		//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
		_order = _team getVariable "wfbe_aicom_order";
		if (isNil "_order") then {_order = []};
		if (count _order >= 3) then {
			_seq = _order select 0;
			_mode = _order select 1;
			_dest = _order select 2;

			if (_seq != _lastSeq) then {
				//--- Fresh order: head out.
				_lastSeq = _seq;
				_arrived = false;
				_captureDone = false;
				[_team, _dest, 'MOVE', 50] Spawn WFBE_CO_FNC_WaypointSimple;
				["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] order #%3 %4.", _side, _team, _seq, _mode]] Call WFBE_CO_FNC_AICOMLog;
			} else {
				//--- On arrival, switch to the mode's local behaviour once.
				if (!_arrived) then {
					if ((leader _team) distance _dest < 200) then {
						_arrived = true;
						if (_mode == "defense") then {
							[_team, _dest, 'SAD', 100] Spawn WFBE_CO_FNC_WaypointSimple;
						} else {
							[_team, _dest, 'SAD', 250] Spawn WFBE_CO_FNC_WaypointSimple;
						};
					};
				};

				//--- Dismount-capture phase: fires once per towns-target order on arrival.
				//--- Mirrors Common_RunSidePatrol.sqf Task 40 camp-sweep (lines 132-217).
				//--- Fixes the mounted-unit capture bug: nearEntities["Man"] counts only
				//--- dismounted soldiers; crew sitting in vehicles scores zero capture ticks.
				if (_arrived && !_captureDone && _mode == "towns-target") then {
					_captureDone = true;

					//--- Recover the town object from the server-broadcast group variable
					//--- wfbe_aicom_townorder = [townObj, time, startPos] set by
					//--- AI_Commander_AssignTowns.sqf with broadcast=true, readable here.
					_townObj   = objNull;
					_townCamps = [];
					//--- A2: groups do not support the [name, default] getVariable form; plain get + isNil.
					_townOrderArr = _team getVariable "wfbe_aicom_townorder";
					if (isNil "_townOrderArr") then {_townOrderArr = []};
					if (count _townOrderArr > 0) then {
						_townObj   = _townOrderArr select 0;
						_townCamps = if (!isNull _townObj) then {_townObj getVariable ["camps", []]} else {[]};
					};

					_campRange = missionNamespace getVariable ["WFBE_C_CAMPS_RANGE", 30];

					//--- Check whether the team has any cargo infantry (non-driver/non-gunner).
					_hasCargo  = false;
					_liveUnits = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
					{
						if (alive _x && vehicle _x != _x) then {
							_chkVeh = vehicle _x;
							if (_x != driver _chkVeh && _x != gunner _chkVeh) then {_hasCargo = true};
						};
					} forEach _liveUnits;

					if (_hasCargo) then {
						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] begin capture-dismount at [%3] (%4 camps).", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}, count _townCamps]] Call WFBE_CO_FNC_AICOMLog;

						if (count _townCamps > 0) then {
							//--- Per-camp sweep: move -> settle -> dismount cargo -> dwell 75 s -> remount.
							//--- Ported from Common_RunSidePatrol.sqf lines 132-189.
							for "_ci" from 0 to ((count _townCamps) - 1) do {
								_campObj = _townCamps select _ci;
								if (isNull _campObj) exitWith {};

								if (!isNull leader _team && alive leader _team) then {
									(leader _team) doMove (getPos _campObj);
								};

								//--- Settle wait: up to 20 s or leader within _campRange m.
								//--- SCOPE BUG PREVENTION: exitWith inside a then{} exits only that
								//--- then-block, NOT the enclosing while. This burned the patrol
								//--- before it was fixed (fleet burned-traps memory). The proximity
								//--- condition belongs in the while header with lazy &&, as below.
								_settleTimeout = time + 20;
								while {time < _settleTimeout && {!(!isNull leader _team && {alive leader _team} && {(leader _team) distance _campObj < _campRange})}} do { sleep 2; };

								//--- DISMOUNT cargo infantry; crew (driver/gunner) stays in vehicle.
								_liveUnits  = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
								_dismounted = [];
								{
									_u = _x;
									if (alive _u && vehicle _u != _u) then {
										_veh = vehicle _u;
										if (_u == driver _veh || _u == gunner _veh) then {
											//--- Crew stays mounted: keeps vehicle ready for remount.
										} else {
											unassignVehicle _u;
											[_u] orderGetIn false;
											_dismounted = _dismounted + [_u];
										};
									};
								} forEach _liveUnits;

								//--- Send dismounted infantry to camp capture point.
								{if (alive _x) then {_x doMove (getPos _campObj)}} forEach _dismounted;

								//--- Dwell ~75 s so presence-based capture ticks register.
								sleep 75;

								//--- REMOUNT: re-assign cargo, order back in (25 s grace timeout).
								if (count _vehicles > 0 && count _dismounted > 0) then {
									_veh = _vehicles select 0;
									{
										if (alive _x && alive _veh) then {
											_x assignAsCargo _veh;
											[_x] orderGetIn true;
										};
									} forEach _dismounted;
									sleep 25;
								};
							};
						} else {
							//--- No camp objects on this town: single dwell at the town-center pos.
							_liveUnits  = (units _team) Call WFBE_CO_FNC_GetLiveUnits;
							_dismounted = [];
							{
								_u = _x;
								if (alive _u && vehicle _u != _u) then {
									_veh = vehicle _u;
									if (_u == driver _veh || _u == gunner _veh) then {
										//--- Crew stays mounted.
									} else {
										unassignVehicle _u;
										[_u] orderGetIn false;
										_dismounted = _dismounted + [_u];
									};
								};
							} forEach _liveUnits;

							{if (alive _x) then {_x doMove _dest}} forEach _dismounted;
							sleep 75;

							if (count _vehicles > 0 && count _dismounted > 0) then {
								_veh = _vehicles select 0;
								{
									if (alive _x && alive _veh) then {
										_x assignAsCargo _veh;
										[_x] orderGetIn true;
									};
								} forEach _dismounted;
								sleep 25;
							};
						};

						["INFORMATION", Format ["Common_RunCommanderTeam.sqf: [%1] team [%2] remounted after capture-dwell at [%3].", _side, _team, if (!isNull _townObj) then {_townObj getVariable ["name","?"]} else {"pos"}]] Call WFBE_CO_FNC_AICOMLog;
					} else {
						//--- Pure-armour team: no cargo infantry present.
						//--- Crew (driver/gunner) counts zero for nearEntities["Man"] capture ticks.
						//--- Workaround: park the vehicle ON the town center so the hull is at least
						//--- inside the capture radius. Infantry capture credit is still zero.
						//--- A brief commander-dismount (eject + doMove + reboard) would fix this
						//--- but is an owner-review option and is NOT implemented here.
						if (!isNull leader _team && alive leader _team) then {
							(leader _team) doMove _dest;
						};
					};
				};
			};
		};
	};

	sleep 20;
};

//--- Team wiped: release the brain's slot.
if (isServer) then {
	["aicom-team-ended", _sideID, _team] Call HandleSpecial;
} else {
	["RequestSpecial", ["aicom-team-ended", _sideID, _team]] Call WFBE_CO_FNC_SendToServer;
};

if (!isNull _team) then {deleteGroup _team};
