/*
	Groups (Used in towns).
*/

Private ["_faction","_k","_l","_side","_u"];
_l = [];//--- Unit list
_k = [];//--- Type used by AI.

_side = "GUER";
_faction = "GUE";

_k = _k + ["Squad"];
_u		= ["GUE_Soldier_CO"];
_u = _u + ["GUE_Soldier_GL"];
_u = _u + ["GUE_Soldier_AR"];
_u = _u + ["GUE_Soldier_1"];

_l = _l + [_u];


_k = _k + ["Squad_Advanced"];
_u		= ["Soldier_TL_PMC"];
_u = _u + ["Soldier_M4A3_PMC"];
_u = _u + ["Soldier_AA_PMC"];
_u = _u + ["Soldier_Bodyguard_M4_PMC"];
_u = _u + ["Soldier_GL_M16A2_PMC"];

_l = _l + [_u];


_k = _k + ["Team"];
_u		= ["GUE_Worker2"];
_u = _u + ["GUE_Woodlander3"];
_u = _u + ["GUE_Villager3"];
_u = _u + ["GUE_Woodlander2"];
_u = _u + ["GUE_Woodlander1"];
_u = _u + ["GUE_Villager4"];
_l = _l + [_u];

_k = _k + ["Team_AT"];
_u		= ["GUE_Soldier_AT"];
_u = _u + ["GUE_Soldier_AT"];

_l = _l + [_u];

_k = _k + ["Team_AA"];
_u		= ["GUE_Soldier_AA"];
_u = _u + ["GUE_Soldier_AA"];

_l = _l + [_u];

_k = _k + ["Team_Sniper"];
_u		= ["GUE_Soldier_Sniper"];

_l = _l + [_u];

//--- B61 (Ray 2026-06-21): Team_MG roster. The defender selector (Server_GetTownGroupsDefender.sqf) requests
//--- "Team_MG" for GUER on most town sizes, but GUER had NO Team_MG roster -> the request resolved nil and was
//--- silently dropped, under-garrisoning every GUER town. Mirrors Groups_INS Team_MG (CO + 2x MG + AR).
_k = _k + ["Team_MG"];
_u		= ["GUE_Soldier_CO"];
_u = _u + ["GUE_Soldier_MG"];
_u = _u + ["GUE_Soldier_MG"];
_u = _u + ["GUE_Soldier_AR"];

_l = _l + [_u];

//--- B61 (Ray 2026-06-21): Squad_Contractor roster. Hired-PMC flavor for GUER town defense
//--- (PMC-in-GUER is already precedented: Squad_Advanced uses Soldier_*_PMC; Motorized has
//--- ArmoredSUV_PMC; a Groups_PMC.sqf keyed to GUER exists). Wired as a RARE (weight 1) elite
//--- garrison on Large/Huge towns only via Server_GetTownGroupsDefender.sqf. All 5 classnames are
//--- registered in Core_PMC.sqf. Rides the merge pass (additive, no group-count bloat).
_k = _k + ["Squad_Contractor"];
_u		= ["Soldier_TL_PMC"];
_u = _u + ["Soldier_MG_PMC"];
_u = _u + ["Soldier_AT_PMC"];
_u = _u + ["Soldier_Medic_PMC"];
_u = _u + ["Soldier_M4A3_PMC"];

_l = _l + [_u];

_k = _k + ["Motorized"];
_u		= ["Offroad_DSHKM_Gue"];
_u = _u + ["Offroad_SPG9_Gue"];
_u = _u + ["ArmoredSUV_PMC"];

_l = _l + [_u];

//--- B61 (Ray 2026-06-21): second Motorized variant - fast PMC scout technical. SUV_PMC (fast) +
//--- ArmoredSUV_PMC with 2-3 dismounts (TL/MG/AT). Aggregated into WFBE_GUER_GROUPS_Motorized
//--- (Config_Groups.sqf pushes same-kind entries into one array; the defender selector picks one
//--- roster at random), so it rides the existing Motorized requests without a new town-table slot.
//--- All classnames registered in Core_PMC.sqf / Core_GUE.sqf.
_k = _k + ["Motorized"];
_u		= ["SUV_PMC"];
_u = _u + ["ArmoredSUV_PMC"];
_u = _u + ["Soldier_TL_PMC"];
_u = _u + ["Soldier_MG_PMC"];
_u = _u + ["Soldier_AT_PMC"];

_l = _l + [_u];


_k = _k + ["AA_Light"];
_u		= ["Ural_ZU23_Gue"];

_l = _l + [_u];


_k = _k + ["AA_Heavy"];
_u		 = ["Ural_ZU23_Gue"];
_u = _u + ["Ural_ZU23_Gue"];


_l = _l + [_u];

_k = _k + ["Mechanized"];
_u =      ["BRDM2_GUE"];
_u = _u + ["M113_UN_EP1"];
_l = _l + [_u];


_k = _k + ["Mechanized_Heavy"];
_u =      ["BRDM2_GUE"];
_u = _u + ["M113_UN_EP1"];

_l = _l + [_u];


_k = _k + ["Armored_Light"];
_u =        ["BMP2_GUE"];
_u = _u +   ["BMP2_GUE"];

_l = _l + [_u];

_k = _k + ["Armored_Heavy"];
_u		= ["T72_GUE"];
_u = _u + ["T72_GUE"];

_l = _l + [_u];

[_k,_l,_side,_faction] Call Compile preprocessFile "Common\Config\Config_Groups.sqf";