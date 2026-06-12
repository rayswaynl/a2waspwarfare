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

	Spawned from Init_Client.sqf after commonInitComplete.
*/
Private ["_interval","_threshold","_lastBuy","_funds","_unitData","_price","_nudgeText","_elapsed","_patrolNudgeDone","_upgrades","_townsHeld","_patrolLvl"];

//--- Master toggle.
if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) < 1) exitWith {};

//--- Per-feature interval (0 = disabled).
_interval = missionNamespace getVariable ["WFBE_C_QOL_ADVISOR_INTERVAL", 300];
if (_interval <= 0) exitWith {};

//--- Derive cheapest vehicle cost from the side's light-factory buy list (with fallback).
_threshold = 0;
{
	_unitData = missionNamespace getVariable _x;
	if !(isNil "_unitData") then {
		_price = _unitData select QUERYUNITPRICE;
		//--- Only consider actual light-factory vehicles (QUERYUNITFACTORY index 6 == 1).
		if ((_unitData select QUERYUNITFACTORY) == 1) then {
			if (_threshold == 0 || _price < _threshold) then {_threshold = _price};
		};
	};
} forEach (missionNamespace getVariable [Format ["WFBE_%1LIGHTUNITS", WFBE_Client_SideJoinedText], []]);

//--- Fallback: if no light-factory unit found, use a sensible default.
if (_threshold <= 0) then {_threshold = 1000};
_threshold = _threshold * 2;

//--- Stamp a neutral start so the first interval is a full wait from mission start.
if (isNil "WFBE_QOL_LAST_PURCHASE_TIME") then {
	WFBE_QOL_LAST_PURCHASE_TIME = time;
};

//--- Commander Patrols nudge: once per session.
_patrolNudgeDone = false;

while {!gameOver} do {
	sleep _interval;

	//--- Re-read interval/toggle in case it changed at runtime; exit cleanly if disabled.
	_interval = missionNamespace getVariable ["WFBE_C_QOL_ADVISOR_INTERVAL", _interval];
	if ((missionNamespace getVariable ["WFBE_C_QOL_TRIO", 1]) < 1) then {_interval = 0};
	if (_interval <= 0) exitWith {};

	//--- Only nudge while the player is alive and not in respawn.
	if (alive player) then {
		//--- Only nudge when last purchase was more than one interval ago.
		_lastBuy = missionNamespace getVariable ["WFBE_QOL_LAST_PURCHASE_TIME", 0];
		_elapsed = time - _lastBuy;
		if (_elapsed >= _interval) then {
			//--- Only nudge when funds exceed the threshold.
			_funds = Call GetPlayerFunds;
			if (_funds >= _threshold) then {
				_nudgeText = Format ["You have $%1 unspent - visit a factory or the gear menu.", _funds];
				hintSilent _nudgeText;
			};
		};

		//--- Commander Patrols nudge (once per session, separate flag).
		//--- Gates: player IS commander + side owns 3+ towns + Patrols unresearched + round > 15 min.
		if (!_patrolNudgeDone && {!isNull commanderTeam} && {commanderTeam == group player} && {time > 900}) then {
			_townsHeld = sideJoined Call GetTownsHeld;
			if (_townsHeld >= 3) then {
				_upgrades = sideJoined Call WFBE_CO_FNC_GetSideUpgrades;
				_patrolLvl = 0;
				if (!isNil "_upgrades" && {count _upgrades > WFBE_UP_PATROLS}) then {
					_patrolLvl = _upgrades select WFBE_UP_PATROLS;
				};
				if (_patrolLvl == 0) then {
					hintSilent "Commander tip: you hold 3+ towns - research Patrols (upgrade menu) to push the frontline automatically.";
					_patrolNudgeDone = true;
				};
			};
		};
	};
};
