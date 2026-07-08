/*
	WFBE_CL_FNC_ConfirmAction -- lightweight two-click confirmation for destructive UI actions.

	Usage: [_key, _message] call WFBE_CL_FNC_ConfirmAction  ->  returns true ONLY on the
	confirming (second) call for the same _key within the timeout window.

	First call for a key: stores it as pending, shows _message as a hint, returns false.
	Second call for the same key within ~6s: clears pending, clears the hint, returns true.
	A different key in between re-arms for that new key.

	Caller keeps its action "armed" while this returns false (do not reset its MenuAction),
	so the player's next click re-enters the handler and confirms.
*/
private ["_key","_msg","_pendKey","_pendTime"];
_key  = _this select 0;
_msg  = _this select 1;

_pendKey  = uiNamespace getVariable ["wfbe_confirm_key", ""];
_pendTime = uiNamespace getVariable ["wfbe_confirm_time", -1000];

if (_pendKey == _key && (time - _pendTime) < 6) exitWith {
	uiNamespace setVariable ["wfbe_confirm_key", ""];
	hintSilent "";
	true
};

uiNamespace setVariable ["wfbe_confirm_key", _key];
uiNamespace setVariable ["wfbe_confirm_time", time];
hintSilent parseText _msg;
false
