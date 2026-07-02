/*
	Common_AICOM_HeliTerrainGuard.sqf

	Author: claude-gaming (cmdcon41-w3j, 2026-07-02)

	Description:
		AI-COMMANDER helicopter terrain look-ahead climb - the HC-local twin of
		Server\server_heli_terrain_guard.sqf.

		server_heli_terrain_guard.sqf is `if (!isServer) exitWith {}` and world-scans
		`vehicles`, so it only ever helps SERVER-local helis (paradrop/supply, GUER
		air-defence, W13 gunship, and AICOM helis founded on the server when no HC is
		connected). Its own header admits: "HC-local AICOM helis would need an HC-side
		copy of this loop - left as a follow-up." On a live 2-HC box EVERY AICOM air
		team is delegated to an HC (Common_RunCommanderTeam runs there), so the gunships
		Ray actually sees get NO terrain climb today. This is that follow-up.

		This manager runs where AICOM hulls are LOCAL (server + each HC) - the SAME
		machine-scoping and BOUNDED wfbe_teams enumeration the sibling managers
		Common_AICOM_HighClimb.sqf / Common_AICOM_AutoFlip.sqf use (NO allUnits /
		allLocal / world `vehicles` scan - the perf trap). It reads each side's
		already-tracked commander teams from the side logic's globally broadcast
		`wfbe_teams` array, walks each team GROUP's units, resolves their vehicle, and
		acts ONLY on a Helicopter hull LOCAL to this machine. That is exactly the
		founded/delegated AICOM air set - never the whole world.

		The per-heli guard REUSES the proven look-ahead climb VERBATIM from
		server_heli_terrain_guard.sqf: a single reusable invisible probe (A2 OA has NO
		getTerrainHeightASL - that is Arma 3; we ground a probe with setPos z=0 and read
		getPosASL), sample terrain along the heli's heading, and raise flyInHeight when
		terrain is rising into the flight path. Reactive only: it raises height, never
		lowers it, so it can never force a heli into the ground; worst case it briefly
		delays a low pass. Same tunables as the server guard so both share one config.

		Coverage note: the server keeps running server_heli_terrain_guard.sqf UNCHANGED
		for its server-local NON-team air (paradrop/supply/GUER/W13 - which are not in
		wfbe_teams). This manager adds the HC coverage + the server AICOM-team coverage;
		a hull touched by both on the server is harmless (both only raise flyInHeight).

		Flag: WFBE_C_AIHELI_TERRAIN_GUARD (default 1 = ON) - the SAME const the server
		guard reads, so one flip toggles heli terrain-guard everywhere.
		Tunables: WFBE_C_AIHELI_GUARD_LOOKAHEAD (250 m), WFBE_C_AIHELI_GUARD_CLEARANCE (60 m).
*/

//--- Read inline (Init_CommonConstants owner registers the constant later). Default ON, mirroring the server guard.
if ((missionNamespace getVariable ["WFBE_C_AIHELI_TERRAIN_GUARD", 1]) < 1) exitWith {};

//--- Only the server and headless clients host AICOM-local vehicles (sibling-manager gate).
if (!isServer && {!isHeadLessClient}) exitWith {};

private ["_machineTag","_probe","_lookAhead","_clearance"];
_machineTag = if (isServer) then {"SERVER"} else {"HC"};
_lookAhead  = missionNamespace getVariable ["WFBE_C_AIHELI_GUARD_LOOKAHEAD", 250];
_clearance  = missionNamespace getVariable ["WFBE_C_AIHELI_GUARD_CLEARANCE", 60];

//--- One reusable terrain-sampling probe (LOCAL to this machine, invisible) - same idiom as the server guard.
_probe = "Sign_sphere10cm_EP1" createVehicleLocal [0, 0, 0];
_probe hideObject true;

["INFORMATION", Format ["Common_AICOM_HeliTerrainGuard.sqf: AICOM-heli terrain guard started (%1, look-ahead %2m, min clearance %3m).", _machineTag, _lookAhead, _clearance]] Call WFBE_CO_FNC_AICOMLog;

//--- ============================================================================
//--- Per-heli look-ahead climb - VERBATIM logic from server_heli_terrain_guard.sqf
//--- (only the enumeration around it changed from a world `vehicles` scan to the
//--- bounded wfbe_teams walk). _this = [heli, probe, lookAhead, clearance].
//--- ============================================================================
WFBE_CO_FNC_AICOM_HeliTerrainGuard_Check = {
	private ["_h","_pr","_la","_cl","_drv","_spd","_dir","_pos","_terrAhead","_heliASL"];
	_h  = _this select 0;
	_pr = _this select 1;
	_la = _this select 2;
	_cl = _this select 3;
	if (_h isKindOf "Helicopter" && {alive _h} && {local _h} && {(getPos _h) select 2 > 8}) then {
		_drv = driver _h;
		if (!isNull _drv && {!isPlayer _drv}) then {
			_spd = speed _h;
			if (_spd > 25) then {
				_dir = direction _h;
				_pos = getPosASL _h;
				//--- look-ahead point along the heli's heading; z=0 (ATL) grounds the probe so getPosASL reads the terrain there.
				_pr setPos [(_pos select 0) + (sin _dir) * _la, (_pos select 1) + (cos _dir) * _la, 0];
				_terrAhead = (getPosASL _pr) select 2;
				_heliASL = _pos select 2;
				if ((_heliASL - _terrAhead) < _cl) then {
					//--- terrain rising into the path: command a climb to restore clearance (engine maintains AGL afterwards).
					_h flyInHeight (_cl + 25);
				};
			};
		};
	};
};

//--- ============================================================================
//--- Manager loop. Bounded enumeration over the side-logic wfbe_teams group arrays
//--- (identical scan shape to Common_AICOM_HighClimb.sqf). Fixed 4s cadence to match
//--- the server guard's sleep 4 (the look-ahead only needs to fire a few seconds
//--- before a rising ridge; a heli at ~50 m/s covers the 250 m look-ahead in ~5s).
//--- ============================================================================
private ["_sides","_perfStart","_perfTeams","_perfLocalHeli","_side","_logik","_teams","_team","_seen","_veh"];

_sides = [west, east, resistance];

while {!WFBE_gameover} do {

	//--- Performance Audit timing (mirrors the sibling managers). Guarded by isNil.
	_perfStart     = diag_tickTime;
	_perfTeams     = 0;   //--- commander teams walked this pass (across all sides)
	_perfLocalHeli = 0;   //--- distinct machine-local helis inspected this pass

	//--- track hulls already inspected this pass so a heli shared across list quirks is counted/probed once.
	_seen = [];

	{
		_side  = _x;
		_logik = _side Call WFBE_CO_FNC_GetSideLogic;

		if (!isNil "_logik" && {!isNull _logik}) then {

			//--- wfbe_teams is broadcast globally (setVariable [...,true] in aicom-team-created),
			//--- so it is readable here on the server AND on every HC. Object getVariable [k,d]
			//--- is A2-OA-safe (never the A3-only group getVariable [k,d]).
			_teams = _logik getVariable ["wfbe_teams", []];

			{
				_team = _x;
				if (!isNull _team) then {
					_perfTeams = _perfTeams + 1;

					//--- BOUNDED: walk only this team's own units, resolve their vehicle, and act
					//--- ONLY on a Helicopter hull local to THIS machine. No world `vehicles` scan.
					{
						_veh = vehicle _x;
						if (
							!isNull _veh &&
							{_veh != _x} &&
							{local _veh} &&
							{!(_veh in _seen)} &&
							{alive _veh} &&
							{_veh isKindOf "Helicopter"}
						) then {
							_seen set [count _seen, _veh];
							_perfLocalHeli = _perfLocalHeli + 1;
							[_veh, _probe, _lookAhead, _clearance] Call WFBE_CO_FNC_AICOM_HeliTerrainGuard_Check;
						};
					} forEach (units _team);
				};
			} forEach _teams;
		};
	} forEach _sides;

	//--- Performance Audit record (tag "aicom_heli_terrainguard"), same guard idiom as the sibling managers.
	if !(isNil "PerformanceAudit_Record") then {
		if (missionNamespace getVariable ["PerformanceAuditEnabled", true]) then {
			["aicom_heli_terrainguard", diag_tickTime - _perfStart, Format["teams:%1;localHeli:%2", _perfTeams, _perfLocalHeli], _machineTag] Call PerformanceAudit_Record;
		};
	};

	sleep 4;
};
