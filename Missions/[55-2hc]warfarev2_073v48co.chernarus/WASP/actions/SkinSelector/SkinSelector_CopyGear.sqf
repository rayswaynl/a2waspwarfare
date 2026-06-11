/*
	SkinSelector_CopyGear.sqf
	Captures the full loadout of _this (the old unit) before deleteVehicle.
	Returns: [primaryWeapon, secondaryWeapon, handgunWeapon, magazines,
	          backpackClass, backpackWeapons, backpackMagazines]
	WFBE_CL_FNC_GetUnitBackpack / WFBE_CL_FNC_GetBackpackContent already
	handle the WF_A2_Vanilla case (return "" / [[],[]] respectively).
	Called as: _gear = _oldUnit call (compile preprocessFile "...")
*/

Private ["_unit","_primary","_secondary","_handgun","_mags","_bp","_bpContent","_bpWeapons","_bpMags"];

_unit = _this;

_primary   = primaryWeapon   _unit;
_secondary = secondaryWeapon _unit;
_handgun   = handgunWeapon   _unit;
_mags      = magazines       _unit;

_bp         = _unit Call WFBE_CL_FNC_GetUnitBackpack;
_bpWeapons  = [];
_bpMags     = [];

if (_bp != "") then {
	_bpContent = _unit Call WFBE_CL_FNC_GetBackpackContent;
	_bpWeapons = _bpContent select 0;
	_bpMags    = _bpContent select 1;
};

[_primary, _secondary, _handgun, _mags, _bp, _bpWeapons, _bpMags]
