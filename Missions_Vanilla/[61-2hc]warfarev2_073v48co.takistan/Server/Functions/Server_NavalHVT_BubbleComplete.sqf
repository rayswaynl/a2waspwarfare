/*
	Server_NavalHVT_BubbleComplete.sqf
	WFBE_SE_FNC_NavalHVT_BubbleComplete

	fable/radius-hold-primitive (GR-2026-07-08a): on-complete callback for a
	WFBE_CO_FNC_RadiusHold_Register'd carrier bubble (Init_NavalHVT.sqf, flag
	WFBE_C_NAVALHVT_BUBBLE_ENABLE). Ports server_town.sqf's existing naval-HVT capture-flip
	payload (design doc S0.1 item 6 / S5.2) near-verbatim, MINUS the camp-flip block and the
	camp-ratio capture-rate math - there are no camps under the bubble model. Server-only
	(only ever called from the RadiusHold dispatcher, itself server-only per design doc S2.1).

	Params:
		0: _holdId       STRING  the hold's registered id (forensics/diag tag).
		1: _anchor        OBJECT  the naval town logic (same object as server_town.sqf's _location).
		2: _winningSide     SIDE  west/east/resistance - the side that completed the hold.
*/

private ["_holdId","_anchor","_winningSide","_oldSideID","_oldSide","_newSID","_objects",
	         "_capUid","_hvtName","_hvtNewSide","_airLogicRef","_newHangar","_oldHangar",
	         "_navDeckZ","_navRefPos"];

_holdId      = _this select 0;
_anchor      = _this select 1;
_winningSide = _this select 2;

if (!isServer) exitWith {};
if (isNull _anchor) exitWith {
	diag_log Format ["RADIUSHOLD-WARN: NavalHVT_BubbleComplete(%1) called with a null anchor.", _holdId];
};

_oldSideID = _anchor getVariable ["sideID", WFBE_C_GUER_ID];
_oldSide   = (_oldSideID) Call WFBE_CO_FNC_GetSideFromID;
_newSID    = _winningSide Call WFBE_CO_FNC_GetSideID;

//--- No-op guard: the primitive only fires onComplete for a sole eligible holder, but if the
//--- winning side somehow already owns this carrier (e.g. a re-registration race), skip the
//--- flip payload entirely rather than re-broadcasting a same-side "capture".
if (_newSID == _oldSideID) exitWith {
	diag_log Format ["RADIUSHOLD-COMPLETE: NavalHVT_BubbleComplete(%1) winner already owns the carrier (sideID=%2) - no-op.", _holdId, _newSID];
};

["INFORMATION", Format ["Server_NavalHVT_BubbleComplete.sqf: Carrier [%1] captured by sideID %2 (bubble, hold=%3).", _anchor getVariable ["name","?"], _newSID, _holdId]] Call WFBE_CO_FNC_LogContent;

//--- Mirrors server_town.sqf:289-293 (side lost/captured SideMessage).
if (_oldSideID != WFBE_C_UNKNOWN_ID) then {
	if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_oldSide]) then {[_oldSide, "Lost", _anchor] Spawn SideMessage};
};
if (missionNamespace getVariable Format ["WFBE_%1_PRESENT",_winningSide]) then {[_winningSide, "Captured", _anchor] Spawn SideMessage};

//--- Mirrors server_town.sqf:295 (the flip itself).
_anchor setVariable ["sideID", _newSID, true];

//--- Mirrors server_town.sqf:328-333 (leaderboard TOWN-capture credit). Re-derive presence from the
//--- bubble's own registered radius instead of reusing a town-loop _objects scan (design doc S5.2).
_objects = _anchor nearEntities [["Man","Car","Motorcycle","Tank","Air","Ship"], (_anchor getVariable ["wfbe_rh_radius", 200])];
{ if (isPlayer _x && {alive _x} && {side _x == _winningSide}) then {_capUid = getPlayerUID _x; if (_capUid != "") then {[_capUid, WFBE_STAT_CAPTURES_TOWN, 1] call WFBE_SE_FNC_RecordStat}} } forEach _objects;

//--- Mirrors server_town.sqf:379-381 (garrison-flag reset; N/A for carriers today, kept defensively
//--- per design doc S0.1 item 5).
_anchor setVariable ["wfbe_active", false];
_anchor setVariable ["wfbe_active_air", false];
_anchor setVariable ["wfbe_episode_spawned", false];

//--- Mirrors server_town.sqf:383 (generic TownCaptured-equivalent broadcast).
[nil, "TownCaptured", [_anchor, _oldSideID, _newSID]] Call WFBE_CO_FNC_SendToClients;

//--- VERBATIM port of server_town.sqf:386-434 (naval-HVT-specific block): silent capture
//--- announcement, MATCH milestone diag_log, marker recolor, and (carrier-HVT only) the hangar
//--- delete-and-respawn-for-new-owner. Camp-flip (server_town.sqf:301-326) and the camp-ratio
//--- capture-rate math (server_town.sqf:236-276) are intentionally NOT ported - there are no
//--- camps under the bubble model (design doc S5.2).
_hvtName    = _anchor getVariable ["name", "Naval HVT"];
_hvtNewSide = _newSID Call WFBE_CO_FNC_GetSideFromID;

[nil, "HandleSpecial", ["naval-hvt-captured", _anchor, _newSID, _hvtName]] Call WFBE_CO_FNC_SendToClients;
["INFORMATION", Format ["Server_NavalHVT_BubbleComplete.sqf: Naval HVT [%1] captured by sideID %2.", _hvtName, _newSID]] Call WFBE_CO_FNC_LogContent;
if ((missionNamespace getVariable ["WFBE_C_MATCH_TELEMETRY", 1]) > 0) then {
	diag_log ("MATCH|v1|MILESTONE|CARRIER_CAP|carrier=" + _hvtName + "|newSideID=" + str _newSID + "|tMin=" + str (round (time / 60)));
};

if (_anchor getVariable ["wfbe_is_carrier_hvt", false]) then {
	_airLogicRef = _anchor getVariable ["wfbe_airfield_logic_ref", objNull];
	if !(isNull _airLogicRef) then {
		_oldHangar = _anchor getVariable ["wfbe_airfield_hangar_obj", objNull];
		if !(isNull _oldHangar) then { deleteVehicle _oldHangar };

		_navDeckZ  = _airLogicRef getVariable ["wfbe_naval_deckz", 16];
		_navRefPos = getPosASL _airLogicRef;
		_newHangar = "HeliHEmpty" createVehicle [_navRefPos select 0, _navRefPos select 1, 0];
		_newHangar setPosASL [_navRefPos select 0, _navRefPos select 1, _navDeckZ];
		_newHangar setDir ((getDir _airLogicRef) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
		_newHangar enableSimulation false;
		_newHangar allowDamage false;
		_newHangar setVariable ["wfbe_is_airfield_hangar", true, true];
		_airLogicRef setVariable ["wfbe_hangar", _newHangar, true];
		_airLogicRef setVariable ["wfbe_airfield_side", _hvtNewSide, true];
		_anchor setVariable ["wfbe_airfield_hangar_obj", _newHangar, true];
		["INFORMATION", Format ["Server_NavalHVT_BubbleComplete.sqf: Carrier [%1] hangar respawned for side %2.", _hvtName, str _hvtNewSide]] Call WFBE_CO_FNC_LogContent;
	};
};