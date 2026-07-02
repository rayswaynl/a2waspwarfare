/*
	Return a side's HQ.
	 Parameters:
		- Side.
*/

switch (_this) do {
	case west: {WFBE_L_BLU getVariable "wfbe_upgrades"};
	case east: {WFBE_L_OPF getVariable "wfbe_upgrades"};
	case resistance: {
		private "_u";
		_u = WFBE_L_GUE getVariable "wfbe_upgrades";
		if (isNil "_u") then { _u = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] }; //--- GUER: no upgrade system -> zero array so callers' select never errors
		_u
	};
	default {[]}; //--- B76: was {objNull}; civilian/unknown side now returns an EMPTY ARRAY so callers' count/select degrade safely (no caller checks isNull on this result). Prevents per-tick RPT errors on a CIV edge.
}