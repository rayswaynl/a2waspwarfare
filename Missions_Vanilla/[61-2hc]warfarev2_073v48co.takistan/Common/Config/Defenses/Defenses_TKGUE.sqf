/*
	Defenses Definition, define the available defenses.
*/

Private ["_c","_f","_faction","_k","_n","_o","_side","_t"];

_side = "GUER";
_faction = "GUE";

_c = []; //--- Classname
_n = []; //--- Name. 					'' = auto generated.
_o = []; //--- Price.
_t = []; //--- Category
_k = []; //--- Kind (Used for town defenses)

//--- Defenses (Statics)
//--- GUER statics stripped to ZU-23 only (Ray 2026-06-16: "drop all GUER statics besides Zu23's").
//--- Removed for static-count / server-FPS relief: WarfareBMGNest_PK_TK_GUE_EP1 (MGNest),
//--- SearchLight_TK_GUE_EP1, DSHKM_TK_GUE_EP1 (MG), AGS_TK_GUE_EP1 (GL), SPG9_TK_GUE_EP1 (AT),
//--- 2b14_82mm_TK_GUE_EP1 (mortar), D30_TK_GUE_EP1 (Artillery). Kept only the ZU-23 AA emplacement.
//--- Town slots whose wfbe_defense_kind no longer resolves (MGNest/MG/GL/AT) spawn nothing — handled
//--- gracefully by Server_SpawnTownDefense.sqf (nil-kind shift-out), so GUER towns get fewer statics.
_c = _c + ['ZU23_TK_GUE_EP1'];
_n = _n + [''];
_o = _o + [600];
_t = _t + ["Defense"];
_k = _k + ["AA"];

//--- Defenses management for towns.
if (isServer) then {[_side, _c, _k] Call Compile preprocessFile "Common\Config\Config_Defenses_Towns.sqf"};

//--- Fortitications and rest.

// [_faction, _c, _n, _o, _t] Call Compile preprocessFile "Common\Config\Config_Defenses.sqf";