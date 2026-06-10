Private ["_builtByRepairTruck","_defenseType","_dir","_index","_manned","_pos","_side","_structure"];
_side = _this select 0;
_defenseType = _this select 1;
_pos = _this select 2;
_dir = _this select 3;
_manned = _this select 4;
_builtByRepairTruck = if (count _this > 5) then {_this select 5} else {false};
// Defense auto-manning defaults on client-side and Custom Action 16 can still toggle it off/on.

_index = (missionNamespace getVariable Format["WFBE_%1DEFENSENAMES",str _side]) find _defenseType;
if (_index != -1) then {
	//--- Position anchors spawn a whole WDDM composition; everything else is a single defense.
	//--- Release-merge (WDDM + engineer-EASA): the single-defense path keeps the EASA repair-truck tagging args
	//--- (manning range + builtByRepairTruck); the composition path is commander-built and does not need them.
	//--- NOTE: Land_Pneu (Site Clearance) is handled client-side in coin_interface.sqf via the dedicated
	//--- RequestSiteClearance PVF and never reaches this path.
	if (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _defenseType) != -1}) then {
		[_side,_defenseType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
	} else {
		[_defenseType,_side,_pos,_dir,_manned,false,missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE",_builtByRepairTruck] Call ConstructDefense;
	};
};
