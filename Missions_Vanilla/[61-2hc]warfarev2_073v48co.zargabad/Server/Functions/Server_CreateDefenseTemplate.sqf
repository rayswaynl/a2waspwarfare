Private ["_created","_current","_dir","_existingTemplate","_i","_object","_origin","_relDir","_relPos","_skip","_template","_toplace","_toWorld"];
_origin = _this select 0;
_template = _this select 1;
_existingTemplate = if (count _this > 2) then {_this select 2} else {[]};

if (isNil "_template") exitWith {
	["WARNING", Format ["Server_CreateDefenseTemplate.sqf: Missing wall template for origin [%1].", typeOf _origin]] Call WFBE_CO_FNC_LogContent;
	[]
};

if (typeName _template != "ARRAY") exitWith {
	["WARNING", Format ["Server_CreateDefenseTemplate.sqf: Invalid wall template type [%1] for origin [%2].", typeName _template, typeOf _origin]] Call WFBE_CO_FNC_LogContent;
	[]
};

_dir = getDir _origin;
_created = [];
_toplace = objNull;

for '_i' from 0 to count(_template)-1 do {
	_current = _template select _i;
	_object = _current select 0;
	_relPos = _current select 1;
	_relDir = _current select 2;
	
	_skip = false;
	if (_i < count(_existingTemplate)) then {
		if (alive(_existingTemplate select _i)) then {_skip = true};
	};
	
	if !(_skip) then {
		_toplace = createVehicle [_object, [0,0,0], [], 0, "NONE"];
		//--- r36 fail-clean: skip null pieces so WFBE_Walls/hq_walls do not accumulate objNull and
		//--- setDir/setPos never run on a failed create (bad class / engine fail mid-ring).
		if (isNull _toplace) then {
			["WARNING", Format ["Server_CreateDefenseTemplate.sqf: createVehicle FAILED for class [%1] on origin [%2] (template index %3).", _object, typeOf _origin, _i]] Call WFBE_CO_FNC_LogContent;
			diag_log format ["DEFWALL|CREATEFAIL|class=%1|origin=%2", _object, typeOf _origin];
		} else {
			_toplace setVariable ["wfbe_defense", true]; //--- This is one of our defenses.

			_toWorld = _origin modelToWorld _relPos;
			_toWorld set [2,0];

			_toplace setDir (_dir - _relDir);
			_toplace setPos _toWorld;
			_created = _created + [_toplace];
		};
	} else {
		_toplace = _existingTemplate select _i;
		_created = _created + [_toplace];
	};
};

_created
