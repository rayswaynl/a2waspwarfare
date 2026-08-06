/*
	Common_HashHasKey.sqf
	WFBE_CO_FNC_HashHasKey

	Test whether a key exists in a Common_HashCreate handle. Part of the SQF utility library
	(card #25). See Common_HashCreate.sqf for the representation/perf notes.

	Params:
		0: _hash  ARRAY, a handle from WFBE_CO_FNC_HashCreate.
		1: _key   ANY, the key to test (compared with the array `find` command).

	Returns: BOOLEAN, true if present.
*/

private ["_hash","_key","_keys"];

_hash = _this select 0;
_key = _this select 1;
_keys = _hash select 0;

(_keys find _key) >= 0
