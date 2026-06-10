/*
	Friendly side-patrol map markers (Patrols upgrade).
	Tracks WFBE_ACTIVE_PATROLS (public [[leaderUnit, sideID], ...] maintained by the
	server) and keeps a local yellow circle on each FRIENDLY patrol leader. Side-local
	only - enemy patrols are never marked. Self-contained loop (does not reuse
	MarkerUpdate): create, follow every 5s, delete when the leader dies.
*/

scriptName "Client\FSM\updatepatrolmarkers.sqf";

private ["_list","_tracked","_keep","_unit","_sid","_mk","_known","_i","_k"];

waitUntil {!isNil "clientInitComplete" && {clientInitComplete}};

_tracked = []; //--- [unit, markerName] pairs
_i = 0;

while {true} do {
	_list = missionNamespace getVariable ["WFBE_ACTIVE_PATROLS", []];

	//--- New friendly patrols.
	{
		_unit = _x select 0;
		_sid = _x select 1;
		if (_sid == WFBE_Client_SideID && {!isNull _unit} && {alive _unit}) then {
			_known = false;
			for "_k" from 0 to (count _tracked - 1) do {
				if (((_tracked select _k) select 0) == _unit) then {_known = true};
			};
			if (!_known) then {
				_i = _i + 1;
				_mk = Format["wfbe_patrolmarker_%1", _i];
				createMarkerLocal [_mk, getPos _unit];
				_mk setMarkerTypeLocal "mil_circle";
				_mk setMarkerColorLocal "ColorYellow";
				_mk setMarkerSizeLocal [0.7,0.7];
				_mk setMarkerTextLocal "Patrol";
				_tracked = _tracked + [[_unit, _mk]];
			};
		};
	} forEach _list;

	//--- Follow / drop.
	_keep = [];
	{
		_unit = _x select 0;
		_mk = _x select 1;
		if (!isNull _unit && {alive _unit}) then {
			_mk setMarkerPosLocal (getPos _unit);
			_keep = _keep + [_x];
		} else {
			deleteMarkerLocal _mk;
		};
	} forEach _tracked;
	_tracked = _keep;

	sleep 5;
};
