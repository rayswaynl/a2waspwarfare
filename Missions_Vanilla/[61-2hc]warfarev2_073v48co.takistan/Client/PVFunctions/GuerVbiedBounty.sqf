/*
	B67 (guer-reward): personal VBIED cash bounty receiver.
	Dispatched server-side (Server_HandleSpecial.sqf guer-vbied-detonate) to the detonator's UID via
	WFBE_CO_FNC_SendToClients. Credits the local player's wallet by the accumulated cash-for-kills amount.
	 Parameters:
		- _this : NUMBER, the cash bounty to credit.
*/

Private ["_bounty"];

if (!isNil "isHeadLessClient" && {isHeadLessClient}) exitWith {}; //--- fix(hunt): the old exitWith sat INSIDE a then{} - it exited only that block and FELL THROUGH to the wallet credit; top-scope form makes the HC guard real.
if (isNull player) exitWith {};

_bounty = _this;
if (isNil "_bounty") exitWith {};
if (typeName _bounty != "SCALAR") exitWith {};
if (_bounty <= 0) exitWith {};

diag_log ("GUERVBIED|v1|CLIENT|received|bounty=" + (str _bounty) + "|uid=" + (getPlayerUID player) + "|crediting wallet"); //--- Ray 2026-06-27: confirm the wallet credit fires on the detonator's client (server+client round-trip trace).
(_bounty) Call ChangePlayerFunds;
