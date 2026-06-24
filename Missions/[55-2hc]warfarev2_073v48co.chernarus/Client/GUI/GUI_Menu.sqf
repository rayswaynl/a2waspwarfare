{ctrlEnable [_x, false]} forEach [11002, 11005, 11006, 11007, 11008];
//--- GUER insurgents: commander/base/upgrade/economy/vote buttons are irrelevant (no HQ/commander/base). Grey them.
if (sideJoined == resistance) then { {ctrlEnable [_x, false]} forEach [11004,11005,11006,11007,11008] };

_enable = false;
if ((barracksInRange || lightInRange || heavyInRange || aircraftInRange || hangarInRange || depotInRange) && (player == leader WFBE_Client_Team)) then {_enable = true};
ctrlEnable [11001,_enable];
ctrlEnable [11006,commandInRange && (player == leader WFBE_Client_Team)]; //--- Special Menu

MenuAction = -1;
WFBE_ForceUpdate = true;

while {alive player && dialog} do {
	//if (side group player != sideJoined) exitWith {closeDialog 0};
	if (!dialog) exitWith {};

	//--- Build Units.
	_enable = false;
	if ((barracksInRange || lightInRange || heavyInRange || aircraftInRange || hangarInRange || depotInRange) && (player == leader WFBE_Client_Team)) then {_enable = true};
	ctrlEnable [11001,_enable];
		if (sideJoined == resistance) then { ctrlEnable [11001, true] }; //--- GUER: base-less, buy always available (funds-only)
	ctrlEnable [11002,gearInRange];
		if (sideJoined == resistance) then { ctrlEnable [11002, true] }; //--- GUER: gear buy always available (funds-only)

		if (sideJoined == resistance) then {
			{ctrlEnable [_x, false]} forEach [11004,11005,11006,11007,11008]; //--- GUER: hold commander/base/upgrade/economy/vote disabled
		} else {
	_enable = false; //added-MrNiceGuy
	if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_enable = true}};
	ctrlEnable [11005,_enable]; //--- Team Orders
	ctrlEnable [11008,_enable]; //--- Commander Menu
	ctrlEnable [11006,commandInRange && (player == leader WFBE_Client_Team)]; //--- Special Menu
	ctrlEnable [11007,commandInRange]; //--- Upgrade Menu
		};

	//--- Uptime.
	_uptime = Call GetTime; //added-MrNiceGuy
	//--- QoL: compact strategic snapshot for the WF-menu top strip.
	private ["_clkH","_clkM","_playerCount","_playerSlots","_townsHeld","_townsTotal","_totalSupplyValue","_compensation","_svPlusText"];
	_clkH = date select 3; _clkM = date select 4;
	_clkH = if (_clkH < 10) then {"0" + str _clkH} else {str _clkH};
	_clkM = if (_clkM < 10) then {"0" + str _clkM} else {str _clkM};
	_playerCount = {isPlayer _x} count playableUnits;
	if (_playerCount == 0 && (isPlayer player)) then {_playerCount = 1};
	_playerSlots = count playableUnits;
	if (_playerSlots < _playerCount) then {_playerSlots = _playerCount};
	_townsTotal = if (isNil "towns") then {0} else {count towns};
	_townsHeld = if (_townsTotal > 0) then {sideJoined Call GetTownsHeld} else {0};
	_totalSupplyValue = sideJoined Call GetTotalSupplyValue;
	_compensation = 0;
	if (sideJoined == WEST) then {_compensation = SUPPLY_COMPENSATION_AMOUNT_WEST};
	if (sideJoined == EAST) then {_compensation = SUPPLY_COMPENSATION_AMOUNT_EAST};
	_svPlusText = Format ["+%1", _totalSupplyValue];
	if (_compensation > 0) then {_svPlusText = Format ["+%1 (+%2)", _totalSupplyValue, _compensation]};
	ctrlSetText [11015, format ["Uptime: %1h %2m | Time %3:%4 | Players %5/%6 | Towns %7/%8 | SV %9", (_uptime select 0) * 24 + (_uptime select 1), _uptime select 2, _clkH, _clkM, _playerCount, _playerSlots, _townsHeld, _townsTotal, _svPlusText]];	//--- QoL: compact top-strip status

	//--- Buy Units.
	if (MenuAction == 1) exitWith {
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_BuyUnits";
	};

	//--- Buy Gear.
	if (MenuAction == 2) exitWith {
		MenuAction = -1;
		closeDialog 0;
		createDialog "WFBE_BuyGearMenu";
	};

	//--- Team Menu.
	if (MenuAction == 3) exitWith {
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_Team";
	};

	//--- Voting Menu.
	if (MenuAction == 4) exitWith {
		MenuAction = -1;
		if(!isNull(commanderTeam))then{
			if(commanderTeam == group player)then{
				if((WFBE_Client_Logic getVariable "wfbe_votetime") <= 0)then{
					ctrlEnable [509101,true];
					closeDialog 0;
					createDialog "WFBE_Commander_VoteMenu";

				}else{
					ctrlEnable [509101,false];
				};
			}else{
				_skip = false;
				if ((WFBE_Client_Logic getVariable "wfbe_votetime") <= 0) then {_skip = true};
				if (!_skip) then {
					closeDialog 0;
					createDialog "WFBE_VoteMenu";
				};

				if !(_skip) exitWith {};
				["RequestCommanderVote", [sideJoined, name player]] Call WFBE_CO_FNC_SendToServer;
				voted = true;
				waitUntil {(WFBE_Client_Logic getVariable "wfbe_votetime") > 0 || !dialog || !alive player};
				if (!alive player || !dialog) exitWith {};
				closeDialog 0;
				createDialog "WFBE_VoteMenu";
			};
		}else{
			_skip = false;
			if ((WFBE_Client_Logic getVariable "wfbe_votetime") <= 0) then {_skip = true};
			if (!_skip) then {
				closeDialog 0;
				createDialog "WFBE_VoteMenu";
			};

			if !(_skip) exitWith {};
			["RequestCommanderVote", [sideJoined, name player]] Call WFBE_CO_FNC_SendToServer;
			voted = true;
			waitUntil {(WFBE_Client_Logic getVariable "wfbe_votetime") > 0 || !dialog || !alive player};
			if (!alive player || !dialog) exitWith {};
			closeDialog 0;
			createDialog "WFBE_VoteMenu";
		};
	};

	//--- Unflip Vehicle.
	if (MenuAction == 10) then { //added-MrNiceGuy
		MenuAction = -1;
		_vehicle = vehicle player;
		if (player != _vehicle) then {
			if (getPos _vehicle select 2 > 3 && !surfaceIsWater (getPos _x)) then {
				[_vehicle, getPos _vehicle, 15] Call PlaceSafe;
			} else {
				_vehicle setPos [getPos _vehicle select 0, getPos _vehicle select 1, 0.5];
				_vehicle setVelocity [0,0,-0.5];
			};
		};
		if (player == _vehicle) then {
			_objects = player nearEntities[["Car","Motorcycle","Tank"],10];
			if (count _objects > 0) then {
				{
					if (getPos _x select 2 > 3 && !surfaceIsWater (getPos _x)) then {
						[_x, getPos _x, 15] Call PlaceSafe;
					} else {
						_x setPos [getPos _x select 0, getPos _x select 1, 0.5];
						_x setVelocity [0,0,-0.5];
					};
				} forEach _objects;
			};
		};
	};

	//--- Headbug Fix.
	if (MenuAction == 11) then { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		titleCut["","BLACK FADED",0];
		_pos = position player;
		_vehi = "Lada1" createVehicle [0,0,0];
		player moveInCargo _vehi;
		deleteVehicle _vehi;
		player setPos _pos;
		titleCut["","BLACK IN",5];
	};

	//--- Display Parameters.
	if (MenuAction == 12) exitWith { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscDisplay_Parameters";
	};

	//--- Command Menu.
	if (MenuAction == 5) exitWith { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_Command";
	};

	//--- Tactical Menu.
	if (MenuAction == 6) exitWith { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_Tactical";
	};

	//--- Upgrade Menu.
	if (MenuAction == 7) exitWith { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "WFBE_UpgradeMenu";
	};

	//--- Economy Menu.
	if (MenuAction == 8) exitWith { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_Economy";
	};

	//--- Service Menu.
	if (MenuAction == 9) exitWith { //added-MrNiceGuy
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_Service";
	};

	//--- MenuAction 20 (Voting Page footer shortcut) removed 2026-06-12 — entry point moved to
	//---   "More votes..." button (WFBE_MenuAction 2) inside WFBE_VoteMenu (idd 500000).

	//--- Command Deck: Skin Selector (re-open from WF menu footer).
	if (MenuAction == 21) exitWith {
		MenuAction = -1;
		if (WFBE_C_SKIN_SELECTOR == 1 && {alive player} && {vehicle player == player}) then {
			closeDialog 0;
			[] execVM "WASP\actions\SkinSelector\SkinSelector_Open.sqf";
		};
	};

	//--- FPS / view-distance picker (re-open from WF menu footer).
	if (MenuAction == 23) exitWith {
		MenuAction = -1;
		closeDialog 0;
		[] execVM "WASP\actions\FPSPicker\FPSPicker_Open.sqf";
	};

	//--- B748: Settings menu (GEAR button = revived skins slot, idc 11021).
	if (MenuAction == 24) exitWith {
		MenuAction = -1;
		closeDialog 0;
		[] execVM "WASP\actions\Settings\Settings_Open.sqf";
	};

	//--- Help Menu
	if (MenuAction == 13) exitWith { //added-spayker
		MenuAction = -1;
		closeDialog 0;
		createDialog "RscMenu_Help";
	};

        //-- HUD:
	// Marty: Keep the menu loop alive so repeated HUD/FPS clicks are processed without reopening the WF menu.
	if (MenuAction == 16) then {
		MenuAction = -1;
		if(RUBHUD)then{RUBHUD = false}else{RUBHUD = true};
	};

	// Marty: Reuse the old FPS-only slot as a GPS enabler; client/server FPS now lives in RHUD.
	if (MenuAction == 19) exitWith {
		MenuAction = -1;
		missionNamespace setVariable ["WFBE_Client_MenuGPSState", true];
		if (!isNull player && {!("ItemGPS" in weapons player)}) then {player addWeapon "ItemGPS"};
		closeDialog 0;
		[] Spawn {
			// PR8 (claude): the engine accepts showGPS while the WF dialog (idd 11000) is still
			// closing yet draws no mini-map - the manual GPS keybind works only because it fires
			// with no dialog open. Wait for the WF menu display to actually close before enabling
			// GPS so the in-game HUD renders. Capped at 1.5s so a stuck display cannot hang this
			// thread; on timeout it falls back to the previous fixed-delay behaviour.
			private ["_deadline"];
			_deadline = time + 1.5;
			waitUntil {(isNull (findDisplay 11000)) || (time > _deadline)};
			sleep 0.10;
			missionNamespace setVariable ["WFBE_Client_MenuGPSState", true];
			if (!isNull player && {!("ItemGPS" in weapons player)}) then {player addWeapon "ItemGPS"};
			RUBGPS = 1;
			showGPS true;
			sleep 0.10;
			showGPS true;
			if (shownGPS) then {
				hint "GPS enabled.\nIf the mini-map stays hidden, press CTRL + M to toggle it.";
			} else {
				hint "GPS could not be enabled yet.\nCheck that your unit has GPS gear.";
			};
		};
	};

	if (MenuAction == 17) then {
		MenuAction = -1;
	if ( zoomgps < 1 ) then { zoomgps = (zoomgps + 0.025); hint "zoom OUT";} else { zoomgps = 1; hint "GPS Zoom: \n MAX Value";};
	};
	if (MenuAction == 18) then {
		MenuAction = -1;
	if ( zoomgps >= 0.025) then { zoomgps = (zoomgps - 0.025); hint "zoom IN";} else { zoomgps = 0.025; hint "GPS Zoom: \n MIN Value";};
	};

	// Earplugs: fade game volume to 20% and back; state persists after the menu closes.
	if (MenuAction == 22) then {
		MenuAction = -1;
		if (isNil "WFBE_Earplugs") then {WFBE_Earplugs = false};
		if (WFBE_Earplugs) then {
			WFBE_Earplugs = false;
			1 fadeSound 1;
			hint "Earplugs: OUT";
		} else {
			WFBE_Earplugs = true;
			1 fadeSound 0.2;
			hint "Earplugs: IN";
		};
	};

	sleep 0.1;
};
