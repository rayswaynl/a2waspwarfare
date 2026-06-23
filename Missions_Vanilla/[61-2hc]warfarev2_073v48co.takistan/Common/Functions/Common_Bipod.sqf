// -WASP-
// 3JIbIDEHb aka Smirnoff_ICE
private ["_unit","_weapon","_affected","_behind","_size"];

waituntil {!isnull (finddisplay 46)}; (findDisplay 46) displayAddEventHandler ["KeyDown","_this select 1 call Bipod_ON; false"];
	
Bipod_ON = {
		switch (_this) do {

            //For using bipod hit TAB
		case 15: {
		_weapon = currentWeapon player;
		_affected = ["ksvk",
		"m107",
		"m107_TWS_EP1",
		"BAF_AS50_scoped",
		"BAF_AS50_TWS",
		"BAF_L110A1_Aim",
		"BAF_L7A2_GPMG",
		"BAF_L86A2_ACOG",
		"BAF_LRR_scoped",
		"BAF_LRR_scoped_W",
		"M110_NVG_EP1",
		"M110_TWS_EP1",
		"M24",
		"M240",
		"m240_scoped_EP1",
		"M249",
		"M249_EP1",
		"M249_m145_EP1",
		"M249_TWS_EP1",
		"M24_des_EP1",
		"M40A3",
		"M60A4_EP1",
		"m8_SAW",
		"m8_sharpshooter",
		"MG36",
		"MG36_camo",
		"Mk_48",
		"Mk_48_DES_EP1",
		"Pecheneg",
		"PK",
		"PMC_AS50_scoped",
		"PMC_AS50_TWS",
		"RPK_74",
		"SCAR_H_LNG_Sniper",
		"SCAR_H_LNG_Sniper_SD"];
		_behind = cursorTarget;
		_size = sizeOf (typeOf _behind);
		Stands_behind = ((player distance _behind < _size/2.2) && (_size < 16.2));
		Lying_stand = ((animationState player == "amovppnemstpsraswrfldnon") && (_weapon in _affected));
		Crouch_stand = ((Stands_behind) && (_weapon in _affected) && (!(typeof _behind isKindOf "Man")) && (!(typeof _behind isKindOf "Air")));
		if (Lying_stand or Crouch_stand) then {
			SetBipodOn = HintSilent (localize "str_bipod"); player setUnitRecoilCoefficient 0; player say "Bipod_ON";
			};
//		};                                          //Debug
//		case 57: {     								//Hit SPACE
//			_behind = cursorTarget;
//			_size = sizeOf (typeOf _behind);
//			_bbr = [(boundingBox _behind select 0 select 0),(boundingBox _behind select 0 select 1),(boundingBox _behind select 0 select 2),(boundingBox _behind select 1 select 0),(boundingBox _behind select 1 select 1),(boundingBox _behind select 1 select 2)];
//			nul = hint format ["%1, %2, %3", name player, currentWeapon player, direction player]; hint format ["%1",_bbr]; hint animationState player; 
		};
//		HintSilent ""; 
		player setUnitRecoilCoefficient 1;
	};
};

//--- Card #210: auto-deploy the bipod when going prone with a bipod-capable MG (no TAB needed).
//--- This reuses the existing key-15 deploy path, which itself re-checks the prone stance and the
//--- bipod-capable weapon list, so the handler only actually deploys for those weapons while lying.
//--- Pure client-local (the deploy path only adjusts recoil coef + hint + say). The TAB display
//--- handler above stays as the manual fallback. The EH is unit-local and is flushed on death, so
//--- Client_OnKilled.sqf re-attaches it to the fresh player unit after each respawn.
Bipod_AddAutoDeploy = {
	if (isNil "Bipod_AutoEH") then {Bipod_AutoEH = -1};
	if (Bipod_AutoEH >= 0) then {player removeEventHandler ["AnimChanged", Bipod_AutoEH]; Bipod_AutoEH = -1};
	Bipod_AutoEH = player addEventHandler ["AnimChanged", {
		if ((_this select 1) == "amovppnemstpsraswrfldnon") then {15 call Bipod_ON};
	}];
};

[] call Bipod_AddAutoDeploy;