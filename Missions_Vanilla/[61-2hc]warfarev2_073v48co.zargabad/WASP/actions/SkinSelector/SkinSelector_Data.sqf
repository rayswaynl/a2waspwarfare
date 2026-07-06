/*
	SkinSelector_Data.sqf
	Returns the skin pool for the calling player's side.
	Output: array of [classname, displayLabel, isGhillie]
	  - displayLabel: "" means "resolve from registry / config at runtime"
	    (2026-07-06 Ray flavor-name pass: every pool entry now carries an explicit non-generic label,
	     nickname + terse model hint; the registry/config fallback path is kept for safety.)
	  - isGhillie: true means entry is only shown to the sniper (role type "Spotter" — see Skill_Init.sqf)
	Each entry is filtered: if the class does not exist in CfgVehicles the entry is dropped.
*/

Private ["_pool","_side","_filtered","_cls","_isGhillie","_lbl","_entry","_i"];

_side = side group player;

_pool = [];

if (_side == WEST) then {
	_pool = [
		["USMC_Soldier",          "Devil Dog (USMC)", false],
		["USMC_Soldier_TL",       "Top Sarge (USMC TL)", false],
		["USMC_SoldierS",         "Old Salt (USMC Recon)", false],
		["USMC_Soldier_MG",       "Gun Bunny (USMC MG)", false],
		["USMC_Soldier_GL",       "Forty Mike (USMC GL)", false],
		["USMC_Soldier_Medic",    "Corpsman Up! (USMC Medic)", false],
		["USMC_SoldierS_Engineer","Demo Dan (USMC Engineer)", false],
		["US_Soldier_EP1",        "GI Joe (US Army)", false],
		["BAF_Soldier_MTP",       "Tommy (BAF MTP)", false],
		["BAF_Soldier_SL_MTP",    "Guv'nor (BAF SL)", false],
		["CZ_Soldier_DES_EP1",    "Desert Wolf (CZ)", false],
		//--- 2026-06-16 pool expansion (OA US Army + French DLC); isClass guard drops any absent on this map.
		["US_Soldier_MG_EP1",     "Belt Feeder (US Army MG)", false],
		["US_Soldier_TL_EP1",     "Point Man (US Army TL)", false],
		["FR_Corpsman",           "Toubib (French Medic)", false],
		["FR_GL",                 "Legionnaire (French GL)", false],
		//--- cmdcon42 pool expansion (Ray 2026-07-02): now that the class-swap works, add visual variety.
		//--- MODEL-ONLY: SkinSelector_ApplyGear.sqf removeAllWeapons + re-applies the players OWN captured
		//--- loadout after the swap, so the chosen class default kit is irrelevant (no gameplay change).
		//--- Every class below is a real A2 CO / OA base-game soldier grep-confirmed in the mission tree;
		//--- the isClass guard drops any a given client lacks. Explicit clean labels for readability.
		["USMC_Soldier_AT",           "Tank Popper (USMC AT)",      false],
		["USMC_Soldier_AA",           "Sky Sweeper (USMC AA)",      false],
		["USMC_Soldier_LAT",          "Pocket Rocket (USMC LAT)",     false],
		["USMC_Soldier_HAT",          "Dragon Slayer (USMC HAT)",           false],
		["USMC_Soldier_SL",           "Gunny (USMC SL)",       false],
		["USMC_Soldier_Pilot",        "Hover Jockey (USMC Pilot)",              false],
		["USMC_Soldier_Crew",         "Tread Head (USMC Crew)",       false],
		["US_Soldier_SL_EP1",         "Platoon Daddy (US Army SL)",    false],
		["US_Soldier_AR_EP1",         "Lead Hose (US Army AR)",    false],
		["US_Soldier_GL_EP1",         "Thump Gun (US Army GL)",       false],
		["US_Soldier_Medic_EP1",      "Band-Aid (US Army Medic)",           false],
		["US_Soldier_Engineer_EP1",   "C4 Charlie (US Army Eng)",        false],
		["US_Soldier_Pilot_EP1",      "Warrant Wizard (US Pilot)",           false],
		["US_Delta_Force_EP1",        "The Unit (Delta)",    false],
		["US_Delta_Force_TL_EP1",     "Ace of Spades (Delta TL)", false],
		["US_Delta_Force_Medic_EP1",  "18 Delta (Delta Medic)",       false],
		["CZ_Special_Forces_DES_EP1", "601st Shadow (CZ SF)", false],
		["BAF_Soldier_AR_MTP",        "Minimi Man (BAF AR)",  false],
		["BAF_Soldier_Medic_MTP",     "Doc Brit (BAF Medic)",         false],
		["BAF_Soldier_Officer_MTP",   "Rupert (BAF Officer)",       false],
		["BAF_Soldier_W",             "Green Jacket (BAF Wdl)", false],
		["FR_R",                      "Musketeer (French Rifleman)",         false],
		["FR_Marksman",               "Tireur (French Marksman)",         false],
		["GER_Soldier_EP1",           "Jaeger (German Rifleman)",         false],
		["GER_Soldier_Scout_EP1",     "Waldgeist (German Scout)",            false],
		//--- Miksuu addon skins (@MiksuuSkins). The isClass guard below drops these until the signed addon is loaded.
		["mks_w_multicam",        "Multicam Merc (Miksuu)", false],
		["mks_w_ranger",          "Ranger Green (Miksuu)", false],
		["mks_w_coyote",          "Coyote Brown (Miksuu)", false],
		//--- Ghillie / sniper skins (sniper role only - kept LAST).
		["USMC_SoldierS_Sniper",  "Bush Wookie (USMC Ghillie)", true],
		["USMC_SoldierS_SniperH", "Swamp Thing (USMC Ghillie)", true],
		["US_Soldier_Sniper_EP1",     "Grass Ghost (US Ghillie)",  true],
		["US_Soldier_Spotter_EP1",    "Wind Caller (US Spotter)", true],
		["BAF_Soldier_Sniper_MTP",    "Hedgerow Horror (BAF Ghillie)",  true]
	];
};

if (_side == EAST) then {
	//--- cmdcon44o (Ray live report 2026-07-04): CDF entries REMOVED from the EAST pool. CDF is a
	//--- BLUFOR-config faction; the cmdcon42 "MODEL-ONLY, side is unaffected" assumption holds while
	//--- alive in the slot group, but the ENGINE RESPAWN re-evaluates the persisted class by CONFIG
	//--- side - an EAST player in a CDF body respawns hostile to his own base AI and gets executed
	//--- on every respawn/rejoin. Cross-side skins are also hard-blocked in SkinSelector_Apply.sqf.
	_pool = [
		["RU_Soldier",            "Comrade Ivan (RU)", false],
		["RU_Soldier_TL",         "Starshina (RU TL)", false],
		["RU_Soldier_AR",         "Suppressive Sergei (RU AR)", false],
		["RU_Soldier_MG",         "Belt Boris (RU MG)", false],
		["RU_Soldier_GL",         "GP Grisha (RU GL)", false],
		["RU_Soldier_Medic",      "Sanitar (RU Medic)", false],
		["Ins_Soldier_1",         "Chedaki Regular (Ins)", false],
		["Ins_Soldier_2",         "Chedaki Irregular (Ins)", false],
		["MVD_Soldier_TL",        "Red Beret (MVD TL)", false],
		//--- 2026-06-16 pool expansion (Takistani Army, for the Takistan-inherited build); isClass guard drops any absent on this map.
		//--- NOTE: TK_Soldier_TL_EP1 does not exist in OA / the faction configs (TKA uses SL naming) — using the registered TK_Soldier_SL_EP1.
		["TK_Soldier_EP1",        "Desert Askar (TK)", false],
		["TK_Soldier_SL_EP1",     "Askar Boss (TK SL)", false],
		//--- cmdcon42 pool expansion (Ray 2026-07-02): OPFOR-flavour variety (RU/MVD/Ins/TK/CDF). MODEL-ONLY -
		//--- side is unaffected by the model and ApplyGear re-applies the players own loadout after the swap.
		//--- All grep-confirmed in the mission tree; isClass guard drops any a client lacks. Clean labels.
		["RU_Soldier_AT",             "RPG Ruslan (RU AT)",   false],
		["RU_Soldier_HAT",            "Vampir (RU Heavy AT)",        false],
		["RU_Soldier_Marksman",       "Dragunov's Son (RU Marksman)",        false],
		["RU_Soldier_Crew",           "Tankist (RU Crew)",    false],
		["RU_Soldier_Pilot",          "Vertushka (RU Pilot)",           false],
		["RUS_Soldier1",              "Ratnik (RU Spetsnaz)",false],
		["RUS_Soldier_TL",            "Alfa Leader (RU Spetsnaz)",     false],
		["RUS_Commander",             "Polkovnik (RU Commander)",       false],
		["Ins_Soldier_AR",           "Chedaki Gunhand (Ins AR)",  false],
		["Ins_Soldier_GL",           "Chedaki Thumper (Ins GL)",     false],
		["Ins_Soldier_MG",           "Chedaki Warpig (Ins MG)", false],
		["Ins_Soldier_CO",           "Ataman (Ins Commander)",     false],
		["Ins_Soldier_AT",           "Chedaki Tank-Taker (Ins AT)", false],
		["TK_Soldier_AR_EP1",         "Zagros Gunner (TK AR)",  false],
		["TK_Soldier_MG_EP1",         "Mountain Mauler (TK MG)", false],
		["TK_Soldier_Officer_EP1",    "Sarhang (TK Officer)",       false],
		["TK_Special_Forces_EP1",     "Scorpion (TK SF)",false],
		["TK_GUE_Soldier_EP1",        "Wolf of Zargabad (TK Guer)",     false],
		//--- Miksuu addon skins (@MiksuuSkins). The isClass guard below drops these until the signed addon is loaded.
		["mks_e_gorka",           "Gorka Ghost (Miksuu)", false],
		["mks_e_spetsnaz",        "Spetsnaz Style (Miksuu)", false],
		//--- Ghillie / sniper skins (sniper role only - kept LAST).
		["RU_Soldier_Sniper",     "Taiga Phantom (RU Ghillie)", true],
		["RU_Soldier_SniperH",    "Zaitsev (RU Ghillie)", true],
		["MVD_Soldier_Sniper",        "MVD Wraith (Ghillie)",       true],
		["Ins_Soldier_Sniper",        "Chedaki Cuckoo (Ghillie)", true],
		["TK_Soldier_Sniper_EP1",     "Dust Devil (TK Ghillie)", true]
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
