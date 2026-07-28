/*
	Casting mode - KeyUp companion. Clears the movement axes so the camera coasts to a stop
	instead of drifting forever after a key is released. Registered alongside the KeyDown
	handler, and only when WFBE_C_CASTER_MODE > 0.
*/

Private ["_dik"];

_dik = (_this select 1);

if (isNil "WFBE_Caster_Active") exitWith {false};
if (!WFBE_Caster_Active) exitWith {false};

switch (_dik) do {
	case 17: {WFBE_Caster_Fwd = 0};
	case 31: {WFBE_Caster_Fwd = 0};
	case 30: {WFBE_Caster_Turn = 0};
	case 32: {WFBE_Caster_Turn = 0};
	case 16: {WFBE_Caster_Up = 0};
	case 18: {WFBE_Caster_Up = 0};
	case 42: {WFBE_Caster_Fast = false};
};

false
