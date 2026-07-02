Private ['_c','_count','_d','_dir','_dis','_n','_s','_side','_t','_v'];

_side = _this;

/* Root Definition */
_MHQ = if (IS_chernarus_map_dependent) then {'LAV25_HQ'} else {'LAV25_HQ'};
_HQ = if (IS_chernarus_map_dependent) then {"LAV25_HQ_unfolded"} else {"M1130_HQ_unfolded_EP1"};
_BAR = if (IS_chernarus_map_dependent) then {"USMC_WarfareBBarracks"} else {"US_WarfareBBarracks_EP1"};
_LVF = if (IS_chernarus_map_dependent) then {"USMC_WarfareBLightFactory"} else {"US_WarfareBLightFactory_EP1"};
_CC = if (IS_chernarus_map_dependent) then {"USMC_WarfareBUAVterminal"} else {"US_WarfareBUAVterminal_EP1"};
_HEAVY = if (IS_chernarus_map_dependent) then {"USMC_WarfareBHeavyFactory"} else {"US_WarfareBHeavyFactory_EP1"};
_AIR = if (IS_chernarus_map_dependent) then {"USMC_WarfareBAircraftFactory"} else {"US_WarfareBAircraftFactory_EP1"};
_SP = if (IS_chernarus_map_dependent) then {"USMC_WarfareBVehicleServicePoint"} else {"US_WarfareBVehicleServicePoint_EP1"};
_AAR = if (IS_chernarus_map_dependent) then {"USMC_WarfareBAntiAirRadar"} else {"US_WarfareBAntiAirRadar_EP1"};
_ARTRAD = if (IS_chernarus_map_dependent) then {"USMC_WarfareBArtilleryRadar"} else {"US_WarfareBArtilleryRadar_EP1"}; //--- Ray 2026-06-26: restored the real BI Warfare artillery-radar model (per-faction, mirrors _AAR). displayName is "Artillery Radar" so the menu label below uses getText again.
_RES = if (IS_chernarus_map_dependent) then {"Land_fortified_nest_small"} else {"Land_fortified_nest_small_EP1"}; //--- reskinned: was Land_Mil_Barracks_i(_EP1) (barracks block); small fortified nest (~8x8m) reads as a depot/reserve, proven buildable defense, small sibling of WFBE_C_DEPOT Land_fortified_nest_big_EP1.

/* Mash used after being deployed */
missionNamespace setVariable [Format["WFBE_%1FARP", _side], 'Camp_EP1'];

/* Construction Crates */
missionNamespace setVariable [Format["WFBE_%1CONSTRUCTIONSITE", _side], 'US_WarfareBContructionSite_EP1'];

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

if ((missionNamespace getVariable ["WFBE_C_ECONOMY_BANK", 0]) > 0) then {
	_v = _v		+ ["Bank"];
	_n = _n		+ ["Land_fortified_nest_big_EP1"];	//--- was Land_Mil_hangar_EP1 (giant ~36x18 aircraft hangar). Swapped to the EP1 fortified-nest compound (~16x16): PROVEN-loadable = it is WFBE_C_DEPOT (Core_Models\CombinedOps.sqf:10 / Arrowhead.sqf:10) and a live cursorTarget (WASP\actions\AddActions.sqf:15); EP1 installed; smaller + reads as fortified vault, distinct from Reserve (Land_Mil_Barracks_i).
	_d = _d		+ ["Federal Reserve"];
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
} forEach [["HQ",_HQ],["BAR",_BAR],["LVF",_LVF],["CC",_CC],["HEAVY",_HEAVY],["AIR",_AIR],["SP",_SP],["AAR",_AAR],["CBR",_ARTRAD],["BANK","Land_fortified_nest_big_EP1"],["ARTRAD",_ARTRAD],["RES",_RES]];	//--- BANK anchor model matches the Bank structure model above (was Land_Mil_hangar_EP1).

missionNamespace setVariable [Format["WFBE_%1MHQNAME", _side], _MHQ];
missionNamespace setVariable [Format["WFBE_%1STRUCTURES", _side], _v];
missionNamespace setVariable [Format["WFBE_%1STRUCTURENAMES", _side], _n];
missionNamespace setVariable [Format["WFBE_%1STRUCTUREDESCRIPTIONS", _side], _d];
missionNamespace setVariable [Format["WFBE_%1STRUCTURECOSTS", _side], _c];
missionNamespace setVariable [Format["WFBE_%1STRUCTURETIMES", _side], _t];
missionNamespace setVariable [Format["WFBE_%1STRUCTUREDISTANCES", _side], _dis];
missionNamespace setVariable [Format["WFBE_%1STRUCTUREDIRECTIONS", _side], _dir];
missionNamespace setVariable [Format["WFBE_%1STRUCTURESCRIPTS", _side], _s];

_n			= ["WarfareBMGNest_M240_US_EP1"];
_n = _n		+ ["M2HD_mini_TriPod_US_EP1"];
_n = _n		+ ["SearchLight_US_EP1"];
_n = _n		+ ["M2StaticMG_US_EP1"];
_n = _n		+ ["BAF_GPMG_Minitripod_W"];
_n = _n		+ ["BAF_GMG_Tripod_W"];
_n = _n		+ ["BAF_L2A1_Minitripod_W"];
_n = _n		+ ["BAF_L2A1_Tripod_W"];
_n = _n		+ ["MK19_TriPod_US_EP1"];
_n = _n		+ ["TOW_TriPod_US_EP1"];
_n = _n		+ ["Stinger_Pod_US_EP1"];
_n = _n		+ ["M252_US_EP1"];
_n = _n		+ ["M119_US_EP1"];
_n = _n		+ ["Land_HBarrier3"];
_n = _n		+ ["Land_HBarrier5"];
_n = _n		+ ["Land_HBarrier_large"];
_n = _n		+ ["US_WarfareBBarrier5x_EP1"];
_n = _n		+ ["US_WarfareBBarrier10x_EP1"];
_n = _n		+ ["US_WarfareBBarrier10xTall_EP1"];
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


_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNet_NATO"} else {"Land_CamoNet_NATO_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNetVar_NATO"} else {"Land_CamoNetVar_NATO_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNetB_NATO"} else {"Land_CamoNetB_NATO_EP1"}];
_n = _n		+ ["Sign_Danger"];
_n = _n		+ ["Fort_RazorWire"];
//_n = _n		+ ["Land_Ind_IlluminantTower"];
_n = _n		+ ["Concrete_Wall_EP1"];

_n = _n		+ ["Land_Campfire"];
_n = _n		+ ["USOrdnanceBox_EP1"];
_n = _n		+ ["USVehicleBox_EP1"];
_n = _n		+ ["USBasicAmmunitionBox_EP1"];
_n = _n		+ ["USBasicWeapons_EP1"];
_n = _n		+ ["USLaunchers_EP1"];
_n = _n		+ ["USSpecialWeapons_EP1"];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"CDF_WarfareBVehicleServicePoint"} else {"US_WarfareBVehicleServicePoint_Base_EP1"}];

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
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MG", _side], ['M2StaticMG_US_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_GL", _side], ['MK19_TriPod_US_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_AAPOD", _side], ['Stinger_Pod_US_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_ATPOD", _side], ['TOW_TriPod_US_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_CANNON", _side], ['M119_US_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MASH", _side], ['MASH_EP1']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MORTAR", _side], ['M252_US_EP1']];

//======================================================================================
//--- cmdcon42-g: DEFENSES/FORTIFICATIONS MENU v2 (WFBE_C_DEFMENU_V2). WEST / US list.
//--- The legacy `_n` above (lines ~161-226) is UNTOUCHED. This block mutates a COPY only
//--- when the flag is on, then registers it. Flag=0 -> exact legacy list registered below.
//--- Removes: dead BAF tripods (no data array -> already invisible; pruned for cleanliness),
//---   SearchLight (permanent-daylight server), Land_Campfire (decoration).
//--- Adds: Watchtower (buildable overwatch), Flak Tower anchor (sub-flag WFBE_C_DEF_FLAKTOWER),
//---   Hedgehog line anchor (one-click AT obstacle). Camo-net recategorisation + WEST cheap-AT
//---   reprice are data-only and live in Core_US.sqf (also flag-gated there).
//======================================================================================
if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {
	//--- REMOVE dead / struck entries.
	_n = _n - ["BAF_GPMG_Minitripod_W","BAF_GMG_Tripod_W","BAF_L2A1_Minitripod_W","BAF_L2A1_Tripod_W"];
	_n = _n - ["SearchLight_US_EP1"];	//--- permanent-daylight clamp -> zero function
	_n = _n - ["Land_Campfire"];		//--- decoration only
	//--- ADD gap-fill buildables. Watchtower: elevated overwatch (Land_Fort_Watchtower_EP1 = WFBE_C_CAMP, IN-TREE).
	_n = _n + ["Land_Fort_Watchtower_EP1"];
	//--- Hedgehog line: one-click 4x Hedgehog_EP1 AT obstacle (anchor -> WFBE_NEURODEF_HEDGEHOGLINE).
	_n = _n + ["Misc_cargo_cont_small"];
	//--- Flak Tower (elevated AA + pooled AI gunner) — own sub-flag so it can be pulled independently.
	if ((missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER", 1]) > 0) then {
		_n = _n + ["Land_Ind_TankSmall"];	//--- anchor -> WFBE_NEURODEF_FLAKTOWER_WEST/EAST
	};
};

missionNamespace setVariable [Format["WFBE_%1DEFENSENAMES", _side], _n];