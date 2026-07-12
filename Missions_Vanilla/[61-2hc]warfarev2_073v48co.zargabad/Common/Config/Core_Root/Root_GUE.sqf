Private ["_side"];

_side = "GUER";

//--- Generic.
missionNamespace setVariable [Format["WFBE_%1CREW", _side], 'GUE_Soldier_Crew'];
missionNamespace setVariable [Format["WFBE_%1PILOT", _side], 'GUE_Soldier_1'];
missionNamespace setVariable [Format["WFBE_%1SOLDIER", _side], 'GUE_Soldier_1'];

//--- Flag texture.
missionNamespace setVariable [Format["WFBE_%1FLAG", _side], '\ca\data\Flag_napa_co.paa'];

missionNamespace setVariable [Format["WFBE_%1AMBULANCES", _side], ['V3S_TK_GUE_EP1','V3S_Gue']];
//missionNamespace setVariable [Format ["WFBE_%1MASHES", _side], ['MASH']];
missionNamespace setVariable [Format["WFBE_%1REPAIRTRUCKS", _side], ['WarfareRepairTruck_Gue','V3S_Repair_TK_GUE_EP1']];
missionNamespace setVariable [Format["WFBE_%1SALVAGETRUCK", _side], ['WarfareSalvageTruck_Gue','V3S_Salvage_TK_GUE_EP1']];
missionNamespace setVariable [Format["WFBE_%1SUPPLYTRUCKS", _side], ['WarfareSupplyTruck_Gue','V3S_Supply_TK_GUE_EP1']];

//--- Radio Announcers.
missionNamespace setVariable [Format ["WFBE_%1_RadioAnnouncers", _side], ['WFHQ_CZ0','WFHQ_CZ1','WFHQ_CZ2']];
missionNamespace setVariable [Format ["WFBE_%1_RadioAnnouncers_Config", _side], 'RadioProtocolCZ'];

//--- Paratroopers.
missionNamespace setVariable [Format["WFBE_%1PARACHUTELEVEL1", _side],['GUE_Soldier_CO','GUE_Soldier_AT','GUE_Soldier_2','GUE_Soldier_3','GUE_Soldier_AR','GUE_Soldier_Medic']];
missionNamespace setVariable [Format["WFBE_%1PARACHUTELEVEL2", _side],['GUE_Soldier_CO','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AA','GUE_Soldier_MG','GUE_Soldier_Medic','GUE_Soldier_Scout','GUE_Soldier_Sniper']];
missionNamespace setVariable [Format["WFBE_%1PARACHUTELEVEL3", _side],['GUE_Soldier_CO','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AA','GUE_Soldier_AA','GUE_Soldier_AR','GUE_Soldier_Medic','GUE_Soldier_Scout','GUE_Soldier_AT','GUE_Soldier_Sniper']];

missionNamespace setVariable [Format["WFBE_%1PARACARGO", _side], 'Mi17_Civilian'];	//--- Paratroopers, Vehicle.
missionNamespace setVariable [Format["WFBE_%1REPAIRTRUCK", _side], 'WarfareRepairTruck_Gue'];//--- Repair Truck model.
missionNamespace setVariable [Format["WFBE_%1STARTINGVEHICLES", _side], ['TT650_Gue','BRDM2_Gue','Offroad_DSHKM_Gue']];//--- Starting Vehicles. C7: BTR90 (BLUFOR/heavy, not a GUER asset) -> BRDM2_Gue (a registered GUER armoured car).
missionNamespace setVariable [Format["WFBE_%1PARAAMMO", _side], ['RUBasicAmmunitionBox','RUBasicWeaponsBox','RULaunchersBox']];//--- Supply Paradropping, Dropped Ammunition.
missionNamespace setVariable [Format["WFBE_%1PARAVEHICARGO", _side], 'BRDM2_Gue'];//--- Supply Paradropping, Dropped Vehicle.
missionNamespace setVariable [Format["WFBE_%1PARAVEHI", _side], 'Mi17_Civilian'];//--- Supply Paradropping, Vehicle
missionNamespace setVariable [Format["WFBE_%1PARACHUTE", _side], 'ParachuteC'];//--- Supply Paradropping, Parachute Model.
missionNamespace setVariable [Format["WFBE_%1SUPPLYTRUCK", _side], 'WarfareSupplyTruck_Gue'];//--- Supply Truck model.

//--- fable/drones-menu: FPV drone classname for GUER (unlocks the sideJoinedText lookup in fpv.sqf).
if ((missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) > 0) then {
	missionNamespace setVariable [Format ["WFBE_%1FPVDRONE", _side], "AH6X_EP1"];
};

//--- Server only.
if (isServer) then {
	//--- Patrols. GUER revamp (task #17/#23): scary insurgents with technicals, an
	//--- armored element, AT/MANPADS ambushers and foot raiders. EVERY entry carries
	//--- at least one Man-class soldier (Common_RunSidePatrol rejects crew-only teams).
	//--- Archetypes per tier: recon-foot / motorized / technical / mechanized / AT-hunter.
	missionNamespace setVariable [Format["WFBE_%1_PATROL_LIGHT", _side], [
		//--- recon-foot: scout-led raiders.
		['GUE_Soldier_Scout','GUE_Soldier_1','GUE_Soldier_MG','GUE_Soldier_AT','GUE_Soldier_Medic'],
		//--- foot AT-hunter: RPG ambush team.
		['GUE_Commander','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AR','GUE_Soldier_2'],
		//--- technical: DSHKM gun-truck + dismounts.
		['Offroad_DSHKM_Gue','GUE_Soldier_1','GUE_Soldier_3','GUE_Soldier_MG'],
		//--- technical: PK pickup raiding party.
		['Pickup_PK_GUE','GUE_Soldier_1','GUE_Soldier_AT','GUE_Soldier_2'],
		//--- motorized: V3S truckload of fighters.
		['V3S_Gue','GUE_Soldier_1','GUE_Soldier_2','GUE_Soldier_3','GUE_Soldier_MG','GUE_Soldier_AT'],
		//--- saboteur cell: demolition-led foot raiders (twin Sab + RPG/MG screen).
		['GUE_Soldier_Sab','GUE_Soldier_Sab','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_Medic'],
		//--- light mechanized: unarmed BTR-40 troop carrier + AT/MG riders.
		['BTR40_TK_GUE_EP1','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_2','GUE_Soldier_Medic']
	]];

	missionNamespace setVariable [Format["WFBE_%1_PATROL_MEDIUM", _side], [
		//--- technical AT-hunter: SPG-9 recoilless truck + RPG dismounts.
		['Offroad_SPG9_Gue','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_Medic'],
		//--- MANPADS ambush: ZU-23 AAA truck + AA gunners (scary to air).
		['Ural_ZU23_Gue','GUE_Soldier_AA','GUE_Soldier_AA','GUE_Soldier_AT','GUE_Soldier_1'],
		//--- mechanized recon: BTR-40 MG armored car + riders.
		['BTR40_MG_TK_GUE_EP1','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_2','GUE_Soldier_Medic'],
		//--- two-technical column: DSHKM + PK with a sniper overwatch dismount.
		['Offroad_DSHKM_Gue','Pickup_PK_GUE','GUE_Soldier_Sniper','GUE_Soldier_AT','GUE_Soldier_Medic'],
		//--- AT screen: SPG-9 + DSHKM dual-technical with RPG/MANPADS dismounts.
		['Offroad_SPG9_Gue','Offroad_DSHKM_Gue','GUE_Soldier_AT','GUE_Soldier_AA','GUE_Soldier_Medic'],
		//--- grenadier ambush: twin GP-25 GL fire team with sniper overwatch.
		['GUE_Soldier_GL','GUE_Soldier_GL','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_Sniper','GUE_Soldier_Medic']
	]];

	missionNamespace setVariable [Format["WFBE_%1_PATROL_HEAVY", _side], [
		//--- mechanized armor: BRDM-2 + AT/MANPADS escort (NO PMC armored SUV).
		['BRDM2_Gue','GUE_Soldier_AT','GUE_Soldier_AA','GUE_Soldier_MG','GUE_Soldier_Medic','GUE_Soldier_1'],
		//--- heavy mechanized: T-72 + BMP-2 with mounted infantry.
		['T72_Gue','BMP2_Gue','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_Medic'],
		//--- armored AT-hunter: BRDM-2 + SPG-9 technical + RPG gunners.
		['BRDM2_Gue','Offroad_SPG9_Gue','GUE_Soldier_AT','GUE_Soldier_AT','GUE_Soldier_AA','GUE_Soldier_Medic'],
		//--- combined column: T-55 + ZU-23 AAA + sniper-led infantry screen.
		['T55_TK_GUE_EP1','Ural_ZU23_Gue','GUE_Soldier_Sniper','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_Medic'],
		//--- mechanized assault: twin BMP-2 IFVs with mounted infantry.
		['BMP2_Gue','BMP2_Gue','GUE_Soldier_AT','GUE_Soldier_MG','GUE_Soldier_Medic'],
		//--- vintage armor column: T-34 + DSHKM technical + AT/MANPADS screen.
		['T34_TK_GUE_EP1','Offroad_DSHKM_Gue','GUE_Soldier_AT','GUE_Soldier_AA','GUE_Soldier_MG','GUE_Soldier_Medic']
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
		[['AK_74_GL','RPG7V','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7VL','PG7VL','PG7VL','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25'],
		 ['AK_74_GL','RPG7V']],
		[['AK_74_GL','RPG7V','Makarov','Binocular','NVGoggles','ItemRadio','ItemMap'],
		 ['30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','30Rnd_545x39_AK','PG7VL','PG7VL','PG7VL','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','8Rnd_9x18_Makarov','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25','1Rnd_HE_GP25'],
		 ['AK_74_GL','RPG7V','Makarov']]
	]];
};

//--- Client only.
if (local player) then {
	//--- Default Faction (Buy Menu), this is the faction name defined in core_xxx.sqf files.
	missionNamespace setVariable [Format["WFBE_%1DEFAULTFACTION", _side], 'Guerilla'];
	
	//--- Import the needed Gear (Available from the gear menu), multiple gear can be used.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Loadout\Loadout_GUE.sqf";
	
	if (WF_A2_CombinedOps) then {
		(_side) Call Compile preprocessFileLineNumbers "Common\Config\Loadout\Loadout_TKGUE.sqf";
	};

	//--- GUER "Insurgents" player overlay (buy-menu pool + per-role gear). Only when the playable faction is on.
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

if (WF_A2_CombinedOps) then {
	//--- Artillery.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Artillery\Artillery_CO_GUE.sqf";
	//--- Units.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Units\Units_CO_GUE.sqf";
	//--- Squads.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Squads\Squad_GUE.sqf";
	//--- Structures.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Structures\Structures_CO_GUE.sqf";
	//--- Upgrades.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Upgrades\Upgrades_CO_GUE.sqf";
} else {
	//--- Artillery.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Artillery\Artillery_GUE.sqf";
	//--- Units.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Units\Units_GUE.sqf";
	//--- Squads.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Squads\Squad_GUE.sqf";
	//--- Structures.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Structures\Structures_GUE.sqf";
	//--- Upgrades.
	(_side) Call Compile preprocessFileLineNumbers "Common\Config\Core_Upgrades\Upgrades_GUE.sqf";
};

//--- C6 (depot-race fix): Root_GUE_PlayerOverlay.sqf (loaded above in the client block) seeds the GUER
//--- player buy pool into WFBE_GUERDEPOTUNITS, but the Units_*_GUE.sqf load that runs right after
//--- (line ~145/156) calls setVariable [WFBE_GUERDEPOTUNITS, <AI roster>], clobbering the player pool for
//--- a frame until the overlay's tier-watch loop re-sets it (up to 10s later). Re-apply the overlay's
//--- first-tick synchronous seed HERE (after the AI roster load) so the player pool is correct from frame 0.
//--- Gate is identical to the overlay (PLAYERSIDE>0 + local GUER player); worldName-branched to match the
//--- overlay's seed exactly (CH GUE_* roster; TK TK_GUE_*_EP1 roster + datsun VBIED-type repoint). The
//--- existing overlay loop still owns subsequent tier-change re-seeds.
if ((missionNamespace getVariable ["WFBE_C_GUER_PLAYERSIDE", 0]) > 0 && {local player} && {side group player == resistance}) then {
	private ["_pool"];
	if (worldName == "Chernarus") then {
		_pool = ["GUE_Soldier_Sab","GUE_Soldier_Medic","GUE_Soldier_MG","GUE_Soldier_AT","GUE_Soldier_AA","GUE_Soldier_Sniper","Offroad_DSHKM_Gue","V3S_Gue","BTR40_TK_GUE_EP1","hilux1_civil_2_covered","Ka137_MG_PMC"]; //--- BTR-40 tier-0 (2026-07-01).
		if ((missionNamespace getVariable ["WFBE_C_GUER_CIVILIAN_DEPOT", 0]) > 0) then {_pool = _pool + ["TT650_Civ","Tractor","SkodaRed","car_sedan","UralCivil"]};
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
		if ((missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE", 0]) > 0) then {_pool = _pool + [missionNamespace getVariable ["WFBE_C_GUER_SUICIDE_BIKE_TYPE", "TT650_Ins"]]}; //--- fable/guer-suicide-bike.
		missionNamespace setVariable ["WFBE_GUERDEPOTUNITS", _pool];
	} else {
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
};
