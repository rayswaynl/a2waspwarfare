/* SpotterMarkContact.sqf - client-side PVF handler (team-intel-pack, 2026-07-02).
   Receives a side-scoped spotter mark from the spotter and creates it locally.
   Guards against re-creating the mark on the spotter's own machine (marker already exists).
   Updates marker text every 60s with elapsed time (freshness fade), then deletes after 180s.

   Parameters (received via WFBE_CL_FNC_HandlePVF dispatch):
     0 - screen-to-world position [x, y, z] of the spotted contact
     1 - mission time (time) when the spot was placed
     2 - marker name string (Spot<N>)

   Flag gate: WFBE_C_SPOTTER_TEAM_MARKS (default 0). The spotter already guards before
   sending, so this handler runs only when the flag is on.
*/
Private ["_pos","_spotTime","_markerName"];

if (isNil "WFBE_Client_SideID") exitWith {};

_pos        = _this select 0;
_spotTime   = _this select 1;
_markerName = _this select 2;

//--- Skip re-creation on the spotter's own machine (marker already exists there).
//--- A2 OA: markerType returns "" for a non-existent marker (WildcardMarker.sqf idiom).
if !((markerType _markerName) in [""]) exitWith {};

createMarkerLocal [_markerName, _pos];
_markerName setMarkerTypeLocal "mil_destroy";
_markerName setMarkerColorLocal "ColorRed";
_markerName setMarkerTextLocal "SPOTTED";
_markerName setMarkerSizeLocal [0.5, 0.5];

//--- Freshness loop: update text at 60s and 120s, colour-fade, delete at 180s.
[_markerName, _spotTime] Spawn {
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
