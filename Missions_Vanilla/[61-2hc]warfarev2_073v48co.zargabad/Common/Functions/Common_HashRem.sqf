/*
	Common_HashRem.sqf
	WFBE_CO_FNC_HashRem

	Remove a key from a Common_HashCreate handle. Part of the SQF utility library (card #25).

	UNLIKE HashSet, this does NOT mutate in place: A2 OA has no `deleteAt` (A3-only) to shrink
	an array, so this rebuilds fresh _keys/_values arrays skipping the removed index and returns
	a NEW hash handle. Callers MUST reassign the result:

		_h = [_h, "somekey"] call WFBE_CO_FNC_HashRem;

	A no-op (returns a fresh identical-content copy of the original _hash) when the key is
	absent.

	Params:
		0: _hash  ARRAY, a handle from WFBE_CO_FNC_HashCreate.
		1: _key   ANY, the key to remove (compared with the array `find` command).

	Returns: ARRAY, the new hash handle to use going forward.
*/

private ["_hash","_key","_keys","_values","_idx","_newKeys","_newValues","_i"];

_hash = _this select 0;
_key = _this select 1;
_keys = _hash select 0;
_values = _hash select 1;
_idx = _keys find _key;

_newKeys = [];
_newValues = [];

if (_idx < 0) then {
	_newKeys = +_keys;
	_newValues = +_values;
} else {
	_i = 0;
	{
		if (_i != _idx) then {
			_newKeys set [count _newKeys, _x];
			_newValues set [count _newValues, (_values select _i)];
		};
		_i = _i + 1;
	} forEach _keys;
};

[_newKeys, _newValues]
