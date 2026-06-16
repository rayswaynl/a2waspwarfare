/*
	SkinSelector_Open.sqf
	Opens the skin selector dialog (idd 27000) and runs the controller loop.
	Mirrors the GUI_Menu_Voting.sqf structural pattern.
	May be called from:
	  - Skill_Init.sqf join hook (show-once on first join)
	  - GUI_Menu.sqf MenuAction 21 (WF-menu SKIN button, re-open)
	  - Init_Keybind.sqf User11 keybind
*/

disableSerialization; //--- BUG-FIX 2026-06-14: suppress "_display does not support serialization" (dialog control held in a local).

Private ["_display","_pool","_visiblePool","_i","_cls","_lbl","_isGhillie",
         "_selectedIdx","_selectedCls","_selectedLbl","_portrait",
         "_regEntry","_factionText","_WFBE_MenuAction"];

//--- Guard.
if (WFBE_C_SKIN_SELECTOR != 1) exitWith {};
if (!(alive player)) exitWith {};
if (!(vehicle player == player)) exitWith {hint "Skin selection is only available on foot."};
if (dialog) exitWith {};

//--- Build visible pool: all non-ghillie skins + ghillie only for the SNIPER.
//--- NB: the sniper role's type string is "Spotter" (legacy misnomer) — WFBE_SK_V_Spotters in
//--- Skill_Init.sqf holds the *_Sniper classes only; there is no separate "Sniper" type.
_pool = call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_Data.sqf");

_visiblePool = [];
_i = 0;
while {_i < count _pool} do {
	Private ["_entry"];
	_entry     = _pool select _i;
	_isGhillie = _entry select 2;
	if (!_isGhillie || (WFBE_SK_V_Type == "Spotter")) then {
		_visiblePool set [count _visiblePool, _entry];
	};
	_i = _i + 1;
};

if (count _visiblePool == 0) exitWith {hint "No skins available for your side."};

createDialog "WFBE_SkinSelectorMenu";

_display = findDisplay 27000;

//--- Populate list.
lbClear 27001;
_i = 0;
while {_i < count _visiblePool} do {
	_lbl = (_visiblePool select _i) select 1;
	lbAdd [27001, _lbl];
	_i = _i + 1;
};
lbSetCurSel [27001, 0];

//--- Show ghillie note if applicable.
if (WFBE_SK_V_Type != "Spotter") then {
	ctrlSetText [27005, localize "STR_WF_SkinSelector_GhillieNote"];
} else {
	ctrlSetText [27005, ""];
};

WFBE_MenuAction = -1;
_selectedIdx = 0;

while {alive player && dialog} do {

	//--- Selection changed: update portrait / labels.
	_selectedIdx = lbCurSel 27001;
	if (_selectedIdx < 0) then {_selectedIdx = 0};
	if (_selectedIdx >= count _visiblePool) then {_selectedIdx = 0};

	_selectedCls = (_visiblePool select _selectedIdx) select 0;
	_selectedLbl = (_visiblePool select _selectedIdx) select 1;

	//--- Portrait.
	_portrait = "";
	_regEntry = missionNamespace getVariable [_selectedCls, []];
	if ((count _regEntry) > QUERYUNITPICTURE) then {
		_portrait = _regEntry select QUERYUNITPICTURE;
	};
	if (_portrait == "") then {
		_portrait = [_selectedCls, "portrait"] Call GetConfigInfo;
	};
	ctrlSetText [27002, _portrait];

	//--- Name label.
	ctrlSetText [27003, _selectedLbl];

	//--- Faction.
	_factionText = [_selectedCls, "faction"] Call GetConfigInfo;
	ctrlSetText [27004, _factionText];

	//--- Handle APPLY (MenuAction 1).
	if (WFBE_MenuAction == 1) exitWith {
		WFBE_MenuAction = -1;
		closeDialog 0;
		diag_log format ["[WFBE (SKIN)] B0 Apply pressed: class='%1' player='%2'", _selectedCls, name player];
		[_selectedCls] execVM "WASP\actions\SkinSelector\SkinSelector_Apply.sqf";
	};

	//--- Handle SKIP (MenuAction 2).
	if (WFBE_MenuAction == 2) exitWith {
		WFBE_MenuAction = -1;
		closeDialog 0;
	};

	sleep 0.1;
};
