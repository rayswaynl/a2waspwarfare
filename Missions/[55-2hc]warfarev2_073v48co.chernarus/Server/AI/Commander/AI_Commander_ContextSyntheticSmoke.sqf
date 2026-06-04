/*
	AI Commander context synthetic smoke helper.
	Phase 2 validation aid only; not wired into gameplay.
	Parameter: _side

	Manual use from server/debug context:
		west Call WFBE_SE_FNC_AI_Com_ContextSyntheticSmoke;
*/

Private ["_side","_logik","_teams","_team","_anchor","_pos","_enemy","_label","_context"];

_side = _this;
_logik = (_side) Call WFBE_CO_FNC_GetSideLogic;
if (isNil "_logik") exitWith {false};
if (isNil "WFBE_SE_FNC_AI_Com_LogAppend") exitWith {false};

_teams = _logik getVariable ["wfbe_teams", []];
_team = grpNull;
if (count _teams > 0) then {_team = _teams select 0};

_anchor = objNull;
if (count towns > 0) then {_anchor = towns select 0};
_pos = [0,0,0];
_label = "synthetic";
if (!isNull _anchor) then {
	_pos = getPos _anchor;
	_label = _anchor getVariable ["name", "town"];
};

_enemy = if (_side == west) then {east} else {west};

[_side, "CONTACT", "SYNTHETIC-C1", [_enemy, "armor", _pos, 3, 6, 0.75, _label]] Call WFBE_SE_FNC_AI_Com_LogAppend;
[_side, "CONTACT", "SYNTHETIC-C2", [_enemy, "armor", [(_pos select 0) + 80, (_pos select 1) + 40, 0], 2, 5, 0.65, _label]] Call WFBE_SE_FNC_AI_Com_LogAppend;
[_side, "INTEL", "SYNTHETIC-RADIO", [_enemy, "unknown", [(_pos select 0) + 120, (_pos select 1) + 80, 0], 0, -1, 0.35, _label, "radio-traffic"]] Call WFBE_SE_FNC_AI_Com_LogAppend;
[_side, "LOSS", "SYNTHETIC-LOSS", [_team, [(_pos select 0) + 300, (_pos select 1) + 150, 0], "vehicle-destroyed", "armor", 0.45]] Call WFBE_SE_FNC_AI_Com_LogAppend;

["INFORMATION", Format ["AI_Commander_ContextSyntheticSmoke: [%1] appended CONTACT/INTEL/LOSS synthetic records near %2.", str _side, _label]] Call WFBE_CO_FNC_LogContent;

if (!isNil "WFBE_SE_FNC_AI_Com_ContextUpdate") then {
	_context = (_side) Call WFBE_SE_FNC_AI_Com_ContextUpdate;
	if (!isNil "WFBE_SE_FNC_AI_Com_ContextDebug") then {[_side, _context] Call WFBE_SE_FNC_AI_Com_ContextDebug};
};

true;
