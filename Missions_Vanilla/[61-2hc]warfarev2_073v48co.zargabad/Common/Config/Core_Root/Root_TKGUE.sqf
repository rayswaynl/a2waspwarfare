Private ["_side"];

_side = "GUER";

//--- Generic.
missionNamespace setVariable [Format["WFBE_%1CREW", _side], 'TK_GUE_Soldier_EP1'];
missionNamespace setVariable [Format["WFBE_%1PILOT", _side], 'TK_GUE_Soldier_EP1'];
missionNamespace setVariable [Format["WFBE_%1SOLDIER", _side], 'TK_GUE_Soldier_EP1'];

//--- Flag texture.
missionNamespace setVariable [Format["WFBE_%1FLAG", _side], '\ca\ca_e\data\flag_tkg_co.paa'];

missionNamespace setVariable [Format["WFBE_%1AMBULANCES", _side], ['V3S_TK_GUE_EP1','V3S_Gue']];
missionNamespace setVariable [Format["WFBE_%1REPAIRTRUCKS", _side], ['WarfareRepairTruck_Gue','V3S_Repair_TK_GUE_EP1']];
missionNamespace setVariable [Format["WFBE_%1SALVAGETRUCK", _side], ['WarfareSalvageTruck_Gue','V3S_Salvage_TK_GUE_EP1']];
missionNamespace setVariable [Format["WFBE_%1SUPPLYTRUCKS", _side], ['WarfareSupplyTruck_Gue','V3S_Supply_TK_GUE_EP1']];

//--- Radio Announcers.
missionNamespace setVariable [Format ["WFBE_%1_RadioAnnouncers", _side], ['WFHQ_TK0_EP1','WFHQ_TK1_EP1','WFHQ_TK2_EP1','WFHQ_TK3_EP1','WFHQ_TK4_EP1']];
missionNamespace setVariable [Format ["WFBE_%1_RadioAnnouncers_Config", _side], 'RadioProtocol_EP1_TK'];

//--- Paratroopers.
missionNamespace setVariable [Format["WFBE_%1PARACHUTELEVEL1", _side],['TK_GUE_Warlord_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AR_EP1','TK_GUE_Bonesetter_EP1']];
missionNamespace setVariable [Format["WFBE_%1PARACHUTELEVEL2", _side],['TK_GUE_Warlord_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AA_EP1','TK_GUE_Soldier_MG_EP1','TK_GUE_Bonesetter_EP1','TK_GUE_Soldier_Sniper_EP1','TK_GUE_Soldier_Sniper_EP1']];
missionNamespace setVariable [Format["WFBE_%1PARACHUTELEVEL3", _side],['TK_GUE_Warlord_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_AA_EP1','TK_GUE_Soldier_AA_EP1','TK_GUE_Soldier_4_EP1','TK_GUE_Soldier_5_EP1','TK_GUE_Soldier_Sniper_EP1','TK_GUE_Soldier_Sniper_EP1']];

missionNamespace setVariable [Format["WFBE_%1PARACARGO", _side], 'UH1H_TK_GUE_EP1'];//--- Paratroopers, Vehicle.
missionNamespace setVariable [Format["WFBE_%1REPAIRTRUCK", _side], 'V3S_Repair_TK_GUE_EP1'];//--- Repair Truck model.
missionNamespace setVariable [Format["WFBE_%1STARTINGVEHICLES", _side], ['V3S_TK_GUE_EP1','Offroad_DSHKM_TK_GUE_EP1']];//--- Starting Vehicles.
missionNamespace setVariable [Format["WFBE_%1PARAAMMO", _side], ['TKBasicAmmunitionBox_EP1','TKBasicWeapons_EP1','TKLaunchers_EP1']];//--- Supply Paradropping, Dropped Ammunition.
missionNamespace setVariable [Format["WFBE_%1PARAVEHICARGO", _side], 'BTR40_TK_GUE_EP1'];//--- Supply Paradropping, Dropped Vehicle.
missionNamespace setVariable [Format["WFBE_%1PARAVEHI", _side], 'UH1H_TK_GUE_EP1'];//--- Supply Paradropping, Vehicle
missionNamespace setVariable [Format["WFBE_%1PARACHUTE", _side], 'ParachuteMediumEast_EP1'];//--- Supply Paradropping, Parachute Model.
missionNamespace setVariable [Format["WFBE_%1SUPPLYTRUCK", _side], 'V3S_Supply_TK_GUE_EP1'];//--- Supply Truck model.

//--- Server only.
if (isServer) then {
	//--- Patrols. TKGUE DIVERSITY FILL (cmdcon41-w3e, Ray-approved). The pools were near-empty + FOOT-ONLY
	//--- (LIGHT 2 / MEDIUM 2 / HEAVY 1, no vehicles) so the w3c motorized road-pick had nothing to prefer.
	//--- Grown to 4-6 varied comps per tier using ONLY known-good TK_GUE classnames already present in the
	//--- mission tree (donors: this Root's STARTINGVEHICLES/PARAVEHICARGO + Root_PMC's TKGUE armor pool +
	//--- Groups/wildcard TK_GUE infantry). Archetypes: foot AT-hunter, MG/sniper team, technical vehicle pair,
	//--- mixed inf+vehicle, AA picket (Ural ZU-23 / Strela) at MEDIUM+HEAVY. Insurgent flavour: light technicals
	//--- (DSHKM/SPG9/PK offroad+pickup) at LIGHT, BTR-40/BRDM at MEDIUM, T-34/T-55 armor at HEAVY.
	missionNamespace setVariable [Format["WFBE_%1_PATROL_LIGHT", _side], [
		//--- MG/sniper scout team (foot).
		['TK_GUE_Soldier_EP1','TK_GUE_Soldier_MG_EP1','TK_GUE_Soldier_Sniper_EP1','TK_GUE_Bonesetter_EP1'],
		//--- foot AT-hunter rifle squad.
		['TK_GUE_Warlord_EP1','TK_GUE_Soldier_AR_EP1','TK_GUE_Soldier_3_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_4_EP1'],
		//--- technical pair: DSHKM offroad + SPG-9 offroad (mounted, road-capable).
		['Offroad_DSHKM_TK_GUE_EP1','Offroad_SPG9_TK_GUE_EP1'],
		//--- mixed: PK pickup + dismounted AT/MG screen.
		['Pickup_PK_TK_GUE_EP1','TK_GUE_Soldier_TL_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_MG_EP1']
	]];

	missionNamespace setVariable [Format["WFBE_%1_PATROL_MEDIUM", _side], [
		//--- foot HAT-hunter command team.
		['TK_GUE_Warlord_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_MG_EP1','TK_GUE_Soldier_HAT_EP1'],
		//--- MANPADS AA picket (foot Strela team).
		['TK_GUE_Soldier_AA_EP1','TK_GUE_Soldier_AA_EP1','TK_GUE_Soldier_TL_EP1','TK_GUE_Bonesetter_EP1'],
		//--- motorized: BTR-40 MG + dismounted AT/HAT screen.
		['BTR40_MG_TK_GUE_EP1','TK_GUE_Soldier_TL_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_HAT_EP1'],
		//--- technical AA picket: Ural ZU-23 + AAT gunner + medic.
		['Ural_ZU23_TK_GUE_EP1','TK_GUE_Soldier_AAT_EP1','TK_GUE_Soldier_TL_EP1','TK_GUE_Bonesetter_EP1'],
		//--- BRDM scout + dismounted AT.
		['BRDM2_TK_GUE_EP1','TK_GUE_Soldier_TL_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_MG_EP1']
	]];

	missionNamespace setVariable [Format["WFBE_%1_PATROL_HEAVY", _side], [
		//--- armor pair: T-34 + T-55 (crewed) with dismounted HAT escort.
		['T55_TK_GUE_EP1','T34_TK_GUE_EP1','TK_GUE_Soldier_HAT_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Bonesetter_EP1'],
		//--- mechanized assault: T-55 + BTR-40 MG + full dismounted squad.
		['T55_TK_GUE_EP1','BTR40_MG_TK_GUE_EP1','TK_GUE_Soldier_TL_EP1','TK_GUE_Soldier_MG_EP1','TK_GUE_Soldier_AT_EP1','TK_GUE_Soldier_HAT_EP1','TK_GUE_Bonesetter_EP1'],
		//--- AA picket at HEAVY: Ural ZU-23 + BRDM + Strela dismounts.
		['Ural_ZU23_TK_GUE_EP1','BRDM2_TK_GUE_EP1','TK_GUE_Soldier_AA_EP1','TK_GUE_Soldier_AAT_EP1','TK_GUE_Soldier_TL_EP1'],
		//--- foot elite AT/sniper strike team (retained legacy entry, expanded).
		['TK_GUE_Soldier_Sniper_EP1','TK_GUE_Soldier_5_EP1','TK_GUE_Soldier_Sniper_EP1','TK_GUE_Soldier_HAT_EP1','TK_GUE_Soldier_AT_EP1']
	]];
	
	//--- AI Loadouts [weapons, magazines, eligible muzzles, {backpack}, {backpack content}].
	missionNamespace setVariable [Format["WFBE_%1_AI_Loadout_0", _side], [
		[['AKS_74_kobra','RPG18','Makarov','Binocular','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','RPG18','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
		 ['AKS_74_kobra','RPG18','Makarov']],
		[['AKS_74_U','RPG18','Makarov','Binocular','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','RPG18','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
		 ['AKS_74_U','RPG18','Makarov']]
	]];	
	missionNamespace setVariable [Format["WFBE_%1_AI_Loadout_1", _side], [
		[['AKS_74_kobra','RPG7V','Makarov','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7V','PG7V','PG7V','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
		 ['AKS_74_kobra','RPG7V','Makarov']],
		[['AKS_74_kobra','RPG7V','Makarov','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7V','PG7V','PG7V','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
		 ['AKS_74_kobra','RPG7V','Makarov']],
		[['SVD','MakarovSD','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','10Rnd_762x54_SVD','HandGrenade_East','HandGrenade_East','8Rnd_9x18_MakarovSD','8Rnd_9x18_MakarovSD','8Rnd_9x18_MakarovSD','8Rnd_9x18_MakarovSD'],
		 ['SVD','MakarovSD']]
	]];
	missionNamespace setVariable [Format["WFBE_%1_AI_Loadout_2", _side], [
		[['AKS_74_pso','RPG7V','Makarov','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7VL','PG7VL','PG7VL','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
		 ['AKS_74_pso','RPG7V','Makarov']],
		[['AKS_74_pso','RPG7V','Makarov','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7VL','PG7VL','PG7VL','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
		 ['AKS_74_pso','RPG7V','Makarov']]
	]];
	missionNamespace setVariable [Format["WFBE_%1_AI_Loadout_3", _side], [
		[['AK_74_GL_kobra','RPG7V','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7VR','PG7VR','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25'],
		 ['AK_74_GL_kobra','RPG7V']],
		[['AK_74_GL_kobra','MetisLauncher','Makarov','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','AT13','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25'],
		 ['AK_74_GL_kobra','MetisLauncher','Makarov']]
	]];
};


//--- Client only.
if (local player) then {
	//--- Default Faction (Buy Menu), this is the faction name defined in core_xxx.sqf files.
	missionNamespace setVariable [Format["WFBE_%1DEFAULTFACTION", _side], 'Takistani Guerilla'];

	//--- Import the needed Gear (Available from the gear menu), multiple gear can be used.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Loadout\Loadout_TKGUE.sqf";
	if ((missionNamespace getVariable "WFBE_C_MODULE_BIS_PMC") > 0) then {(_side) Call Compile preprocessFileLineNumbers "Common\Config\Loadout\Loadout_PMC.sqf"};

	//--- GUER "Insurgents" player overlay (buy-menu pool + per-role gear). Only when the playable faction is on.
	//--- Shared source with Root_GUE_PlayerOverlay.sqf; branched on #ifdef IS_CHERNARUS_MAP_DEPENDENT inside.
	if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0) then {
		Call Compile preprocessFileLineNumbers "Common\Config\Core_Root\Root_GUE_PlayerOverlay.sqf";
	};
};

//--- Default Loadout [weapons, magazines, eligible muzzles, {backpack}, {backpack content}].
missionNamespace setVariable [Format["WFBE_%1_DefaultGear", _side], [
	['AKS_74_kobra','Makarov','Binocular','NVGoggles','ItemCompass','ItemMap','ItemRadio','ItemWatch'],
	['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','HandGrenade_East','HandGrenade_East','HandGrenade_East','SmokeShellRed','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov'],
	['AKS_74_kobra','Makarov']
]];

//--- Squads.
(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Squads\Squad_OA_TKGUE.sqf";

if (WF_A2_CombinedOps) then {
	//--- Artillery.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Artillery\Artillery_CO_GUE.sqf";
	//--- Units.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Units\Units_CO_GUE.sqf";
	//--- Structures.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Structures\Structures_CO_GUE.sqf";
	//--- Upgrades.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Upgrades\Upgrades_CO_GUE.sqf";
} else {
	//--- Artillery.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Artillery\Artillery_OA_TKGUE.sqf";
	//--- Units.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Units\Units_OA_TKGUE.sqf";
	//--- Structures.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Structures\Structures_OA_TKGUE.sqf";
	//--- Upgrades.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Upgrades\Upgrades_OA_TKGUE.sqf";
};

//--- Match Root_GUE's post-units player-pool seed: Units_*_GUE overwrites WFBE_GUERDEPOTUNITS after the
//--- overlay loads, so restore the Takistan GUER player depot immediately instead of waiting for the overlay loop.
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {local player} && {side group player == resistance}) then {
	private ["_pool"];
	WFBE_C_GUER_VBIED_TYPE = "datsun1_civil_2_covered";
	WFBE_C_GUER_SUICIDE_BIKE_TYPE = "TT650_TK_CIV_EP1"; //--- fable/guer-suicide-bike: TK/ZG repoint (mirrors the VBIED_TYPE repoint above).
	_pool = ["TK_GUE_Soldier_EP1","TK_GUE_Bonesetter_EP1","TK_GUE_Soldier_MG_EP1","TK_GUE_Soldier_AT_EP1","TK_GUE_Soldier_AA_EP1","TK_GUE_Soldier_Sniper_EP1","Offroad_DSHKM_TK_GUE_EP1","Pickup_PK_TK_GUE_EP1","V3S_TK_GUE_EP1","BTR40_MG_TK_GUE_EP1","datsun1_civil_2_covered","Ka137_MG_PMC"]; //--- BTR-40 (MG) tier-0 (2026-07-01).
	if ((missionNamespace getVariable ["WFBE_C_GUER_CIVILIAN_DEPOT", 0]) > 0) then {_pool = _pool + ["Old_bike_TK_CIV_EP1","Old_moto_TK_Civ_EP1","Volha_1_TK_CIV_EP1","LandRover_TK_CIV_EP1","Ural_TK_CIV_EP1"]};
	//--- fable/fix-guer-fob: C6 reseed clobbers WFBE_GUERDEPOTUNITS without the overlay's FOB-truck / M113-VBIED
	//--- gating (Root_GUE_PlayerOverlay.sqf:63-65,101-111) - re-apply the same gating here so a FOB truck earned via
	//--- WFBE_GUER_FOB_AVAIL (and the kill-gated M113 VBIED) survive this reseed instead of vanishing until the next
	//--- overlay tier-signature change. Correctness fix restoring already-shipped FOB/M113 content - no flag.
	private ["_c6Kills","_c6M113On","_c6FobAvail","_c6FobTrucks","_c6Fi"];
	_c6Kills = missionNamespace getVariable ["WFBE_GUER_PLAYER_KILLS", 0];
	_c6M113On = _c6Kills >= (missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_KILLS", 25]);
	if (_c6M113On) then {_pool = _pool + [missionNamespace getVariable ["WFBE_C_GUER_VBIED_M113_TYPE", "M113_UN_EP1"]]};
	_c6FobAvail = missionNamespace getVariable ["WFBE_GUER_FOB_AVAIL", [0,0,0]];
	_c6FobTrucks = missionNamespace getVariable ["WFBE_C_GUER_FOB_TRUCKS", []];
	for "_c6Fi" from 0 to ((count _c6FobTrucks) - 1) do {
		if (_c6Fi < (count _c6FobAvail) && {(_c6FobAvail select _c6Fi) > 0}) then {_pool = _pool + [_c6FobTrucks select _c6Fi]};
	};
	if ((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) then {_pool = _pool + [missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_TK_CIV_EP1"]]}; //--- fable/guer-suicide-bike.
	missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", _pool];
};
