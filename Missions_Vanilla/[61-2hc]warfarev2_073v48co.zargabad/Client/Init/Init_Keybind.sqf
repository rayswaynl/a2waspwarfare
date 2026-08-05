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

//--- REVERTED 2026-08-03 (live regression, wave0803c): #1960 armed these on display 46. In game
//--- the Skin Selector dialog then opened on unrelated keys (owner-reported: SHIFT, and repeatedly
//--- while the map was open), thrashing dialog create/close and tanking CLIENT fps. The pre-#1960
//--- player-unit form was inert but harmless and shipped for months. Left UNARMED until the
//--- User11 match condition is fixed and verified IN GAME on the test box, not just at boot.

