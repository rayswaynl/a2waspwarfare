if (!isServer || !IS_zargabad_lowpop_map) exitWith {};

Private ["_band", "_boundary", "_edge", "_pos", "_safe", "_safeLogged", "_safeRange", "_since", "_timeout", "_types", "_unit", "_vehicle", "_xPos", "_yPos"];

_band = missionNamespace getVariable ["WFBE_C_ZARGABAD_EDGE_GUARD_BAND", 120];
_boundary = missionNamespace getVariable "WFBE_BOUNDARIESXY";
_safeRange = missionNamespace getVariable ["WFBE_C_ZARGABAD_EDGE_GUARD_SAFE_RANGE", 325];
_timeout = missionNamespace getVariable ["WFBE_C_ZARGABAD_EDGE_GUARD_TIMEOUT", 45];
_types = ["LocationLogicStart", "LocationLogicDepot", "LocationLogicCamp", "LocationLogicAirport"];

["INITIALIZATION", Format ["Zargabad_EdgeGuard.sqf: outer [%1]m rim timeout [%2]s safe range [%3]m.", _band, _timeout, _safeRange]] Call WFBE_CO_FNC_LogContent;

while {true} do {
	sleep 10;
	{
		_unit = _x;
		if (alive _unit && isPlayer _unit) then {
			_vehicle = vehicle _unit;
			if (alive _vehicle && !(_vehicle isKindOf "Air")) then {
				_pos = getPos _vehicle;
				_xPos = _pos select 0;
				_yPos = _pos select 1;
				_edge = (_xPos < _band) || (_yPos < _band) || (_xPos > (_boundary - _band)) || (_yPos > (_boundary - _band));
				_safe = (count (_pos nearEntities [_types, _safeRange])) > 0;
				if (_edge && !_safe) then {
					_since = _vehicle getVariable ["WFBE_Zargabad_EdgeSince", -1];
					if (_since < 0) then {
						_vehicle setVariable ["WFBE_Zargabad_EdgeSince", time];
					} else {
						if ((time - _since) >= _timeout) then {
							["WARNING", Format ["Zargabad_EdgeGuard.sqf: [%1] removed from edge rim at [%2].", name _unit, _pos]] Call WFBE_CO_FNC_LogContent;
							_vehicle setDamage 1;
							_vehicle setVariable ["WFBE_Zargabad_EdgeSince", -1];
						};
					};
				} else {
					if (_edge && _safe) then {
						_safeLogged = _vehicle getVariable ["WFBE_Zargabad_EdgeSafeLogged", false];
						if (!_safeLogged) then {
							["INFORMATION", Format ["Zargabad_EdgeGuard.sqf: [%1] allowed at safe edge rim [%2].", name _unit, _pos]] Call WFBE_CO_FNC_LogContent;
							_vehicle setVariable ["WFBE_Zargabad_EdgeSafeLogged", true];
						};
					} else {
						_vehicle setVariable ["WFBE_Zargabad_EdgeSafeLogged", false];
					};
					_vehicle setVariable ["WFBE_Zargabad_EdgeSince", -1];
				};
			};
		};
	} forEach allUnits;
};
