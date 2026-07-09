/*
	Return a side's structures.
	 Parameters:
		- Side.
*/

switch (_this) do {
	case west: {if (isNil "WFBE_L_BLU") then {[]} else {WFBE_L_BLU getVariable ["wfbe_structures", []]}};
	case east: {if (isNil "WFBE_L_OPF") then {[]} else {WFBE_L_OPF getVariable ["wfbe_structures", []]}};
	case resistance: {if (isNil "WFBE_L_GUE") then {[]} else {WFBE_L_GUE getVariable ["wfbe_structures", []]}};
	default {[]};
}