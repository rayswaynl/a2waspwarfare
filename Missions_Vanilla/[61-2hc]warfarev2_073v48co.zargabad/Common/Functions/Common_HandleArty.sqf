private ["_vehicle","_unit"];

_unit = _this select 2;
_vehicle = _this select 0;
waituntil {(_vehicle getVariable "restricted") && ({isPlayer _x} count (crew _vehicle) != 0)};
_unit action  ["getOut", _vehicle];hintsilent "ARTILLERY MISSION RUNNING";

