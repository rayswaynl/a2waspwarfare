/*
	Common_HashCreate.sqf
	WFBE_CO_FNC_HashCreate

	CBA-inspired key/value store for A2 OA - part of the SQF utility library (card #25,
	GR-2026-07-08a). Representation is TWO PARALLEL ARRAYS, not a native map type (A2 OA has
	none) - [_keys, _values], where element i of _values corresponds to element i of _keys.

	HONEST PERF NOTE: HashGet/HashSet/HashHasKey/HashRem all do a LINEAR SCAN over _keys via
	the array `find` command. This is NOT a hash table and is NOT faster than the existing
	manual-scan idiom already used in Server_CmdTownLedger.sqf - it exists purely to give
	callers a single documented, reusable key/value API instead of hand-rolling parallel-array
	scans at each call site. Do not adopt this expecting an algorithmic perf win.

	Nested arrays in SQF are held by reference, so mutating the _keys/_values array returned by
	`_hash select 0`/`_hash select 1` (via `set`) mutates the same object the caller holds -
	HashSet relies on this and mutates in place. HashRem cannot shrink an array in place without
	a banned A3 command (`deleteAt`), so it returns a NEW hash handle - always reassign its
	result:

		_h = [_h, "somekey"] call WFBE_CO_FNC_HashRem;

	Params: none.
	Returns: a new empty hash handle, ARRAY [[],[]].
*/

[[], []]
