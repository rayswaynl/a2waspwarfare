/*
	Common_AsrFiredGuard.sqf
	Post-sleep null-shooter fix for the OPTIONAL 3rd-party ASR AI mod (asr_ai sys_aiskill).
	
	Live RPT shows a low-frequency script error INSIDE the mod (not mission code):
	    Error in expression <[_shooter,_k]  -> mod file sys_aiskill/fnc_fired.sqf line 115,
	    "_x reveal [_shooter,_k]", inside the reveal loop over "_shooter nearEntities [...]" (line 118).
	Root cause: the mod's fired handler runs in a spawned thread and does "sleep _burst;" (mod
	line 98) BEFORE that reveal loop. This mission trash-collects corpses/wrecks aggressively, so a
	shooter that dies DURING the sleep is objNull by the time the loop runs -> stale-object error.
	
	An earlier version of this guard only checked isNull _shooter at ENTRY (before the mod's sleep),
	which never caught the real race: the shooter is alive when it fires and only goes null during
	the sleep. Fix: REPLACE the mod global asr_ai_sys_aiskill_fnc_fired with a faithful copy of the
	mod's fired logic PLUS a post-sleep null-shooter exit. The XEH invokes the global BY NAME
	(Extended_FiredBIS -> asr_ai_sys_aiskill_fnc_firedEH -> spawn asr_ai_sys_aiskill_fnc_fired), so
	the reassignment takes effect immediately, per-machine. Inert when the mod is absent (vanilla
	clients): logs one line and exits. Idempotent. GVAR expansion is CBA A2 (asr_ai_sys_aiskill_*).
	The @adwasp ASR AI build is frozen (A2OA is EOL); if a future mod build changes fnc_fired, re-sync
	this copy - the "not present" RPT line below is the tell if the global is ever renamed.
	Correctness fix - ships unflagged per repo flag policy.
*/

if (!isNil "WFBE_ASR_FIRED_PATCHED") exitWith {}; //--- Already patched on this machine.

if (isNil "asr_ai_sys_aiskill_fnc_fired") exitWith {
	["INFORMATION", "Common_AsrFiredGuard.sqf: ASR AI fired handler not present on this machine - patch not installed."] Call WFBE_CO_FNC_LogContent;
};

WFBE_ASR_FIRED_PATCHED = true;

//--- Faithful reimplementation of the mod's asr_ai_sys_aiskill_fnc_fired with a post-sleep null guard.
asr_ai_sys_aiskill_fnc_fired = {
	private ["_shooter","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile","_cfg","_snda","_snd","_range","_k","_sdweap","_sdammo","_distance","_detectupto","_audible","_ammofactor","_burst"];
	_shooter = _this select 0;
	_weapon = _this select 1;
	_muzzle = _this select 2;
	_mode = _this select 3;
	_ammo = _this select 4;
	_magazine = _this select 5;
	_projectile = _this select 6;
	
	asr_ai_sys_aiskill_fired = true;
	
	if (_muzzle == _weapon) then {
		_cfg = configFile >> "cfgWeapons" >> _weapon;
	} else {
		_cfg = configFile >> "cfgWeapons" >> _weapon >> _muzzle;
	};
	
	_sdweap = false;
	_sdammo = false;
	_audible = [configFile >> "CfgAmmo" >> _ammo >> "audiblefire", "number", 16] call CBA_fnc_getConfigEntry;
	if ([_cfg >> "firelightintensity", "number", 0] call CBA_fnc_getConfigEntry < 0.01) then {_sdweap = true};
	if (_audible < 1) then {_sdammo = true};
	if (_sdweap && _sdammo) exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	
	if ([_cfg, configFile >> "CfgWeapons" >> "GrenadeLauncher"] call CBA_fnc_inheritsFrom) exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	
	if (_mode != _muzzle) then {
		_cfg = _cfg >> _mode;
	};
	_snda = getArray (_cfg >> "soundbegin");
	if (count _snda < 2) exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	_snd = getArray (_cfg >> (_snda select 0));
	if (count _snd < 4) exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	if (_snd select 0 == "") exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	_range = _snd select 3;
	if (typeName _range != "SCALAR") exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	
	//--- apply JSRS fix for loud rifles with short sound range
	if (isClass (configFile >> "CfgPatches" >> "JSRS_Distance")) then {
		if (_range >= 200) then {
			if (_range < 1200) then {
				_range = 1200;
			};
		};
	};
	//--- apply userconfig coefficient
	_range = _range * asr_ai_sys_aiskill_gunshothearing;
	
	_ammofactor = _audible / 16;
	if (_ammofactor > 1 || _sdweap) then {
		_range = _range * _ammofactor;
	};
	
	if (_range < 30) exitWith {
		asr_ai_sys_aiskill_fired = nil;
	};
	
	_detectupto = _range / 1.5; //--- max distance for which calculated knowledge is at least 0.5
	
	if (isPlayer gunner _shooter && asr_ai_sys_aiskill_gunshothearing_debug == 1) then {
		hintSilent format ["ASR DEBUG: gunshot hearing aid: minimum reveal of 0.5 at max range of %1 meters", _detectupto];
	};
	
	_burst = [_cfg >> "burst", "number", 1] call CBA_fnc_getConfigEntry;
	
	//--- little hack to prevent AI gunners shooting long bursts while turning around
	if (!isPlayer _shooter) then {
		if (vehicle _shooter == _shooter) then {
			if (_burst > 3) then {
				if (isNil {_shooter getVariable "asr_ai_sys_aiskill_shooting"}) then {
					_shooter forceSpeed 0;
				};
			};
		};
	};
	
	sleep _burst; //--- reveal with delay, stop to shoot, helps performance too
	
	//--- POST-SLEEP FIX: the shooter may have died and been trash-collected during the sleep above;
	//--- a stale objNull here poisons the reveal loop below (mod fnc_fired.sqf:115). Exit cleanly.
	if (isNull _shooter) exitWith { asr_ai_sys_aiskill_fired = nil };
	
	if (!isPlayer _shooter) then {
		if (vehicle _shooter == _shooter) then {
			if (_burst > 3) then {
				if (isNil {_shooter getVariable "asr_ai_sys_aiskill_shooting"}) then {
					_shooter forceSpeed -1;
				};
			};
		};
	};
	
	{
		if (group _x != group _shooter) then {
			_distance = [_shooter,_x] call CBA_fnc_getDistance;
			//--- gain knowledge based on weapon sound and range
			_k = 1.5 * (1 - _distance/_range);
			_x reveal [_shooter,_k]; // noqa: A3REVEAL
		};
	} forEach (_shooter nearEntities [["CAManBase","StaticWeapon"],_detectupto]);
	
	asr_ai_sys_aiskill_fired = nil;
};

["INFORMATION", "Common_AsrFiredGuard.sqf: post-sleep null-shooter fix installed (replaced asr_ai_sys_aiskill_fnc_fired)."] Call WFBE_CO_FNC_LogContent;
