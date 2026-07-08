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
};
player addEventHandler ["KeyDown", WF_SkinSelector_Hotkey];

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
};

