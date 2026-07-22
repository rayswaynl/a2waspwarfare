private ["_vehicle","_unit"];

_unit = _this select 2;
_vehicle = _this select 0;
//--- fix(arty-lifecycle): Client_BuildUnit.sqf wires this as a "GetIn" handler on rocket artillery, so it
//--- normally starts when an AI gunner boards and can outlive the hull for the rest of the match. Once the
//--- vehicle is deleted the 1-arg getVariable returns Nothing, `Nothing && {...}` is a script error, and
//--- because the condition could then never be satisfied the waitUntil re-threw it on every re-check.
//--- Terminate on null/dead instead. isNull is tested FIRST behind lazy || so the getVariable never runs
//--- against a null object (a null object ignores the 2-arg default - see RequestVehicleSell.sqf L72-73).
waituntil {isNull _vehicle || {!alive _vehicle} || {(_vehicle getVariable ["restricted", false]) && {({isPlayer _x} count (crew _vehicle)) != 0}}};
if (isNull _vehicle || {!alive _vehicle}) exitWith {};
if (isNull _unit) exitWith {};
_unit action  ["getOut", _vehicle];hintsilent "ARTILLERY MISSION RUNNING";

