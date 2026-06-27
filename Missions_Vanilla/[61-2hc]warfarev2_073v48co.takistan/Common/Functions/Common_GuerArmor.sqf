/*
	Common_GuerArmor.sqf — GUER "improvised armour": adds a HandleDamage to a resistance light vehicle that
	reduces NON-AT damage (small-arms / shrapnel / blast) by WFBE_C_GUER_IMPROVISED_ARMOR percent. AT/HEAT rounds
	still punch through, so technicals stay killable. No visual. Reuses the Common_ModifyVehicle _rearmor pattern.
	Input: [_vehicle]. Runs where the vehicle is local (called from Common_CreateVehicle). Arma 2 OA only.
*/
private ["_vehicle","_armor"];
_vehicle = _this select 0;
if (isNull _vehicle) exitWith {};

_armor = {
	private ["_dam","_ammo","_pct"];
	_dam  = _this select 2;
	_ammo = _this select 4;
	_pct  = missionNamespace getVariable ["WFBE_C_GUER_IMPROVISED_ARMOR", 0];
	//--- improvised plating mostly stops small-arms/shrapnel; AT/HEAT/ATGM rounds are NOT mitigated.
	if (isNil "_ammo") exitWith {_dam};
	if (_ammo != "" && {(_ammo find "_AT") >= 0 || {(_ammo find "PG7") >= 0} || {(_ammo find "PG9") >= 0} || {(_ammo find "HEAT") >= 0} || {(_ammo find "TOW") >= 0} || {(_ammo find "Maverick") >= 0} || {(_ammo find "Hellfire") >= 0} || {(_ammo find "AT13") >= 0} || {(_ammo find "Metis") >= 0}}) exitWith {_dam};
	_dam * (1 - (_pct / 100))
};
_vehicle addEventHandler ["HandleDamage", format ["_this Call %1", _armor]];
