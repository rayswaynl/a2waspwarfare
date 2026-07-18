/*
	Server-owned AICOM transport refund observer.
	Parameters: [private dispatch token]

	The HC never submits a refund completion command. This worker watches the exact server-known
	transport stored in the receipt, verifies that the live hull crossed the map boundary, consumes
	the receipt once, and credits the server-derived price. Destroyed, retained, stale, or missing
	hulls do not produce a refund.
*/
Private ["_token","_receipts","_receipt","_receiptIndex","_found","_vehicle","_pos","_worldSize","_offMap","_finished","_deadline"];

if (!isServer) exitWith {};
if (count _this < 1) exitWith {};
_token = _this select 0;
if (typeName _token != "STRING" || {_token == ""}) exitWith {};

//--- DEADLINE FIX: cover the full server-observed flight-refund budget, not just part of it.
//--- Receipt registration (aicom-team-created -> Server_HandleSpecial.sqf) fires synchronously,
//--- in the same tick as the AIR-INSERT Spawn block below in Common_RunCommanderTeam.sqf, so the
//--- worst-case time from registration to the hull reaching the map edge is the sum of that
//--- blocks own waits: board(30s) + run-in(240s) + land/disembark(40s) + fly-to-edge(360s) = 670s.
//--- The prior 390s deadline expired BEFORE a legitimate long flight could ever reach the edge,
//--- silently dropping the refund (receipt just goes stale/unconsumed). 900s covers the full
//--- 670s budget with a ~230s margin for scheduler/poll jitter; it does not change WHO gets paid
//--- or HOW MUCH, only how long the server is willing to keep watching a legitimate flight.
_deadline = time + 900;
_finished = false;
while {time < _deadline && {!_finished}} do {
	_receipts = missionNamespace getVariable ["WFBE_AICOM_HELI_REFUND_RECEIPTS", []];
	_receiptIndex = -1;
	_found = false;
	{
		if (count _x >= 9) then {
			if (!_found && {(_x select 0) == _token} && {(_x select 8) == 0}) then {
				_receipt = _x;
				_receiptIndex = _forEachIndex;
				_found = true;
			};
		};
	} forEach _receipts;
	if (!_found) then {
		_finished = true;
	} else {
		_vehicle = _receipt select 2;
		if (isNull _vehicle || {!alive _vehicle}) then {
			_finished = true;
		} else {
			_worldSize = switch (toLower worldName) do {
				case "takistan": {12800};
				case "zargabad": {8192};
				default {15360};
			};
			_pos = getPos _vehicle;
			_offMap = ((_pos select 0) < 0) || {((_pos select 0) > _worldSize)} || {((_pos select 1) < 0)} || {((_pos select 1) > _worldSize)};
			if (_offMap) then {
				//--- Consume before credit: a concurrent worker/re-entry sees state 1.
				_receipt set [8, 1];
				_receipts set [_receiptIndex, _receipt];
				missionNamespace setVariable ["WFBE_AICOM_HELI_REFUND_RECEIPTS", _receipts];
				[(_receipt select 4), (_receipt select 7)] Call ChangeAICommanderFunds;
				["INFORMATION", Format ["Server_AICOM_HeliRefundWatch.sqf: accepted $%1 for [%2] owner %3 (server hull edge, one-shot).", _receipt select 7, str (_receipt select 4), _receipt select 5]] Call WFBE_CO_FNC_AICOMLog;
				_finished = true;
			};
		};
	};
	if (!_finished) then {sleep 3};
};
