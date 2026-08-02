disableSerialization;
Private ["_color","_control","_duration","_text","_textcontent","_display","_ctrl","_i"];
_control = _this select 0;
_text = _this select 1;
_duration = _this select 2;
_color = _this select 3;

//--- Snapshot the dialog/control before the worker suspends. currentBEDialog is mutable: the parent
//--- can close this menu and open another dialog while the fade loop is sleeping.
_display = uiNamespace getVariable ["currentBEDialog", displayNull];
if (isNull _display) exitWith {};
_ctrl = _display displayCtrl _control;
if (isNull _ctrl) exitWith {};

//--- Animate.
_textcontent = parsetext (Format["<t size='0.8' color='#%1' font='Zeppelin33'>%2</t>",_color,_text]);
_ctrl ctrlSetStructuredText _textcontent;
_ctrl ctrlShow true;

_i = 0;
while {_i < _duration && {!isNull _display} && {!isNull _ctrl}} do {
	_ctrl ctrlSetFade (_i % 2);
	_ctrl ctrlCommit 1;

	_i = _i + 1;
	sleep 1;
};

if (!isNull _display && {!isNull _ctrl}) then {
	_ctrl ctrlSetStructuredText parseText ("");
	_ctrl ctrlShow false;
};
