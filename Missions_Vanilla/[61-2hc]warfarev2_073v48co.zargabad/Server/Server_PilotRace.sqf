/*
	Server_PilotRace.sqf — PILOT-RACE loop (SERVER-only). Lane B3 (Ray 2026-07-02).

	Every AI aircraft killed with a live crew (isKindOf "Air", !isPlayer driver, side not civilian)
	ejects a capturable downed pilot + a fuzzy global map ping.  First side to reach the pilot
	within 20 m scores WFBE_C_PILOT_CAPTURE_REWARD funds.  The pilot auto-dies + marker clears
	after WFBE_C_PILOT_TTL seconds.  Global alive cap: WFBE_C_PILOT_MAX_LIVE.

	A2-OA-1.64 rules applied throughout:
	  - Avoids newer collection helpers and equality shorthand in added lines.
	  - getVariable 2-arg form used only on objects (safe on objects in A2 OA 1.64).
	  - createMarker on server replicates to all clients incl. JIP; deleteMarker clears for all.
	  - setCaptive/allowDamage/setDamage run where the object is local (server-created units are local).
	  - ParachuteC classname confirmed via WFBE_GUERPARACHUTE in Root_GUE.sqf:34.
	  - Reward via [side, amount, reason, false] call ChangeSideSupply (server-side pattern used throughout).

	FIX (2026-07-02, review): previous version stored the live-pilot registry as a script-local
	  (_livePilots) and spawn/call helpers as script-locals (_spawnPilot/_maxLive).  These did NOT
	  survive A2 OA spawn/call thread-boundary crossings:
	    BLOCKER: WFBE_SE_FNC_PilotRaceEject body ran in a new spawn thread; _livePilots/_maxLive/
	             _spawnPilot were nil there -> count nil / call nil -> no pilot ever spawned.
	    HIGH:    _livePilots = _livePilots + [...] inside a call block wrote to the call's child scope;
	             the outer variable never grew -> MAX_LIVE cap was never reached.
	  Resolution: registry stored in missionNamespace ("WFBE_PilotRace_Live").
	  WFBE_SE_FNC_PilotRaceEject is now fully self-contained: reads NS var, checks cap via
	  missionNamespace getVariable, spawns inline, writes NS var back.  Main loop likewise reads/
	  writes NS var each tick.  No script-local state crosses any thread boundary.
*/
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_PILOT_RACE", 0]) < 1) exitWith {};

private ["_reward","_ttl","_mkPrefix"];

_reward   = missionNamespace getVariable ["WFBE_C_PILOT_CAPTURE_REWARD", 500];
_ttl      = missionNamespace getVariable ["WFBE_C_PILOT_TTL",            300];
_mkPrefix = "wfbe_pilotrace_mk_";

//--- Persistent live registry in missionNamespace.
//--- Each entry: [_pilot, _markerName, _spawnTime, _pilotSide, _chute, _pilotGroup].
//--- Index 5 = pilot group (stored at spawn so it can be deleteGroup'd even if pilot
//--- goes null externally before the cleanup path runs).
//--- Written/read via NS so it survives all spawn/call thread crossings.
missionNamespace setVariable ["WFBE_PilotRace_Live", []];

["INITIALIZATION", Format ["Server_PilotRace.sqf: PILOT-RACE started (reward=%1 ttl=%2 max=%3).", _reward, _ttl, (missionNamespace getVariable ["WFBE_C_PILOT_MAX_LIVE", 2])]] Call WFBE_CO_FNC_LogContent;

//--- WFBE_SE_FNC_PilotRaceEject: self-contained spawn handler.
//--- _this = [_aircraft, _acSide].
//--- Reads + writes WFBE_PilotRace_Live and WFBE_C_PILOT_MAX_LIVE directly from missionNamespace
//--- so it is independent of any parent-thread scope.  Called via:
//---   [_dead, _vs2] spawn WFBE_SE_FNC_PilotRaceEject
//--- from the killed EH, which already runs on the server (object local = server).
WFBE_SE_FNC_PilotRaceEject = {
	private ["_ac","_acSide","_liveNow","_maxLive","_pos","_fuzz","_mk","_pilotClass","_chuteModel"];
	private ["_grp","_pilot","_chute","_uid","_liveArr","_entry"];

	_ac      = _this select 0;
	_acSide  = _this select 1;

	//--- Read registry + cap from namespace each time (no parent-thread locals).
	_liveNow = missionNamespace getVariable ["WFBE_PilotRace_Live", []];
	_maxLive = missionNamespace getVariable ["WFBE_C_PILOT_MAX_LIVE", 2];

	if ((count _liveNow) >= _maxLive) exitWith {
		diag_log format ["PILOTRACE|CAP|alive=%1 max=%2|skip", count _liveNow, _maxLive];
	};

	_pos = getPos _ac;

	//--- Pilot classname: reuse GUER pilot (confirmed GUE_Soldier_Pilot in Config_GUE.sqf:88).
	//--- Group: civilian so the pilot does not fight back but is not auto-hostile to either side.
	_pilotClass = missionNamespace getVariable ["WFBE_GUERRESPILOT", "GUE_Soldier_Pilot"];
	_chuteModel = missionNamespace getVariable ["WFBE_GUERPARACHUTE", "ParachuteC"];

	_grp = createGroup civilian;
	if (isNull _grp) exitWith {
		diag_log "PILOTRACE|ERROR|createGroup civilian returned null";
	};

	//--- Spawn pilot at crash altitude so he visibly descends under a chute.
	_pilot = _grp createUnit [_pilotClass, [(_pos select 0), (_pos select 1), ((_pos select 2) max 80)], [], 0, "NONE"];
	if (isNull _pilot) exitWith {
		deleteGroup _grp;
		diag_log "PILOTRACE|ERROR|createUnit pilot returned null";
	};

	//--- Captive + injured, AI disabled so he does not fight or move.
	_pilot setCaptive true;
	_pilot setDamage 0.7;
	{_pilot disableAI _x} forEach ["AUTOTARGET","TARGET","AUTOCOMBAT","FSM","MOVE","ANIM"];
	_pilot setVariable ["wfbe_pilot_race", true, true];

	//--- Parachute descent: chute at altitude, pilot moves into driver seat.
	_chute = _chuteModel createVehicle [(_pos select 0) + (20 - random 40), (_pos select 1) + (20 - random 40), ((_pos select 2) max 80)];
	_pilot moveInDriver _chute;

	//--- Fuzzy marker: offset up to 400 m from real position to force a foot search.
	//--- Use count of current registry (re-read to be safe) for unique suffix.
	_liveArr = missionNamespace getVariable ["WFBE_PilotRace_Live", []];
	_uid = Format ["%1_%2", round time, count _liveArr];
	_mk  = "wfbe_pilotrace_mk_" + _uid;
	_fuzz = [(_pos select 0) + (200 - random 400), (_pos select 1) + (200 - random 400), 0];
	createMarker [_mk, _fuzz];
	_mk setMarkerType "mil_dot";
	_mk setMarkerColor "ColorYellow";
	_mk setMarkerText "DOWNED PILOT";

	//--- Append to registry and write back to namespace.
	//--- Store _grp as index 5 so every cleanup path can deleteGroup it even if
	//--- the pilot unit goes null externally before cleanup runs.
	_entry = [_pilot, _mk, time, _acSide, _chute, _grp];
	_liveArr = _liveArr + [_entry];
	missionNamespace setVariable ["WFBE_PilotRace_Live", _liveArr];

	diag_log format ["PILOTRACE|SPAWN|side=%1|pos=%2|fuzzy=%3|mk=%4|alive=%5", _acSide, _pos, _fuzz, _mk, count _liveArr];
};

//--- MAIN LOOP: runs every 5 s, two duties:
//--- (A) Attach the killed EH to any new untagged AI Air vehicle.
//--- (B) Maintain the live registry: capture check + TTL.
while {!WFBE_GameOver} do {
	sleep 5;

	private ["_now","_livePilots","_keptPilots"];
	_now = time;

	//--- (A) EH ATTACHMENT SCAN: walk all vehicles, find untagged AI Air.
	//--- wfbe_pr_eh object variable prevents double-attaching.
	{
		private ["_v","_vSide"];
		_v = _x;
		if (!isNull _v
			&& {alive _v}
			&& {_v isKindOf "Air"}
			&& {!(isPlayer (driver _v))}
			&& {isNil {_v getVariable "wfbe_pr_eh"}}
		) then {
			_vSide = side _v;
			//--- Exclude civilian (empty/parked) hulls — only armed sides get pilots.
			if (!(_vSide in [civilian])) then {
				_v setVariable ["wfbe_pr_eh", true];
				_v addEventHandler ["Killed", {
					private ["_dead","_drv","_vs2"];
					_dead = _this select 0;
					if (!(_dead isKindOf "Air")) exitWith {};
					_drv = driver _dead;
					if (isNull _drv) exitWith {};
					if (isPlayer _drv) exitWith {};
					_vs2 = side _dead;
					if (_vs2 in [civilian]) exitWith {};
					[_dead, _vs2] spawn WFBE_SE_FNC_PilotRaceEject;
				}];
			};
		};
	} forEach vehicles;

	//--- (B) LIVE REGISTRY: read from namespace, do capture check + TTL cleanup, write back.
	_livePilots = missionNamespace getVariable ["WFBE_PilotRace_Live", []];
	_keptPilots = [];
	{
		private ["_entry","_p","_mk","_spawnT","_pSide","_pChute","_pGrp","_drop","_reason","_near","_capSide"];
		_entry  = _x;
		_p      = _entry select 0;
		_mk     = _entry select 1;
		_spawnT = _entry select 2;
		_pSide  = _entry select 3;
		_pChute = _entry select 4;
		_pGrp   = _entry select 5;

		_drop   = false;
		_reason = "";

		//--- Pilot dead / null?
		if (isNull _p) then { _drop = true; _reason = "null"; };
		if (!_drop && {!(alive _p)}) then { _drop = true; _reason = "dead"; };

		//--- TTL expired?
		if (!_drop && {(_now - _spawnT) > _ttl}) then {
			_drop = true;
			_reason = "ttl";
			if (alive _p) then { _p setDamage 1; };
		};

		//--- Capture check: any non-civilian, non-pilot-side alive man within 20 m?
		if (!_drop) then {
			_near    = (getPos _p) nearEntities ["Man", 20];
			_capSide = civilian;
			{
				if (alive _x && {!((side _x) in [civilian])} && {!((side _x) in [_pSide])}) then {
					_capSide = side _x;
				};
			} forEach _near;
			if (!(_capSide in [civilian])) then {
				//--- First non-enemy, non-civilian side within range wins the reward.
				[_capSide, _reward, Format ["Pilot-race capture: +S %1.", _reward], false] call ChangeSideSupply;
				//--- Notify sides.
				[_capSide,  "HandleSpecial", ["serverMessage", Format ["Downed pilot captured! +$%1 to your side.", _reward]]] Call WFBE_CO_FNC_SendToClients;
				[_pSide, "HandleSpecial", ["serverMessage", "Enemy captured our downed pilot!"]] Call WFBE_CO_FNC_SendToClients;
				diag_log format ["PILOTRACE|CAPTURE|capSide=%1|reward=%2|pilotSide=%3|mk=%4", _capSide, _reward, _pSide, _mk];
				if (alive _p) then { _p setDamage 1; };
				_drop = true;
				_reason = "captured";
			};
		};

		if (_drop) then {
			//--- Marker clear (deleteMarker on server propagates to all clients).
			deleteMarker _mk;
			//--- Chute cleanup.
			if (!isNull _pChute) then { deleteVehicle _pChute; };
			//--- Pilot cleanup (pilot is civilian/captive — no player can be in this group).
			if (!isNull _p) then { deleteVehicle _p; };
			//--- Group cleanup: UNCONDITIONAL — uses the stored group ref (index 5) so the
			//--- group is deleteGroup'd even if _p went null externally before this path ran.
			//--- deleteGroup only removes an empty group; unit is already deleted above (or was
			//--- already gone), so the group is empty by the time we reach this line.
			if (!isNull _pGrp) then { deleteGroup _pGrp; };
			diag_log format ["PILOTRACE|DESPAWN|reason=%1|remaining=%2", _reason, count _keptPilots];
		} else {
			_keptPilots = _keptPilots + [_entry];
		};
	} forEach _livePilots;

	//--- Write pruned registry back to namespace.
	missionNamespace setVariable ["WFBE_PilotRace_Live", _keptPilots];
};

//--- Round-end: clean all live pilots + markers so nothing persists into the next match.
{
	private ["_entry","_p","_mk","_pChute","_pGrp"];
	_entry  = _x;
	_p      = _entry select 0;
	_mk     = _entry select 1;
	_pChute = _entry select 4;
	_pGrp   = _entry select 5;
	deleteMarker _mk;
	if (!isNull _pChute) then { deleteVehicle _pChute; };
	if (!isNull _p) then { deleteVehicle _p; };
	//--- Unconditional group cleanup using stored ref — safe even if pilot was already null.
	if (!isNull _pGrp) then { deleteGroup _pGrp; };
} forEach (missionNamespace getVariable ["WFBE_PilotRace_Live", []]);
missionNamespace setVariable ["WFBE_PilotRace_Live", []];
