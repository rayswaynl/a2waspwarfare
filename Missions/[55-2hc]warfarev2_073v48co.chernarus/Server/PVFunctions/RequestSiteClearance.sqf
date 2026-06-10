/*
	RequestSiteClearance.sqf — Server PVF for the Site Clearance commander action.

	Sent by coin_interface.sqf when the player places the 'Land_Pneu' anchor.
	The client passes the real 'player' object in the payload so that Gate 3 in
	Server_SiteClearance.sqf compares the ACTUAL placer against the commander,
	not the result of a server-side leader() lookup (which would always be the
	commander and would make the gate inert).

	TRUST MODEL NOTE: client-supplied player identity is acceptable here because:
	(a) the gate checks the player is the commander group leader — a non-commander
	    cannot forge a passing payload without also somehow being the commander;
	(b) coin_interface only fires on the requesting machine, so the payload player
	    IS the local player; spoofing it gains nothing an attacker could not already
	    do by simply being elected commander.

	Parameters (array sent from coin_interface.sqf):
		_this select 0 : sideJoined (Side)
		_this select 1 : placement position [x, y, z]
		_this select 2 : player (the client who triggered placement)
*/

private ["_side","_pos","_reqPlayer"];

_side      = _this select 0;
_pos       = _this select 1;
_reqPlayer = _this select 2;

[_side, _pos, _reqPlayer] Call Server_SiteClearance;
