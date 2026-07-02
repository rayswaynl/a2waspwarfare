/*
	SkinSelector_CopyGear.sqf
	Captures the full loadout of _this (the old unit) before deleteVehicle.
	Returns: [primaryWeapon, allWeapons, magazines,
	          backpackClass, backpackWeapons, backpackMagazines]
	WFBE_CL_FNC_GetUnitBackpack / WFBE_CL_FNC_GetBackpackContent already
	handle the WF_A2_Vanilla case (return "" / [[],[]] respectively).
	Called as: _gear = _oldUnit call (compile preprocessFile "...")

	cmdcon42 A2-OA-1.64 FIX (Ray 2026-07-02): the previous version read the handgun with
	`handgunWeapon _unit`. `handgunWeapon` is an Arma-3-ONLY command; in A2 OA 1.64 it is
	not a recognised token, so the parser threw "Missing ;" on this line, the whole CopyGear
	compile FAILED, and the `call` returned nil. That left `_gear` undefined at the Apply
	call site (SkinSelector_Apply.sqf line 133), which threw "Undefined variable: _gear",
	ABORTED the apply mid-flight BEFORE selectPlayer ever ran, and left the freshly-created
	skinned unit standing idle next to the player (RPT chain reached B3 then died).
	Fix: capture the full `weapons _unit` list (A2-valid; used at GUI_BuyGearMenu.sqf:15).
	`weapons` returns EVERY carried weapon incl. the pistol, NVGoggles, binoculars and GPS,
	so it strictly super-sets the old primary/secondary/handgun split - no loadout is lost.
	_primary is kept separately only so ApplyGear can re-`selectWeapon` it after re-adding.
*/

Private ["_unit","_primary","_allWeapons","_mags","_bp","_bpContent","_bpWeapons","_bpMags"];

_unit = _this;

_primary    = primaryWeapon _unit;
_allWeapons = weapons       _unit;
_mags       = magazines     _unit;

_bp         = _unit Call WFBE_CL_FNC_GetUnitBackpack;
_bpWeapons  = [];
_bpMags     = [];

if (_bp != "") then {
	_bpContent = _unit Call WFBE_CL_FNC_GetBackpackContent;
	_bpWeapons = _bpContent select 0;
	_bpMags    = _bpContent select 1;
};

[_primary, _allWeapons, _mags, _bp, _bpWeapons, _bpMags]
