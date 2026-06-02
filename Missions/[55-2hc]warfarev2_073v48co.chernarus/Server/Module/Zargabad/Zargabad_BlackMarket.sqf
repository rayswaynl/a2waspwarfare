if (!isServer || !IS_zargabad_lowpop_map) exitWith {};

Private ["_airfield", "_ammos", "_box", "_cachePositions", "_pos", "_side", "_sideID", "_smoke", "_type"];

waitUntil {townInit && !isNil "towns"};

_airfield = objNull;
{
	if ((_x getVariable ["name", ""]) == "Zargabad Airfield") exitWith {_airfield = _x};
} forEach towns;

if (isNull _airfield) exitWith {};

_cachePositions = [
	[3930,3995,0],
	[4100,3825,0],
	[4235,4040,0],
	[4970,3890,0],
	[3310,3865,0]
];

while {true} do {
	sleep (600 + random 360);
	_sideID = _airfield getVariable ["sideID", WFBE_C_GUER_ID];
	if (_sideID in [WFBE_C_WEST_ID, WFBE_C_EAST_ID]) then {
		_side = _sideID Call WFBE_CO_FNC_GetSideFromID;
		_ammos = missionNamespace getVariable [Format ["WFBE_%1PARAAMMO", str _side], []];
		if (count _ammos > 0) then {
			_pos = _cachePositions select floor(random count _cachePositions);
			_type = _ammos select floor(random count _ammos);
			_box = _type createVehicle [0,0,0];
			_box setPos _pos;
			_box setVariable ["wfbe_trashable", false];
			_smoke = "SmokeShellYellow" createVehicle _pos;
			["INFORMATION", Format ["Zargabad_BlackMarket.sqf: [%1] cache [%2] surfaced near [%3].", _side, _type, _pos]] Call WFBE_CO_FNC_LogContent;
			sleep 300;
			if (!isNull _smoke) then {deleteVehicle _smoke};
			if (!isNull _box) then {_box setVariable ["wfbe_trashable", true]};
		};
	};
};
