/*
	Server_BombProbe.sqf -- STAGE A VERIFICATION HARNESS (TEST HARNESS - never arm on the live box).

	Answers the two open questions recorded in docs\plans\2026-07-24-ai-air-easa-loadouts.md (Stage A,
	never built) and the 2026-07-28 follow-up on the same audit:

	  (1) Does an OA 1.64 AI pilot/gunner actually RELEASE an unguided bomb (FAB/Mk82/GBU) at a
	      revealed ground target once the EASA-AI kit table has applied a bomb-bearing loadout, with
	      NO scripted forcing of the fire order (reveal + doTarget + doFire only, exactly the AICOM
	      idiom in Common_RunCommanderTeam.sqf's own heli-cannon-nudge block) ?
	  (2) The EASA-AI kit table in Common_RunCommanderTeam.sqf (~L478-524) marks Mi24_P and Su34 as
	      HULL rows (kTur=false -> plain addWeapon/removeWeapon/weapons/magazines), but a manned
	      gunner position's armament commonly lives under a CfgVehicles>>Turrets>>MainTurret config
	      subclass, addressed at runtime only via weaponsTurret/magazinesTurret[path] -- NOT the plain
	      hull commands. If that is true for these two airframes, the existing kit-apply loop is
	      silently missing the turret slot. This probe logs BOTH the hull view and every real config
	      turret path (via WFBE_CO_FNC_GetVehicleTurretsGear, which walks the CfgVehicles>>Turrets
	      tree) side by side, before and after the kit is applied, so the mismatch (if any) is
	      directly visible in the RPT diff instead of inferred.

	Flag: WFBE_C_BOMB_PROBE (Common\Init\Init_CommonConstants.sqf TEST HARNESS block, default 0).
	Flag-off is byte-identical: this file exitWith{}s at the top before touching anything else.
	Origin override: WFBE_C_BOMB_PROBE_ORIGIN (same block, default a documented map-corner guess --
	VERIFY it is clear terrain/water on your test box before arming; override the constant if not).

	Design (throwaway dedicated-test-box run only; see docs\plans\2026-07-28-bomb-stage-a-runbook.md):
	  a. Spawn 5 AI-crewed hulls (Mi24_P, Su34, A10, AV8B2, Su25_TK_EP1) EAST-crewed (crew nationality
	     is cosmetic here -- only SIDE matters for hostility, and every hull needs to be hostile to the
	     SAME single ground cluster) at a fixed, documented offshore/corner position.
	  b. Log BOMBPROBE|v1|baseline| gear: hull (weapons/magazines) + turret:[-1] (the pseudo
	     driver-turret this codebase already uses for e.g. the Ka-137/AW159 manned turret rows) +
	     every REAL config turret path found by WFBE_CO_FNC_GetVehicleTurretsGear, each logged with
	     BOTH the live weaponsTurret/magazinesTurret read and the static CfgVehicles>>Turrets
	     weapons[]/magazines[] reference array side by side.
	     weaponsTurret/magazinesTurret are VERIFIED present on A2 OA 1.64 (introduced OA 1.52, i.e.
	     <=1.64 -- see PR body for the verification trail); this is not the "if not available" config
	     fallback branch, both are read every time for cross-validation.
	  c. Apply the EASA-AI kit table VERBATIM-copied from Common_RunCommanderTeam.sqf:498-545,
	     INCLUDING the WFBE_C_AICOM_AIR_BOMBS-gated bomb-preserve/-grant mutation, read from the SAME
	     live flag -- never refactored, so a future edit to the original table is a trivial diff
	     against this copy. Then log BOMBPROBE|v1|post-kit| the same way as (b). This directly answers
	     "did the kit land on the turret?".
	  d. Spawn a small WEST ground cluster (infantry + one empty truck) 800m away, reveal it to each
	     hull's group, then repeatedly (every 20s for 5 minutes) issue ONLY reveal (already done once)
	     + doTarget + doFire from whichever seat controls the weapon (gunner if present, else the
	     pilot/driver) -- deliberately no selectWeapon call, so weapon/ammo choice is entirely the
	     AI's own decision. A "Fired" EH on each hull logs BOMBPROBE|v1|fired| for every shot and
	     classifies it against the bomb-role launcher names the kit table itself can add
	     (AirBombLauncher/BombLauncherF35/HeliBombLauncher/Mk82BombLauncher_6).
	  e. Log one BOMBPROBE|v1|verdict| per airframe (totalFired, bombFired), then deleteVehicle
	     everything this probe created (hulls, crew, ground cluster, both groups).

	A2-OA-safe: no isEqualType/isEqualTo/params/pushBack/findIf/selectRandom/apply, no forceWeaponFire
	(A3-only -- deliberately not used; fireAtTarget exists on OA 1.64 but Stage A tests the AI's OWN
	release decision, so no force-fire command of any kind is used here), explicit private locals
	(never inline `private _x =`), numeric-flag `> 0` guards, no A3 array-form reveal (unit-form
	`group reveal target` only, matching Client_WatchdogCommandBarDeadUnits.sqf's existing usage).
*/
if !(isServer) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_BOMB_PROBE", 0]) <= 0) exitWith {};

diag_log "BOMBPROBE|v1|START|";
["WARNING", "Server_BombProbe.sqf: STAGE A TEST HARNESS is ARMED (WFBE_C_BOMB_PROBE>0). This must NEVER be true on the live server."] Call WFBE_CO_FNC_LogContent;

//--- Let the mission environment finish settling before spawning test hulls (mirrors the
//--- Server_GuerAirDef.sqf wait-then-settle idiom; this probe has no gameplay dependency on towns).
waitUntil {!isNil "commonInitComplete" && {commonInitComplete}};
sleep 10;

Private ["_origin","_targetPos","_targetPos2","_easaKits","_roster","_grp","_hulls","_logGear","_targetGrp","_targetTruck","_targetClass","_infClass","_endTime"];

_origin = missionNamespace getVariable ["WFBE_C_BOMB_PROBE_ORIGIN", [500,500,300]];
_targetPos  = [(_origin select 0) + 800, (_origin select 1), 0];
_targetPos2 = [(_origin select 0) + 820, (_origin select 1) + 20, 0];

//--- (1) EASA-AI kit table -- VERBATIM copy of Common_RunCommanderTeam.sqf:498-523. Do NOT refactor;
//--- if that table changes, copy the new literals here so the probe keeps testing the REAL live table.
_easaKits = [
	["AH64D_EP1", ["HellfireLauncher"], ["8Rnd_Hellfire"], ["HellfireLauncher","StingerLauncher_twice"], ["8Rnd_Hellfire","2Rnd_Stinger"], false],
	["AH1Z", ["HellfireLauncher"], ["8Rnd_Hellfire","8Rnd_Hellfire"], ["HellfireLauncher","SidewinderLaucher_AH1Z"], ["8Rnd_Hellfire","2Rnd_Sidewinder_AH1Z"], false],
	["Ka52", ["AT9Launcher"], ["4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P"], ["AT9Launcher","Igla_twice"], ["4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","2Rnd_Igla"], false],
	["Ka52Black", ["VikhrLauncher"], ["12Rnd_Vikhr_KA50"], ["R73Launcher_2","VikhrLauncher"], ["2Rnd_R73","12Rnd_Vikhr_KA50"], false],
	["Mi24_P", ["AT9Launcher","HeliBombLauncher"], ["4Rnd_AT9_Mi24P","2Rnd_FAB_250"], ["AT9Launcher","Igla_twice"], ["4Rnd_AT9_Mi24P","2Rnd_Igla"], false],
	["Mi24_V", ["AT9Launcher"], ["4Rnd_AT9_Mi24P"], ["AT9Launcher","Igla_twice"], ["4Rnd_AT9_Mi24P","2Rnd_Igla"], false],
	["AW159_Lynx_BAF", ["CRV7_HEPD","CTWS","SpikeLauncher_ACR"], ["6Rnd_CRV7_HEPD","200Rnd_40mmHE_FV510","200Rnd_40mmSABOT_FV510","2Rnd_Spike_ACR","2Rnd_Spike_ACR"], ["CRV7_HEPD","CTWS","SpikeLauncher_ACR","StingerLauncher_twice"], ["6Rnd_CRV7_HEPD","200Rnd_40mmHE_FV510","200Rnd_40mmSABOT_FV510","2Rnd_Spike_ACR","2Rnd_Stinger"], true],
	["Su34", ["Ch29Launcher_Su34","R73Launcher_2"], ["6Rnd_Ch29","2Rnd_R73","2Rnd_R73"], ["AirBombLauncher","BombLauncherF35","Ch29Launcher_Su34","R73Launcher_2"], ["4Rnd_FAB_250","2Rnd_FAB_250","2Rnd_GBU12","4Rnd_Ch29","2Rnd_R73"], false],
	["Su25_TK_EP1", ["AT9Launcher","R73Launcher_2","S8Launcher"], ["4Rnd_AT9_Mi24P","4Rnd_AT9_Mi24P","2Rnd_R73","40Rnd_S8T"], ["AT9Launcher","AirBombLauncher","R73Launcher_2","S8Launcher"], ["4Rnd_AT9_Mi24P","4Rnd_FAB_250","2Rnd_FAB_250","2Rnd_R73","40Rnd_S8T"], false],
	["A10", ["FFARLauncher","Mk82BombLauncher_6"], ["38Rnd_FFAR","6Rnd_Mk82"], ["MaverickLauncher","StingerLauncher_twice"], ["2Rnd_Maverick_A10","2Rnd_Stinger"], false],
	["AV8B2", ["MaverickLauncher","SidewinderLaucher_AH1Z"], ["2Rnd_Maverick_A10","2Rnd_Maverick_A10","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z"], ["HellfireLauncher","MaverickLauncher","SidewinderLaucher_AH1Z"], ["8Rnd_Hellfire","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z"], false]
];

//--- AIR BOMBS mutation -- VERBATIM copy of Common_RunCommanderTeam.sqf:531-545. Reads the SAME live
//--- flag, so WFBE_C_AICOM_AIR_BOMBS=0 (server default) faithfully reproduces "kit strips the
//--- Mi24_P/A10 stock bomb, AV8B2 never had one"; Su34/Su25_TK_EP1 already carry FAB unconditionally
//--- from their own rows above regardless of this flag. Arm WFBE_C_AICOM_AIR_BOMBS=1 too (see
//--- runbook) to test bomb RELEASE on the other three airframes.
if ((missionNamespace getVariable ["WFBE_C_AICOM_AIR_BOMBS", 0]) > 0) then {
	{
		Private ["_abType"];
		_abType = _x select 0;
		if (_abType == "A10") then {
			_easaKits set [_forEachIndex, ["A10", ["FFARLauncher","Mk82BombLauncher_6"], ["38Rnd_FFAR","6Rnd_Mk82"], ["MaverickLauncher","StingerLauncher_twice","Mk82BombLauncher_6"], ["2Rnd_Maverick_A10","2Rnd_Stinger","6Rnd_Mk82"], false]];
		};
		if (_abType == "Mi24_P") then {
			_easaKits set [_forEachIndex, ["Mi24_P", ["AT9Launcher","HeliBombLauncher"], ["4Rnd_AT9_Mi24P","2Rnd_FAB_250"], ["AT9Launcher","Igla_twice","HeliBombLauncher"], ["4Rnd_AT9_Mi24P","2Rnd_Igla","2Rnd_FAB_250"], false]];
		};
		if (_abType == "AV8B2") then {
			_easaKits set [_forEachIndex, ["AV8B2", ["MaverickLauncher","SidewinderLaucher_AH1Z"], ["2Rnd_Maverick_A10","2Rnd_Maverick_A10","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z"], ["HellfireLauncher","MaverickLauncher","SidewinderLaucher_AH1Z","Mk82BombLauncher_6"], ["8Rnd_Hellfire","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z","6Rnd_Mk82"], false]];
		};
	} forEach _easaKits;
};

//--- Bomb-role launcher names the kit table above can add to our 5 test airframes: AirBombLauncher,
//--- BombLauncherF35, HeliBombLauncher, Mk82BombLauncher_6. NOT hoisted into a shared variable here --
//--- the "Fired" EH below fires like an independently scheduled invocation and A2 OA addEventHandler
//--- callbacks are not guaranteed to see the registering script's `private` scope (same class of trap
//--- as `Spawn` not capturing outer locals), so the EH carries its own literal copy of this exact list
//--- instead of risking an undefined-variable throw the first time it actually fires.

//--- (2) Test roster: [class, pilotClass, needsGunner, gunnerClass]. All EAST-crewed (side is what
//--- drives hostility here, not faction authenticity) so a single WEST ground cluster is hostile to
//--- every hull via the mission's own default WEST/EAST relation -- no setFriend calls needed.
_roster = [
	["Mi24_P", "RU_Soldier_Pilot", true, "RU_Soldier_Crew"],
	["Su34", "RU_Soldier_Pilot", false, ""],
	["A10", "RU_Soldier_Pilot", false, ""],
	["AV8B2", "RU_Soldier_Pilot", false, ""],
	["Su25_TK_EP1", "RU_Soldier_Pilot", false, ""]
];

_grp = [east, "bombprobe"] Call WFBE_CO_FNC_CreateGroup;
_hulls = [];
{
	Private ["_class","_pilotClass","_needsGunner","_gunnerClass","_spawnPos","_veh","_pilot","_gunner"];
	_class = _x select 0;
	_pilotClass = _x select 1;
	_needsGunner = _x select 2;
	_gunnerClass = _x select 3;
	_spawnPos = [(_origin select 0) + (_forEachIndex * 150), (_origin select 1) - 300, (_origin select 2)];
	_veh = [_class, _spawnPos, east, 0, false, true, true, "FLY"] Call WFBE_CO_FNC_CreateVehicle;
	_pilot = objNull;
	_gunner = objNull;
	if (!isNull _veh && {!isNull _grp}) then {
		_pilot = [_pilotClass, _grp, _spawnPos, east] Call WFBE_CO_FNC_CreateUnit;
		if (!isNull _pilot) then {
			_pilot moveInDriver _veh;
			if (_needsGunner && {_gunnerClass != ""}) then {
				_gunner = [_gunnerClass, _grp, _spawnPos, east] Call WFBE_CO_FNC_CreateUnit;
				if (!isNull _gunner) then { _gunner moveInGunner _veh; };
			};
		};
	};
	_hulls = _hulls + [[_veh, _class, _pilot, _gunner]];
	diag_log ("BOMBPROBE|v1|spawn|class=" + _class + "|hull=" + str (!isNull _veh) + "|pilot=" + str (!isNull _pilot) + "|gunner=" + str (!isNull _gunner));
} forEach _roster;

sleep 5; //--- let moveInDriver/moveInGunner settle before reading crew-dependent state.

//--- Gear logger: [_veh, _tag] -> hull + turret:[-1] (pseudo driver-turret, same addressing this
//--- codebase's own _kTur branch already uses) + every REAL config turret path from
//--- WFBE_CO_FNC_GetVehicleTurretsGear (live weaponsTurret/magazinesTurret next to the static
//--- CfgVehicles>>Turrets weapons[]/magazines[] reference, so a hull-vs-turret mismatch is visible
//--- directly in the RPT, not inferred).
_logGear = {
	Private ["_veh","_tag","_hw","_hm","_negW","_negM","_turrets","_t","_cfgW","_cfgM","_tPath","_tPathStr","_liveW","_liveM"];
	_veh = _this select 0;
	_tag = _this select 1;
	if (isNull _veh) exitWith {};
	_hw = weapons _veh;
	_hm = magazines _veh;
	diag_log ("BOMBPROBE|v1|" + _tag + "|class=" + typeOf _veh + "|scope=hull|weapons=" + str _hw + "|mags=" + str _hm);
	_negW = _veh weaponsTurret [-1];
	_negM = _veh magazinesTurret [-1];
	diag_log ("BOMBPROBE|v1|" + _tag + "|class=" + typeOf _veh + "|scope=turret:[-1]|weapons=" + str _negW + "|mags=" + str _negM);
	_turrets = (typeOf _veh) Call WFBE_CO_FNC_GetVehicleTurretsGear;
	{
		_t = _x;
		_cfgW = _t select 0;
		_cfgM = _t select 1;
		_tPath = _t select 2;
		_tPathStr = str _tPath;
		_liveW = [];
		_liveM = [];
		if ((typeName _tPath) == "ARRAY" && {(count _tPath) > 0}) then {
			_liveW = _veh weaponsTurret _tPath;
			_liveM = _veh magazinesTurret _tPath;
		};
		diag_log ("BOMBPROBE|v1|" + _tag + "|class=" + typeOf _veh + "|scope=turret:" + _tPathStr + "|weapons=" + str _liveW + "|mags=" + str _liveM + "|cfgWeapons=" + str _cfgW + "|cfgMags=" + str _cfgM);
	} forEach _turrets;
};

//--- (b) BASELINE gear, before the kit touches anything.
{
	Private ["_h"];
	_h = _x select 0;
	if (!isNull _h) then { [_h, "baseline"] Call _logGear; };
} forEach _hulls;

//--- (c) Apply the kit -- VERBATIM apply-logic copied from Common_RunCommanderTeam.sqf:546-579
//--- (only the turret/hull swap + the diag_log line; the EASA-research gate and RICH-GEAR block do
//--- not apply here, this probe applies the kit unconditionally to every spawned hull).
{
	Private ["_kh","_khType","_khHit","_khRow","_stW","_stM","_kW","_kM","_kTur"];
	_kh = _x select 0;
	if (!isNull _kh && {alive _kh} && {local _kh} && {_kh isKindOf "Air"}) then {
		_khType = typeOf _kh;
		_khHit = false;
		{
			if (!_khHit && {(_x select 0) == _khType}) then {
				_khHit = true;
				_khRow = _x;
				_stW = _khRow select 1;
				_stM = _khRow select 2;
				_kW  = _khRow select 3;
				_kM  = _khRow select 4;
				_kTur = _khRow select 5;
				if (_kTur) then {
					{_kh removeMagazineTurret [_x, [-1]]} forEach _stM;
					{_kh removeWeaponTurret  [_x, [-1]]} forEach _stW;
					{_kh addMagazineTurret [_x, [-1]]} forEach _kM;
					{_kh addWeaponTurret  [_x, [-1]]} forEach _kW;
				} else {
					{_kh removeMagazine _x} forEach _stM;
					{_kh removeWeapon   _x} forEach _stW;
					{_kh addMagazine _x} forEach _kM;
					{_kh addWeapon   _x} forEach _kW;
				};
				diag_log ("BOMBPROBE|v1|kitapplied|class=" + _khType + "|turret=" + str _kTur);
			};
		} forEach _easaKits;
	};
} forEach _hulls;

//--- (c) POST-KIT gear, same logger, same scopes -- diff this against the baseline lines above.
{
	Private ["_h"];
	_h = _x select 0;
	if (!isNull _h) then { [_h, "post-kit"] Call _logGear; };
} forEach _hulls;

//--- Fired EH per hull -- classifies purely from the fired weapon classname against the bomb-role
//--- launcher list above (self-contained literal in the EH body; no outer-scope capture needed).
{
	Private ["_h"];
	_h = _x select 0;
	if (!isNull _h) then {
		_h setVariable ["wfbe_bombprobe_fired_count", 0];
		_h setVariable ["wfbe_bombprobe_bomb_fired", false];
		_h addEventHandler ["Fired", {
			Private ["_u","_w","_a","_isBomb"];
			_u = _this select 0;
			_w = _this select 1;
			_a = _this select 4;
			_isBomb = _w in ["AirBombLauncher","BombLauncherF35","HeliBombLauncher","Mk82BombLauncher_6"];
			_u setVariable ["wfbe_bombprobe_fired_count", (_u getVariable ["wfbe_bombprobe_fired_count", 0]) + 1];
			if (_isBomb) then { _u setVariable ["wfbe_bombprobe_bomb_fired", true]; };
			diag_log ("BOMBPROBE|v1|fired|class=" + typeOf _u + "|weapon=" + str _w + "|ammo=" + str _a);
		}];
	};
} forEach _hulls;

//--- (d) WEST ground target cluster, 800m from the aircraft spawn line.
_infClass = "US_Soldier_EP1";
_targetClass = "HMMWV_M1035_DES_EP1"; //--- unarmed cargo HMMWV; empty/parked, stands in for "static truck".
_targetTruck = [_targetClass, _targetPos2, west, 0, false, true, true, "NONE"] Call WFBE_CO_FNC_CreateVehicle;
_targetGrp = [west, "bombprobe-target"] Call WFBE_CO_FNC_CreateGroup;
if (!isNull _targetGrp) then {
	for "_ti" from 0 to 3 do {
		Private ["_tu","_tp"];
		_tp = [(_targetPos select 0) + (_ti * 5), (_targetPos select 1) + (_ti * 5), 0];
		_tu = [_infClass, _targetGrp, _tp, west] Call WFBE_CO_FNC_CreateUnit;
	};
};

diag_log ("BOMBPROBE|v1|targets|truck=" + str (!isNull _targetTruck) + "|infantry=" + str (count (units _targetGrp)));

//--- Reveal the cluster to every hull's group once (full knowledge; unit-form reveal only).
if (!isNull _grp) then {
	if (!isNull _targetTruck) then { _grp reveal _targetTruck; };
	{ _grp reveal _x; } forEach (units _targetGrp);
};

//--- (d) 5-minute engagement window: re-issue doTarget/doFire every 20s from whichever seat controls
//--- the weapon (gunner if present, else pilot/driver). No selectWeapon call -- weapon/ammo choice is
//--- entirely the AI's own decision, matching the plan doc's "no scripted forcing" requirement.
_endTime = time + 300;
while {time < _endTime} do {
	{
		Private ["_h","_p","_g","_shooter"];
		_h = _x select 0;
		_p = _x select 2;
		_g = _x select 3;
		if (!isNull _h && {alive _h}) then {
			_shooter = _p;
			if (!isNull _g && {alive _g}) then { _shooter = _g; };
			if (!isNull _shooter && {alive _shooter} && {!isNull _targetTruck} && {alive _targetTruck}) then {
				_shooter doTarget _targetTruck;
				_shooter doFire _targetTruck;
			};
		};
	} forEach _hulls;
	sleep 20;
};

//--- (e) Verdict per airframe, then full teardown.
{
	Private ["_h","_c","_p","_g","_fc","_bf"];
	_h = _x select 0;
	_c = _x select 1;
	_p = _x select 2;
	_g = _x select 3;
	_fc = 0;
	_bf = false;
	if (!isNull _h) then {
		_fc = _h getVariable ["wfbe_bombprobe_fired_count", 0];
		_bf = _h getVariable ["wfbe_bombprobe_bomb_fired", false];
	};
	diag_log ("BOMBPROBE|v1|verdict|class=" + _c + "|totalFired=" + str _fc + "|bombFired=" + str _bf);
	if (!isNull _p && {alive _p}) then { deleteVehicle _p; };
	if (!isNull _g && {alive _g}) then { deleteVehicle _g; };
	if (!isNull _h) then { deleteVehicle _h; };
} forEach _hulls;

if (!isNull _targetGrp) then {
	{ if (alive _x) then { deleteVehicle _x; }; } forEach (units _targetGrp);
	deleteGroup _targetGrp;
};
if (!isNull _targetTruck) then { deleteVehicle _targetTruck; };
if (!isNull _grp) then { deleteGroup _grp; };

diag_log "BOMBPROBE|v1|END|";
["WARNING", "Server_BombProbe.sqf: STAGE A TEST HARNESS run complete, all probe objects torn down."] Call WFBE_CO_FNC_LogContent;
