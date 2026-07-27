/*
	WFBE_SE_FNC_MintCapability -- generic server-minted, purpose-bound, one-shot capability token.

	THREAT MODEL (read this before using): A2 OA's publicVariable/PVEH channel and the shared
	Server_HandleSpecial dispatch it feeds carry NO trusted sender identity -- any connected client can
	send any payload claiming to be any object, side, team, or player it can observe or compute (see
	the fake-identity-binding writeup this generalises: hardening PRs for RespawnST and RequestBaseArea
	both shipped "requester identity" guards that validated a client-supplied object reference against a
	value the SAME client could also compute -- which proves nothing). This helper closes that class of
	hole for any endpoint that adopts it: the server mints an unguessable, single-use, short-lived
	secret and delivers it PRIVATELY (a targeted PVF via WFBE_CO_FNC_SendToClient, never the shared
	RequestSpecial bus) to the one client whose connection actually owns the nominated player object at
	mint time. Only whoever received that reply can ever present the matching token back, because it
	never crosses the shared channel, and the UID it is filed under is derived server-side from the
	object's OWNER, not from anything the client states. Pair with WFBE_SE_FNC_ConsumeCapability, which
	atomically compares, clears, and reports the token back at the point of use.

	WHAT THIS DOES NOT PROTECT AGAINST: it does not stop the legitimate token holder from doing
	something they are otherwise allowed to do (this is a possession/freshness proof, not an
	authorization/permission check -- callers must still gate WHO is allowed to mint a given purpose,
	e.g. side/team/range/funds, exactly as every adopting endpoint already does for its own domain
	rules); it does not stop the holder's own client from being modified to automate legitimate re-use
	within the TTL (rate limiting only bounds MINT frequency, not what a valid holder does with a token
	before it expires or is consumed); it does not survive a player disconnecting and a different human
	taking over that UID mid-TTL (same trust boundary as every other per-UID server variable in this
	codebase); and it is only as strong as the caller's OWN atomic consume discipline -- a caller that
	reads the token, performs its side effect, and consumes LAST has reintroduced a TOCTOU race this
	helper cannot fix for them (see WFBE_SE_FNC_ConsumeCapability's doc comment).

	Precedents this generalises (copy their shape, don't reinvent it per-endpoint):
	  Server/Init/Init_IcbmTel.sqf (WFBE_SE_FNC_IcbmTelAuth, one-shot purpose-bound ~15s TTL mint,
	  private reply via targeted PVF) and Server/Support/Support_FPV.sqf ("auth" mode, adds the
	  per-UID mint rate stamp this helper also implements).

	Params: [_purpose (STRING), _player (OBJECT), _replyCase (STRING), _challenge (STRING, optional,
	         default ""), _ttl (SCALAR, optional, default 15), _minInterval (SCALAR, optional, default 1)]
	  _purpose     - non-empty; keys the capability's storage AND is echoed back in the reply so a
	                 single generic client-side dispatcher can route replies for many purposes.
	  _player      - the requesting player object; the UID used for storage/reply is ALWAYS
	                 getPlayerUID _player, never a client-supplied string.
	  _replyCase   - the HandleSpecial case name the client is listening for; this helper does not
	                 assume any particular client-side contract beyond the reply payload shape
	                 [_replyCase, _purpose, _token, _expires, _challenge].
	  _challenge   - opaque value echoed back unchanged so the client can correlate the async reply
	                 with the UI action that triggered it; purely a caller convenience, not a security
	                 input (never trusted for anything on the server side).
	  _ttl         - capability lifetime in seconds from mint/first-issue.
	  _minInterval - minimum seconds between FRESH mints for the same purpose+UID (mirrors the
	                 Support_FPV.sqf auth-flood hardening); re-issuing an already-valid, unexpired
	                 capability is a cheap read with no state mutation and is deliberately EXEMPT from
	                 this throttle -- gating reuse too would let a flooding attacker deny the
	                 legitimate owner's own retries, which is worse than the flood this guards against.

	Returns: true if a capability was minted or reused and privately replied to the player's owning
	         client; false if the request was refused (bad shape, non-player, or rate-limited) --
	         refusals are WARNING-logged and receive NO reply, so a throttled caller simply times out
	         instead of being told anything an attacker could use to fingerprint the gate.
*/
Private ["_purpose","_player","_replyCase","_challenge","_ttl","_minInterval","_uid","_capKey","_mintKey","_cap","_capValid","_token","_expires","_now","_last","_blocked"];

if (typeName _this != "ARRAY" || {count _this < 3}) exitWith {false};
_purpose = _this select 0;
_player = _this select 1;
_replyCase = _this select 2;
_challenge = if (count _this > 3) then {_this select 3} else {""};
_ttl = if (count _this > 4) then {_this select 4} else {15};
_minInterval = if (count _this > 5) then {_this select 5} else {1};

if (typeName _purpose != "STRING" || {_purpose == ""}) exitWith {false};
if (typeName _player != "OBJECT" || {isNull _player}) exitWith {false};
if (typeName _replyCase != "STRING" || {_replyCase == ""}) exitWith {false};
if (typeName _challenge != "STRING") then {_challenge = ""};
if (typeName _ttl != "SCALAR" || {_ttl <= 0}) then {_ttl = 15};
if (typeName _minInterval != "SCALAR" || {_minInterval < 0}) then {_minInterval = 1};
if (!alive _player || {!isPlayer _player}) exitWith {false};

_uid = getPlayerUID _player;
if (_uid == "") exitWith {false};

_capKey = Format ["wfbe_cap_%1_server_%2", _purpose, _uid];
_mintKey = Format ["wfbe_cap_%1_mint_last_%2", _purpose, _uid];
_blocked = false;
_token = "";
_expires = 0;

//--- Unscheduled: the reuse-check, the rate-check, and any fresh write happen as one atomic step
//--- (isNil {} runs its code without a scheduler yield on A2/OA). See Support_FPV.sqf's "auth" mode
//--- for the precedent this mirrors.
isNil {
	_cap = missionNamespace getVariable [_capKey, []];
	_capValid = false;
	if (typeName _cap == "ARRAY" && {count _cap >= 2}) then {
		if (typeName (_cap select 0) == "STRING" && {typeName (_cap select 1) == "SCALAR"}) then {
			if ((_cap select 0) != "" && {(_cap select 1) > time}) then {_capValid = true};
		};
	};
	if (_capValid) then {
		//--- Cheap read, no mutation -- deliberately not rate-limited (see doc comment above).
		_token = _cap select 0;
		_expires = _cap select 1;
	} else {
		_now = time;
		_last = missionNamespace getVariable [_mintKey, -1e9];
		if (typeName _last != "SCALAR") then {_last = -1e9};
		if ((_now - _last) < _minInterval) then {
			_blocked = true;
		} else {
			missionNamespace setVariable [_mintKey, _now];
			_token = Format ["%1:%2:%3:%4:%5", _purpose, _uid, floor (diag_tickTime * 1000), floor (random 1000000000), floor (random 1000000000)];
			_expires = time + _ttl;
			missionNamespace setVariable [_capKey, [_token, _expires]];
		};
	};
};

if (_blocked) exitWith {
	["WARNING", Format ["Server_MintCapability.sqf: mint throttled for purpose [%1] UID [%2].", _purpose, _uid]] Call WFBE_CO_FNC_LogContent;
	false
};

[_player, "HandleSpecial", [_replyCase, _purpose, _token, _expires, _challenge]] Call WFBE_CO_FNC_SendToClient;
true
