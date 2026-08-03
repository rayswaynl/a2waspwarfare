/*
	Common_HashSet.sqf
	WFBE_CO_FNC_HashSet

	Insert or overwrite a key in a Common_HashCreate handle, IN PLACE (see Common_HashCreate.sqf
	for why this works - nested arrays are held by reference in SQF). Part of the SQF utility
	library (card #25).

	Params:
		0: _hash   ARRAY, a handle from WFBE_CO_FNC_HashCreate.
		1: _key    ANY, the key to set (compared with the array `find` command).
		2: _value  ANY, the value to store.

	Returns: _hash (same handle, mutated in place - the return value is a convenience for
	         chaining, not a new object).
*/

private ["_hash","_key","_value","_keys","_values","_idx"];

_hash = _this select 0;
_key = _this select 1;
_value = _this select 2;
_keys = _hash select 0;
_values = _hash select 1;
_idx = _keys find _key;

if (_idx < 0) then {
	_keys set [count _keys, _key];
	_values set [count _values, _value];
} else {
	_values set [_idx, _value];
};

_hash
