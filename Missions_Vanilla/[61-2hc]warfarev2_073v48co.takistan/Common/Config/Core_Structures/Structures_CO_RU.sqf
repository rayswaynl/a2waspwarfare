Private ['_c','_count','_d','_dir','_dis','_n','_s','_side','_t','_v'];

_side = _this;

/* Root Definition */
_MHQ = "BTR90_HQ";
_HQ = "BTR90_HQ_unfolded";
_BAR = if (IS_chernarus_map_dependent) then {"RU_WarfareBBarracks"} else {"TK_WarfareBBarracks_EP1"};
_LVF = if (IS_chernarus_map_dependent) then {"RU_WarfareBLightFactory"} else {"TK_WarfareBLightFactory_EP1"};
_CC = if (IS_chernarus_map_dependent) then {"RU_WarfareBUAVterminal"} else {"TK_WarfareBUAVterminal_EP1"};
_HEAVY = if (IS_chernarus_map_dependent) then {"RU_WarfareBHeavyFactory"} else {"TK_WarfareBHeavyFactory_EP1"};
_AIR = if (IS_chernarus_map_dependent) then {"RU_WarfareBAircraftFactory"} else {"TK_WarfareBAircraftFactory_EP1"};
_SP = if (IS_chernarus_map_dependent) then {"RU_WarfareBVehicleServicePoint"} else {"TK_WarfareBVehicleServicePoint_EP1"};
_AAR = if (IS_chernarus_map_dependent) then {"RU_WarfareBAntiAirRadar"} else {"TK_WarfareBAntiAirRadar_EP1"};
_ARTRAD = if (IS_chernarus_map_dependent) then {"RU_WarfareBArtilleryRadar"} else {"TK_WarfareBArtilleryRadar_EP1"}; //--- Ray 2026-06-26: restored the real BI Warfare artillery-radar model (per-faction, mirrors _AAR). displayName is "Artillery Radar" so the menu label below uses getText again.
_RES = if (IS_chernarus_map_dependent) then {"Land_fortified_nest_small"} else {"Land_fortified_nest_small_EP1"}; //--- reskinned: was Land_Mil_Barracks_i(_EP1) (barracks block); small fortified nest (~8x8m) reads as a depot/reserve, proven buildable defense, small sibling of WFBE_C_DEPOT Land_fortified_nest_big_EP1.

/* Mash used after being deployed */
missionNamespace setVariable [Format["WFBE_%1FARP", _side], 'CampEast_EP1'];

/* Construction Crates */
missionNamespace setVariable [Format["WFBE_%1CONSTRUCTIONSITE", _side], 'TK_WarfareBContructionSite_EP1'];

/* Structures */
_v			= ["Headquarters"];
_n			= [_HQ];
_d			= [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
_c			= [missionNamespace getVariable "WFBE_C_STRUCTURES_HQ_COST_DEPLOY"];
_t			= [if (WF_Debug) then {1} else {30}];
_s			= ["HQSite"];
_dis		= [15];
_dir		= [0];

_v = _v		+ ["Barracks"];
_n = _n		+ [_BAR];
_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
_c = _c		+ [200];
_t = _t		+ [if (WF_Debug) then {1} else {60}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [18];
_dir = _dir	+ [90];

_v = _v		+ ["Light"];
_n = _n		+ [_LVF];
_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
_c = _c		+ [600];
_t = _t		+ [if (WF_Debug) then {1} else {60}];
_s = _s		+ ["MediumSite"];
_dis = _dis	+ [25];
_dir = _dir	+ [90];

_v = _v		+ ["CommandCenter"];
_n = _n		+ [_CC];
_d = _d		+ [localize "STR_WF_CommandCenter"];
_c = _c		+ [1200];
_t = _t		+ [if (WF_Debug) then {1} else {60}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [20];
_dir = _dir	+ [90];

_v = _v		+ ["Heavy"];
_n = _n		+ [_HEAVY];
_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
_c = _c		+ [2800];
_t = _t		+ [if (WF_Debug) then {1} else {60}];
_s = _s		+ ["MediumSite"];
_dis = _dis	+ [25];
_dir = _dir	+ [90];

_v = _v		+ ["Aircraft"];
_n = _n		+ [_AIR];
_d = _d		+ [localize "STR_WF_AircraftFactory"];
_c = _c		+ [4400];
_t = _t		+ [if (WF_Debug) then {1} else {60}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [31];
_dir = _dir	+ [90];

_v = _v		+ ["ServicePoint"];
_n = _n		+ [_SP];
_d = _d		+ [localize "STR_WF_MAIN_ServicePoint"];
_c = _c		+ [700];
_t = _t		+ [if (WF_Debug) then {1} else {60}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [21];
_dir = _dir	+ [90];

if ((missionNamespace getVariable "WFBE_C_STRUCTURES_ANTIAIRRADAR") > 0) then {
	_v = _v		+ ["AARadar"];
	_n = _n		+ [_AAR];
	_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
	_c = _c		+ [3200];
	_t = _t		+ [if (WF_Debug) then {1} else {60}];
	_s = _s		+ ["MediumSite"];
	_dis = _dis	+ [21];
	_dir = _dir	+ [90];
};

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_COUNTERBATTERY", 0]) > 0) then {
	_v = _v		+ ["CBRadar"];
	_n = _n		+ [_ARTRAD];	//--- b760: real per-faction *_WarfareBArtilleryRadar (was Land_Antenna placeholder); keeps the counter-battery label below.
	_d = _d		+ [localize "STR_WF_UPGRADE_CBRadar"];
	_c = _c		+ [2400];
	_t = _t		+ [if (WF_Debug) then {1} else {60}];
	_s = _s		+ ["SmallSite"];
	_dis = _dis	+ [21];	//--- b760: bumped 16->21 for the larger real *_WarfareBArtilleryRadar dish (matches AAR/ArtilleryRadar build-clear); stays SmallSite.
	_dir = _dir	+ [90];
};

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_RADIOTOWER", 0]) > 0) then { //--- Radio Tower: buildable comms structure. Land_Vysilac_FM (owner-chosen lattice broadcast tower 2026-07-10) - base-A2 CAStructures, all-map safe.
	_v = _v		+ ["RadioTower"];
	_n = _n		+ ["Land_Vysilac_FM"];
	_d = _d		+ ["Radio Tower"];
	_c = _c		+ [1800];
	_t = _t		+ [if (WF_Debug) then {1} else {60}];
	_s = _s		+ ["SmallSite"];
	_dis = _dis	+ [16];
	_dir = _dir	+ [90];
};

if ((missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	_v = _v		+ ["Bank"];
	//--- cmdcon42-g (part C): WFBE_C_BANK_MODEL_V2 swaps the Bank model to the office building
	//--- (WFBE_C_BANK_MODEL_V2_CLASS, default Land_A_Office01_EP1). Flag=0 -> legacy bunker.
	//--- Bank logic keys on the 'Bank' rlType tag, so it is model-agnostic. WFBE_C_DEPOT untouched.
	_n = _n		+ [if ((missionNamespace getVariable ["WFBE_C_BANK_MODEL_V2", 1]) > 0) then {missionNamespace getVariable ["WFBE_C_BANK_MODEL_V2_CLASS", "Land_A_Office01_EP1"]} else {"Land_fortified_nest_big_EP1"}];
	_d = _d		+ ["Bank Rossii"];
	_c = _c		+ [9500];
	_t = _t		+ [if (WF_Debug) then {1} else {300}];
	_s = _s		+ ["MediumSite"];
	_dis = _dis	+ [30];
	_dir = _dir	+ [0];
};

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_ARTILLERYRADAR", 0]) > 0) then {
	_v = _v		+ ["ArtilleryRadar"];
	_n = _n		+ [_ARTRAD];
	_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];	//--- b760: real *_WarfareBArtilleryRadar displayName is "Artillery Radar"; back to getText like every other structure.
	_c = _c		+ [2400];
	_t = _t		+ [if (WF_Debug) then {1} else {60}];
	_s = _s		+ ["MediumSite"];
	_dis = _dis	+ [21];
	_dir = _dir	+ [90];
};

if ((missionNamespace getVariable ["WFBE_C_STRUCTURES_RESERVE", 0]) > 0) then {
	_v = _v		+ ["Reserve"];
	_n = _n		+ [_RES];
	_d = _d		+ ["Reserve"];
	_c = _c		+ [2000];
	_t = _t		+ [if (WF_Debug) then {1} else {60}];
	_s = _s		+ ["MediumSite"];
	_dis = _dis	+ [30];	//--- walled-yard walls reach ±24 m
	_dir = _dir	+ [90];
};

for [{_count = count _v - 1},{_count >= 0},{_count = _count - 1}] do {
	missionNamespace setVariable [Format["WFBE_%1%2TYPE",_side,_v select _count],_count];
};

{
	missionNamespace setVariable [Format ["%1%2",_side, _x select 0], _x select 1];
} forEach [["HQ",_HQ],["BAR",_BAR],["LVF",_LVF],["CC",_CC],["HEAVY",_HEAVY],["AIR",_AIR],["SP",_SP],["AAR",_AAR],["CBR",_ARTRAD],["RT","Land_Vysilac_FM"],["BANK",(if ((missionNamespace getVariable ["WFBE_C_BANK_MODEL_V2", 1]) > 0) then {missionNamespace getVariable ["WFBE_C_BANK_MODEL_V2_CLASS", "Land_A_Office01_EP1"]} else {"Land_fortified_nest_big_EP1"})],["ARTRAD",_ARTRAD],["RES",_RES]]; //--- cmdcon42-g (part C): BANK anchor model matches the flag-selected Bank structure model above (WFBE_C_BANK_MODEL_V2). Land_telek1 rejected: likely absent

missionNamespace setVariable [Format["WFBE_%1MHQNAME", _side], _MHQ];
missionNamespace setVariable [Format["WFBE_%1STRUCTURES", _side], _v];
missionNamespace setVariable [Format["WFBE_%1STRUCTURENAMES", _side], _n];
missionNamespace setVariable [Format["WFBE_%1STRUCTUREDESCRIPTIONS", _side], _d];
missionNamespace setVariable [Format["WFBE_%1STRUCTURECOSTS", _side], _c];
missionNamespace setVariable [Format["WFBE_%1STRUCTURETIMES", _side], _t];
missionNamespace setVariable [Format["WFBE_%1STRUCTUREDISTANCES", _side], _dis];
missionNamespace setVariable [Format["WFBE_%1STRUCTUREDIRECTIONS", _side], _dir];
missionNamespace setVariable [Format["WFBE_%1STRUCTURESCRIPTS", _side], _s];

/* Defenses */
_n			= ["RU_WarfareBMGNest_PK"];
_n = _n		+ ["SearchLight_TK_EP1"];
_n = _n		+ ["KORD_TK_EP1"];
_n = _n		+ ["KORD_high_TK_EP1"];
_n = _n		+ ["AGS_TK_EP1"];
_n = _n		+ ["SPG9_TK_INS_EP1"];
_n = _n		+ ["Metis_TK_EP1"];
_n = _n		+ ["Igla_AA_pod_TK_EP1"];
_n = _n		+ ["ZU23_TK_EP1"];
_n = _n		+ ["2b14_82mm_TK_EP1"];
_n = _n		+ ["D30_TK_EP1"];
_n = _n		+ ["Land_HBarrier3"];
_n = _n		+ ["Land_HBarrier5"];
_n = _n		+ ["Land_HBarrier_large"];
_n = _n		+ ["TK_WarfareBBarrier5x_EP1"];
_n = _n		+ ["TK_WarfareBBarrier10x_EP1"];
_n = _n		+ ["TK_WarfareBBarrier10xTall_EP1"];

_n = _n		+ ["MASH_EP1"];
_n = _n		+ ["Land_fort_bagfence_long"];
_n = _n		+ ["Land_fort_bagfence_corner"];
_n = _n		+ ["Land_fort_bagfence_round"];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_fortified_nest_small"} else {"Land_fortified_nest_small_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_fort_rampart"} else {"Land_fort_rampart_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_fort_artillery_nest"} else {"Land_fort_artillery_nest_EP1"}];
_n = _n		+ ["Hhedgehog_concreteBig"];
_n = _n		+ ["Hedgehog_EP1"];

//_____________SPAWNMARKER____________
_n = _n		+ ["Sr_border"];
_n = _n		+ ["HeliH"];
_n = _n		+ ["HeliHRescue"];
_n = _n		+ ["HeliHCivil"];

_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNet_EAST"} else {"Land_CamoNet_EAST_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNetVar_EAST"} else {"Land_CamoNetVar_EAST_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNetB_EAST"} else {"Land_CamoNetB_EAST_EP1"}];
_n = _n		+ ["Sign_Danger"];
_n = _n		+ ["Fort_RazorWire"];
//_n = _n		+ ["Land_Ind_IlluminantTower"];
_n = _n		+ ["Concrete_Wall_EP1"];
_n = _n		+ ["Land_Campfire"];
_n = _n		+ ["RUOrdnanceBox"];
_n = _n		+ ["RUVehicleBox"];
_n = _n		+ ["RUBasicAmmunitionBox"];
_n = _n		+ ["RUBasicWeaponsBox"];
_n = _n		+ ["RULaunchersBox"];
_n = _n		+ ["RUSpecialWeaponsBox"];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"INS_WarfareBVehicleServicePoint"} else {"TK_WarfareBVehicleServicePoint_Base_EP1"}];

//--- WDDM commander positions (Stage 1): build-menu anchors; composition spawned by Server_ConstructPosition.sqf
_n = _n		+ ["Land_Ind_BoardsPack1"];	//--- AA Position (Light)
_n = _n		+ ["Land_CncBlock_Stripes"];			//--- AA Position (Heavy)
_n = _n		+ ["Land_Barrel_sand"];	//--- Artillery (Light)
_n = _n		+ ["Land_Ind_BoardsPack2"];	//--- Artillery (Heavy)
_n = _n		+ ["Land_WoodenRamp"];		//--- Mixed Position (Light)
_n = _n		+ ["RoadCone"];				//--- Mixed Position (Heavy)
_n = _n		+ ["Paleta1"];				//--- Base Wall - Straight
_n = _n		+ ["Paleta2"];				//--- Base Wall - Corner
_n = _n		+ ["Land_Ind_Timbers"];		//--- Base Wall - Gate
if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) > 0) then {
	_n = _n + ["Land_Pneu"];			//--- Site Clearance (commander only)
};

/* Class used for AI, AI will attempt to build those */
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MG", _side], ['KORD_high_TK_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_GL", _side], ['AGS_TK_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_AAPOD", _side], ['Igla_AA_pod_TK_EP1','ZU23_TK_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_ATPOD", _side], ['Metis_TK_EP1','SPG9_TK_INS_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_CANNON", _side], ['D30_TK_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MASH", _side], ['MASH_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MORTAR", _side], ['2b14_82mm_TK_EP1']];

//======================================================================================
//--- cmdcon42-g: DEFENSES/FORTIFICATIONS MENU v2 (WFBE_C_DEFMENU_V2). EAST / RU list.
//--- Legacy `_n` above is UNTOUCHED. This block mutates it only when the flag is on.
//--- Flag=0 -> exact legacy list. Removes struck entries (SearchLight = permanent-daylight
//--- server; Land_Campfire = decoration). Adds Watchtower + Hedgehog-line + Flak-tower anchors.
//======================================================================================
if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {
	_n = _n - ["SearchLight_TK_EP1"];	//--- permanent-daylight clamp -> zero function
	_n = _n - ["Land_Campfire"];		//--- decoration only
	_n = _n + ["Land_Fort_Watchtower_EP1"];	//--- elevated overwatch buildable (IN-TREE)
	_n = _n + ["Misc_cargo_cont_small"];	//--- Hedgehog Line anchor (AT obstacle)
	if ((missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER", 1]) > 0) then {
		_n = _n + ["Land_Ind_TankSmall"];	//--- Flak Tower anchor (elevated AA + AI gunner)
	};
	//--- fable/wddm-functional-defenses: FORTIFICATION PACK (Ray: "Fortifications! Not fortresses -
	//--- useful items like a row of concrete walls, or a way to block LoS to your base... larger
	//--- assets basically."). Five PASSIVE anchor-composition buildables; own flag so the pack can be
	//--- toggled independently. Anchors -> WFBE_NEURODEF_FORTIF_* (Init_Defenses.sqf).
	if ((missionNamespace getVariable ["WFBE_C_DEF_FORTIF_PACK", 0]) > 0) then {
		_n = _n + ["Misc_cargo_cont_net1"];		//--- Wall Row (Concrete, ~22 m)
		_n = _n + ["Misc_cargo_cont_net2"];		//--- Wall Corner (Concrete, L-section)
		_n = _n + ["Misc_cargo_cont_net3"];		//--- LoS Screen (Tall, ~43 m)
		_n = _n + ["Misc_cargo_cont_tiny"];		//--- HESCO Line (~39 m)
		_n = _n + ["Misc_concrete_High"];		//--- Gate Complex (drive-through mouth)
	};
};

missionNamespace setVariable [Format["WFBE_%1DEFENSENAMES", _side], _n];