/*
	SkinSelector_Data.sqf
	Returns the skin pool for the calling player's side.
	Output: array of [classname, displayLabel, isGhillie]
	  - displayLabel: "" means "resolve from registry / config at runtime"
	  - isGhillie: true means entry is only shown to the sniper (role type "Spotter" — see Skill_Init.sqf)
	Each entry is filtered: if the class does not exist in CfgVehicles the entry is dropped.
*/

Private ["_pool","_side","_filtered","_cls","_isGhillie","_lbl","_entry","_i"];

_side = side group player;

_pool = [];

if (_side == WEST) then {
	_pool = [
		["USMC_Soldier",          "", false],
		["USMC_Soldier_TL",       "", false],
		["USMC_SoldierS",         "", false],
		["USMC_Soldier_MG",       "", false],
		["USMC_Soldier_GL",       "", false],
		["USMC_Soldier_Medic",    "", false],
		["USMC_SoldierS_Engineer","", false],
		["US_Soldier_EP1",        "", false],
		["BAF_Soldier_MTP",       "", false],
		["BAF_Soldier_SL_MTP",    "", false],
		["CZ_Soldier_DES_EP1",    "", false],
		//--- 2026-06-16 pool expansion (OA US Army + French DLC); isClass guard drops any absent on this map.
		["US_Soldier_MG_EP1",     "", false],
		["US_Soldier_TL_EP1",     "", false],
		["FR_Corpsman",           "", false],
		["FR_GL",                 "", false],
		//--- cmdcon42 pool expansion (Ray 2026-07-02): now that the class-swap works, add visual variety.
		//--- MODEL-ONLY: SkinSelector_ApplyGear.sqf removeAllWeapons + re-applies the players OWN captured
		//--- loadout after the swap, so the chosen class default kit is irrelevant (no gameplay change).
		//--- Every class below is a real A2 CO / OA base-game soldier grep-confirmed in the mission tree;
		//--- the isClass guard drops any a given client lacks. Explicit clean labels for readability.
		["USMC_Soldier_AT",           "USMC Rifleman (AT)",      false],
		["USMC_Soldier_AA",           "USMC Rifleman (AA)",      false],
		["USMC_Soldier_LAT",          "USMC Rifleman (LAT)",     false],
		["USMC_Soldier_HAT",          "USMC Heavy AT",           false],
		["USMC_Soldier_SL",           "USMC Squad Leader",       false],
		["USMC_Soldier_Pilot",        "USMC Pilot",              false],
		["USMC_Soldier_Crew",         "USMC Vehicle Crew",       false],
		["US_Soldier_SL_EP1",         "US Army Squad Leader",    false],
		["US_Soldier_AR_EP1",         "US Army Autorifleman",    false],
		["US_Soldier_GL_EP1",         "US Army Grenadier",       false],
		["US_Soldier_Medic_EP1",      "US Army Medic",           false],
		["US_Soldier_Engineer_EP1",   "US Army Engineer",        false],
		["US_Soldier_Pilot_EP1",      "US Army Pilot",           false],
		["US_Delta_Force_EP1",        "Delta Force Operator",    false],
		["US_Delta_Force_TL_EP1",     "Delta Force Team Leader", false],
		["US_Delta_Force_Medic_EP1",  "Delta Force Medic",       false],
		["CZ_Special_Forces_DES_EP1", "CZ Special Forces (Des)", false],
		["BAF_Soldier_AR_MTP",        "BAF Autorifleman (MTP)",  false],
		["BAF_Soldier_Medic_MTP",     "BAF Medic (MTP)",         false],
		["BAF_Soldier_Officer_MTP",   "BAF Officer (MTP)",       false],
		["BAF_Soldier_W",             "BAF Rifleman (Woodland)", false],
		["FR_R",                      "French Rifleman",         false],
		["FR_Marksman",               "French Marksman",         false],
		["GER_Soldier_EP1",           "German Rifleman",         false],
		["GER_Soldier_Scout_EP1",     "German Scout",            false],
		//--- Miksuu addon skins (@MiksuuSkins). The isClass guard below drops these until the signed addon is loaded.
		["mks_w_multicam",        "", false],
		["mks_w_ranger",          "", false],
		["mks_w_coyote",          "", false],
		//--- Ghillie / sniper skins (sniper role only - kept LAST).
		["USMC_SoldierS_Sniper",  "", true],
		["USMC_SoldierS_SniperH", "", true],
		["US_Soldier_Sniper_EP1",     "US Army Sniper (Ghillie)",  true],
		["US_Soldier_Spotter_EP1",    "US Army Spotter (Ghillie)", true],
		["BAF_Soldier_Sniper_MTP",    "BAF Sniper (MTP Ghillie)",  true]
	];
};

if (_side == EAST) then {
	//--- cmdcon44o (Ray live report 2026-07-04): CDF entries REMOVED from the EAST pool. CDF is a
	//--- BLUFOR-config faction; the cmdcon42 "MODEL-ONLY, side is unaffected" assumption holds while
	//--- alive in the slot group, but the ENGINE RESPAWN re-evaluates the persisted class by CONFIG
	//--- side - an EAST player in a CDF body respawns hostile to his own base AI and gets executed
	//--- on every respawn/rejoin. Cross-side skins are also hard-blocked in SkinSelector_Apply.sqf.
	_pool = [
		["RU_Soldier",            "", false],
		["RU_Soldier_TL",         "", false],
		["RU_Soldier_AR",         "", false],
		["RU_Soldier_MG",         "", false],
		["RU_Soldier_GL",         "", false],
		["RU_Soldier_Medic",      "", false],
		["Ins_Soldier_1",         "", false],
		["Ins_Soldier_2",         "", false],
		["MVD_Soldier_TL",        "", false],
		//--- 2026-06-16 pool expansion (Takistani Army, for the Takistan-inherited build); isClass guard drops any absent on this map.
		//--- NOTE: TK_Soldier_TL_EP1 does not exist in OA / the faction configs (TKA uses SL naming) — using the registered TK_Soldier_SL_EP1.
		["TK_Soldier_EP1",        "", false],
		["TK_Soldier_SL_EP1",     "", false],
		//--- cmdcon42 pool expansion (Ray 2026-07-02): OPFOR-flavour variety (RU/MVD/Ins/TK/CDF). MODEL-ONLY -
		//--- side is unaffected by the model and ApplyGear re-applies the players own loadout after the swap.
		//--- All grep-confirmed in the mission tree; isClass guard drops any a client lacks. Clean labels.
		["RU_Soldier_AT",             "Russian Rifleman (AT)",   false],
		["RU_Soldier_HAT",            "Russian Heavy AT",        false],
		["RU_Soldier_Marksman",       "Russian Marksman",        false],
		["RU_Soldier_Crew",           "Russian Vehicle Crew",    false],
		["RU_Soldier_Pilot",          "Russian Pilot",           false],
		["RUS_Soldier1",              "Russian Soldier (Ratnik)",false],
		["RUS_Soldier_TL",            "Russian Team Leader",     false],
		["RUS_Commander",             "Russian Commander",       false],
		["Ins_Soldier_AR",           "Insurgent Autorifleman",  false],
		["Ins_Soldier_GL",           "Insurgent Grenadier",     false],
		["Ins_Soldier_MG",           "Insurgent Machinegunner", false],
		["Ins_Soldier_CO",           "Insurgent Commander",     false],
		["Ins_Soldier_AT",           "Insurgent Rifleman (AT)", false],
		["TK_Soldier_AR_EP1",         "Takistani Autorifleman",  false],
		["TK_Soldier_MG_EP1",         "Takistani Machinegunner", false],
		["TK_Soldier_Officer_EP1",    "Takistani Officer",       false],
		["TK_Special_Forces_EP1",     "Takistani Special Forces",false],
		["TK_GUE_Soldier_EP1",        "Takistani Guerrilla",     false],
		//--- Miksuu addon skins (@MiksuuSkins). The isClass guard below drops these until the signed addon is loaded.
		["mks_e_gorka",           "", false],
		["mks_e_spetsnaz",        "", false],
		//--- Ghillie / sniper skins (sniper role only - kept LAST).
		["RU_Soldier_Sniper",     "", true],
		["RU_Soldier_SniperH",    "", true],
		["MVD_Soldier_Sniper",        "MVD Sniper (Ghillie)",       true],
		["Ins_Soldier_Sniper",        "Insurgent Sniper (Ghillie)", true],
		["TK_Soldier_Sniper_EP1",     "Takistani Sniper (Ghillie)", true]
	];
};

//--- Filter: drop entries whose class does not exist in CfgVehicles (e.g. missing DLC).
_filtered = [];
_i = 0;
while {_i < count _pool} do {
	_entry     = _pool select _i;
	_cls       = _entry select 0;
	_isGhillie = _entry select 2;

	if (isClass (configFile >> "CfgVehicles" >> _cls)) then {
		//--- Resolve display label from unit registry; fall back to config displayName.
		_lbl = "";
		Private ["_regEntry"];
		_regEntry = missionNamespace getVariable [_cls, []];
		if ((count _regEntry) > QUERYUNITLABEL) then {
			_lbl = _regEntry select QUERYUNITLABEL;
		};
		if (_lbl == "") then {
			_lbl = [_cls, "displayName"] Call GetConfigInfo;
		};
		if (_lbl == "") then {_lbl = _cls};

		_filtered set [count _filtered, [_cls, _lbl, _isGhillie]];
	};
	_i = _i + 1;
};

_filtered
