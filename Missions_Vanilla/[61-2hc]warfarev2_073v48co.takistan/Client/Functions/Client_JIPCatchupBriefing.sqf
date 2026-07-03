/*
	Lane 181 late-join catch-up briefing.
	Default-off local hint that reads already replicated mission state only.
*/

Private ["_enable","_delay","_minAge","_myID","_west","_east","_guer","_neutral","_frontName","_frontSide","_frontDist","_townSide","_townSideText","_townName","_d","_mins","_hours","_rem","_ageText","_intent","_aiObj","_aiFocus","_spearhead","_commander","_cmdTeam","_cmdLead","_msg"];

_enable = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_BRIEFING", 0];
if (_enable < 1) exitWith {};
if (isDedicated) exitWith {};
if !(isNil {uiNamespace getVariable "WFBE_JIP_CATCHUP_SHOWN"}) exitWith {};
uiNamespace setVariable ["WFBE_JIP_CATCHUP_SHOWN", true];

waitUntil {!isNil "clientInitComplete" && {clientInitComplete}};
waitUntil {!isNil "townInit" && {townInit} && {!isNil "towns"}};

_delay = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_DELAY", 16];
if (_delay < 0) then {_delay = 0};
uiSleep _delay;

_minAge = missionNamespace getVariable ["WFBE_C_JIP_CATCHUP_MIN_AGE", 300];
if (time < _minAge) exitWith {};
if (isNil "sideJoined") exitWith {};
if !(sideJoined in [west, east, resistance]) exitWith {};

_myID = sideID;
if (!isNil "WFBE_Client_SideID") then {_myID = WFBE_Client_SideID};

_west = 0;
_east = 0;
_guer = 0;
_neutral = 0;
_frontName = "No front town";
_frontSide = "Unknown";
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
_ageText = Format ["%1m", _mins];
if (_hours > 0) then {_ageText = Format ["%1h %2m", _hours, _rem]};

_intent = missionNamespace getVariable [Format ["WFBE_AICOM_INTENT_%1", _myID], ""];
_aiObj = missionNamespace getVariable [Format ["WFBE_AICOM_OBJNAME_%1", _myID], ""];
_aiFocus = missionNamespace getVariable [Format ["WFBE_AICOM_FOCUS_NAME_%1", _myID], ""];
_spearhead = Format ["Nearest front: %1 (%2)", _frontName, _frontSide];
if !(_aiObj in [""]) then {_spearhead = _aiObj};
if !(_aiFocus in [""]) then {_spearhead = Format ["%1 (focus)", _aiFocus]};
if (_intent in [""]) then {_intent = "No AI order broadcast"};

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

_msg = Format [
	"<t color='#42b6ff' size='1.2'>Catch-up briefing</t><br/><br/>Round age: <t color='#e0b94f'>%1</t><br/>Towns: WEST %2 | EAST %3 | GUER %4 | Neutral %5<br/>Spearhead: <t color='#28ff14'>%6</t><br/>Order: %7<br/>Commander: %8",
	_ageText,
	_west,
	_east,
	_guer,
	_neutral,
	_spearhead,
	_intent,
	_commander
];

hint parseText _msg;
