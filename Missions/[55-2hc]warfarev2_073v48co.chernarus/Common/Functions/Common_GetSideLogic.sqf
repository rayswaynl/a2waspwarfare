/*
	Return a side's logic.
	 Parameters:
		- Side.

	A2 OA nil-guard: if a side logic global is not defined (mission has no GUE/BLU/OPF logic object)
	return objNull rather than throwing "undefined variable WFBE_L_xxx" into the RPT.
	This prevents the ~28+/round error flood when GetSideLogic is called with resistance on
	missions where WFBE_L_GUE was never placed.
*/

switch (_this) do {
	case west:       { if (isNil "WFBE_L_BLU") then {objNull} else {WFBE_L_BLU} };
	case east:       { if (isNil "WFBE_L_OPF") then {objNull} else {WFBE_L_OPF} };
	case resistance: { if (isNil "WFBE_L_GUE") then {objNull} else {WFBE_L_GUE} };
	default          { objNull };
};

