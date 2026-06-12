/*
	Return a side's HQ.
	 Parameters:
		- Side.
	Marty: nil-guarded - side logics may not exist for every side on every mission
	(e.g. WFBE_L_GUE on AI-only setups); returning objNull keeps callers safe.
*/

switch (_this) do {
	case west: {if (isNil "WFBE_L_BLU") then {objNull} else {WFBE_L_BLU getVariable "wfbe_hq"}};
	case east: {if (isNil "WFBE_L_OPF") then {objNull} else {WFBE_L_OPF getVariable "wfbe_hq"}};
	case resistance: {if (isNil "WFBE_L_GUE") then {objNull} else {WFBE_L_GUE getVariable "wfbe_hq"}};
	default {objNull};
}
