/*
	Return an empty 'safe' position.
	 Parameters:
		- Position (Object / Position).
		- Radius.
*/

Private ["_i" ,"_object", "_position", "_tpos"];

_object = _this select 0;
_radius = _this select 1;

if (typeName _object == "OBJECT") then {_object = getPos _object};

_position = [(_object select 0)+5,(_object select 1)+5,0];
_i = 0;

while {_i < 1000} do {
	_tpos = [(_object select 0)+(_radius - (random (_radius * 2))),(_object select 1)+(_radius - (random (_radius * 2))),0];
	if (count (_tpos isFlatEmpty [15, 0, 2, 10, 0, false, objNull]) > 0) exitWith {_position = _tpos};
	_i = _i + 1;
};

if (_i >= 1000) then {
	["WARNING", Format ["Common_GetEmptyPosition.sqf: no empty position after 1000 attempts near [%1,%2] radius %3; using fallback.", _object select 0, _object select 1, _radius]] Call WFBE_CO_FNC_AICOMLog;
};

_position