/* Generated-mission only: remove cached lobby-profile drift before recipe overrides. */

Private ["_params","_entry","_name","_value","_names"];

_params = missionConfigFile >> "Params";
_names = [];
for "_i" from 0 to ((count _params) - 1) do {
	_entry = _params select _i;
	if (isClass _entry) then {
		_name = configName _entry;
		_value = getNumber (_entry >> "default");
		missionNamespace setVariable [_name, _value];
		_names set [count _names, _name];
	};
};
missionNamespace setVariable ["WASP_LAB_PARAM_NAMES", _names];
diag_log ("WASPLAB|v1|PARAM_RESET|count=" + str (count _names));
