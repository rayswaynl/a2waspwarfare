/*
	Server_PilotRace.sqf — PILOT-RACE loop (SERVER-only). Lane B3 (Ray 2026-07-02).

	Every AI aircraft killed with a live crew (isKindOf "Air", !isPlayer driver, side not civilian)
	ejects a capturable downed pilot + a fuzzy global map ping.  First side to reach the pilot
	within 20 m scores WFBE_C_PILOT_CAPTURE_REWARD funds.  The pilot auto-dies + marker clears
	after WFBE_C_PILOT_TTL seconds.  Global alive cap: WFBE_C_PILOT_MAX_LIVE.

	A2-OA-1.64 rules applied throughout:
	  - No A3 cmds (no isEqualType/findIf/selectRandom/pushBack/apply/params/select-substring/string find).
	  - No Boolean == / != comparisons.
	  - getVariable 2-arg form used only on objects (safe on objects in A2 OA 1.64).
	  - createMarker on server replicates to all clients incl. JIP; deleteMarker clears for all.
	  - setCaptive/allowDamage/setDamage run where the object is local (server-created units are local).
	  - ParachuteC classname confirmed via WFBE_GUERPARACHUTE in Root_GUE.sqf:34.
	  - Reward via [side, amount, reason, false] call ChangeSideSupply (server-side pattern used throughout).
*/
if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_PILOT_RACE", 0]) < 1) exitWith {};

private ["_reward","_ttl","_maxLive","_livePilots","_mkPrefix","_spawnPilot"];

_reward   = missionNamespace getVariable ["WFBE_C_PILOT_CAPTURE_REWARD", 500];
_ttl      = missionNamespace getVariable ["WFBE_C_PILOT_TTL",            300];
_maxLive  = missionNamespace getVariable ["WFBE_C_PILOT_MAX_LIVE",       2];
_mkPrefix = "wfbe_pilotrace_mk_";

//--- Live registry: each entry [_pilot, _markerName, _spawnTime, _pilotSide, _chute].
//--- Script-local (NOT persistent) so it cannot outlive the round or leak.
_livePilots = [];

["INITIALIZATION", Format ["Server_PilotRace.sqf: PILOT-RACE started (reward=%1 ttl=%2 max=%3).", _reward, _ttl, _maxLive]] Call WFBE_CO_FNC_LogContent;

//--- HELPER: spawn a downed pilot + fuzzy marker, register in _livePilots.
//--- _this = [_aircraft, _acSide].  Aircraft is local to server (killed EH fires where object is local).
//--- Returns nothing; silently exits if cap reached.
_spawnPilot = {
	private ["_ac","_acSide","_pos","_fuzz","_mk","_pilotClass","_chuteModel","_grp","_pilot","_chute","_uid"];

	if ((count _livePilots) >= _maxLive) exitWith {};

	_ac     = _this select 0;
	_acSide = _this select 1;

	_pos = getPos _ac;

	//--- Pilot classname: reuse GUER pilot (confirmed GUE_Soldier_Pilot in Config_GUE.sqf:88).
	//--- Group: civilian so the pilot does not fight back but is not auto-hostile to either side.
	_pilotClass  = missionNamespace getVariable ["WFBE_GUERRESPILOT", "GUE_Soldier_Pilot"];
	_chuteModel  = missionNamespace getVariable ["WFBE_GUERPARACHUTE", "ParachuteC"];

	_grp = createGroup civilian;
	if (isNull _grp) exitWith {};

	//--- Spawn pilot at crash altitude so he visibly descends under a chute.
	_pilot = _grp createUnit [_pilotClass, [(_pos select 0), (_pos select 1), ((_pos select 2) max 80)], [], 0, "NONE"];
	if (isNull _pilot) exitWith { deleteGroup _grp; };

	//--- Captive + injured, AI disabled so he does not fight or move.
	_pilot setCaptive true;
	_pilot setDamage 0.7;
	{_pilot disableAI _x} forEach ["AUTOTARGET","TARGET","AUTOCOMBAT","FSM","MOVE","ANIM"];
	_pilot setVariable ["wfbe_pilot_race", true, true];

	//--- Parachute descent: chute at altitude, pilot moves into driver seat.
	_chute = _chuteModel createVehicle [(_pos select 0) + (20 - random 40), (_pos select 1) + (20 - random 40), ((_pos select 2) max 80)];
	_pilot moveInDriver _chute;

	//--- Fuzzy marker: offset up to 400 m from real position to force a foot search.
	_uid = Format ["%1_%2", round time, count _livePilots];
	_mk  = _mkPrefix + _uid;
	_fuzz = [(_pos select 0) + (200 - random 400), (_pos select 1) + (200 - random 400), 0];
	createMarker [_mk, _fuzz];
	_mk setMarkerType "mil_dot";
	_mk setMarkerColor "ColorYellow";
	_mk setMarkerText "DOWNED PILOT";

	_livePilots = _livePilots + [[_pilot, _mk, time, _acSide, _chute]];

	diag_log format ["PILOTRACE|SPAWN|side=%1|pos=%2|fuzzy=%3|mk=%4|alive=%5", _acSide, _pos, _fuzz, _mk, count _livePilots];
};

//--- Bridge function stored in missionNamespace so the killed EH string can reach it.
//--- EH bodies cannot close over script-local vars directly in A2 OA; the Spawn call places
//--- the body in the server's scheduler where _livePilots, _maxLive, _spawnPilot are in scope.
//--- Pattern confirmed: {_this Spawn WFBE_SE_FNC_OnHQKilled} used throughout Init_Server.sqf.
WFBE_SE_FNC_PilotRaceEject = {
	private ["_dead","_vs"];
	_dead = _this select 0;
	_vs   = _this select 1;
	if ((count _livePilots) < _maxLive) then {
		[_dead, _vs] call _spawnPilot;
	};
};

//--- MAIN LOOP: runs every 5 s, two duties:
//--- (A) Attach the killed EH to any new untagged AI Air vehicle.
//--- (B) Maintain the live registry: capture check + TTL.
while {!WFBE_GameOver} do {
	sleep 5;

	private ["_now","_keptPilots"];
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
			if (!(_vSide == civilian)) then {
				_v setVariable ["wfbe_pr_eh", true];
				_v addEventHandler ["Killed", {
					private ["_dead","_drv","_vs2"];
					_dead = _this select 0;
					if (!(_dead isKindOf "Air")) exitWith {};
					_drv = driver _dead;
					if (isNull _drv) exitWith {};
					if (isPlayer _drv) exitWith {};
					_vs2 = side _dead;
					if (_vs2 == civilian) exitWith {};
					[_dead, _vs2] spawn WFBE_SE_FNC_PilotRaceEject;
				}];
			};
		};
	} forEach vehicles;

	//--- (B) LIVE REGISTRY: capture check + TTL cleanup.
	_keptPilots = [];
	{
		private ["_entry","_p","_mk","_spawnT","_pSide","_pChute","_drop","_reason","_near","_capSide"];
		_entry  = _x;
		_p      = _entry select 0;
		_mk     = _entry select 1;
		_spawnT = _entry select 2;
		_pSide  = _entry select 3;
		_pChute = _entry select 4;

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
				if (alive _x && {!(side _x == civilian)} && {!(side _x == _pSide)}) then {
					_capSide = side _x;
				};
			} forEach _near;
			if (!(_capSide == civilian)) then {
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
			//--- Pilot + group cleanup (pilot is civilian/captive — no player can be in this group).
			if (!isNull _p) then {
				private ["_g"];
				_g = group _p;
				deleteVehicle _p;
				if (!isNull _g) then { deleteGroup _g; };
			};
			diag_log format ["PILOTRACE|DESPAWN|reason=%1|remaining=%2", _reason, count _keptPilots];
		} else {
			_keptPilots = _keptPilots + [_entry];
		};
	} forEach _livePilots;
	_livePilots = _keptPilots;
};

//--- Round-end: clean all live pilots + markers so nothing persists into the next match.
{
	private ["_entry","_p","_mk","_pChute","_g"];
	_entry  = _x;
	_p      = _entry select 0;
	_mk     = _entry select 1;
	_pChute = _entry select 4;
	deleteMarker _mk;
	if (!isNull _pChute) then { deleteVehicle _pChute; };
	if (!isNull _p) then {
		_g = group _p;
		deleteVehicle _p;
		if (!isNull _g) then { deleteGroup _g; };
	};
} forEach _livePilots;
_livePilots = [];
