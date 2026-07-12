/*
	Common_WeightedDraw.sqf
	WFBE_CO_FNC_WeightedDraw

	fable/radius-hold-primitive (GR-2026-07-08a): pure weighted-roll primitive, no side-wallet or
	eligibility coupling. Extracted from AI_Commander_Wildcard.sqf's proven roll algorithm (cumulative
	sum / random walk / de-correlation entropy jitter / fallback, AI_Commander_Wildcard.sqf:619-655 at
	time of extraction) per design doc S0.2 - reused as the ALGORITHM, not a call into the side-economy
	function. Callers needing an eligibility re-draw loop (e.g. a future KotH reward table) build it by
	zeroing ineligible weights before calling, and re-calling this on an unacceptable result - that
	retry policy is caller-specific and intentionally NOT baked into this primitive.

	Params:
		0: _weightPairs   ARRAY of [id, weight] pairs, e.g. [[1,17],[2,8],[3,0], ...].
		                  Zero-weight entries are effectively ineligible (never selected unless every
		                  entry is zero, see fallback below).

	Returns: the chosen id (whatever type the caller used for id, typically a NUMBER). If every weight
	         is <= 0 (cumSum <= 0), falls back to the FIRST entry's id (mirrors the wildcard's own
	         "fallback to card 1" - card 1 is the wildcard's first table entry). Empty input returns nil.
*/

private ["_weightPairs","_cumSum","_entropy","_roll","_i","_chosen","_cumSum2"];

_weightPairs = _this select 0;

if (count _weightPairs == 0) exitWith { nil };

_cumSum = 0;
{ _cumSum = _cumSum + (_x select 1) } forEach _weightPairs;

if (_cumSum > 0) then {
	//--- DE-CORRELATION: second independent random call mixed in (mirrors AI_Commander_Wildcard.sqf).
	_entropy = random 1;
	_roll = (random _cumSum) + _entropy * 0.0001;
	_i = 0;
	_cumSum2 = 0;
	while {_i < count _weightPairs && {isNil "_chosen"}} do {
		_cumSum2 = _cumSum2 + ((_weightPairs select _i) select 1);
		if (_roll < _cumSum2) then { _chosen = (_weightPairs select _i) select 0; };
		_i = _i + 1;
	};
};

if (isNil "_chosen") then { _chosen = (_weightPairs select 0) select 0; };

_chosen