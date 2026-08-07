/*
	WFBE_CO_FNC_IsHcName - belt-and-braces HC-name membership test (fix0807b/hc-quoted-names).
	Live RPT evidence 2026-08-07: an A2OA launch flag shaped -name="HC-AI-Control-1" bakes literal
	double-quote characters into the resolved profile name -
	CHATRELAY|v1|JOIN|"HC-AI-Control-1"|player joined vs a real player's
	CHATRELAY|v1|JOIN|Zwanon - so a raw (name _x) in WFBE_C_HC_NAMES test misses every quoted HC.
	That miss let a fully-enrolled HC pass the connect nameGate (Server_OnPlayerConnected.sqf) as a
	WEST player despite PR #2376, and separately let the same HC WIN the elected-commander seat via
	the commander-vote eligibility gate (Server_VoteForCommander.sqf) - both read the SAME registry.

	Init_CommonConstants.sqf's WFBE_C_HC_NAMES registry was widened (the BELT) to carry both the
	bare and the quoted variant of every registered HC name, which alone fixes every EXISTING raw
	`in WFBE_C_HC_NAMES` call site with zero consumer-file changes. This helper is the second layer
	(the BRACES): it additionally strips one leading and one trailing literal double-quote (ASCII 34) off the
	candidate before the membership test, so any OTHER future quoting/whitespace quirk (a launcher
	change, a different OS quoting convention) is still caught here, in ONE place, without another
	repo-wide grep. The highest-value money/enrollment consumers (connect gate, BankIncome,
	Common_CreditSidePlayers, victory tally, town-ai sortie gate, commander vote, kill-bounty
	credit in RequestOnUnitKilled.sqf) were switched to call this helper directly.

	A2-OA-1.64 safe: toArray/toString char-code strip (same idiom as RecordStat.sqf's
	WFBE_SE_FNC_SanitizeStatName and server_playerstat_loop.sqf) - substring `select [a,b]` is
	A3-only and banned on this engine (AGENTS.md / lint code A3SELECT), so this uses only
	scalar-index `select N` plus a bounded `for` loop, never a slice.

	Params: 0 - candidate name (STRING)
	Returns: BOOL - true if the (possibly quote-wrapped) candidate matches WFBE_C_HC_NAMES.
*/
Private ["_name","_hcNames","_chars","_len","_stripped","_inner","_i"];
_name = _this select 0;
if (typeName _name != "STRING") exitWith {false};

_hcNames = missionNamespace getVariable ["WFBE_C_HC_NAMES", []];
if (_name in _hcNames) exitWith {true};

_chars = toArray _name;
_len = count _chars;
_stripped = _name;
if (_len >= 2 && {(_chars select 0) == 34} && {(_chars select (_len - 1)) == 34}) then {
	_inner = [];
	for "_i" from 1 to (_len - 2) do { _inner set [count _inner, _chars select _i]; };
	_stripped = toString _inner;
};

(_stripped != _name) && {_stripped in _hcNames}
