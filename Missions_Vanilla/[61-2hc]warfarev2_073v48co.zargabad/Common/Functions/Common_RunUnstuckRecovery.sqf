/*
	Apply the local AICOM-style recovery ladder to a stalled team.
	Parameters: [team, tier, side, destination, origin].
	The caller must run this where the group is local.  Side patrols use this
	bridge because they own their waypoint loop and never receive wfbe_aicom_order.
*/

Private ["_uTeam","_uTier","_uSide","_uDest","_uOrigin","_uLdr","_uVeh","_uPlayerNear","_uRds","_uNode","_uFoot","_uPGR","_uDir","_uRevSpd","_uPlayerBlocked","_uPlayerBlockedMax","_uForceTeleport","_uTerminal","_uGroupUnits","_uHulls","_uHull"];

_uTeam   = _this select 0;
_uTier   = _this select 1;
_uSide   = _this select 2;
_uDest   = _this select 3;
_uOrigin = if (count _this > 4) then {_this select 4} else {"unknown"};
_uLdr    = leader _uTeam;

if (isNull _uTeam || {isNull _uLdr} || {!alive _uLdr} || {_uTier < 1}) exitWith {};

diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_FIRED|team=" + (str _uTeam) + "|tier=" + str _uTier + "|map=" + worldName + "|dist=" + str (round (_uLdr distance _uDest)) + "|origin=" + _uOrigin);
missionNamespace setVariable ["wfbe_waspscale_recov", (missionNamespace getVariable ["wfbe_waspscale_recov", 0]) + 1];
if (!isServer) then {["RequestSpecial", ["waspscale-counter-delta", "wfbe_waspscale_recov"]] Call WFBE_CO_FNC_SendToServer};
[_uTeam, _uTier, _uSide] Call WFBE_CO_FNC_AICOMRecoveryNotify; //--- Grok idea #28: gated WFBE_C_AICOM_RECOVERY_NOTIFY default 0, inert at default.

{if (alive _x && {vehicle _x == _x} && {!isNull (assignedVehicle _x)} && {alive (assignedVehicle _x)} && {canMove (assignedVehicle _x)}) then {[_x] orderGetIn true}} forEach (units _uTeam);

_uVeh = vehicle _uLdr;
if (_uTier == 1 && {!isNull _uVeh} && {_uVeh != _uLdr} && {alive _uVeh} && {canMove _uVeh}) then {
	_uVeh setVelocity [0,0,0];
	_uDir = vectorDir _uVeh;
	_uRevSpd = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_REVERSE_SPEED", 6];
	_uVeh setVelocity [(- (_uDir select 0)) * _uRevSpd, (- (_uDir select 1)) * _uRevSpd, (velocity _uVeh) select 2];
	sleep 1.5;
	if (!isNull _uVeh && {alive _uVeh}) then {_uVeh setVelocity [(- (_uDir select 0)) * _uRevSpd, (- (_uDir select 1)) * _uRevSpd, (velocity _uVeh) select 2]};
	_uLdr doMove (_uVeh modelToWorld [0,-14,0]);
};

if (_uTier == 2) then {
	//--- Rebuild the local move path once before the last-resort tier-3 relocation.
	[_uTeam, _uDest, "MOVE", 25] Spawn WFBE_CO_FNC_WaypointSimple;
};

if (_uTier >= 3) then {
	_uPGR = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_PLAYER_GUARD_R", 300];
	_uPlayerNear = false;
	{if (isPlayer _x && {(_x distance _uLdr) < _uPGR}) then {_uPlayerNear = true}} forEach playableUnits;
	_uFoot = (vehicle _uLdr) == _uLdr;
	_uPlayerBlocked = _uTeam getVariable "wfbe_aicom_recovery_player_blocked";
	if (isNil "_uPlayerBlocked") then {_uPlayerBlocked = 0};
	_uPlayerBlockedMax = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_PLAYER_BLOCKED_MAX", 3];
	if (_uPlayerBlockedMax < 1) then {_uPlayerBlockedMax = 1};
	if (_uPlayerNear) then {_uPlayerBlocked = _uPlayerBlocked + 1} else {_uPlayerBlocked = 0};
	_uTeam setVariable ["wfbe_aicom_recovery_player_blocked", _uPlayerBlocked];
	_uForceTeleport = (missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_FORCE_PLAYER_TELEPORT", 0]) > 0;
	_uTerminal = false;
	diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_PLAYER_GUARD|team=" + (str _uTeam) + "|tier=" + str _uTier + "|playerNear=" + str _uPlayerNear + "|blocked=" + str _uPlayerBlocked + "|limit=" + str _uPlayerBlockedMax + "|forceTeleport=" + str _uForceTeleport);
	if (_uPlayerNear && {_uPlayerBlocked >= _uPlayerBlockedMax}) then {
		if (_uForceTeleport) then {
			_uPlayerNear = false;
			_uTeam setVariable ["wfbe_aicom_recovery_player_blocked", 0];
			diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_PLAYER_GUARD_OVERRIDDEN|team=" + (str _uTeam) + "|tier=" + str _uTier);
		} else {
			_uTerminal = true;
			diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|PATROL_RECYCLE_PLAYER_BLOCKED|team=" + (str _uTeam) + "|tier=" + str _uTier + "|blocked=" + str _uPlayerBlocked);
			_uGroupUnits = +(units _uTeam);
			_uHulls = [];
			{
				if (!isNull _x) then {
					_uHull = vehicle _x;
					if (_uHull != _x && {!(_uHull in _uHulls)}) then {_uHulls set [count _uHulls, _uHull]};
				};
			} forEach _uGroupUnits;
			{if (!isNull _x && {alive _x} && {!isPlayer _x}) then {deleteVehicle _x}} forEach _uGroupUnits;
			{
				_uHull = _x;
				if (!isNull _uHull && {alive _uHull} && {({isPlayer _x} count (crew _uHull)) == 0}) then {deleteVehicle _uHull};
			} forEach _uHulls;
		};
	};
	if (!_uTerminal) then {
		if (!_uPlayerNear) then {
			if (!_uFoot && {!isNull _uVeh} && {alive _uVeh}) then {
				_uRds = (getPos _uVeh) nearRoads 150;
				if (count _uRds > 0) then {
					_uNode = [getPos _uVeh, _uRds] Call WFBE_CO_FNC_GetClosestEntity;
					if (!isNull _uNode && {!surfaceIsWater (getPos _uNode)}) then {
						_uVeh setVelocity [0,0,0];
						_uVeh setPos (getPos _uNode);
					};
				} else {
					//--- fix(alife-stall r34): NOROAD_STEP parity with RunCommanderTeam (side-patrol bridge used empty nearRoads as silent no-op).
					if ((missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP", 1]) > 0) then {
						private ["_nvDest","_nvBrg","_nvStep","_nvGuess","_nvFlat","_nvVp"];
						_nvDest = _uDest;
						if (typeName _nvDest == "OBJECT" && {!isNull _nvDest}) then {_nvDest = getPos _nvDest};
						if (typeName _nvDest == "ARRAY" && {count _nvDest >= 2}) then {
							_nvVp = getPosATL _uVeh;
							_nvBrg = ((_nvDest select 0) - (_nvVp select 0)) atan2 ((_nvDest select 1) - (_nvVp select 1));
							_nvStep = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST", 90];
							if (_nvStep > ((_uVeh distance _nvDest) - 15)) then {_nvStep = ((_uVeh distance _nvDest) - 15) max 0};
							if (_nvStep > 5) then {
								_nvGuess = [(_nvVp select 0) + _nvStep * (sin _nvBrg), (_nvVp select 1) + _nvStep * (cos _nvBrg), 0];
								_nvFlat = _nvGuess isFlatEmpty [12, 0, 2, 14, 0, false, objNull];
								if (count _nvFlat > 0 && {!surfaceIsWater _nvFlat}) then {
									_uVeh setVelocity [0,0,0];
									_uVeh setPos _nvFlat;
									diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_NOROAD|team=" + (str _uTeam) + "|tier=" + str _uTier + "|step=" + str (round _nvStep) + "|veh=1|origin=" + _uOrigin);
								};
							};
						};
					};
				};
			} else {
				_uRds = (getPos _uLdr) nearRoads (missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_FOOT_ROAD_R", 200]);
				if (count _uRds > 0) then {
					_uNode = [getPos _uLdr, _uRds] Call WFBE_CO_FNC_GetClosestEntity;
					if (!isNull _uNode && {!surfaceIsWater (getPos _uNode)}) then {
						_uLdr setVelocity [0,0,0];
						_uLdr setPos (getPos _uNode);
						{if (alive _x && {_x != _uLdr} && {vehicle _x == _x}) then {_x doFollow _uLdr}} forEach (units _uTeam);
					};
				} else {
					//--- fix(alife-stall r34): foot NOROAD_STEP when no road in ring.
					if ((missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP", 1]) > 0) then {
						private ["_nrDest","_nrBrg","_nrStep","_nrGuess","_nrFlat","_nrLp"];
						_nrDest = _uDest;
						if (typeName _nrDest == "OBJECT" && {!isNull _nrDest}) then {_nrDest = getPos _nrDest};
						if (typeName _nrDest == "ARRAY" && {count _nrDest >= 2}) then {
							_nrLp = getPosATL _uLdr;
							_nrBrg = ((_nrDest select 0) - (_nrLp select 0)) atan2 ((_nrDest select 1) - (_nrLp select 1));
							_nrStep = missionNamespace getVariable ["WFBE_C_AICOM_RECOVERY_NOROAD_STEP_DIST", 90];
							if (_nrStep > ((_uLdr distance _nrDest) - 10)) then {_nrStep = ((_uLdr distance _nrDest) - 10) max 0};
							if (_nrStep > 5) then {
								_nrGuess = [(_nrLp select 0) + _nrStep * (sin _nrBrg), (_nrLp select 1) + _nrStep * (cos _nrBrg), 0];
								_nrFlat = _nrGuess isFlatEmpty [8, 0, 3, 10, 0, false, objNull];
								if (count _nrFlat > 0 && {!surfaceIsWater _nrFlat}) then {
									_uLdr setVelocity [0,0,0];
									_uLdr setPos _nrFlat;
									{if (alive _x && {_x != _uLdr} && {vehicle _x == _x}) then {_x doFollow _uLdr}} forEach (units _uTeam);
									diag_log ("AICOMSTAT|v2|EVENT|" + (str _uSide) + "|" + str (round (time / 60)) + "|UNSTUCK_NOROAD|team=" + (str _uTeam) + "|tier=" + str _uTier + "|step=" + str (round _nrStep) + "|veh=0|origin=" + _uOrigin);
								};
							};
						};
					};
				};
			};
		} else {
			if (!_uFoot && {!isNull _uVeh} && {alive _uVeh}) then {
				_uVeh setVelocity [(velocity _uVeh) select 0, (velocity _uVeh) select 1, 4];
			};
			_uLdr doMove _uDest;
		};
		[_uTeam, _uDest, "MOVE", 25] Spawn WFBE_CO_FNC_WaypointSimple;
	};
};
