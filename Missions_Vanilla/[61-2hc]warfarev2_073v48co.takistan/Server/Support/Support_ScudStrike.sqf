//--- Support_ScudStrike.sqf — SCUD Saturation Strike (oil-platform payoff). [feat/naval-hvt-objectives]
//--- One Chukar_EP1 launches from the owning oil platform and flies BALLISTIC toward the target
//--- (self-propelled via setVelocity/flyInHeight — NO AI pilot; the Chukar is a missile, mirroring
//--- the live ICBM module, not a piloted aircraft like the drone strike). On arrival the SCUD MIRVs
//--- a saturation barrage over the target zone, then is deleted. NO enemy warning is broadcast.
//--- Payload: ["ScudStrike", _side, _destination, _playerTeam, _requester]
//--- Server-authoritative: validates requester/team/action grant + owned oil platform + per-platform cooldown + funds before firing.
//---
//--- Warheads (Sh_125_HE + Bo_GBU12_LGB are EXACTLY what the live drone-saturation-strike uses -> proven):
//---   HE x3      Sh_125_HE        scattered area bursts (anti-infantry / soft)
//---   SADARM x2  Bo_GBU12_LGB     top-attack drop on detected enemy armour
//---   WP x3      SmokeShellWhite  incendiary / obscuring burn layer

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) != 1) exitWith {
	["INFORMATION","Support_ScudStrike.sqf : feature disabled (WFBE_C_NAVAL_HVT=0), ignoring."] Call WFBE_CO_FNC_LogContent;
};

private ["_side","_destination","_playerTeam","_requester","_sideID","_enemySides","_hvtList","_platform","_pad",
         "_cooldownKey","_lastFired","_now","_funds","_launchPos","_dx","_dy","_len","_dist",
         "_chukar","_travelTime","_zoneR","_warHE","_warSADARM","_warWP","_caller","_x"];

if (typeName _this != "ARRAY" || {count _this < 5}) exitWith {
	["WARNING", Format ["Support_ScudStrike.sqf : rejected malformed payload [%1].", _this]] Call WFBE_CO_FNC_LogContent;
};
_side        = _this select 1;
_destination = _this select 2;
_playerTeam  = _this select 3;
_requester   = _this select 4;

if (!(_side in [west, east])) exitWith {
	["WARNING", Format ["Support_ScudStrike.sqf : rejected invalid side [%1].", _side]] Call WFBE_CO_FNC_LogContent;
};
if ((typeName _destination != "ARRAY") || {typeName _playerTeam != "GROUP"} || {typeName _requester != "OBJECT"}) exitWith {
	["WARNING", Format ["Support_ScudStrike.sqf : rejected malformed fields side=%1 destination=%2 team=%3 requester=%4.", _side, typeName _destination, typeName _playerTeam, typeName _requester]] Call WFBE_CO_FNC_LogContent;
};
if ((count _destination < 2) || {typeName (_destination select 0) != "SCALAR"} || {typeName (_destination select 1) != "SCALAR"}) exitWith {
	["WARNING", Format ["Support_ScudStrike.sqf : rejected malformed destination [%1].", _destination]] Call WFBE_CO_FNC_LogContent;
};
if (isNull _playerTeam || {isNull _requester} || {!alive _requester} || {!isPlayer _requester} || {group _requester != _playerTeam} || {side _playerTeam != _side} || {leader _playerTeam != _requester}) exitWith {
	["WARNING", Format ["Support_ScudStrike.sqf : rejected requester/team mismatch requester=%1 team=%2 side=%3.", _requester, _playerTeam, _side]] Call WFBE_CO_FNC_LogContent;
};
if !(_requester getVariable ["wfbe_scud_action_armed", false]) exitWith {
	["WARNING", Format ["Support_ScudStrike.sqf : rejected requester without server-granted action requester=%1 team=%2 side=%3.", _requester, _playerTeam, _side]] Call WFBE_CO_FNC_LogContent;
};

_sideID      = _side call GetSideID;
_now         = time;
_zoneR       = WFBE_C_SCUD_ZONE_RADIUS;
_warHE       = WFBE_C_SCUD_WARHEAD_HE;
_warSADARM   = WFBE_C_SCUD_WARHEAD_SADARM;
_warWP       = WFBE_C_SCUD_WARHEAD_WP;

["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] team [%2] SCUD request at %3.", str _side, _playerTeam, _destination]] Call WFBE_CO_FNC_LogContent;

//--- VALIDATION 1: the caller's side must OWN an oil-platform HVT.
_hvtList = missionNamespace getVariable ["WFBE_NAVAL_HVT_PLATFORMS", []];
_platform = objNull;
{
	if (!isNull _x && {(_x getVariable ["sideID", -1]) == _sideID} && {_x getVariable ["wfbe_is_naval_hvt", false]}) then {_platform = _x};
} forEach _hvtList;
if (isNull _platform) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- no owned oil platform.", str _side]] Call WFBE_CO_FNC_LogContent;
};
_pad = _platform getVariable ["wfbe_scud_pad_ref", objNull];
if (isNull _pad || {(_requester distance _pad) > 75}) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- requester not near SCUD pad.", str _side]] Call WFBE_CO_FNC_LogContent;
};

//--- VALIDATION 2: per-platform cooldown.
_cooldownKey = Format ["WFBE_SCUD_LAST_%1", str _platform];
_lastFired = missionNamespace getVariable [_cooldownKey, -99999];
if ((_now - _lastFired) < WFBE_C_SCUD_COOLDOWN) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- cooldown (%2s left).", str _side, round (WFBE_C_SCUD_COOLDOWN - (_now - _lastFired))]] Call WFBE_CO_FNC_LogContent;
};

//--- VALIDATION 3: server-authoritative funds (deduct on the calling team's group).
if (isNull _playerTeam) exitWith {["WARNING","Support_ScudStrike.sqf : denied -- null calling team."] Call WFBE_CO_FNC_LogContent};
_funds = _playerTeam Call WFBE_CO_FNC_GetTeamFunds;
if (_funds < WFBE_C_SCUD_COST) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- insufficient funds (%2 < %3).", str _side, _funds, WFBE_C_SCUD_COST]] Call WFBE_CO_FNC_LogContent;
};

//--- All checks pass: deduct funds + stamp cooldown BEFORE firing (anti double-fire race).
[_playerTeam, -WFBE_C_SCUD_COST] Call WFBE_CO_FNC_ChangeTeamFunds;
missionNamespace setVariable [_cooldownKey, _now];

["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] AUTHORISED -- launching from %2 at target %3.", str _side, getPos _platform, _destination]] Call WFBE_CO_FNC_LogContent;

//--- LAUNCH: one Chukar from the platform, flown ballistic toward the target (pure vector, no pilot).
_enemySides = (WFBE_PRESENTSIDES - [_side]) + [resistance];
_launchPos = [getPos _platform select 0, getPos _platform select 1, 350];
_dx = (_destination select 0) - (_launchPos select 0);
_dy = (_destination select 1) - (_launchPos select 1);
_len = sqrt ((_dx * _dx) + (_dy * _dy));
if (_len < 1) then {_len = 1};
_dist = _len;

_chukar = createVehicle ["Chukar_EP1", _launchPos, [], 0, "FLY"];
_chukar setPosASL [_launchPos select 0, _launchPos select 1, 350];
_chukar setVectorDir [_dx / _len, _dy / _len, 0];
_chukar setVelocity [(_dx / _len) * 140, (_dy / _len) * 140, 0];
_chukar flyInHeight 350;
_chukar setSpeedMode "FULL";
_chukar setVariable ["wfbe_naval_cap", true, true];	//--- exempt from group/vehicle GC

_travelTime = ((_dist / 140) min 30) max 4;
_caller = _requester;

//--- SATURATION: after flight, MIRV the warhead mix over the target zone, then clean up the missile.
[_chukar, _destination, _zoneR, _warHE, _warSADARM, _warWP, _enemySides, _caller, _travelTime] spawn {
	private ["_ch","_dest","_zoneR","_warHE","_warSADARM","_warWP","_enemySides","_caller","_travelTime",
	         "_armour","_i","_ang","_r","_veh","_x"];
	_ch         = _this select 0;
	_dest       = _this select 1;
	_zoneR      = _this select 2;
	_warHE      = _this select 3;
	_warSADARM  = _this select 4;
	_warWP      = _this select 5;
	_enemySides = _this select 6;
	_caller     = _this select 7;
	_travelTime = _this select 8;

	sleep _travelTime;

	//--- Acquire enemy armour/static in the zone for the SADARM top-attack rounds.
	_armour = [];
	{
		if (alive _x && {(side _x) in _enemySides} && {!(_x isKindOf "Air")} && {(_x isKindOf "LandVehicle") || (_x isKindOf "StaticWeapon")}) then {
			_armour set [count _armour, _x];
		};
	} forEach (nearestObjects [_dest, ["LandVehicle","StaticWeapon"], _zoneR]);

	//--- SADARM x2: top-attack drop from altitude on the two best targets (scatter if none).
	for "_i" from 0 to 1 do {
		if (_i < count _armour) then {
			_veh = _armour select _i;
			if (!isNull _caller) then { _veh setVariable ["wfbe_lasthitby", _caller, true]; _veh setVariable ["wfbe_lasthittime", time, true]; };
			_warSADARM createVehicle [getPos _veh select 0, getPos _veh select 1, 120];
		} else {
			_ang = random 360; _r = random (_zoneR * 0.6);
			_warSADARM createVehicle [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 120];
		};
		sleep 0.4;
	};

	//--- HE x3: scattered area bursts across the zone.
	for "_i" from 0 to 2 do {
		_ang = random 360; _r = random _zoneR;
		_warHE createVehicle [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 0];
		sleep 0.3;
	};

	//--- WP x3: incendiary / obscuring burn layer.
	for "_i" from 0 to 2 do {
		_ang = random 360; _r = random (_zoneR * 0.7);
		_warWP createVehicle [(_dest select 0) + _r * sin _ang, (_dest select 1) + _r * cos _ang, 0];
		sleep 0.2;
	};

	["INFORMATION", Format ["Support_ScudStrike.sqf : saturation delivered at %1 (%2 armour targets).", _dest, count _armour]] Call WFBE_CO_FNC_LogContent;

	if (!isNull _ch) then { {deleteVehicle _x} forEach (crew _ch); deleteVehicle _ch; };
};
