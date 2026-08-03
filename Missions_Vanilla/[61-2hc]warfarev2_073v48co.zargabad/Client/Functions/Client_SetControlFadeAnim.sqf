//--- OA 1.64 (2026-08-03): NO disableSerialization and NO Display/Control held in a local across the
//--- sleep below. Holding either kills a suspending script on A2 OA (opposite of A3) - the engine-verified
//--- finding from the m0730f->g incident (docs/CHANGELOG-m0730g.md). Symptom when violated: the loop dies
//--- after its first sleep, so the trailing cleanup never runs and the "click on map" hint (17022) stays
//--- stuck on screen forever for every Tactical Arty/SCUD/TEL/Recon placement. Every dialog/control lookup
//--- below is re-fetched inline at its point of use, mirroring the proven-safe GUI_RespawnMenu.sqf idiom.
Private ["_color","_control","_duration","_text","_textcontent","_i"];
_control = _this select 0;
_text = _this select 1;
_duration = _this select 2;
_color = _this select 3;

if (isNull (uiNamespace getVariable ["currentBEDialog", displayNull])) exitWith {};
if (isNull ((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control)) exitWith {};

//--- Animate.
_textcontent = parsetext (Format["<t size='0.8' color='#%1' font='Zeppelin33'>%2</t>",_color,_text]);
((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control) ctrlSetStructuredText _textcontent;
((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control) ctrlShow true;

_i = 0;
while {_i < _duration && {!isNull (uiNamespace getVariable ["currentBEDialog", displayNull])} && {!isNull ((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control)}} do {
	((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control) ctrlSetFade (_i % 2);
	((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control) ctrlCommit 1;

	_i = _i + 1;
	sleep 1;
};

if (!isNull (uiNamespace getVariable ["currentBEDialog", displayNull]) && {!isNull ((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control)}) then {
	((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control) ctrlSetStructuredText parseText ("");
	((uiNamespace getVariable ["currentBEDialog", displayNull]) displayCtrl _control) ctrlShow false;
};
