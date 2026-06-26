/*
	EASA_ApplyKit.sqf  (EASA_ApplyKit)
	OWNER-side kit application. Runs on the client that bought the kit (the vehicle is local to it,
	since EASA only operates on a player-driven vehicle). Publishes the kit spec + authoritative
	counters as JIP-persistent vehicle state, realises it locally, then signals every other machine.
	Input : [_vehicle, _kitSpec]   (_kitSpec = [] clears any kit)
	Arma 2 OA only.
*/
private ["_vehicle","_spec","_kind"];
_vehicle = _this select 0;
_spec    = _this select 1;
if (isNull _vehicle) exitWith {};

_vehicle setVariable ["WFBE_KIT_Spec", _spec, true];   //--- public + JIP-persistent

if (count _spec > 0) then {
	_kind = _spec select 0;
	switch (_kind) do {
		//--- index 3 is the finite-resource count for both armed kits (maxAmmo / maxHits).
		case "MOUNT": { _vehicle setVariable ["WFBE_KIT_Ammo",     (_spec select 3), true]; };
		case "ARMOR": { _vehicle setVariable ["WFBE_KIT_HitsLeft", (_spec select 3), true]; };
		default {};
	};
};

//--- Realise locally now (publicVariable does not fire the handler on the setter) + tell everyone else.
[_vehicle] call WFBE_CL_FNC_KitBuild;
WFBE_KIT_SIGNAL = _vehicle;
publicVariable "WFBE_KIT_SIGNAL";
