/*
	WFBE_SE_FNC_ConsumeCapability -- atomic compare-and-consume for a WFBE_SE_FNC_MintCapability token.

	THREAT MODEL: see WFBE_SE_FNC_MintCapability's doc comment for the full picture; in short, the
	minted token is the only thing standing between "this request came from the connection that
	actually owns this player object" and "this request came from anyone who could guess/observe an
	object reference" for endpoints with no other server-verifiable channel. This half of the pair
	exists because possession alone is not enough -- a token that can be presented twice, or read
	before it is cleared, reopens the exact TOCTOU hole capability tokens are meant to close. This
	function runs the compare + clear as ONE unscheduled step (SQF code inside isNil {} runs without a
	scheduler yield on A2/OA, mirroring Support_FPV.sqf's purchase-phase atomic block), and clears the
	stored capability THE MOMENT a matching token is found -- before returning to the caller, and
	therefore strictly before any side effect the caller performs with the result. A caller that
	instead reads the token, performs its side effect, and consumes LAST has reintroduced the race this
	function exists to close; always gate the side effect on this function's return value, never the
	other way around.

	WHAT THIS DOES NOT PROTECT AGAINST: it does not re-validate anything about the PLAYER beyond
	deriving their UID server-side (alive/side/team/range/funds/etc. remain the caller's job, same as
	every existing in-repo adopter of the mint/consume idiom); it cannot stop a caller from performing
	its side effect and consuming out of order (see above -- this function has no way to know when or
	whether the caller's side effect happens); it does not protect a purpose from being consumed by
	whichever request happens to win the race for the FIRST correct token presentation -- that race is
	inherent to "one-shot", not a flaw of this implementation; and an expired-but-matched token is
	still consumed (burned) here, not left available for a hypothetical retry, matching every existing
	in-repo precedent (Init_IcbmTel.sqf, Support_FPV.sqf) -- a stale token is treated as spent, not
	re-issuable, so a resend after expiry cannot retry the same secret.

	Precedents this generalises: Server/Init/Init_IcbmTel.sqf (WFBE_SE_FNC_IcbmTelFire's capability
	check, ~lines 554-577) and Server/Support/Support_FPV.sqf (the purchase-phase atomic block).

	Params: [_purpose (STRING), _player (OBJECT), _token (STRING)]
	  _purpose - must match the purpose the capability was minted under.
	  _player  - the presenting player object; the UID checked is ALWAYS getPlayerUID _player, never a
	             client-supplied UID string.
	  _token   - the secret the client is presenting back.

	Returns: [_ok (BOOL), _reason (STRING)].
	  _ok == true   -> _reason == ""; the capability existed, matched, was unexpired, and is now
	                    cleared. Safe to perform the side effect.
	  _ok == false  -> _reason is one of:
	                    "missing"    - no capability on file for this purpose+UID (never minted,
	                                   already consumed, expired-and-reaped by another call, or the
	                                   call itself carried a malformed/empty argument -- degenerate
	                                   call shapes are folded into this bucket rather than inventing a
	                                   fifth reason code, since the safe outcome is identical: nothing
	                                   valid was available to consume).
	                    "malformed"  - a value WAS on file but not the [token, expires] shape this
	                                   pair writes (defensive; should not occur in normal operation).
	                    "mismatched" - a capability is on file but _token does not match it; the stored
	                                   capability is left UNTOUCHED (it may still belong to the
	                                   legitimate in-flight request racing this one).
	                    "expired"    - _token matched but its TTL had already elapsed; consumed anyway
	                                   (see above) so a resend cannot retry it.
*/
Private ["_purpose","_player","_token","_uid","_capKey","_cap","_state","_expires"];

_state = "missing";

if (typeName _this == "ARRAY" && {count _this >= 3}) then {
	_purpose = _this select 0;
	_player = _this select 1;
	_token = _this select 2;

	if (typeName _purpose == "STRING" && {_purpose != ""} && {typeName _player == "OBJECT"} && {!isNull _player} && {typeName _token == "STRING"} && {_token != ""}) then {
		_uid = getPlayerUID _player;
		if (_uid != "") then {
			_capKey = Format ["wfbe_cap_%1_server_%2", _purpose, _uid];
			_expires = 0;

			//--- Unscheduled: compare + clear happen as one atomic step, so no concurrently-spawned
			//--- consume for the same purpose+UID can observe the token between the match check and
			//--- the clear.
			isNil {
				_cap = missionNamespace getVariable [_capKey, []];
				if (typeName _cap != "ARRAY" || {count _cap < 2}) then {
					_state = "missing";
				} else {
					if (typeName (_cap select 0) != "STRING" || {typeName (_cap select 1) != "SCALAR"}) then {
						_state = "malformed";
					} else {
						if (_token != (_cap select 0)) then {
							_state = "mismatched";
						} else {
							//--- Cleared BEFORE this function returns -- strictly before any caller
							//--- side effect.
							missionNamespace setVariable [_capKey, []];
							_expires = _cap select 1;
							if (_expires <= time) then {_state = "expired"} else {_state = "ok"};
						};
					};
				};
			};
		};
	};
};

if (_state != "ok") exitWith {
	["WARNING", Format ["Server_ConsumeCapability.sqf: consume denied for purpose [%1] UID [%2]: %3.", (if (isNil "_purpose") then {"?"} else {_purpose}), (if (isNil "_uid") then {"?"} else {_uid}), _state]] Call WFBE_CO_FNC_LogContent;
	[false, _state]
};

[true, ""]
