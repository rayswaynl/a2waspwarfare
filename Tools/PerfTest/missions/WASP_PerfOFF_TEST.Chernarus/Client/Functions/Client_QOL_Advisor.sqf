/*
	QoL trio feat.3: Advisor Nudge.
	Low-frequency client-side helper for new players.
	Every WFBE_C_QOL_ADVISOR_INTERVAL seconds (default 300, 0 = disabled), if the player
	has a large unspent fund balance (> 2x cheapest vehicle cost) and has not bought anything
	in the last interval, show one hintSilent nudge.
	Suppressed while the player is dead / in respawn.

	Last-purchase tracking: GUI_Menu_BuyUnits.sqf stamps WFBE_QOL_LAST_PURCHASE_TIME = time
	on each purchase.  This script reads that variable.

	Also shows a once-per-session nudge to the side commander when:
	  - player IS the side commander (commanderTeam == group player)
	  - side owns >= 3 towns
	  - Patrols upgrade is unresearched (wfbe_upgrades index WFBE_UP_PATROLS == 0)
	  - round time > 15 min
	(WILDCARD V2 RECONCILIATION: owner-approved commander Patrols nudge)

	Lane 158 extends the same low-frequency advisor with once-per-session client-only reminders for:
	  - first-time commander basics;
	  - economy split slider visibility;
	  - EASA loadouts while in an EASA-capable vehicle;
	  - supply vehicle pickup/delivery flow.

	Spawned from Init_Client.sqf after commonInitComplete.
*/
Private ["_interval","_threshold","_lastBuy","_funds","_unitData","_price","_nudgeText","_elapsed","_patrolNudgeDone","_upgrades","_townsHeld","_patrolLvl","_inRangeKeys","_commanderNudgeDone","_economyNudgeDone","_easaNudgeDone","_supplyNudgeDone","_nudgeShown","_isCommander","_cmdPercent","_veh","_target","_easaTypes","_supplyTypes","_isSupplyVehicle","_loadedSupply"];

//--- Master toggle.
if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) < 1) exitWith {};

//--- Per-feature interval (0 = disabled).
_interval = missionNamespace getVariable ["WFBE_C_QOL_ADVISOR_INTERVAL", 300];
if (_interval <= 0) exitWith {};

//--- E6: threshold is no longer a one-time light-factory derivation (wrong for infantry-only / GUER, who never see a light factory).
//--- It is now recomputed each tick from whatever factory/depot pools are actually IN RANGE (the *InRange globals the buy
//--- menu uses), so the nudge scales to what the player can really buy and is skipped entirely when nothing is in range.

//--- Stamp a neutral start so the first interval is a full wait from mission start.
if (isNil "WFBE_QOL_LAST_PURCHASE_TIME") then {
	WFBE_QOL_LAST_PURCHASE_TIME = time;
};

//--- Commander Patrols nudge: once per session.
_patrolNudgeDone = false;
_commanderNudgeDone = false;
_economyNudgeDone = false;
_easaNudgeDone = false;
_supplyNudgeDone = false;

while {!gameOver} do {
	sleep _interval;

	//--- Re-read interval/toggle in case it changed at runtime; exit cleanly if disabled.
	_interval = missionNamespace getVariable ["WFBE_C_QOL_ADVISOR_INTERVAL", _interval];
	if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) < 1) then {_interval = 0};
	if (_interval <= 0) exitWith {};

	//--- Only nudge while the player is alive and not in respawn.
	if (alive player) then {
		_nudgeShown = false;
		_isCommander = false;
		if (!isNull commanderTeam) then {
			if ((group player) in [commanderTeam]) then {_isCommander = true};
		};

		//--- Commander basics nudge: once after the commander has had a few minutes to orient.
		if (!_nudgeShown && {!_commanderNudgeDone} && {_isCommander} && {time > 300}) then {
			hintSilent "Commander tip: use the WF Command menu to order teams, queue upgrades, and keep the HQ alive.";
			_commanderNudgeDone = true;
			_nudgeShown = true;
		};

		//--- Economy split nudge: separate from the basic commander tip so each message stays readable.
		if (!_nudgeShown && {!_economyNudgeDone} && {_isCommander} && {time > 600}) then {
			_cmdPercent = WFBE_Client_Logic getVariable ["wfbe_commander_percent", 70];
			hintSilent Format ["Economy tip: the Economy menu slider controls commander vs player income. Current commander share: %1%2.", _cmdPercent, "%"];
			_economyNudgeDone = true;
			_nudgeShown = true;
		};

		//--- Commander Patrols nudge (once per session, separate flag).
		//--- Gates: player IS commander + side owns 3+ towns + Patrols unresearched + round > 15 min.
		if (!_nudgeShown && {!_patrolNudgeDone} && {_isCommander} && {time > 900}) then {
			_townsHeld = sideJoined Call GetTownsHeld;
			if (_townsHeld >= 3) then {
				_upgrades = sideJoined Call WFBE_CO_FNC_GetSideUpgrades;
				_patrolLvl = 0;
				if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_PATROLS}) then {
					_patrolLvl = _upgrades select WFBE_UP_PATROLS;
				};
				if (_patrolLvl < 1) then {
					hintSilent "Commander tip: you hold 3+ towns - research Patrols (upgrade menu) to push the frontline automatically.";
					_patrolNudgeDone = true;
					_nudgeShown = true;
				};
			};
		};

		//--- EASA nudge: only when the player is actually in an EASA-capable vehicle.
		if (!_nudgeShown && {!_easaNudgeDone} && {(missionNamespace getVariable ["WFBE_C_MODULE_WFBE_EASA", 0]) > 0}) then {
			_veh = vehicle player;
			_easaTypes = missionNamespace getVariable ["WFBE_EASA_Vehicles", []];
			if (!(_veh in [player]) && {(typeOf _veh) in _easaTypes}) then {
				hintSilent "EASA tip: service points can change aircraft loadouts with Loadout (EASA). GUER aircraft can use friendly town centers.";
				_easaNudgeDone = true;
				_nudgeShown = true;
			};
		};

		//--- Supply delivery nudge: support-role players often miss the pickup -> Command Center loop.
		if (!_nudgeShown && {!_supplyNudgeDone}) then {
			_veh = vehicle player;
			_target = cursorTarget;
			_supplyTypes = [];
			{_supplyTypes set [count _supplyTypes, _x]} forEach (missionNamespace getVariable [Format ["WFBE_%1SUPPLYTRUCKS", WFBE_Client_SideJoinedText], []]);
			{if !(_x in _supplyTypes) then {_supplyTypes set [count _supplyTypes, _x]}} forEach WFBE_C_SUPPLY_HELI_TYPES;
			_isSupplyVehicle = false;
			_loadedSupply = 0;
			if (!(_veh in [player]) && {(typeOf _veh) in _supplyTypes}) then {
				_isSupplyVehicle = true;
				_loadedSupply = _veh getVariable ["SupplyAmount", 0];
			};
			if (!_isSupplyVehicle && {!isNull _target} && {(typeOf _target) in _supplyTypes}) then {
				_isSupplyVehicle = true;
				_loadedSupply = _target getVariable ["SupplyAmount", 0];
			};
			if (_isSupplyVehicle) then {
				if (_loadedSupply > 0) then {
					hintSilent "Supply tip: loaded supply vehicles need the Command Center (C marker). Deliver before the cargo is lost.";
				} else {
					hintSilent "Supply tip: collect from friendly [+SUPPLY] towns, then deliver the cargo to your Command Center (C marker).";
				};
				_supplyNudgeDone = true;
				_nudgeShown = true;
			};
		};

		//--- Existing unspent-funds nudge stays on the purchase-suppression cadence, after one-off tips so they cannot starve.
		if (!_nudgeShown) then {
			_lastBuy = missionNamespace getVariable ["WFBE_QOL_LAST_PURCHASE_TIME", 0];
			_elapsed = time - _lastBuy;
			if (_elapsed >= _interval) then {
				//--- E6: figure out which factory/depot pools are in range RIGHT NOW (same globals the buy menu reads).
				//--- GUER (resistance) is base-less and always buys from the Depot pool, so treat depot as in-range for them.
				_inRangeKeys = [];
				if (barracksInRange) then {_inRangeKeys set [count _inRangeKeys, "Barracks"]};
				if (lightInRange) then {_inRangeKeys set [count _inRangeKeys, "Light"]};
				if (heavyInRange) then {_inRangeKeys set [count _inRangeKeys, "Heavy"]};
				if (aircraftInRange) then {_inRangeKeys set [count _inRangeKeys, "Aircraft"]};
				if (hangarInRange) then {_inRangeKeys set [count _inRangeKeys, "Airport"]};
				if (depotInRange || {sideJoined in [resistance]}) then {_inRangeKeys set [count _inRangeKeys, "Depot"]};

				//--- Derive the cheapest unit the player can actually buy from those in-range pools.
				_threshold = 0;
				{
					{
						_unitData = missionNamespace getVariable _x;
						if !(isNil "_unitData") then {
							_price = _unitData select QUERYUNITPRICE;
							if (_threshold < 1 || _price < _threshold) then {_threshold = _price};
						};
					} forEach (missionNamespace getVariable [Format ["WFBE_%1%2UNITS", WFBE_Client_SideJoinedText, _x], []]);
				} forEach _inRangeKeys;

				//--- E6: nothing buyable in range -> skip the nudge entirely (don't spam infantry-only / out-of-base players).
				if (_threshold > 0) then {
					_threshold = _threshold * 2;
					//--- Only nudge when funds exceed the threshold.
					_funds = Call GetPlayerFunds;
					if (_funds >= _threshold) then {
						_nudgeText = Format ["You have $%1 unspent - visit a factory or the gear menu.", _funds];
						hintSilent _nudgeText;
						_nudgeShown = true;
					};
				};
			};
		};
	};
};
