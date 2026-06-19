/*
	Common_AICOMServiceTick.sqf   (B48, claude-gaming 2026-06-19)

	Per-tick AICOM SELF-SERVICE. A damaged / low-ammo AI-commander team (default: only teams
	with armour/heli, the costly-to-replace ones) detours to the nearest SAFE friendly
	town-centre, REPAIRS + REARMS + HEALS with the same primitives players use, then clears
	its goto so AI_Commander_AssignTowns retargets it back to the front.

	DEFAULT OFF (WFBE_C_AICOM_SERVICE_ENABLED = 0). Ships dark for an A/B soak.

	LOCALITY: HC-local. Called from Common_RunCommanderTeam.sqf's 20s order loop, where the
	team's units are local to this machine, so setDamage / setVehicleAmmo / setFuel / doMove
	all have correct locality.

	GUARDRAILS (hard):
	  - never pulled out of a firefight: skip while leader behaviour == "COMBAT" or any enemy
	    within WFBE_C_AICOM_SVC_SAFE_DIST of the leader.
	  - abort + return to the front if an enemy enters SAFE_DIST while en-route.
	  - the team ALWAYS holds a live MOVE order (en-route) or is retargeted (done/abort) -
	    it is never doStop-frozen. A player must never see a standing-still AI.
	  - hard en-route timeout (never drives to an unreachable point forever).
	  - NO sim-gating / distance-gating; antistack untouched.

	A2-OA SAFETY: group vars use plain getVariable + isNil (A2 groups do NOT support the
	[name,default] form); type tests use classname isKindOf "X" (valid in A2 OA); getPos is
	only called on objects; NO isEqualType / isEqualTo; reveal is not used.

	params: _this = [ _team(group), _side, _sideID, _vehicles(array of the team's vehicles) ]
*/

private ["_team","_side","_sideID","_vehicles","_ldr","_state","_safeDist","_supRange",
         "_enemySide","_enemyNear","_armourOnly","_members","_dmgT","_ammoT","_hasHeavy",
         "_needs","_reach","_best","_bestD","_twn","_d","_svcPos","_deadline"];

_team     = _this select 0;
_side     = _this select 1;
_sideID   = _this select 2;
_vehicles = _this select 3;

if (isNull _team) exitWith {};
_ldr = leader _team;
if (isNull _ldr || {!alive _ldr}) exitWith {};

_safeDist  = missionNamespace getVariable ["WFBE_C_AICOM_SVC_SAFE_DIST", 600];
_supRange  = missionNamespace getVariable ["WFBE_C_UNITS_SUPPORT_RANGE", 70];
_enemySide = if (_side == west) then {east} else {if (_side == east) then {west} else {east}};

//--- A2: plain get + isNil (NO [name,default] on groups)
_state = _team getVariable "wfbe_aicom_svcstate";
if (isNil "_state") then {_state = ""};

//--- live enemy presence near the leader (never-pull-out-of-contact / abort guard)
_enemyNear = {alive _x && {side _x == _enemySide}} count ((getPos _ldr) nearEntities [["Man","LandVehicle","Air"], _safeDist]);

if (_state == "enroute") then {
	//--- ============ EN-ROUTE: driving to the service point ============
	_svcPos   = _team getVariable "wfbe_aicom_svcpos";
	_deadline = _team getVariable "wfbe_aicom_svcdeadline";
	if (isNil "_svcPos" || {isNil "_deadline"}) exitWith {
		_team setVariable ["wfbe_aicom_svcstate", ""];
	};
	if (_enemyNear > 0 || {time > _deadline}) exitWith {
		//--- threatened or timed out -> drop the detour, retarget to the front and fight
		_team setVariable ["wfbe_aicom_svcstate", ""];
		_team setVariable ["wfbe_teamgoto", objNull, true];
		_team setVariable ["wfbe_aicom_townorder", [], false];
		_team setVariable ["wfbe_teammode", "towns", true];
	};
	if ((_ldr distance _svcPos) <= _supRange) then {
		//--- ARRIVED + SAFE: snap repair/rearm/heal (SAFE_DIST guarantees no witnesses).
		//--- HEAL every member (units _team are all men, incl. the vehicle crews who are
		//--- group members), then REPAIR+REARM+REFUEL the team's vehicles.
		{if (alive _x) then {_x setDamage 0}} forEach (units _team);
		{
			if (!isNull _x && {alive _x}) then {
				_x setDamage 0; _x setVehicleAmmo 1;
				if (_x isKindOf "Air") then {_x setFuel 1};
			};
		} forEach _vehicles;
		diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|SERVICE_DONE|" + (str _team));
		//--- clear + retarget to the front (same idiom as the on-capture re-task)
		_team setVariable ["wfbe_aicom_svcstate", ""];
		_team setVariable ["wfbe_teamgoto", objNull, true];
		_team setVariable ["wfbe_aicom_townorder", [], false];
		_team setVariable ["wfbe_teammode", "towns", true];
	};
	//--- else: still driving; the MOVE waypoint laid below carries it (never frozen).
} else {
	//--- ============ IDLE: decide whether to detour ============
	//--- B49 RELAX: use TRIGGER_DIST (smaller than SAFE_DIST) for the START gate so a DISENGAGED team can
	//--- detour to service even with enemies 300-600m off (the old SAFE_DIST gate blocked every grinding
	//--- team so this never fired). COMBAT teams are still never pulled out; the en-route abort below still
	//--- uses the full SAFE_DIST. A2-safe (nearEntities + side/alive checks, same idiom as _enemyNear).
	private "_enemyTrig";
	_enemyTrig = {alive _x && {side _x == _enemySide}} count ((getPos _ldr) nearEntities [["Man","LandVehicle","Air"], (missionNamespace getVariable ["WFBE_C_AICOM_SVC_TRIGGER_DIST", 300])]);
	if (behaviour _ldr == "COMBAT" || {_enemyTrig > 0}) exitWith {}; //--- never leave a fight; no enemy within trigger-dist
	_armourOnly = (missionNamespace getVariable ["WFBE_C_AICOM_SVC_ARMOUR_ONLY", 1]) > 0;
	_members    = (units _team) - [objNull];
	_dmgT       = missionNamespace getVariable ["WFBE_C_AICOM_SVC_DMG_THRESH", 0.5];
	_ammoT      = missionNamespace getVariable ["WFBE_C_AICOM_SVC_AMMO_THRESH", 0.35];

	//--- armour/heli gate (default: only service the costly teams)
	_hasHeavy = {alive _x && {(vehicle _x) != _x} && {((vehicle _x) isKindOf "Tank") || {(vehicle _x) isKindOf "APC"} || {(vehicle _x) isKindOf "Air"}}} count _members;
	if (_armourOnly && {_hasHeavy == 0}) exitWith {};

	//--- needs-service: any wounded member, OR a weaponed combat vehicle low on ammo
	_needs = false;
	{
		if (!_needs && {alive _x} && {getDammage _x > _dmgT}) then {_needs = true};
	} forEach _members;
	if (!_needs) then {
		{
			if (!_needs && {!isNull _x} && {alive _x}
			    && {(_x isKindOf "Tank") || {(_x isKindOf "APC")} || {(_x isKindOf "Air")} || {(_x isKindOf "Car")}}
			    && {count (weapons _x) > 0}) then {
				if ((_x Call WFBE_CO_FNC_GetAmmoFraction) < _ammoT) then {_needs = true};
			};
		} forEach _vehicles;
	};
	if (!_needs) exitWith {};

	//--- nearest SAFE friendly town-centre within reach
	_reach = missionNamespace getVariable ["WFBE_C_AICOM_SVC_REACH", 4000];
	_best = objNull; _bestD = 1e9;
	{
		_twn = _x;
		if ((_twn getVariable ["sideID", -1]) == _sideID) then {
			_d = _ldr distance _twn;
			if (_d < _bestD && {_d <= _reach}) then {
				if (({alive _x && {side _x == _enemySide}} count ((getPos _twn) nearEntities [["Man"], _safeDist])) == 0) then {
					_best = _twn; _bestD = _d;
				};
			};
		};
	} forEach towns;
	if (isNull _best) exitWith {}; //--- nothing safe in reach -> keep fighting

	//--- DETOUR: road-march MOVE + stamp state/pos/deadline (en-route drive cap)
	_svcPos = getPos _best;
	_team setVariable ["wfbe_aicom_svcstate", "enroute"];
	_team setVariable ["wfbe_aicom_svcpos", _svcPos];
	_team setVariable ["wfbe_aicom_svcdeadline", time + (missionNamespace getVariable ["WFBE_C_AICOM_SVC_TIMEOUT", 300])];
	[_team, _svcPos, 'MOVE', 40] Spawn WFBE_CO_FNC_WaypointSimple;
	diag_log ("AICOMSTAT|v1|EVENT|" + (str _side) + "|" + str (round (time / 60)) + "|SERVICE_ENROUTE|" + (_best getVariable ["name", "?"]));
};
