/*
Toggle automatic IR smoke deployment off/on for this vehicle.
Trello (Suggested) #38: "Add UserAction key to turn off the IR smoke".

_this select 0 = the vehicle (_target)
_this select 3 = action args: [_disabled] where _disabled is true (turn auto-deploy OFF) / false (back ON)

wfbe_irs_disabled is read by Common\Module\IRS\IRS_OnIncomingMissile.sqf to gate auto-deploy.
public(true) broadcast so server-owned vehicles honor the toggle too.

r74: fail-clean null/dead hull + short/malformed action args before setVariable/vehicleChat
(action can race a sold/deleted hull; args missing when re-bound without [true]/[false]).
*/

Private ["_vehicle","_disabled","_args"];

_vehicle = _this select 0;
if (isNil "_vehicle") exitWith {};
if (typeName _vehicle != "OBJECT") exitWith {};
if (isNull _vehicle || {!alive _vehicle}) exitWith {};

if (isNil "_this" || {typeName _this != "ARRAY"} || {count _this < 4}) exitWith {};
_args = _this select 3;
if (isNil "_args" || {typeName _args != "ARRAY"} || {count _args < 1}) exitWith {};
_disabled = _args select 0;
if (typeName _disabled != "BOOL") exitWith {};

_vehicle setVariable ["wfbe_irs_disabled", _disabled, true];

if (_disabled) then {
	_vehicle vehicleChat localize "STR_WF_CHAT_IRS_Disabled";
} else {
	_vehicle vehicleChat localize "STR_WF_CHAT_IRS_Enabled";
};