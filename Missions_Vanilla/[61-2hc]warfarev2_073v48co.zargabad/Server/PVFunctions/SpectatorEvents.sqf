/* SpectatorEvents.sqf -- server-side sink for the HC spectator event forward channel
   (spectator v8, Common_SpectatorEventFeed.sqf). Payload: array of compact events
   [t, x, y, sideID, kind]. Merges into the server's own event ring so the <=1Hz batch
   broadcaster picks them up alongside server-local events. typeName guards first --
   a malformed payload must never throw inside a PVF handler. */
Private ["_e"];

if ((typeName _this) != "ARRAY") exitWith {};
if (isNil "WFBE_CO_FNC_SpectatorEvEnqueue") exitWith {};

{
	_e = _x;
	if ((typeName _e) == "ARRAY" && {(count _e) >= 5}) then {
		_e Call WFBE_CO_FNC_SpectatorEvEnqueue;
	};
} forEach _this;
