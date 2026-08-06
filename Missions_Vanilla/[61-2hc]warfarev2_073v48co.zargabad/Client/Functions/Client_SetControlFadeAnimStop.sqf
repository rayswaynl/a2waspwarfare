disableSerialization;
Private ["_control","_display","_ctrl"];
_control = _this select 0;

//--- Resolve the active dialog once. A missing/closed dialog is a normal race with menu teardown.
_display = uiNamespace getVariable ["currentBEDialog", displayNull];
if (isNull _display) exitWith {};
_ctrl = _display displayCtrl _control;
if (isNull _ctrl) exitWith {};
if !(ctrlShown _ctrl) exitWith {};

_ctrl ctrlSetStructuredText parseText ("");
_ctrl ctrlShow false;
