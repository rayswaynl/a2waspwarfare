/*
	Return a side HQ deloy status.
	 Parameters:
		- Side.
*/

switch (_this) do {
	case west: {if (isNil "WFBE_L_BLU") then {false} else {WFBE_L_BLU getVariable ["wfbe_hq_deployed", false]}};
	case east: {if (isNil "WFBE_L_OPF") then {false} else {WFBE_L_OPF getVariable ["wfbe_hq_deployed", false]}};
	case resistance: {if (isNil "WFBE_L_GUE") then {false} else {WFBE_L_GUE getVariable ["wfbe_hq_deployed", false]}};
	default {objNull};
}

