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

//--- Display 46 persists across player-unit replacement, so it owns these client keybinds.
//--- KeyDown is a display event in A2/OA; attaching it to the player silently leaves both
//--- the Skin Selector and gear filler binds unarmed. A repeated client-init replaces only
//--- this pair, preventing duplicate callbacks while preserving unrelated display handlers.
if (!isNil "WF_SkinSelector_Hotkey_EH") then {
	(findDisplay 46) displayRemoveEventHandler ["KeyDown", WF_SkinSelector_Hotkey_EH];
};
if (!isNil "WF_Gear_Hotkeys_EH") then {
	(findDisplay 46) displayRemoveEventHandler ["KeyDown", WF_Gear_Hotkeys_EH];
};
WF_SkinSelector_Hotkey_EH = (findDisplay 46) displayAddEventHandler ["KeyDown", "_this call WF_SkinSelector_Hotkey"];
WF_Gear_Hotkeys_EH = (findDisplay 46) displayAddEventHandler ["KeyDown", "_this call WF_Gear_Hotkeys"];

