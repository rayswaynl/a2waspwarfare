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
		//--- Ray 3B (GR-2026-07-03a): the old GUER unconditional gear-buy enable is GATED. With WFBE_C_GUER_GEAR_PROXIMITY
		//--- default 1, the button follows gearInRange (line above), which now goes true for GUER only near a friendly
		//--- town-center depot / GUER-held camp / deployed FOB barracks (Client\FSM\updateavailableactions.fsm,
		//--- WFBE_C_UNITS_PURCHASE_GEAR_RANGE = 150m). Flag 0 restores the pre-fix buy-anywhere behaviour for GUER.
		if (sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_GEAR_PROXIMITY", 1]) < 1}) then { ctrlEnable [11002, true] };

		if (sideJoined == resistance) then {
			{ctrlEnable [_x, false]} forEach [11004,11005,11006,11008]; //--- GUER: hold commander/base/economy/vote disabled
				ctrlEnable [11007, true]; //--- B75 (guer-tech): the Upgrade Center is a READ-ONLY kill-tech progression viewer for GUER (GUI_UpgradeMenu.sqf resistance branch).
		} else {
	_enable = false; //added-MrNiceGuy
	if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_enable = true}};
	ctrlEnable [11005,true]; //--- Command war-room: always openable on WEST/EAST; the dialog gates internally (Take Command vs war room). JIP-safe.
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

	//--- Buy Gear. Ray 3B (GR-2026-07-03a): re-check the gear gate here too so the menu cannot be opened via any other
	//--- route (e.g. a raced MenuAction) while out of range - mirrors the ctrlEnable [11002,...] button gate. The GUER
	//--- flag-0 (buy-anywhere restore) branch keeps opening, matching the button re-enable above.
	if (MenuAction == 2) exitWith {
		MenuAction = -1;
		if (gearInRange || {sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_GEAR_PROXIMITY", 1]) < 1}}) then {
			closeDialog 0;
			createDialog "WFBE_BuyGearMenu";
		};
	};

	//--- Team Menu.
	if (MenuAction == 3) exitWith {
		MenuAction = -1;
		closeDialog 0;
		if ((missionNamespace getVariable ["WFBE_C_TEAM_MENU_V2", 0]) > 0) then {
			createDialog "RscMenu_TeamV2";
		} else {
			createDialog "RscMenu_Team";
		};
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
			//--- No human commander: the AI is running this side.
			_skip = false;
			if ((WFBE_Client_Logic getVariable "wfbe_votetime") <= 0) then {_skip = true};
			if (!_skip) then {
				//--- Round-start vote window still open: keep the normal vote menu.
				closeDialog 0;
				createDialog "WFBE_VoteMenu";
			};

			if (!_skip) then {
				//--- Round-start path: cast a vote (unchanged behaviour).
				["RequestCommanderVote", [sideJoined, name player]] Call WFBE_CO_FNC_SendToServer;
				voted = true;
				waitUntil {(WFBE_Client_Logic getVariable "wfbe_votetime") > 0 || !dialog || !alive player};
				if (alive player && dialog) then {
					closeDialog 0;
					createDialog "WFBE_VoteMenu";
				};
			} else {
				//--- Mid-round: the vote window is permanently closed for JIP joiners, so
				//--- there is no re-vote. Claim the empty AI commander seat ("TAKE COMMAND").
				["RequestClaimCommander", [sideJoined, group player]] Call WFBE_CO_FNC_SendToServer;
				closeDialog 0;
			};
		};
	};

	//--- Unflip Vehicle.
	if (MenuAction == 10) then { //added-MrNiceGuy
		MenuAction = -1;
		_vehicle = vehicle player;
		if (player != _vehicle) then {
			if (getPos _vehicle select 2 > 3 && !surfaceIsWater (getPos _vehicle)) then {
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

	//--- Command Menu (commander-only war room). Open UNCONDITIONALLY on WEST/EAST: the dialog's own
	//--- gate (GUI_Menu_Command.sqf) shows the TAKE COMMAND button + explainer when you are not (yet) the
	//--- commander, and the war room when you are. This is what fixes the JIP dead-button - a joiner whose
	//--- commanderTeam has not replicated still gets a live claim button instead of a disabled/blank tab.
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
		if ((call (compile preprocessFile "WASP\actions\SkinSelector\SkinSelector_Enabled.sqf")) && {alive player} && {vehicle player == player}) then {
			closeDialog 0;
			[] execVM "WASP\actions\SkinSelector\SkinSelector_Open.sqf";
		};
	};

	//--- FPS / view-distance button now opens the unified PLAYER SETTINGS dialog (GR-2026-07-03a).
	if (MenuAction == 23) exitWith {
		MenuAction = -1;
		closeDialog 0;
		[] execVM "WASP\actions\Settings\Settings_Open.sqf";
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
	//--- cmdcon42 (Ray 2026-07-02) GPS/Mini-Map button fix. Previous behaviour: the button set showGPS true
	//--- but then read `shownGPS` ~0.2s later and, on a false-negative race, hinted "GPS could not be enabled"
	//--- even after a successful enable — so the button LOOKED dead. Also, if the player genuinely had no way
	//--- to get ItemGPS the failure was silent. New behaviour: guarantee ItemGPS (add it), enable GPS reliably
	//--- once the WF dialog has actually closed (showGPS draws nothing while idd 11000 is still up), and give a
	//--- single clear hint. `showGPS`/`shownGPS` are the same A2-OA-1.64 commands the Tactical menu and every
	//--- marker loop already rely on. An always-on RPT line records the transition so a tester can confirm.
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
			private ["_deadline","_hasGPS"];
			_deadline = time + 1.5;
			waitUntil {(isNull (findDisplay 11000)) || (time > _deadline)};
			sleep 0.10;
			missionNamespace setVariable ["WFBE_Client_MenuGPSState", true];
			//--- Guarantee the GPS receiver: showGPS renders NOTHING without ItemGPS in the player's kit.
			if (!isNull player && {!("ItemGPS" in weapons player)}) then {player addWeapon "ItemGPS"};
			_hasGPS = (!isNull player) && {"ItemGPS" in weapons player};
			RUBGPS = 1;
			showGPS true;
			sleep 0.10;
			showGPS true;
			//--- Always-on state line so a tester can confirm the button fired and whether the kit has GPS.
			diag_log format ["[WFBE (GPS)] GPS button: hasItemGPS=%1 shownGPS=%2 (menu closed, showGPS true issued)", _hasGPS, shownGPS];
			//--- Base the hint on whether the player actually HAS the receiver, not on the racey shownGPS read
			//--- (shownGPS can lag one frame behind showGPS true and produced false "could not enable" hints).
			if (_hasGPS) then {
				hint "GPS / Mini-Map enabled.\nIf the mini-map stays hidden, press CTRL + M to toggle it.";
			} else {
				hint "Requires GPS.\nGet ItemGPS (equip GPS gear) and try again.";
			};
		};
	};

	//--- wiki-wins: removed dormant GPS-zoom router cases (MenuAction 17/18) — no control or key ever sets those values, and zoomgps is never read elsewhere.

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

	// qol-polish-pack: friendly name-tag overlay toggle (the worldToScreen loop + RscTitles live in Init_Client.sqf / Titles.hpp).
	if (MenuAction == 25) then {
		MenuAction = -1;
		if (isNil "WFBE_NameTagsEnabled") then {WFBE_NameTagsEnabled = false};
		WFBE_NameTagsEnabled = !WFBE_NameTagsEnabled;
		hint (Format ["Name tags: %1", if (WFBE_NameTagsEnabled) then {"ON"} else {"OFF"}]);
	};

	sleep 0.1;
};
