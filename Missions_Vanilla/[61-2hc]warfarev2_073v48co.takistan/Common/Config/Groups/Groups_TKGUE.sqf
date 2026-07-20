/*
	Groups (Used in towns).
*/

Private ["_faction","_k","_l","_side","_u"];
_l = [];//--- Unit list
_k = [];//--- Type used by AI.

_side = "GUER";
_faction = "TKGUE";

_k = _k + ["Squad"];
_u		= ["TK_GUE_Warlord_EP1"];
_u = _u + ["TK_GUE_Soldier_3_EP1"];
_u = _u + ["TK_GUE_Soldier_AR_EP1"];
_u = _u + ["TK_GUE_Soldier_AR_EP1"];
_u = _u + ["TK_GUE_Soldier_MG_EP1"];

_u = _u + ["TK_GUE_Soldier_4_EP1"];
_u = _u + ["TK_GUE_Soldier_5_EP1"];
_u = _u + ["TK_GUE_Soldier_EP1"];
_l = _l + [_u];

_k = _k + ["Squad_Advanced"];
_u		= ["TK_GUE_Soldier_EP1"];
_u = _u + ["TK_GUE_Soldier_4_EP1"];
_u = _u + ["TK_GUE_Soldier_4_EP1"];
_u = _u + ["TK_GUE_Soldier_MG_EP1"];
_u = _u + ["TK_GUE_Soldier_AR_EP1"];

_u = _u + ["TK_GUE_Soldier_3_EP1"];
_u = _u + ["TK_GUE_Soldier_5_EP1"];
_u = _u + ["TK_GUE_Soldier_3_EP1"];
_l = _l + [_u];

_k = _k + ["Team"];
_u		= ["TK_GUE_Warlord_EP1"];
_u = _u + ["TK_GUE_Soldier_AR_EP1"];
_u = _u + ["TK_GUE_Bonesetter_EP1"];
_u = _u + ["TK_GUE_Soldier_5_EP1"];
_u = _u + ["TK_GUE_Soldier_4_EP1"];

_l = _l + [_u];
//--- B757 garrison variety: warlord retinue.
_k = _k + ["Team"];
_u        = ["TK_GUE_Warlord_EP1"];
_u = _u + ["TK_GUE_Soldier_HAT_EP1"];
_u = _u + ["TK_GUE_Soldier_Sniper_EP1"];
_u = _u + ["TK_GUE_Bonesetter_EP1"];
_l = _l + [_u];


_k = _k + ["Team_MG"];
_u =      ["TK_GUE_Soldier_MG_EP1"];
_u = _u + ["TK_GUE_Soldier_MG_EP1"];

_l = _l + [_u];


_k = _k + ["Team_AT"];
_u =  ["TK_GUE_Soldier_AT_EP1"];
_u = _u + ["TK_GUE_Soldier_HAT_EP1"];
_u = _u + ["TK_GUE_Soldier_AT_EP1"];
_u = _u + ["TK_GUE_Soldier_AT_EP1"];

_l = _l + [_u];
//--- B757 garrison variety: RPG hunter team with assistant.
_k = _k + ["Team_AT"];
_u        = ["TK_GUE_Soldier_AT_EP1"];
_u = _u + ["TK_GUE_Soldier_AAT_EP1"];
_u = _u + ["TK_GUE_Soldier_HAT_EP1"];
_l = _l + [_u];


_k = _k + ["Team_AA"];
_u		= ["TK_GUE_Soldier_AA_EP1"];
_u = _u + ["TK_GUE_Soldier_AA_EP1"];

_l = _l + [_u];

_k = _k + ["Team_Sniper"];
_u		= ["TK_GUE_Soldier_Sniper_EP1"];
_u = _u + ["TK_GUE_Soldier_Sniper_EP1"];

_l = _l + [_u];
//--- B757 garrison variety: KSVK overwatch pair.
_k = _k + ["Team_Sniper"];
_u        = ["Soldier_Sniper_KSVK_PMC"];
_u = _u + ["TK_GUE_Soldier_Sniper_EP1"];
_l = _l + [_u];


//--- Roster free win: contractor squad is required by the GUER town picker on all maintained maps.
_k = _k + ["Squad_Contractor"];
_u        = ["Soldier_TL_PMC"];
_u = _u + ["Soldier_MG_PMC"];
_u = _u + ["Soldier_AT_PMC"];
_u = _u + ["Soldier_Medic_PMC"];
_u = _u + ["Soldier_M4A3_PMC"];
_l = _l + [_u];

//--- Roster free win: contractor squad is required by the GUER town picker on all maintained maps.
_k = _k + ["Squad_Contractor"];
_u        = ["Soldier_TL_PMC"];
_u = _u + ["Soldier_MG_PMC"];
_u = _u + ["Soldier_AT_PMC"];
_u = _u + ["Soldier_Medic_PMC"];
_u = _u + ["Soldier_M4A3_PMC"];
_l = _l + [_u];

_k = _k + ["Motorized"];

_u =      ["Offroad_DSHKM_TK_GUE_EP1"];
_u = _u + ["Offroad_SPG9_TK_GUE_EP1"];
_u = _u + ["ArmoredSUV_PMC"];

_l = _l + [_u];
//--- B757 garrison variety: PMC convoy.
_k = _k + ["Motorized"];
_u        = ["SUV_PMC"];
_u = _u + ["ArmoredSUV_PMC"];
_l = _l + [_u];

//--- B757 garrison variety: PK technical pair.
_k = _k + ["Motorized"];
_u        = ["Pickup_PK_TK_GUE_EP1"];
_u = _u + ["Pickup_PK_TK_GUE_EP1"];
_l = _l + [_u];


if ((missionNamespace getVariable ["WFBE_C_GUER_WAVE_DEPTH_VARIANTS", 0]) > 0) then {
	//--- Optional lane 31 variants: same group keys, existing classnames only, no flag-0 roster change.
	_k = _k + ["Squad"];
	_u		= ["TK_GUE_Warlord_EP1"];
	_u = _u + ["TK_GUE_Bonesetter_EP1"];
	_u = _u + ["TK_GUE_Soldier_AT_EP1"];
	_u = _u + ["TK_GUE_Soldier_AR_EP1"];
	_u = _u + ["TK_GUE_Soldier_MG_EP1"];
	_l = _l + [_u];

	_k = _k + ["Team"];
	_u		= ["TK_GUE_Warlord_EP1"];
	_u = _u + ["TK_GUE_Bonesetter_EP1"];
	_u = _u + ["TK_GUE_Soldier_AT_EP1"];
	_u = _u + ["TK_GUE_Soldier_MG_EP1"];
	_l = _l + [_u];

	_k = _k + ["Team_MG"];
	_u		= ["TK_GUE_Warlord_EP1"];
	_u = _u + ["TK_GUE_Soldier_MG_EP1"];
	_u = _u + ["TK_GUE_Soldier_AR_EP1"];
	_u = _u + ["TK_GUE_Bonesetter_EP1"];
	_l = _l + [_u];

	_k = _k + ["Motorized"];
	_u		= ["Offroad_SPG9_TK_GUE_EP1"];
	_u = _u + ["TK_GUE_Soldier_AT_EP1"];
	_u = _u + ["TK_GUE_Bonesetter_EP1"];
	_u = _u + ["TK_GUE_Soldier_AR_EP1"];
	_l = _l + [_u];
};

_k = _k + ["AA_Light"];
_u		= ["Ural_ZU23_TK_GUE_EP1"];
_u = _u + ["Ural_ZU23_TK_GUE_EP1"];

_l = _l + [_u];

_k = _k + ["AA_Heavy"];
//--- Captured Shilka + ZU-23 truck + MANPAD pair; all classes are verified build/spawn entries.
_u		= ["ZSU_INS"];
_u = _u + ["Ural_ZU23_TK_GUE_EP1"];
_u = _u + ["TK_GUE_Soldier_AA_EP1"];
_u = _u + ["TK_GUE_Soldier_AA_EP1"];

_l = _l + [_u];

_k = _k + ["Mechanized"];
_u		= ["BTR40_MG_TK_GUE_EP1"];
_u = _u + ["BRDM2_TK_GUE_EP1"];
_l = _l + [_u];
//--- B757 garrison variety: battle-bus militia column.
_k = _k + ["Mechanized"];
_u        = ["BTR40_MG_TK_GUE_EP1"];
_u = _u + ["BTR40_TK_GUE_EP1"];
_u = _u + ["TK_GUE_Soldier_AT_EP1"];
_u = _u + ["TK_GUE_Soldier_MG_EP1"];
_u = _u + ["TK_GUE_Soldier_AR_EP1"];
_u = _u + ["TK_GUE_Bonesetter_EP1"];
_u = _u + ["TK_GUE_Soldier_3_EP1"];
_u = _u + ["TK_GUE_Soldier_4_EP1"];
_l = _l + [_u];



_k = _k + ["Mechanized_Heavy"];
_u =      ["BRDM2_TK_GUE_EP1"];
_u = _u + ["ArmoredSUV_PMC"];

_l = _l + [_u];

_k = _k + ["Armored_Light"];
_u		= ["T34_TK_GUE_EP1"];
_u = _u + ["T34_TK_GUE_EP1"];

_l = _l + [_u];

_k = _k + ["Armored_Heavy"];
_u		= ["T55_TK_GUE_EP1"];
_u = _u + ["T55_TK_GUE_EP1"];

_l = _l + [_u];
//--- B757 garrison variety: rare captured T-72 The Prize.
_k = _k + ["Armored_Heavy"];
_u        = ["T72_GUE"];
_u = _u + ["T55_TK_GUE_EP1"];
_l = _l + [_u];



[_k,_l,_side,_faction] Call Compile preprocessFile "Common\Config\Config_Groups.sqf";
