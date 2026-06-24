/*
	B67 (guer-reward): personal VBIED cash bounty receiver.
	Dispatched server-side (Server_HandleSpecial.sqf guer-vbied-detonate) to the detonator's UID via
	WFBE_CO_FNC_SendToClients. Credits the local player's wallet by the accumulated cash-for-kills amount.
	 Parameters:
		- _this : NUMBER, the cash bounty to credit.
*/

Private ["_bounty"];

if (!isNil "isHeadLessClient") then {if (isHeadLessClient) exitWith {}};
if (isNull player) exitWith {};

_bounty = _this;
if (isNil "_bounty") exitWith {};
if (typeName _bounty != "SCALAR") exitWith {};
if (_bounty <= 0) exitWith {};

(_bounty) Call ChangePlayerFunds;
