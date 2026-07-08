/*
	Toggle automatic IR smoke deployment off/on for this vehicle.
	Trello (Suggested) #38: "Add UserAction key to turn off the IR smoke".

	_this select 0 = the vehicle (_target)
	_this select 3 = action args: [_disabled] where _disabled is true (turn auto-deploy OFF) / false (back ON)

	wfbe_irs_disabled is read by Common\Module\IRS\IRS_OnIncomingMissile.sqf to gate auto-deploy.
	public(true) broadcast so server-owned vehicles honor the toggle too.
*/

Private ["_vehicle","_disabled"];

_vehicle = _this select 0;
_disabled = (_this select 3) select 0;

_vehicle setVariable ["wfbe_irs_disabled", _disabled, true];

if (_disabled) then {
	_vehicle vehicleChat localize "STR_WF_CHAT_IRS_Disabled";
} else {
	_vehicle vehicleChat localize "STR_WF_CHAT_IRS_Enabled";
};
