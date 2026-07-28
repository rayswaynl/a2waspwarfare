/*
	client_crater_cleaner.sqf - fable/wreck-crater-hygiene (owner 2026-07-28: "what about the ground
	deformations that happen after aircraft crashes?").

	Explosion crater decals (CraterLong / CraterLong_small) are engine-spawned LOCAL to each client
	(nothing in-tree ever creates one), so the existing server-side Server\FSM\cleaners\
	crater_cleaner.sqf structurally cannot see them - the same locality blindspot this codebase has
	fixed for arty wrecks, heli wrecks and empty hulls. This is the per-client mirror:
	- scans only around the player (craters farther away are not rendered for this client anyway),
	- first sight stamps wfbe_crater_seen (LOCAL var on a LOCAL object - no network traffic),
	- deletes only once a crater has aged past WFBE_C_CLIENT_CRATER_AGE seconds AND the area is
	  quiet (no live soldier other than the player within the quiet radius) - so battle scars
	  never vanish mid-firefight in front of anyone.
	HCs never run this (no renderer -> no local craters; Init_Client does not run there anyway).
*/

private ["_period","_age","_radius","_quietR","_crats","_c","_seen","_men","_hostile","_deleted"];

if (!hasInterface) exitWith {};
if ((missionNamespace getVariable ["WFBE_C_CLIENT_CRATER_CLEANER", 0]) <= 0) exitWith {};

while {!gameOver} do {
	_period = missionNamespace getVariable ["WFBE_C_CLIENT_CRATER_PERIOD", 120];
	if (_period < 30) then {_period = 30};
	sleep _period;
	if (!isNull player && {alive player}) then {
		_age    = missionNamespace getVariable ["WFBE_C_CLIENT_CRATER_AGE", 600];
		_radius = missionNamespace getVariable ["WFBE_C_CLIENT_CRATER_RADIUS", 2000];
		_quietR = missionNamespace getVariable ["WFBE_C_CLIENT_CRATER_QUIET_R", 150];
		_deleted = 0;
		{
			_c = _x;
			if (!isNull _c) then {
				_seen = _c getVariable "wfbe_crater_seen";
				if (isNil "_seen") then {
					_c setVariable ["wfbe_crater_seen", time];
				} else {
					if ((time - _seen) > _age && {_deleted < 20}) then {
						//--- quiet guard: any live soldier besides the player nearby keeps the scar.
						_hostile = false;
						_men = (getPos _c) nearEntities [["Man"], _quietR];
						{if (alive _x && {_x != player}) then {_hostile = true}} forEach _men;
						if (!_hostile) then {
							deleteVehicle _c;
							_deleted = _deleted + 1;
						};
					};
				};
			};
		} forEach ((nearestObjects [getPos player, ["CraterLong"], _radius]) + (nearestObjects [getPos player, ["CraterLong_small"], _radius]));
	};
};
