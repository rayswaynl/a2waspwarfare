/*
	Parameters Constants Initialization, use the same class name for parameter as variables.

	MP note: paramsArray is positional and can be shorter or reordered-stale vs missionConfigFile >> Params
	when the dedicated server lobby cache was written by an older build. Out-of-range selects yield nil and
	would previously write nil into missionNamespace (unsetting the variable). Fall back to the mission
	param default for any index outside the live array so Constants isNil-guards are not the only safety net.
*/

for '_i' from 0 to (count (missionConfigFile >> "Params"))-1 do {
	_paramName = (configName ((missionConfigFile >> "Params") select _i));
	_value = if (isMultiplayer) then {
		if (_i < count paramsArray) then {
			paramsArray select _i
		} else {
			getNumber (missionConfigFile >> "Params" >> _paramName >> "default")
		}
	} else {
		getNumber (missionConfigFile >> "Params" >> _paramName >> "default")
	};

	//--- A2: never persist a nil lobby slot (unset var). Prefer mission default so downstream
	//--- missionNamespace getVariable fallbacks and Constants isNil guards see a real SCALAR.
	if (isNil "_value") then {
		_value = getNumber (missionConfigFile >> "Params" >> _paramName >> "default");
	};

	//--- A stale lobby cache can still provide a non-nil value from an older schema. Reject it
	//--- before a mode switch or other first-frame consumer sees an unsupported scalar.
	_values = getArray (missionConfigFile >> "Params" >> _paramName >> "values");
	if ((count _values > 0) && {!(_value in _values)}) then {
		_fallback = getNumber (missionConfigFile >> "Params" >> _paramName >> "default");
		diag_log format ["## PARAMGUARD|name=%1|value=%2|fallback=%3", _paramName, _value, _fallback];
		_value = _fallback;
	};

	missionNamespace setVariable [_paramName, _value];
};

["INITIALIZATION", "Init_Parameters.sqf: Parameters are defined."] Call WFBE_CO_FNC_LogContent;
