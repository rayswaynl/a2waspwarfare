Private['_amount','_team','_cur'];

_team = _this select 0;
_amount = _this select 1;

if (isNull _team) exitWith {};

//--- cmdcon43-h NIL-GUARD (Ray 2026-07-02): wfbe_funds can be nil on a group that was never funded (a
//--- fresh skin-swap group, a JIP/civilian slot, an AICOM helper). `nil + _amount` yields nil in A2-OA,
//--- which DESTROYS the variable and permanently zeroes that wallet (a refund/credit into an orphaned
//--- group would silently nuke it). Treat a missing/non-numeric current balance as 0 so a credit lands
//--- as its own value and a debit floors at the delta instead of erasing the wallet. A2-OA-1.64 safe:
//--- getVariable / typeName == / plain arithmetic (no isEqualType, no A3 commands).
_cur = _team getVariable "wfbe_funds";
if (isNil "_cur" || {typeName _cur != "SCALAR"}) then {_cur = 0};

_team setVariable ["wfbe_funds", (_cur + _amount), true];