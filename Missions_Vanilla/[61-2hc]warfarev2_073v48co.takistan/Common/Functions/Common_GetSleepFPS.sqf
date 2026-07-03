Private ["_delay","_scale","_fps","_multiplier"];

_delay = _this;
_scale = (missionNamespace getVariable ["WFBE_C_INCOME_SLEEP_FPS_SCALE", 1]) max 1;
if (_scale <= 1) exitWith {_delay};
if (_scale > 2) then {_scale = 2};

_fps = diag_fps;
_multiplier = 1;

if (_fps <= 15 && _fps > 10) then {_multiplier = 1.15};
if (_fps <= 10 && _fps > 7) then {_multiplier = 1.25};
if (_fps <= 7 && _fps > 5) then {_multiplier = 1.30};
if (_fps <= 5) then {_multiplier = 1.50};

_delay + (((_delay * _multiplier) - _delay) * (_scale - 1))
