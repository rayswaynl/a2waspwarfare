/*
	J1 funds authority (2026-07-13): PvP killstreak bounty math, extracted VERBATIM from
	Client/PVFunctions/AwardBountyPlayer.sqf lines 12-27 so the SERVER can compute the amount at
	send time (RequestOnUnitKilled.sqf) - authoritative and immune to the client-side score-sync
	lag / corpse-deletion underpay (the client read `score _killed` at receive time).
	NOTE: _coef is computed BEFORE the score<=0 branch, exactly like the client file - for
	score <= 0 the fractional negative exponent yields INF/NaN in _coef, which is harmless ONLY
	because that branch returns the literal 180 and never reads _coef. Do not reorder.
	 Parameters:
		0 - killed player score (NUMBER, read server-side)
		1 - victim pre-reset killstreak (NUMBER)
	 Returns: SCALAR bounty.
	A2-OA-1.64 safe: arithmetic / min / round only. Streak constants are unconditional
	Init_CommonConstants.sqf globals, identical on every machine.
*/
Private ["_score","_streak","_coef","_bounty","_mult"];

_score = _this select 0;
_streak = _this select 1;

_coef = 7*_score;
_coef = _coef^(-0.1);

_bounty = if (_score <= 0) then {
            180;
          } else {
            100+14*_score*_coef;
          };

_bounty = round _bounty;

//--- Card #66 (killstreak bounty): scale the payout by the VICTIM streak, clamped at the cap.
_mult = 1 + ((_streak min WFBE_C_UNITS_BOUNTY_STREAK_CAP) * WFBE_C_UNITS_BOUNTY_STREAK_COEF);
_bounty = round (_bounty * _mult);

_bounty
