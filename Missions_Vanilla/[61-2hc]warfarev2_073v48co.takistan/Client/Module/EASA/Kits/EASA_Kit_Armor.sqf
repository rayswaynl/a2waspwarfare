/*
	EASA_Kit_Armor.sqf  (EASA_Kit_Armor)
	Appliqué-armor HandleDamage. Mirrors the Common_ModifyAirVehicle _rearmor pattern, retargeted from
	AA missiles to AT/HEAT ammo on ground vehicles, with a finite charge count. Runs on whatever machine
	the vehicle is local to (its return value is what the engine honours there).
	Input  : HandleDamage args [_unit,_selection,_damage,_source,_ammo]
	Returns: the (possibly reduced) damage for this selection.

	v1 behaviour: when charges deplete, protection simply stops (returns full damage); the cage visual
	stays until the vehicle is rearmed (refreshes WFBE_KIT_HitsLeft) or destroyed. No mid-event visual
	mutation -> avoids HandleDamage re-entrancy hazards.
	Arma 2 OA only.
*/
private ["_veh","_selection","_dmg","_ammo","_spec","_hits","_pct","_tags","_match"];
_veh       = _this select 0;
_selection = _this select 1;
_dmg       = _this select 2;
_ammo      = _this select 4;

_spec = _veh getVariable ["WFBE_KIT_Spec", []];
if (count _spec == 0 || {(_spec select 0) != "ARMOR"}) exitWith {_dmg};

_hits = _veh getVariable ["WFBE_KIT_HitsLeft", 0];
if (_hits <= 0) exitWith {_dmg};                          //--- kit spent.
if (isNil "_ammo" || {_ammo == ""}) exitWith {_dmg};      //--- collision / non-projectile -> ignore.

_pct  = _spec select 2;
_tags = _spec select 4;

_match = false;
{ if ((_ammo find _x) >= 0) exitWith {_match = true}; } forEach _tags;
if (!_match) exitWith {_dmg};                             //--- not an AT/HEAT round we counter.

//--- Count one charge per damage event: HandleDamage fires once per selection plus once for the
//--- whole-object "" selection. Gate the decrement on "" so a single hit spends a single charge.
if (_selection == "") then {
	_veh setVariable ["WFBE_KIT_HitsLeft", (_hits - 1), true];
};

_dmg * (1 - (_pct / 100))
