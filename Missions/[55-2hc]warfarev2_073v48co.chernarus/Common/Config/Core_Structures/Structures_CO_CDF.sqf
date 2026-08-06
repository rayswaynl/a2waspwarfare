Private ['_c','_count','_d','_dir','_dis','_n','_s','_side','_t','_v'];

_side = _this;

/* Root Definition */
_MHQ = "BMP2_HQ_CDF";
_HQ = "BMP2_HQ_CDF_unfolded";
_BAR = "CDF_WarfareBBarracks";
_LVF = "CDF_WarfareBLightFactory";
_CC = "CDF_WarfareBUAVterminal";
_HEAVY = "CDF_WarfareBHeavyFactory";
_AIR = "CDF_WarfareBAircraftFactory";
_SP = "CDF_WarfareBVehicleServicePoint";
_AAR = "CDF_WarfareBAntiAirRadar";

/* Mash used after being deployed */
missionNamespace setVariable [Format["WFBE_%1FARP", _side], 'Camp'];

/* Construction Crates */
missionNamespace setVariable [Format["WFBE_%1CONSTRUCTIONSITE", _side], 'CDF_WarfareBContructionSite'];

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
_t = _t		+ [if (WF_Debug) then {1} else {70}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [18];
_dir = _dir	+ [90];

_v = _v		+ ["Light"];
_n = _n		+ [_LVF];
_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
_c = _c		+ [600];
_t = _t		+ [if (WF_Debug) then {1} else {90}];
_s = _s		+ ["MediumSite"];
_dis = _dis	+ [25];
_dir = _dir	+ [90];

_v = _v		+ ["CommandCenter"];
_n = _n		+ [_CC];
_d = _d		+ [localize "STR_WF_CommandCenter"];
_c = _c		+ [1200];
_t = _t		+ [if (WF_Debug) then {1} else {110}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [20];
_dir = _dir	+ [90];

_v = _v		+ ["Heavy"];
_n = _n		+ [_HEAVY];
_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
_c = _c		+ [2800];
_t = _t		+ [if (WF_Debug) then {1} else {130}];
_s = _s		+ ["MediumSite"];
_dis = _dis	+ [25];
_dir = _dir	+ [90];

_v = _v		+ ["Aircraft"];
_n = _n		+ [_AIR];
_d = _d		+ [localize "STR_WF_AircraftFactory"];
_c = _c		+ [4400];
_t = _t		+ [if (WF_Debug) then {1} else {150}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [31];
_dir = _dir	+ [90];

_v = _v		+ ["ServicePoint"];
_n = _n		+ [_SP];
_d = _d		+ [localize "STR_WF_MAIN_ServicePoint"];
_c = _c		+ [700];
_t = _t		+ [if (WF_Debug) then {1} else {70}];
_s = _s		+ ["SmallSite"];
_dis = _dis	+ [21];
_dir = _dir	+ [90];

if ((missionNamespace getVariable "WFBE_C_STRUCTURES_ANTIAIRRADAR") > 0) then {
	_v = _v		+ ["AARadar"];
	_n = _n		+ [_AAR];
	_d = _d		+ [getText (configFile >> "CfgVehicles" >> (_n select (count _n - 1)) >> "displayName")];
	_c = _c		+ [3200];
	_t = _t		+ [if (WF_Debug) then {1} else {280}];
	_s = _s		+ ["MediumSite"];
	_dis = _dis	+ [21];
	_dir = _dir	+ [90];
};

for [{_count = count _v - 1},{_count >= 0},{_count = _count - 1}] do {
	missionNamespace setVariable [Format["WFBE_%1%2TYPE",_side,_v select _count],_count];
};

{
	missionNamespace setVariable [Format ["%1%2",_side, _x select 0], _x select 1];
} forEach [["HQ",_HQ],["BAR",_BAR],["LVF",_LVF],["CC",_CC],["HEAVY",_HEAVY],["AIR",_AIR],["SP",_SP],["AAR",_AAR]];

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
_n			= ["CDF_WarfareBMGNest_PK"];
_n = _n		+ ["DSHkM_Mini_TriPod_CDF"];	
_n = _n		+ ["DSHKM_CDF"];
_n = _n		+ ["SearchLight_CDF"];
_n = _n		+ ["AGS_CDF"];
_n = _n		+ ["SPG9_CDF"];
_n = _n		+ ["ZU23_CDF"];
_n = _n		+ ["2b14_82mm_CDF"];
_n = _n		+ ["D30_CDF"];
_n = _n		+ ["Land_HBarrier3"];
_n = _n		+ ["Land_HBarrier5"];
_n = _n		+ ["Land_HBarrier_large"];
_n = _n		+ ["Base_WarfareBBarrier5x"];
_n = _n		+ ["Base_WarfareBBarrier10x"];
_n = _n		+ ["Base_WarfareBBarrier10xTall"];
_n = _n		+ ["MASH_EP1"];
_n = _n		+ ["Land_fort_bagfence_long"];
_n = _n		+ ["Land_fort_bagfence_corner"];
_n = _n		+ ["Land_fort_bagfence_round"];
_n = _n		+ ["Land_Misc_Cargo2B"];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_fortified_nest_small"} else {"Land_fortified_nest_small_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_fort_rampart"} else {"Land_fort_rampart_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_fort_artillery_nest"} else {"Land_fort_artillery_nest_EP1"}];
_n = _n		+ ["Hhedgehog_concreteBig"];
_n = _n		+ ["Hedgehog_EP1"];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNet_NATO"} else {"Land_CamoNet_NATO_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNetVar_NATO"} else {"Land_CamoNetVar_NATO_EP1"}];
_n = _n		+ [if (IS_chernarus_map_dependent) then {"Land_CamoNetB_NATO"} else {"Land_CamoNetB_NATO_EP1"}];
_n = _n		+ ["Sign_Danger"];
_n = _n		+ ["HeliH"];
_n = _n		+ ["Fort_RazorWire"];
_n = _n		+ ["Land_Ind_IlluminantTower"];
_n = _n		+ ["Concrete_Wall_EP1"];
_n = _n		+ ["Land_Campfire"];
_n = _n		+ ["RUOrdnanceBox"];
_n = _n		+ ["RUVehicleBox"];
_n = _n		+ ["RUBasicAmmunitionBox"];
_n = _n		+ ["RUBasicWeaponsBox"];
_n = _n		+ ["RULaunchersBox"];
_n = _n		+ ["RUSpecialWeaponsBox"];

/* Class used for AI, AI will attempt to build those */
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MG", _side], ['DSHKM_CDF']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_GL", _side], ['AGS_CDF']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_AAPOD", _side], ['ZU23_CDF']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_ATPOD", _side], ['SPG9_CDF']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_CANNON", _side], ['D30_CDF']];
missionNamespace setVariable [Format["WFBE_%1DEFENSES_MASH", _side], ['MASH']];

if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) > 0) then {
	_n = _n + ["Land_Pneu"];			//--- Site Clearance (commander only)
};

//======================================================================================
//--- cmdcon42-g parity (2026-08-04, owner in-game report "items still missing"): CDF was the ONLY
//--- faction file that never received the DEFENSES/FORTIFICATIONS MENU v2 block - US/RU/GUE/OA_TKA
//--- all have it, so Chernarus-WEST players were missing Watchtower, Hedgehog Line, Flak Tower and
//--- the 5-item Fortification Pack that exist on every other side/terrain. Mirrors
//--- Structures_CO_US.sqf (same _side = "WEST", same anchors) minus the BAF-tripod removals CDF
//--- never listed. Legacy `_n` above is untouched; flag=0 registers the exact legacy list.
//======================================================================================
if ((missionNamespace getVariable ["WFBE_C_DEFMENU_V2", 1]) > 0) then {
	_n = _n - ["SearchLight_CDF"];	//--- permanent-daylight clamp -> zero function
	_n = _n - ["Land_Campfire"];		//--- decoration only
	_n = _n + ["Land_Fort_Watchtower_EP1"];	//--- elevated overwatch buildable (IN-TREE)
	_n = _n + ["Misc_cargo_cont_small"];	//--- Hedgehog Line anchor -> WFBE_NEURODEF_HEDGEHOGLINE
	if ((missionNamespace getVariable ["WFBE_C_DEF_FLAKTOWER", 1]) > 0) then {
		_n = _n + ["Land_Ind_TankSmall"];	//--- anchor -> WFBE_NEURODEF_FLAKTOWER_WEST
	};
	if ((missionNamespace getVariable ["WFBE_C_DEF_FORTIF_PACK", 0]) > 0) then {
		_n = _n + ["Misc_cargo_cont_net1"];		//--- Wall Row (Concrete, ~22 m)
		_n = _n + ["Misc_cargo_cont_net2"];		//--- Wall Corner (Concrete, L-section)
		_n = _n + ["Misc_cargo_cont_net3"];		//--- LoS Screen (Tall, ~43 m)
		_n = _n + ["Misc_cargo_cont_tiny"];		//--- HESCO Line (~39 m)
		_n = _n + ["Misc_concrete_High"];		//--- Gate Complex (drive-through mouth)
	};
};

missionNamespace setVariable [Format["WFBE_%1DEFENSENAMES", _side], _n];