/*
	Return a side's structures.
	 Parameters:
		- Side.
	//--- r63 asset-registry desync: return only non-null ALIVE entries. BuildingKilled removes
	//--- the object from wfbe_structures asynchronously (Spawn EH), so a concurrent AICOM tick
	//--- (Produce/Teams/Base spacing) could still see the just-killed factory and task against it.
	//--- GetFactories already filters alive; the raw GetSideStructures consumer paths did not.
	//--- Read-side filter only (no write-back) so we never race the killed writer.
*/

private ["_logik","_raw","_out"];
_out = [];
_logik = switch (_this) do {
	case west: {if (isNil "WFBE_L_BLU") then {objNull} else {WFBE_L_BLU}};
	case east: {if (isNil "WFBE_L_OPF") then {objNull} else {WFBE_L_OPF}};
	case resistance: {if (isNil "WFBE_L_GUE") then {objNull} else {WFBE_L_GUE}};
	default {objNull};
};
if (isNull _logik) exitWith {_out};
_raw = _logik getVariable "wfbe_structures";
if (isNil "_raw" || {typeName _raw != "ARRAY"}) exitWith {_out};
{
	if (!isNil "_x") then {
		if (!isNull _x && {alive _x}) then {_out = _out + [_x]};
	};
} forEach _raw;
_out