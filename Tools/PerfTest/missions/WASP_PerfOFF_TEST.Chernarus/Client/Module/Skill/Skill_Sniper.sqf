/*
	Script: Sniper Skill System by Benny.
	Description: Add special skills to the defined sniper.
*/
Private ['_binoculars','_markerName','_markertime','_screenPos'];

_binoculars = missionNamespace getVariable 'WFBE_BINOCULARS';
if !((currentWeapon player) in _binoculars) exitWith {hint (localize "STR_WF_INFO_Spot_Info")};

if (isNil "markerID") then {markerID = 1};
_screenPos = screenToWorld [0.5,0.5];

//--- Defect-1 fix (HIGH): include a per-client UID in the marker name so names are globally
//--- unique across all same-side spotters. Without this, two spotters both start at Spot1
//--- and the second clobbers the first on every receiving client; their fade loops also
//--- delete each other. getPlayerUID player returns the Steam64 UID string (~17 chars),
//--- which is unique per account. A2 OA 1.64: getPlayerUID is valid client-side.
Private ['_spotUID'];
_spotUID = getPlayerUID player;
if (_spotUID == "") then {_spotUID = "X"};
_markerName = Format ["Spot_%1_%2", _spotUID, markerID];
createMarkerLocal [_markerName,_screenPos];
_markertime = [daytime] call bis_fnc_timetostring;
_markerName setMarkerTextLocal Format ['SPOTTED: %1',_markertime];
_markerName setMarkerTypeLocal "mil_destroy";
_markerName setMarkerColorLocal "ColorRed";
_markerName setMarkerSizeLocal [0.5,0.5];
markerID = markerID + 1;

WFBE_SK_V_LastUse_Spot = time;
//--- team-intel-pack: if WFBE_C_SPOTTER_TEAM_MARKS is set, broadcast the spot to same-side
//--- clients via SpotterMarkContact PVF. The local mark already exists above; the PVF
//--- receiver guards against re-creating it on this machine (markerType check on the name).
if ((missionNamespace getVariable ["WFBE_C_SPOTTER_TEAM_MARKS", 0]) > 0) then {
	[sideJoined, "SpotterMarkContact", [_screenPos, time, _markerName]] Call WFBE_CO_FNC_SendToClients;
	//--- Defect-4 fix (LOW): give the spotter's own machine the same freshness fade that
	//--- teammates get via SpotterMarkContact. Run the fade loop locally instead of the bare
	//--- 180s delete, so colour updates and elapsed-time text show for the spotter too.
	//--- _markerName and time are passed via _this because Spawn does not share locals.
	[_markerName, time] Spawn {
		Private ["_mn","_st","_elapsed"];
		_mn = _this select 0;
		_st = _this select 1;

		sleep 60;
		//--- 60s mark: orange + "Xm ago" text.
		if ((markerType _mn) in [""]) exitWith {};
		_elapsed = round ((time - _st) / 60);
		_mn setMarkerTextLocal ("SPOTTED " + str _elapsed + "m ago");
		_mn setMarkerColorLocal "ColorOrange";

		sleep 60;
		//--- 120s mark: yellow + updated "Xm ago" text.
		if ((markerType _mn) in [""]) exitWith {};
		_elapsed = round ((time - _st) / 60);
		_mn setMarkerTextLocal ("SPOTTED " + str _elapsed + "m ago");
		_mn setMarkerColorLocal "ColorYellow";

		sleep 60;
		//--- 180s elapsed: delete.
		if !((markerType _mn) in [""]) then {deleteMarkerLocal _mn};
	};
} else {
	//--- Flag is off: bare 180s delete (original behaviour; flag-off inert path preserved).
	[_markerName] Spawn {
		Private ["_marker"];
		_marker = _this select 0;
		sleep 180;
		deleteMarkerLocal _marker;
	};
};