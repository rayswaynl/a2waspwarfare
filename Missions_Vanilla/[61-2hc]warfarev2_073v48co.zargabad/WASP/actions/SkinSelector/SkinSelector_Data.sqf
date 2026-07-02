/*
	SkinSelector_Data.sqf
	Returns the skin pool for the calling player's side.
	Output: array of [classname, displayLabel, isGhillie]
	  - displayLabel: "" means "resolve from registry / config at runtime"
	  - isGhillie: true means entry is only shown to the sniper (role type "Spotter" — see Skill_Init.sqf)
	Each entry is filtered: if the class does not exist in CfgVehicles the entry is dropped.
*/

Private ["_pool","_side","_filtered","_cls","_isGhillie","_lbl","_entry","_i"];

_side = side group player;

_pool = [];

if (_side == WEST) then {
	_pool = [
		["USMC_Soldier",          "", false],
		["USMC_Soldier_TL",       "", false],
		["USMC_SoldierS",         "", false],
		["USMC_Soldier_MG",       "", false],
		["USMC_Soldier_GL",       "", false],
		["USMC_Soldier_Medic",    "", false],
		["USMC_SoldierS_Engineer","", false],
		["US_Soldier_EP1",        "", false],
		["BAF_Soldier_MTP",       "", false],
		["BAF_Soldier_SL_MTP",    "", false],
		["CZ_Soldier_DES_EP1",    "", false],
		//--- 2026-06-16 pool expansion (OA US Army + French DLC); isClass guard drops any absent on this map.
		["US_Soldier_MG_EP1",     "", false],
		["US_Soldier_TL_EP1",     "", false],
		["FR_Corpsman",           "", false],
		["FR_GL",                 "", false],
		//--- Miksuu addon skins (@MiksuuSkins). The isClass guard below drops these until the signed addon is loaded.
		["mks_w_multicam",        "", false],
		["mks_w_ranger",          "", false],
		["mks_w_coyote",          "", false],
		["USMC_SoldierS_Sniper",  "", true],
		["USMC_SoldierS_SniperH", "", true]
	];
};

if (_side == EAST) then {
	_pool = [
		["RU_Soldier",            "", false],
		["RU_Soldier_TL",         "", false],
		["RU_Soldier_AR",         "", false],
		["RU_Soldier_MG",         "", false],
		["RU_Soldier_GL",         "", false],
		["RU_Soldier_Medic",      "", false],
		["CDF_Soldier",           "", false],
		["CDF_Soldier_TL",        "", false],
		["CDF_Soldier_Light",     "", false],
		["Ins_Soldier_1",         "", false],
		["Ins_Soldier_2",         "", false],
		["MVD_Soldier_TL",        "", false],
		//--- 2026-06-16 pool expansion (Takistani Army, for the Takistan-inherited build); isClass guard drops any absent on this map.
		//--- NOTE: TK_Soldier_TL_EP1 does not exist in OA / the faction configs (TKA uses SL naming) — using the registered TK_Soldier_SL_EP1.
		["TK_Soldier_EP1",        "", false],
		["TK_Soldier_SL_EP1",     "", false],
		//--- Miksuu addon skins (@MiksuuSkins). The isClass guard below drops these until the signed addon is loaded.
		["mks_e_gorka",           "", false],
		["mks_e_spetsnaz",        "", false],
		["RU_Soldier_Sniper",     "", true],
		["RU_Soldier_SniperH",    "", true]
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
