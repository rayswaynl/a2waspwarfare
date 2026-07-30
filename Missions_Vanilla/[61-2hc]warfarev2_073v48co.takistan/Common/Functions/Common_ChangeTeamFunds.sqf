Private['_amount','_team','_cur'];

_team = _this select 0;
_amount = _this select 1;

if (isNull _team) exitWith {};

//--- FUNDS-AUTH 20260730: non-SCALAR amount (string/bool/array forge via client ChangePlayerFunds
//--- or a malformed server debit) used to feed _cur + _amount and could nil/destroy wfbe_funds.
//--- Reject non-numbers before any wallet write. Zero no-ops are allowed (harmless).
if (isNil \"_amount\" || {typeName _amount != \"SCALAR\"}) exitWith {};

//--- cmdcon43-h NIL-GUARD (Ray 2026-07-02): wfbe_funds can be nil on a group that was never funded (a
//--- fresh skin-swap group, a JIP/civilian slot, an AICOM helper). 
il + _amount yields nil in A2-OA,
//--- which DESTROYS the variable and permanently zeroes that wallet (a refund/credit into an orphaned
//--- group would silently nuke it). Treat a missing/non-numeric current balance as 0 so a credit lands
//--- as its own value and a debit floors at the delta instead of erasing the wallet. A2-OA-1.64 safe:
//--- getVariable / typeName == / plain arithmetic (no isEqualType, no A3 commands).
_cur = _team getVariable \"wfbe_funds\";
if (isNil \"_cur\" || {typeName _cur != \"SCALAR\"}) then {_cur = 0};

//--- FUNDS-AUTH 20260730: never stamp a negative wallet. A concurrent overspend or race that would
//--- push below zero clamps to 0 instead of publishing a negative balance (negative funds break
//--- affordability gates that use < cost and can desync JIP record lock-step semantics).
_team setVariable [\"wfbe_funds\", ((_cur + _amount) max 0), true];

//--- Ray pick A (2026-07-03) FUNDS-RECORD LOCK-STEP: keep WFBE_JIP_USER<uid> cash in step with this
//--- wallet change so a JIP zero-latch recovery from the record is provably safe (a real spend-to-0
//--- also writes 0 into the record, so restore never re-grants). This fn is the single choke-point for
//--- group-funds changes (Client_ChangePlayerFunds -> clientTeam -> here; every server credit/debit ->
//--- here). It runs WHERE called: server-side we update the record inline; client-side we mirror the now
//--- broadcast (authoritative) wallet back to the server over the existing PVF channel (the server re-reads
//--- the group's own wfbe_funds - no client number is trusted). On a hosted/listen server isServer is true
//--- for the local player too, so it takes the inline path (no needless PVF). AI/commander groups carry no
//--- wfbe_uid and are skipped inside the helper. A2-OA-1.64 safe: isServer / isNull / getVariable / PVF send.
if (isServer) then {
	[_team] Call WFBE_SE_FNC_SyncFundsRecord;
} else {
	//--- Only mirror the LOCAL player's own slot group (the common self-spend/credit); a cross-player
	//--- transfer target self-reconciles on its own next change/disconnect, and the restore rule only ever
	//--- raises toward the record when the wallet is 0/nil, so a slightly-stale record can never grant money.
	if (!isNull player && {_team == group player} && {!isNil {_team getVariable \"wfbe_side\"}}) then {
		[\"RequestFundsRecord\", [player]] Call WFBE_CO_FNC_SendToServer;
	};
};
