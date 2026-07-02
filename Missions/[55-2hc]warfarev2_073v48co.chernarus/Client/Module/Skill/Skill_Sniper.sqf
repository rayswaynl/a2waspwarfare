/*
	Script: Sniper Skill System by Benny.
	Description: Add special skills to the defined sniper.
*/
Private ['_binoculars','_markerName','_markertime','_screenPos'];

_binoculars = missionNamespace getVariable 'WFBE_BINOCULARS';
if !((currentWeapon player) in _binoculars) exitWith {hint (localize "STR_WF_INFO_Spot_Info")};

if (isNil "markerID") then {markerID = 1};
_screenPos = screenToWorld [0.5,0.5];

_markerName = Format ["Spot%1",markerID];
createMarkerLocal [_markerName,_screenPos];
_markertime = [daytime] call bis_fnc_timetostring;
_markerName setMarkerText Format ['SPOTTED: %1',_markertime];
_markerName setMarkerTypeLocal "mil_destroy";
_markerName setMarkerColorLocal "ColorRed";
_markerName setMarkerSizeLocal [0.5,0.5];
markerID = markerID + 1;

WFBE_SK_V_LastUse_Spot = time;
//--- team-intel-pack: if WFBE_C_SPOTTER_TEAM_MARKS is set, broadcast the spot to same-side
//--- clients via SpotterMarkContact PVF. The local mark already exists above; the PVF
//--- receiver guards against re-creating it on this machine (isNil check on the name).
if ((missionNamespace getVariable ["WFBE_C_SPOTTER_TEAM_MARKS", 0]) > 0) then {
	[sideJoined, "SpotterMarkContact", [_screenPos, time, _markerName]] Call WFBE_CO_FNC_SendToClients;
};


[_markerName] Spawn {
	Private ["_marker"];
	_marker = _this select 0;
	sleep 180;
	deleteMarkerLocal _marker;
};