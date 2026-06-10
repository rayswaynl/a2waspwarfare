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
	//--- Site Clearance anchor: intercept BEFORE any object is built.  No object ever spawns.
	//--- WFBE_C_UNITS_BULLDOZER gates the feature; Land_Pneu is already absent from DEFENSENAMES when gate is off,
	//--- but the explicit check here makes the no-spawn guarantee unconditional and self-documenting.
	if ((missionNamespace getVariable ["WFBE_C_UNITS_BULLDOZER", 0]) > 0 &&
	    {_defenseType == "Land_Pneu"}) then {
		[_side, _pos, leader (_side Call WFBE_CO_FNC_GetCommanderTeam)] Call Server_SiteClearance;
	} else {
		//--- Position anchors spawn a whole WDDM composition; everything else is a single defense.
		//--- Release-merge (WDDM + engineer-EASA): the single-defense path keeps the EASA repair-truck tagging args
		//--- (manning range + builtByRepairTruck); the composition path is commander-built and does not need them.
		if (!isNil "WFBE_POSITION_ANCHOR_NAMES" && {(WFBE_POSITION_ANCHOR_NAMES find _defenseType) != -1}) then {
			[_side,_defenseType,_pos,_dir,_manned] Spawn Server_ConstructPosition;
		} else {
			[_defenseType,_side,_pos,_dir,_manned,false,missionNamespace getVariable "WFBE_C_BASE_DEFENSE_MANNING_RANGE",_builtByRepairTruck] Call ConstructDefense;
		};
	};
};
