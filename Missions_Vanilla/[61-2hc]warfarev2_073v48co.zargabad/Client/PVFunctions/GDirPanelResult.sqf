/*
	GDirPanelResult.sqf  (A1 Commissar Panel)
	GUIDE-REV GR-2026-07-03a

	Server pushes the accept/deny outcome back to the requesting GUER client.
	Displays a hint with result summary.

	Parameters (pushed by server via GDirPanelResult SendToClient):
	  _this = [status (String: "accept"|"deny"), message (String), verb (String), townId (String)]

	A2-OA-1.64 safe.
*/

private ["_status","_msg","_verb","_townId"];

_status = if (count _this > 0) then {_this select 0} else {"deny"};
_msg    = if (count _this > 1) then {_this select 1} else {"Unknown error."};
_verb   = if (count _this > 2) then {_this select 2} else {"?"};
_townId = if (count _this > 3) then {_this select 3} else {"?"};

if (_status == "accept") then {
	hint Format ["[GUER Director]\n%1\n(%2 -> %3)", _msg, _verb, _townId];
} else {
	hint Format ["[GUER Director - DENIED]\n%1\n(%2 -> %3)", _msg, _verb, _townId];
};
