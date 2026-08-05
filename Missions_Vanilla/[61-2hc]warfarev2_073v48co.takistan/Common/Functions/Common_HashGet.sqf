/*
	Common_HashGet.sqf
	WFBE_CO_FNC_HashGet

	Look up a key in a Common_HashCreate handle. Part of the SQF utility library (card #25).
	See Common_HashCreate.sqf for the representation/perf notes.

	Params:
		0: _hash     ARRAY, a handle from WFBE_CO_FNC_HashCreate.
		1: _key      ANY, the key to look up (compared with the array `find` command).
		2: _default  ANY, optional, returned when the key is absent. Defaults to nil (Void)
		             when omitted - test with `isNil "_result"` if you need to distinguish
		             "absent" from "present with a nil-like value".

	Returns: the stored value, or _default if the key is not present.
*/

private ["_hash","_key","_keys","_values","_idx","_result"];

_hash = _this select 0;
_key = _this select 1;
_keys = _hash select 0;
_values = _hash select 1;
_idx = _keys find _key;

if (_idx >= 0) then {
	_result = _values select _idx;
} else {
	if (count _this > 2) then {
		_result = _this select 2;
	};
};

_result
