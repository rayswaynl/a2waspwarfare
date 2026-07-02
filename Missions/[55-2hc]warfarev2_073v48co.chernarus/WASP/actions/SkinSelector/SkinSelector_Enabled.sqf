/*
	SkinSelector_Enabled.sqf
	Returns BOOLEAN: is the Command-Deck skin selector active for this client right now.

	cmdcon41-w3l: introduces the WFBE_C_SKINSEL master flag (DEFAULT 1 = ON) resolved here so
	the whole feature can be flipped from ONE place without editing Init_CommonConstants.sqf.
	Semantics:
	  - WFBE_C_SKINSEL is the new master. It is read with a getVariable DEFAULT of 1, so the
	    selector is ON out of the box even though nothing sets WFBE_C_SKINSEL in the constants
	    file. A host/param may set WFBE_C_SKINSEL = 0 to force it off.
	  - The LEGACY constant WFBE_C_SKIN_SELECTOR (default 0 in Init_CommonConstants.sqf) is
	    honoured too: if a host explicitly set it to 1 the selector stays on regardless.
	  => enabled = (WFBE_C_SKINSEL == 1) OR (WFBE_C_SKIN_SELECTOR == 1).

	A2 OA 1.64 note: == is used only on Numbers here (never on Booleans). No A3 ops.
	Call as:  _on = call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_Enabled.sqf");
*/

Private ["_master","_legacy"];
_master = missionNamespace getVariable ["WFBE_C_SKINSEL", 1];
_legacy = missionNamespace getVariable ["WFBE_C_SKIN_SELECTOR", 0];

((_master == 1) || (_legacy == 1))
