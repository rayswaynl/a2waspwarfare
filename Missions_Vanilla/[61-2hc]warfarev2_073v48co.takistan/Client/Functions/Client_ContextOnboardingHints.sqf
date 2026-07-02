/*
	Lane 182 contextual onboarding hints.
	Default-off local hints stored once per player profile and side.
*/

Private ["_enable","_delay","_key","_text"];

_enable = missionNamespace getVariable ["WFBE_C_ONBOARDING_CONTEXT_HINTS", 0];
if (_enable < 1) exitWith {};
if (isDedicated) exitWith {};

waitUntil {!isNil "clientInitComplete" && {clientInitComplete}};
if (isNil "sideJoined") exitWith {};
if (isNil "sideJoinedText") exitWith {};
if !(sideJoined in [west, east, resistance]) exitWith {};

_delay = missionNamespace getVariable ["WFBE_C_ONBOARDING_CONTEXT_DELAY", 35];
if (_delay < 0) then {_delay = 0};
uiSleep _delay;

_key = Format ["WFBE_CONTEXT_HINT_BUY_%1", sideJoinedText];
if !(profileNamespace getVariable [_key, false]) then {
	_text = "<t color='#42b6ff' size='1.2'>Buying your first kit</t><br/><br/>Use the scroll action menu near a friendly base or captured town center. The WF menu opens gear, infantry, vehicles, support and commander tools from one place.";
	hint parseText _text;
	profileNamespace setVariable [_key, true];
	saveProfileNamespace;
};

[] spawn {
	Private ["_key","_loops","_funds","_mark","_text"];

	_key = Format ["WFBE_CONTEXT_HINT_FUNDS_%1", sideJoinedText];
	if (profileNamespace getVariable [_key, false]) exitWith {};
	_mark = missionNamespace getVariable ["WFBE_C_ONBOARDING_CONTEXT_FUNDS", 300];
	if (_mark < 0) then {_mark = 0};
	uiSleep 25;

	_loops = 0;
	while {_loops < 90} do {
		_funds = Call GetPlayerFunds;
		if (_funds >= _mark) exitWith {
			if (sideJoined in [resistance]) then {
				_text = "<t color='#42b6ff' size='1.2'>GUER field tech</t><br/><br/>Your cash buys gear and vehicles, while GUER tech comes from player kills and factory wrecks. Watch the RHUD tech line and use captured towns for more options.";
			} else {
				_text = "<t color='#42b6ff' size='1.2'>Money and upgrades</t><br/><br/>Cash buys your team gear and units. The side supply pool funds structures and upgrades, so a good commander turns town income into better factories and support.";
			};
			hint parseText _text;
			profileNamespace setVariable [_key, true];
			saveProfileNamespace;
		};
		_loops = _loops + 1;
		uiSleep 20;
	};
};

[] spawn {
	Private ["_key","_loops","_text"];

	_key = Format ["WFBE_CONTEXT_HINT_COMMANDER_%1", sideJoinedText];
	if (profileNamespace getVariable [_key, false]) exitWith {};
	uiSleep 45;

	_loops = 0;
	while {_loops < 180} do {
		if !(isNil "commanderTeam") then {
			if !(isNull commanderTeam) then {
				if ((group player) in [commanderTeam]) exitWith {
					_text = "<t color='#42b6ff' size='1.2'>You are commander</t><br/><br/>Open the WF menu and use Command to steer teams, queue upgrades, manage income and keep the HQ alive. The side economy is now your lever.";
					hint parseText _text;
					profileNamespace setVariable [_key, true];
					saveProfileNamespace;
				};
			};
		};
		_loops = _loops + 1;
		uiSleep 20;
	};
};
