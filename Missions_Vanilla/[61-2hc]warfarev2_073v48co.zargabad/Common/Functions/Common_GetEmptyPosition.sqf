/*
	Return an empty 'safe' position.
	 Parameters:
		- Position (Object / Position).
		- Radius.
		- Optional maximum attempts (default 1000).
*/

Private ["_attempts", "_band", "_bandAttempts", "_found", "_i", "_lastDry", "_maxAttempts", "_object", "_position", "_radius", "_searchRadius", "_tpos"];

_object = _this select 0;
_radius = _this select 1;
_maxAttempts = if (count _this > 2) then {_this select 2} else {1000};
if (typeName _maxAttempts != "SCALAR") then {_maxAttempts = 1000};
if (_maxAttempts < 1) then {_maxAttempts = 1000};
_maxAttempts = floor _maxAttempts;
_bandAttempts = floor (_maxAttempts / 4);
if (_bandAttempts < 1) then {_bandAttempts = 1};

if (typeName _object == "OBJECT") then {_object = getPos _object};

//--- Search four bounded bands instead of spending all 1000 checks at one radius.
_attempts = 0;
_band = 0;
_found = false;
_searchRadius = _radius max 5;
_position = [(_object select 0)+(_searchRadius - (random (_searchRadius * 2))),(_object select 1)+(_searchRadius - (random (_searchRadius * 2))),0];
_lastDry = +_object;

while {_band < 4 && {!_found}} do {
	_searchRadius = ((_radius * (1 + (_band * 0.5))) max 5);
	_i = 0;
	while {_attempts < _maxAttempts && {_attempts < ((_band + 1) * _bandAttempts)} && {!_found}} do {
		_tpos = [(_object select 0)+(_searchRadius - (random (_searchRadius * 2))),(_object select 1)+(_searchRadius - (random (_searchRadius * 2))),0];
		_position = _tpos;
		if (!(surfaceIsWater _tpos)) then {_lastDry = +_tpos};
		if (!(surfaceIsWater _tpos) && {count (_tpos isFlatEmpty [15, 0, 2, 10, 0, false, objNull]) > 0}) then {_found = true};
		_i = _i + 1;
		_attempts = _attempts + 1;
	};
	_band = _band + 1;
};

if (!_found) then {
	_position = _lastDry;
	["WARNING", Format ["Common_GetEmptyPosition.sqf: no empty position after %4 attempts near [%1,%2] radius %3; using last dry fallback.", _object select 0, _object select 1, _radius, _maxAttempts]] Call WFBE_CO_FNC_AICOMLog;
};

_position
