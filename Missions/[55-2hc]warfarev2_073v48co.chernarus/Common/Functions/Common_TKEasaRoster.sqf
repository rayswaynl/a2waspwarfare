//--- ============================================================================================
//--- Common_TKEasaRoster.sqf  (cmdcon42-i)
//--- SINGLE SOURCE OF TRUTH for the Takistan-only "EASA loadout" air variant roster.
//---
//--- Ray's ask: "add balanced EASA versions per air factory level, per level per side, on Takistan."
//--- This returns a data catalog of SYNTHETIC buy tokens. Each token is a distinct classname STRING
//--- (e.g. "TKV_AH64D_HYDRA") that is NOT a CfgVehicles class. It is:
//---   1. registered (Core_US / Core_TKA) as a deep-copy of the real base-hull buy tuple, with the
//---      display name + price + air-research level (UPGRADE) overridden - so it shows a correct
//---      crew/portrait in the buy dialog and gates at its own tier;
//---   2. listed in the player air buy lists (Units_CO_US / Units_OA_TKA) and, for the top tiers,
//---      in the per-airfield exclusive roster (Init_Common) - TAKISTAN ONLY (gated on worldName);
//---   3. remapped to the real hull in Client_BuildUnit BEFORE createVehicle, then armed with the
//---      kit's weapon+magazine classnames via hull-level addWeapon/addMagazine (the AH6X_M134
//---      precedent, PR #151 / commit a6a61a098).
//---
//--- The kit weapon/magazine CLASSNAMES below are reused VERBATIM from the EASA loadout tables
//--- (Client/Module/EASA/EASA_Init.sqf) for the SAME base hull, so every classname is config-proven
//--- on that airframe (AH64D_EP1 line 592-597, A10_US_EP1 line 393-469, Su25_TK_EP1 line 133-192,
//--- and the Su25_Ins/Mi24_P Hind kits line 105-129 for the Mi-24). None of the four base hulls are
//--- in EASA_Equip's turret-special list (only AW159_Lynx_BAF / Ka137_MG_PMC are), so plain
//--- addWeapon/addMagazine is the correct application path.
//---
//--- BALANCE (Ray repricing correction on PR #172): variant price = BASE HULL TUPLE PRICE x LEVEL PREMIUM,
//--- rounded to the nearest 100: L2 = x1.20, L3 = x1.30, L4 = x1.45, L5 (airfield-exclusive warload) = x1.65.
//--- Sanity floor: every variant >= base x1.15 (all rows clear it). A variant must NEVER undercut its stock
//--- hull (more weapons may not cost less). Base tuple prices: AH64D_EP1 34707 / A10_US_EP1 32320 (Core_US.sqf),
//--- Mi24_D_TK_EP1 22580 / Su25_TK_EP1 31980 (Core_TKA.sqf). Pairing table in the PR body.
//---
//--- Row tuple shape (this catalog's OWN format - NOT the QUERYUNIT buy tuple):
//---   [ token, baseHull, sideText, displayName, price, upgradeLevel, isAirfieldExclusive,
//---     [ [weapons...], [magazines...] ] ]
//---     token               - synthetic buy-key classname STRING (unique)
//---     baseHull            - real CfgVehicles class to createVehicle + arm
//---     sideText            - "US" (WEST) or "TKA" (EAST), for list routing / faction label
//---     displayName         - clean UI label, e.g. "AH-64D (Hellfire II kit)"
//---     price               - buy cost
//---     upgradeLevel        - QUERYUNITUPGRADE gate (air-research level 0-5)
//---     isAirfieldExclusive - true = only offered at a captured TK airfield hangar (top tier)
//---     kit                 - [ [weaponClasses], [magazineClasses] ] applied on the created hull
//---
//--- Flag-gated: WFBE_C_TK_EASA_ROSTER (default 1). Returns [] on Chernarus or when the flag is off.
//--- A2-OA-1.64 safe: string classnames, plain arrays, no A3 primitives. Runs on every machine that
//--- needs the catalog (server + each client) - all know worldName, so the worldName gate is uniform.
//--- ============================================================================================

private ["_roster"];

//--- TAKISTAN-ONLY + feature flag. IS_chernarus_map_dependent is worldName-derived (initJIPCompatible.sqf);
//--- worldName is known identically on server and every client, so this gate is machine-uniform.
if (IS_chernarus_map_dependent) exitWith { [] };
if ((missionNamespace getVariable ["WFBE_C_TK_EASA_ROSTER", 1]) <= 0) exitWith { [] };

_roster = [

	//--- ===================== WEST / US =====================
	//--- Base hulls: AH64D_EP1 (attack heli, base tier 4, 34707) | A10_US_EP1 (CAS plane, base tier 4, 32320).
	//--- Kit classnames verbatim from EASA_Init.sqf AH64D_EP1 (l.592-597) + A10_US_EP1 (l.393-469).

	//--- L2 (light): rocket/gun support kit on the Apache. Hydra pod + short Hellfire load.
	["TKV_AH64D_HYDRA","AH64D_EP1","US","AH-64D (Hydra rocket kit)",41600,2,false,   //--- 34707 x1.20 = 41648 -> 41600
		[["HellfireLauncher","FFARLauncher"],["8Rnd_Hellfire","38Rnd_FFAR","38Rnd_FFAR"]]],

	//--- L3 (mid AT): the signature Hellfire II anti-armour load.
	["TKV_AH64D_HELLFIRE","AH64D_EP1","US","AH-64D (Hellfire II kit)",45100,3,false,   //--- 34707 x1.30 = 45119 -> 45100
		[["HellfireLauncher"],["8Rnd_Hellfire","8Rnd_Hellfire"]]],

	//--- L3 (mid): A-10 Maverick + Hydra strike, mixed AG.
	["TKV_A10_MAVERICK","A10_US_EP1","US","A-10C (Maverick strike kit)",42000,3,false,   //--- 32320 x1.30 = 42016 -> 42000
		[["HellfireLauncher","MaverickLauncher","FFARLauncher"],["8Rnd_Hellfire","2Rnd_Maverick_A10","38Rnd_FFAR"]]],

	//--- L4 (heavy AT/AA): Apache full AGM-114 + Stinger self-defence (EASA AH64D_EP1 default row).
	["TKV_AH64D_STINGER","AH64D_EP1","US","AH-64D (Hellfire + Stinger kit)",50300,4,false,   //--- 34707 x1.45 = 50325 -> 50300
		[["HellfireLauncher","StingerLauncher_twice"],["8Rnd_Hellfire","2Rnd_Stinger"]]],

	//--- L4 (heavy AT): A-10 AGM-114 + Maverick heavy anti-armour.
	["TKV_A10_HEAVY","A10_US_EP1","US","A-10C (heavy AT kit)",46900,4,false,   //--- 32320 x1.45 = 46864 -> 46900
		[["HellfireLauncher","MaverickLauncher"],["8Rnd_Hellfire","2Rnd_Maverick_A10","2Rnd_Maverick_A10"]]],

	//--- L5 (top AT/AA, airfield-exclusive): A-10 full warload - AGM-114 + Maverick + AIM-9L AA.
	["TKV_A10_WARLORD","A10_US_EP1","US","A-10C (full warload kit)",53300,5,true,   //--- 32320 x1.65 = 53328 -> 53300
		[["HellfireLauncher","MaverickLauncher","SidewinderLaucher_AH1Z"],["8Rnd_Hellfire","2Rnd_Maverick_A10","2Rnd_Sidewinder_AH1Z"]]],

	//--- ===================== EAST / TKA =====================
	//--- Base hulls: Mi24_D_TK_EP1 (attack heli, base tier 3, 22580) | Su25_TK_EP1 (CAS plane, base tier 4, 31980).
	//--- Mi-24 kit classnames from EASA Su25_Ins/Mi24_P Hind rows (l.105-129, l.640-647): AT9Launcher/
	//--- 4Rnd_AT9_Mi24P, 57mmLauncher/64Rnd_57mm, Igla_twice/2Rnd_Igla - standard Hind armament.
	//--- Su-25 kit classnames verbatim from EASA Su25_TK_EP1 (l.133-192).

	//--- L2 (light): Hind S-5 rocket support pod pass.
	["TKV_MI24_ROCKETS","Mi24_D_TK_EP1","TKA","Mi-24 (S-5 rocket kit)",27100,2,false,   //--- 22580 x1.20 = 27096 -> 27100
		[["57mmLauncher"],["64Rnd_57mm","64Rnd_57mm"]]],

	//--- L3 (mid AT): Ataka-V anti-armour load.
	["TKV_MI24_ATAKA","Mi24_D_TK_EP1","TKA","Mi-24 (Ataka-V AT kit)",29400,3,false,   //--- 22580 x1.30 = 29354 -> 29400
		[["AT9Launcher","57mmLauncher"],["4Rnd_AT9_Mi24P","64Rnd_57mm"]]],

	//--- L3 (mid): Su-25 Kh-29 + S-8 heavy AG strike.
	["TKV_SU25_KH29","Su25_TK_EP1","TKA","Su-25 (Kh-29 strike kit)",41600,3,false,   //--- 31980 x1.30 = 41574 -> 41600
		[["Ch29Launcher_Su34","S8Launcher"],["6Rnd_Ch29","40Rnd_S8T"]]],

	//--- L4 (heavy AT/AA): Hind Ataka-V + Igla self-defence.
	["TKV_MI24_IGLA","Mi24_D_TK_EP1","TKA","Mi-24 (Ataka + Igla kit)",32700,4,false,   //--- 22580 x1.45 = 32741 -> 32700
		[["AT9Launcher","Igla_twice"],["4Rnd_AT9_Mi24P","2Rnd_Igla"]]],

	//--- L4 (heavy): Su-25 Ataka-V + GBU-12 precision heavy strike.
	["TKV_SU25_HEAVY","Su25_TK_EP1","TKA","Su-25 (Ataka + GBU kit)",46400,4,false,   //--- 31980 x1.45 = 46371 -> 46400
		[["AT9Launcher","BombLauncherF35"],["4Rnd_AT9_Mi24P","2Rnd_GBU12","2Rnd_GBU12"]]],

	//--- L5 (top AT/AA, airfield-exclusive): Su-25 Kh-29 + R-73 AA top warload.
	["TKV_SU25_WARLORD","Su25_TK_EP1","TKA","Su-25 (full warload kit)",52800,5,true,   //--- 31980 x1.65 = 52767 -> 52800
		[["Ch29Launcher_Su34","R73Launcher_2","S8Launcher"],["6Rnd_Ch29","2Rnd_R73","40Rnd_S8T"]]]
];

_roster
