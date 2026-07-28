/*
	Casting mode - key handler. Registered ONLY when WFBE_C_CASTER_MODE > 0, so with the
	flag at 0 no handler is added to findDisplay 46 at all.

	F9 (67) toggles casting (allowlist enforced inside Client_CasterMode.sqf). Every other
	key here is inert unless casting is actually running, so normal play is unaffected.

	Raw DIK: W 17, S 31, A 30, D 32, Q 16, E 18, LShift 42, Tab 15, F 33, F9 67.
	OUTSTANDING: DIK codes and KeyDown auto-repeat behaviour are not runtime-verified
	(no Arma client in the build environment).
*/

Private ["_dik","_down","_handled"];

_dik = (_this select 1);
_down = true;
_handled = false;

if (_dik == 67) exitWith {
	[] Spawn WFBE_CL_FNC_CasterMode;
	true
};

if (isNil "WFBE_Caster_Active") exitWith {_handled};
if (!WFBE_Caster_Active) exitWith {_handled};

switch (_dik) do {
	case 17: {WFBE_Caster_Fwd = 1; _handled = true};
	case 31: {WFBE_Caster_Fwd = -1; _handled = true};
	case 30: {WFBE_Caster_Turn = -1; _handled = true};
	case 32: {WFBE_Caster_Turn = 1; _handled = true};
	case 16: {WFBE_Caster_Up = -1; _handled = true};
	case 18: {WFBE_Caster_Up = 1; _handled = true};
	case 42: {WFBE_Caster_Fast = true; _handled = true};
	case 15: {WFBE_Caster_CycleStep = 1; _handled = true};
	case 33: {WFBE_Caster_Follow = objNull; _handled = true};
};

_handled
