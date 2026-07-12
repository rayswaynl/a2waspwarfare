/*
	Lane 181 late-join catch-up briefing (visual pass + DEFAULT ON, Ray pick 2026-07-04).
	One side-coloured hint card for true late joiners: round age, towns per side, own team +
	funds, researched tech, nearest non-friendly town, AI commander order and CO name.
	Reads ONLY already-replicated state: the towns array, the group's broadcast wfbe_funds,
	the side logic's wfbe_upgrades, and the WFBE_AICOM_* PVs seeded to JIP clients by
	Server_OnPlayerConnected.sqf. Auto-clears after WFBE_C_JIP_CATCHUP_DURATION seconds.
	Gates: WFBE_C_JIP_CATCHUP_BRIEFING (default 1) + WFBE_C_JIP_CATCHUP_MIN_AGE (fresh match
	starts never see it) + a one-shot uiNamespace latch (respawns never re-show it).
	A2-OA-1.64 safe: hint parseText structured text (size/color/br only), 1-arg getVariable
	on the GROUP receiver, no isEqualType/findIf/pushBack/selectRandom.
*/

Private ["_enable","_delay","_minAge","_duration","_myID","_west","_east","_guer","_neutral","_frontName","_frontSide","_frontDist","_townSide","_townSideText","_d","_mins","_hours","_rem","_ageText","_intent","_aiObj","_aiFocus","_axis","_commander","_cmdTeam","_cmdLead","_msg","_sideColor","_sideName","_funds","_teamName","_upg","_tech","_frontText"];

_enable = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_BRIEFING", 0];
if (_enable < 1) exitWith {};
if (isDedicated) exitWith {};
if !(isNil {uiNamespace getVariable "WFBE_JIP_CATCHUP_SHOWN"}) exitWith {};
uiNamespace setVariable ["WFBE_JIP_CATCHUP_SHOWN", true];

waitUntil {!isNil "clientInitComplete" && {clientInitComplete}};
waitUntil {!isNil "townInit" && {townInit} && {!isNil "towns"}};

//--- Delay past the JIP loading fade / onboarding cards before showing anything.
_delay = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_DELAY", 16];
if (_delay < 0) then {_delay = 0};
uiSleep _delay;

_minAge = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_MIN_AGE", 300];
if (time < _minAge) exitWith {};
if (isNil "sideJoined") exitWith {};
if !(sideJoined in [west, east, resistance]) exitWith {};

_myID = sideID;
if (!isNil "WFBE_Client_SideID") then {_myID = WFBE_Client_SideID};

//--- Side identity: muted military header colour per side (no neon).
_sideColor = "#b8c4cc";
_sideName = "UNKNOWN";
switch (sideJoined) do {
	case west: {_sideColor = "#4d9bff"; _sideName = "WEST"};
	case east: {_sideColor = "#ff6a5e"; _sideName = "EAST"};
	case resistance: {_sideColor = "#7ed37e"; _sideName = "GUER"};
};

_west = 0;
_east = 0;
_guer = 0;
_neutral = 0;
_frontName = "";
_frontSide = "";
_frontDist = 1000000;

{
	if !(isNull _x) then {
		_townSide = _x getVariable ["sideID", WFBE_C_UNKNOWN_ID];
		_townSideText = switch (_townSide) do {
			case WFBE_C_WEST_ID: {"WEST"};
			case WFBE_C_EAST_ID: {"EAST"};
			case WFBE_C_GUER_ID: {"GUER"};
			default {"Neutral"};
		};
		switch (_townSide) do {
			case WFBE_C_WEST_ID: {_west = _west + 1};
			case WFBE_C_EAST_ID: {_east = _east + 1};
			case WFBE_C_GUER_ID: {_guer = _guer + 1};
			default {_neutral = _neutral + 1};
		};
		if !(_townSide in [_myID]) then {
			_d = player distance _x;
			if (_d < _frontDist) then {
				_frontDist = _d;
				_frontName = _x getVariable ["name", "Unknown town"];
				_frontSide = _townSideText;
			};
		};
	};
} forEach towns;

_mins = floor (time / 60);
_hours = floor (_mins / 60);
_rem = _mins - (_hours * 60);
_ageText = Format ["%1 min", _mins];
if (_hours > 0) then {_ageText = Format ["%1 h %2 min", _hours, _rem]};

//--- Own team + funds (broadcast group wallet; 1-arg read - GROUP receiver defaults are an A2 trap).
_teamName = str (group player);
_funds = (group player) getVariable "wfbe_funds";
if (isNil "_funds") then {_funds = 0};
if ((typeName _funds) != "SCALAR") then {_funds = 0};
_funds = round _funds;

//--- Researched side tech: count of non-zero entries in the side logic's upgrade array.
_tech = 0;
if (!isNil "WFBE_Client_Logic") then {
	_upg = WFBE_Client_Logic getVariable "wfbe_upgrades";
	if (!isNil "_upg") then {
		{if (_x > 0) then {_tech = _tech + 1}} forEach _upg;
	};
};

//--- Nearest non-friendly town: the practical "where do I go" pointer.
_frontText = "none in range";
if (_frontDist < 900000) then {
	_frontText = Format ["%1 (%2) - %3 km", _frontName, _frontSide, (round (_frontDist / 100)) / 10];
};

//--- AI commander order + axis (JIP-seeded PVs; graceful wording when no order broadcast yet).
_intent = missionNamespace getVariable [Format ["WFBE_AICOM_INTENT_%1", _myID], ""];
_aiObj = missionNamespace getVariable [Format ["WFBE_AICOM_OBJNAME_%1", _myID], ""];
_aiFocus = missionNamespace getVariable [Format ["WFBE_AICOM_FOCUS_NAME_%1", _myID], ""];
_axis = "";
if !(_aiObj in [""]) then {_axis = _aiObj};
if !(_aiFocus in [""]) then {_axis = _aiFocus};
if (_intent in [""]) then {_intent = "No commander order yet"};
if !(_axis in [""]) then {_intent = Format ["%1 - %2", _intent, _axis]};

_commander = switch (sideJoined) do {
	case west: {"James (AI)"};
	case east: {"Viktor (AI)"};
	case resistance: {"Resistance cells"};
	default {"Commander"};
};
if !(isNil "WFBE_Client_Logic") then {
	_cmdTeam = WFBE_Client_Logic getVariable "wfbe_commander";
	if !(isNil "_cmdTeam") then {
		if !(isNull _cmdTeam) then {
			_cmdLead = leader _cmdTeam;
			if !(isNull _cmdLead) then {_commander = name _cmdLead};
		};
	};
};

//--- Card: side-coloured header, grey label column, per-side coloured town counts.
_msg = Format ["<t color='%1' size='1.25'>CATCH-UP BRIEFING</t><br/><t color='#9aa7b0' size='0.9'>Joined %2 - round %3 in progress</t><br/><br/>", _sideColor, _sideName, _ageText];
_msg = _msg + Format ["<t color='#9aa7b0'>Towns  </t><t color='#4d9bff'>WEST %1</t>  <t color='#ff6a5e'>EAST %2</t>  <t color='#7ed37e'>GUER %3</t>  <t color='#b8b8b8'>Free %4</t><br/>", _west, _east, _guer, _neutral];
_msg = _msg + Format ["<t color='#9aa7b0'>Team   </t>%1  <t color='#e0b94f'>$%2</t><br/>", _teamName, _funds];
_msg = _msg + Format ["<t color='#9aa7b0'>Tech   </t>%1 upgrades researched<br/>", _tech];
_msg = _msg + Format ["<t color='#9aa7b0'>Front  </t>%1<br/>", _frontText];
_msg = _msg + Format ["<t color='#9aa7b0'>Order  </t>%1<br/>", _intent];
_msg = _msg + Format ["<t color='#9aa7b0'>CO     </t>%1<br/>", _commander];

hint parseText _msg;

//--- Self-clear so the card never lingers into gameplay (0 = leave it to the engine hint fade).
_duration = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_DURATION", 15];
if (_duration > 0) then {
	uiSleep _duration;
	hintSilent "";
};
