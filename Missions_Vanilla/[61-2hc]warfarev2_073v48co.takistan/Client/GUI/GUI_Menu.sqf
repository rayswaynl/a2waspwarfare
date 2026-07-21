disableSerialization;
private ["_setWFMenuState"];
_setWFMenuState = {
	private ["_controlId","_state"];
	_controlId = _this select 0;
	_state = _this select 1;
	ctrlEnable [_controlId, _state];
	((findDisplay 11000) displayCtrl _controlId) ctrlSetFade (if (_state) then {0} else {0.55});
	((findDisplay 11000) displayCtrl _controlId) ctrlCommit 0;
};
{[_x, false] call _setWFMenuState} forEach [11002, 11005, 11006, 11007, 11008];
//--- GUER insurgents: commander/base/upgrade/economy/vote buttons are irrelevant (no HQ/commander/base). Grey them.
if (sideJoined == resistance) then { {[_x, false] call _setWFMenuState} forEach [11004,11005,11006,11007,11008] };
//--- A1 Commissar Panel (owner 2026-07-07): for GUER, REPURPOSE the (GUER-dead) Economy button as the
//--- panel entry instead of the cramped corner button - re-enable it and relabel. MenuAction 8 branches
//--- by side below. The corner 11030 button is retired (hidden for all sides); its MenuAction 30 path
//--- stays as a harmless no-op fallback.
if (sideJoined == resistance) then {
	[11008, true] call _setWFMenuState;
	private ["_gvisTeam","_gvisWallet","_gvisLabel"];
	if ((missionNamespace getVariable ["WFBE_C_GDIR_VIS", 1]) > 0) then {
		_gvisTeam = group player;
		_gvisWallet = _gvisTeam getVariable "wfbe_funds";
		if (isNil "_gvisWallet") then {_gvisWallet = 0};
		_gvisLabel = Format ["Towns ($%1)", round _gvisWallet];
	} else {
		_gvisLabel = "Towns";
	};
	ctrlSetText [11008, _gvisLabel]; //--- WFBE_C_GDIR_VIS: wallet shown when flag on (default 1)
};
ctrlShow [11030, false];
//--- fable/drones-menu: for GUER, repurpose the (GUER-dead) Tactical Center button as the Drones entry.
if (sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) > 0}) then {
	[11006, true] call _setWFMenuState;
	ctrlSetText [11006, "Drone"];
};
//--- fable/guer-tabs-menu-declutter: for GUER, relabel the (GUER read-only kill-tech viewer) Factory Upgrade tab as Base unlocks.
if (sideJoined == resistance) then {
	ctrlSetText [11007, "Base unlocks"];
};

_enable = false;
if ((barracksInRange || lightInRange || heavyInRange || aircraftInRange || hangarInRange || depotInRange) && (player == leader WFBE_Client_Team)) then {_enable = true};
[11001, _enable] call _setWFMenuState;
[11006, commandInRange && (player == leader WFBE_Client_Team)] call _setWFMenuState; //--- Special Menu
if (sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) > 0}) then {[11006, true] call _setWFMenuState}; //--- fable/drones-menu: restore DRONES enable overridden by line above

MenuAction = -1;
WFBE_ForceUpdate = true;

while {alive player && dialog} do {
	//if (side group player != sideJoined) exitWith {closeDialog 0};
	if (!dialog) exitWith {};

	//--- Build Units.
	_enable = false;
	if ((barracksInRange || lightInRange || heavyInRange || aircraftInRange || hangarInRange || depotInRange) && (player == leader WFBE_Client_Team)) then {_enable = true};
	[11001, _enable] call _setWFMenuState;
		if (sideJoined == resistance) then { [11001, true] call _setWFMenuState }; //--- GUER: base-less, buy always available (funds-only)
	[11002, gearInRange] call _setWFMenuState;
		//--- Ray 3B (GR-2026-07-03a): the old GUER unconditional gear-buy enable is GATED. With WFBE_C_GUER_GEAR_PROXIMITY
		//--- default 1, the button follows gearInRange (line above), which now goes true for GUER only near a friendly
		//--- town-center depot / GUER-held camp / deployed FOB barracks (Client\FSM\updateavailableactions.fsm,
		//--- WFBE_C_UNITS_PURCHASE_GEAR_RANGE = 150m). Flag 0 restores the pre-fix buy-anywhere behaviour for GUER.
		if (sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_GEAR_PROXIMITY", 1]) < 1}) then { [11002, true] call _setWFMenuState };

		if (sideJoined == resistance) then {
			{[_x, false] call _setWFMenuState} forEach [11004,11005]; //--- GUER: hold commander/base/vote disabled; 11008=Towns re-enabled pre-loop
			if ((missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) <= 0) then {[11006, false] call _setWFMenuState}; //--- fable/drones-menu: keep Drones button live when flag on
				[11007, true] call _setWFMenuState; //--- B75 (guer-tech): the Upgrade Center is a READ-ONLY kill-tech progression viewer for GUER (GUI_UpgradeMenu.sqf resistance branch).
				if (((missionNamespace getVariable ["WFBE_C_GUER_LOCKOUT_MIN", 0]) * 60) > time) then { {[_x, false] call _setWFMenuState} forEach [11001,11002,11008] }; //--- fable/guer-lockout: buy/gear/Town Actions held until activation
		} else {
	_enable = false; //added-MrNiceGuy
	if (!isNull(commanderTeam)) then {if (commanderTeam == group player) then {_enable = true}};
	[11005, true] call _setWFMenuState; //--- Command war-room: always openable on WEST/EAST; the dialog gates internally (Take Command vs war room). JIP-safe.
	[11008, _enable] call _setWFMenuState; //--- Commander Menu
	[11006, commandInRange && (player == leader WFBE_Client_Team)] call _setWFMenuState; //--- Special Menu
	[11007, commandInRange] call _setWFMenuState; //--- Upgrade Menu
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
	ctrlSetText [11015, format ["WF HUB | %1h %2m | Time %3:%4 | Players %5/%6 | Towns %7/%8 | SV %9", (_uptime select 0) * 24 + (_uptime select 1), _uptime select 2, _clkH, _clkM, _playerCount, _playerSlots, _townsHeld, _townsTotal, _svPlusText]];	//--- QoL: compact top-strip status

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
		//--- fable/drones-menu: GUER opens Drone Ops menu; W/E keep Tactical Center.
		if (sideJoined == resistance && {(missionNamespace getVariable ["WFBE_C_GUER_DRONES_MENU", 1]) > 0}) then {
			createDialog "WFBE_GuerDronesMenu";
		} else {
			createDialog "RscMenu_Tactical";
		};
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
		//--- A1 Commissar Panel: the Economy slot doubles as the GUER Town Actions entry.
		if (sideJoined == resistance) then {
			createDialog "WFBE_GDirCommissarMenu";
		} else {
			createDialog "RscMenu_Economy";
		};
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

	//--- RADIO: vehicle radio menu (replaces the obsolete FPS button, which duplicated the SETUP/GEAR
	//--- Settings entry point at MenuAction 24). Gate at click time: needs the player in a vehicle AND
	//--- a side Radio Tower, matching the vehicle addAction gate in Init_Unit.sqf.
	if (MenuAction == 26) exitWith {
		MenuAction = -1;
		if (vehicle player == player) exitWith {
			hint "Radio requires a vehicle.";
		};
		if !((side player) call WFBE_CO_FNC_HasSideRadioTower) exitWith {
			hint "Requires a Radio Tower.";
		};
		closeDialog 0;
		[vehicle player, player] execVM "WASP\Radio\Radio_Menu.sqf";
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

	// qol-polish-pack: friendly name-tag overlay toggle (the worldToScreen loop + RscTitles live in Init_Client.sqf / Titles.hpp).
	if (MenuAction == 25) then {
		MenuAction = -1;
		if (isNil "WFBE_NameTagsEnabled") then {WFBE_NameTagsEnabled = false};
		WFBE_NameTagsEnabled = !WFBE_NameTagsEnabled;
		missionNamespace setVariable ["WFBE_NameTagsEnabled", WFBE_NameTagsEnabled];
		hint (Format ["Name tags: %1", if (WFBE_NameTagsEnabled) then {"ON"} else {"OFF"}]);
		if !(isNil "WFBE_CO_FNC_SetProfileVariable") then {["WFBE_NAMETAGS_ENABLED", WFBE_NameTagsEnabled] Call WFBE_CO_FNC_SetProfileVariable};
	};

	//--- A1 Commissar Panel: open GUER Director panel (GUER-only; guarded inside the onLoad).
	if (MenuAction == 30) then {
		MenuAction = -1;
		if (sideJoined == resistance) then {
			closeDialog 0;
			createDialog "WFBE_GDirCommissarMenu";
		};
	};

	sleep 0.1;
};
