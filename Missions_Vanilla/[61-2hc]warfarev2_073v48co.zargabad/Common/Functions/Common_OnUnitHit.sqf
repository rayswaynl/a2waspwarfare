/*
	Triggered whenever a unit take a consequent hit.
	 Parameters:
		- Killed
		- Killer
		- Side ID
*/

Private ["_causedby","_damage","_unit"];

_unit = _this select 0;
_causedby = _this select 1;
_damage = _this select 2;

if (_damage >= 0.05 && !isNull _causedby && _causedby != _unit) then {
	_unit setVariable ["wfbe_lasthitby", _causedby, true];
	_unit setVariable ["wfbe_lasthittime", time, true];
};
