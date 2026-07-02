//--- Support_ScudStrike.sqf — SCUD Saturation Strike (carrier payoff). [feat/naval-hvt-objectives]
//--- cmdcon41-w2 (Ray 2026-07-02): stale "oil platform" wording corrected to "carrier" throughout — the
//--- naval HVTs are LHD carriers (Khe Sanh Alpha/Bravo/Charlie), never oil platforms. Behaviour unchanged.
//--- One Chukar_EP1 launches from the owning carrier and flies BALLISTIC toward the target
//--- (self-propelled via setVelocity/flyInHeight — NO AI pilot; the Chukar is a missile, mirroring
//--- the live ICBM module, not a piloted aircraft like the drone strike). On arrival the SCUD MIRVs
//--- a saturation barrage over the target zone, then is deleted. NO enemy warning is broadcast.
//--- Payload: ["ScudStrike", _side, _destination, _playerTeam]
//--- Server-authoritative: validates owned carrier + per-carrier cooldown + funds before firing.
//---
//--- Warheads (Sh_125_HE + Bo_GBU12_LGB are EXACTLY what the live drone-saturation-strike uses -> proven):
//---   HE x3      Sh_125_HE        scattered area bursts (anti-infantry / soft)
//---   SADARM x2  Bo_GBU12_LGB     top-attack drop on detected enemy armour
//---   WP x3      SmokeShellWhite  incendiary / obscuring burn layer

if (!isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_NAVAL_HVT", 1]) != 1) exitWith {
	["INFORMATION","Support_ScudStrike.sqf : feature disabled (WFBE_C_NAVAL_HVT=0), ignoring."] Call WFBE_CO_FNC_LogContent;
};

private ["_side","_destination","_playerTeam","_sideID","_enemySides","_hvtList","_platform",
         "_cooldownKey","_lastFired","_now","_funds","_launchPos","_dx","_dy","_len","_dist",
         "_chukar","_travelTime","_zoneR","_warHE","_warSADARM","_warWP","_caller","_x"];

_side        = _this select 1;
_destination = _this select 2;
_playerTeam  = _this select 3;
_sideID      = _side call GetSideID;
_now         = time;
_zoneR       = WFBE_C_SCUD_ZONE_RADIUS;
_warHE       = WFBE_C_SCUD_WARHEAD_HE;
_warSADARM   = WFBE_C_SCUD_WARHEAD_SADARM;
_warWP       = WFBE_C_SCUD_WARHEAD_WP;

["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] team [%2] SCUD request at %3.", str _side, _playerTeam, _destination]] Call WFBE_CO_FNC_LogContent;

//--- VALIDATION 1: the caller's side must OWN a carrier HVT.
_hvtList = missionNamespace getVariable ["WFBE_NAVAL_HVT_PLATFORMS", []];
_platform = objNull;
{
	if (!isNull _x && {(_x getVariable ["sideID", -1]) == _sideID} && {_x getVariable ["wfbe_is_naval_hvt", false]}) then {_platform = _x};
} forEach _hvtList;
if (isNull _platform) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- no owned carrier.", str _side]] Call WFBE_CO_FNC_LogContent;
};

//--- VALIDATION 2: per-platform cooldown.
_cooldownKey = Format ["WFBE_SCUD_LAST_%1", str _platform];
_lastFired = missionNamespace getVariable [_cooldownKey, -99999];
if ((_now - _lastFired) < WFBE_C_SCUD_COOLDOWN) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- cooldown (%2s left).", str _side, round (WFBE_C_SCUD_COOLDOWN - (_now - _lastFired))]] Call WFBE_CO_FNC_LogContent;
};

//--- VALIDATION 3: server-authoritative funds (deduct on the calling team's group).
if (isNull _playerTeam) exitWith {["WARNING","Support_ScudStrike.sqf : denied -- null calling team."] Call WFBE_CO_FNC_LogContent};
_funds = _playerTeam getVariable ["wfbe_funds", 0];
if (_funds < WFBE_C_SCUD_COST) exitWith {
	["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] denied -- insufficient funds (%2 < %3).", str _side, _funds, WFBE_C_SCUD_COST]] Call WFBE_CO_FNC_LogContent;
};

//--- All checks pass: deduct funds + stamp cooldown BEFORE firing (anti double-fire race).
_playerTeam setVariable ["wfbe_funds", (_funds - WFBE_C_SCUD_COST), true];
missionNamespace setVariable [_cooldownKey, _now];

["INFORMATION", Format ["Support_ScudStrike.sqf : [%1] AUTHORISED -- launching from %2 at target %3.", str _side, getPos _platform, _destination]] Call WFBE_CO_FNC_LogContent;

//--- ============================================================================================
//--- cmdcon41 THEATRICAL CARRIER LAUNCH (feature 1, Ray 2026-07-02). Flag WFBE_C_SCUD_THEATRICS (default 1).
//--- Before the Chukar spawns, play a launch sequence on the firing carrier's DECK SCUD launcher:
//---   (a) ERECT via the VERIFIED in-tree action "scudLaunch" (Init_NavalHVT.sqf:348 uses this exact action to
//---       raise the deck SCUD at spawn -> proven present on MAZ_543_SCUD_TK_EP1). The deck launcher is spawned
//---       ALREADY erect + attachTo-pinned static, so we re-issue scudLaunch (harmless, keeps it vertical) rather
//---       than a config animate with an unverified anim name. NO A3 anim source was verifiable, so per the brief
//---       we do NOT call animate with a guessed name (would silently no-op / error); scudLaunch is the safe path.
//---   (b) FX: a SmokeShellWhite backblast cluster at the launcher (SmokeShellWhite is confirmed in-tree -- it is
//---       WFBE_C_SCUD_WARHEAD_WP). NO deck light: "Land_Fire" is NOT present anywhere in this mission tree (grep
//---       verified), so per the brief we SKIP the light and do smoke only. No invented ammo classnames.
//---   (c) KLAXON: the base-under-attack alarm alias "inbound" (registered CfgSound; Common_HandleAlarm.sqf:11,
//---       CampCaptured.sqf:50) to OWNING-SIDE clients only, via a side-scoped SendToClients HandleSpecial case.
//---   (d) DE-ERECT: there is NO verified reverse action for the A2 Scud (scudLaunch is the only proven one), and
//---       the launcher is a permanent static deck prop that is erect at round start anyway, so we log + skip the
//---       reverse rather than call an unverified "scudDown". The tube simply stays up (as it already was).
//--- Independently flag-gated; everything is server-side createVehicle + one side-scoped klaxon. No perf loop.
if ((missionNamespace getVariable ["WFBE_C_SCUD_THEATRICS", 1]) == 1) then {
	private ["_scudVeh"];
	_scudVeh = _platform getVariable ["wfbe_hvt_scud", objNull];
	if (isNull _scudVeh) then {
		["INFORMATION", "Support_ScudStrike.sqf : SCUD_THEATRICS deck launcher ref missing (wfbe_hvt_scud null) -- skipping theatrics, strike continues."] Call WFBE_CO_FNC_LogContent;
	} else {
		//--- (a) ERECT (proven action). The launcher is static/erect already; re-issue is a safe no-op-if-up.
		_scudVeh action ["scudLaunch", _scudVeh];
		["INFORMATION", "Support_ScudStrike.sqf : SCUD_THEATRICS erect via action scudLaunch (deck launcher already vertical)."] Call WFBE_CO_FNC_LogContent;
		//--- (b) BACKBLAST smoke cluster at the launcher base (createVehicle GLOBAL so all clients see it). 4 puffs.
		private ["_sp","_i","_ang","_r"];
		_sp = getPosASL _scudVeh;
		for "_i" from 0 to 3 do {
			_ang = random 360; _r = random 4;
			(createVehicle ["SmokeShellWhite", [(_sp select 0) + _r * sin _ang, (_sp select 1) + _r * cos _ang, (_sp select 2)], [], 0, "NONE"]);
		};
		//--- (d) DE-ERECT: no verified reverse action for the A2 Scud -> log + skip (tube stays up, as at round start).
		["INFORMATION", "Support_ScudStrike.sqf : SCUD_THEATRICS de-erect skipped (no verified reverse action for MAZ_543_SCUD_TK_EP1 scud launcher)."] Call WFBE_CO_FNC_LogContent;
	};
	//--- (c) KLAXON to the OWNING side only (side-scoped SendToClients; the client HandleSpecial case plays "inbound").
	[_side, "HandleSpecial", ["scud-klaxon"]] Call WFBE_CO_FNC_SendToClients;
};

//--- LAUNCH: one Chukar from the carrier, flown ballistic toward the target (pure vector, no pilot).
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
_caller = leader _playerTeam;

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
