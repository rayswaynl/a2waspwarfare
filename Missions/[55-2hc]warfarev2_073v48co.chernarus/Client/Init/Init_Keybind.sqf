/* Command Deck: Skin Selector keybind (User11). */
WF_SkinSelector_Hotkey = {
	Private ["_key"];
	_key = _this select 1;

	if (_key in (actionKeys "User11")) then {
		if ((call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_Enabled.sqf")) && {alive player} && {vehicle player == player}) then {
			if (!dialog) then {
				[] execVM "WASP\actions\SkinSelector\SkinSelector_Open.sqf";
			};
		};
	};

	false
};

/* Gear keybinding */
WF_Gear_Hotkeys = {
	Private ['_ctrl','_key'];
	_key = _this select 1;
	_ctrl = _this select 3;

	if (_key in (actionKeys "User15")) then {
		WF_Logic setVariable ['filler','all'];
	};
	if (_key in (actionKeys "User16")) then {
		WF_Logic setVariable ['filler','template'];
	};
	if (_key in (actionKeys "User17")) then {
		WF_Logic setVariable ['filler','primary'];
	};
	if (_key in (actionKeys "User18")) then {
		WF_Logic setVariable ['filler','secondary'];
	};
	if (_key in (actionKeys "User19")) then {
		WF_Logic setVariable ['filler','sidearm'];
	};
	if (_key in (actionKeys "User20")) then {
		WF_Logic setVariable ['filler','misc'];
	};

	false
};

//--- REVERTED 2026-08-03 (live regression, wave0803c): #1960 armed these on display 46. In game
//--- the Skin Selector dialog then opened on unrelated keys (owner-reported: SHIFT, and repeatedly
//--- while the map was open), thrashing dialog create/close and tanking CLIENT fps. The pre-#1960
//--- player-unit form was inert but harmless and shipped for months. Left UNARMED until the
//--- User11 match condition is fixed and verified IN GAME on the test box, not just at boot.

