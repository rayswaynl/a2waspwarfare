/*
	SkinSelector_Data.sqf
	Returns the skin pool for the calling player's side.
	Output: array of [classname, displayLabel, isGhillie]
	  - displayLabel: "" means "resolve from registry / config at runtime"
	  - isGhillie: true means entry is only shown to Sniper/Spotter role
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
