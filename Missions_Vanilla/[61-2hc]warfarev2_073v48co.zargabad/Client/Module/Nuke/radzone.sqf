/* 
    Original Author: 
    Contributors : Marty
    Name: radzone.sqf
    Parameters:
      0 - _target    : object - Used as a coordinates location for impact.
    Description:
        This script is run on server side. It generates damage to objects within the radiation range and broadcasts 
        a public variable when object is a player in order to play a radiation sound effect on client side.
*/

Private ['_target'];

_target = _this select 0;

[_target] Spawn {
    Private [
        "_radiation_range",
        "_radiation_duration",
        "_radiation_interval",
        "_radiation_end_time",
        "_array",
        "_target",
        "_PLAYER_Radiated",
        "_RADZONE_marker_name_west",
        "_RADZONE_marker_name_east",
        "_RADZONE_markerPosition",
        "_RADZONE_markerType",
        "_RADZONE_markerText",
        "_RADZONE_markerColor",
        "_RADZONE_markerRadius",
        "_RADZONE_marker_elipse_name_west",
        "_RADZONE_marker_elipse_name_east"
    ];

    _target = _this select 0;

    
    // Radiation duration settings
    // Radiation duration is retrieved from mission parameters.
    // WFBE_RADZONE_TIME is expressed in minutes and converted to seconds below.
    _radiation_duration = missionNamespace getVariable "WFBE_RADZONE_TIME";         // time in minutes.
	_radiation_duration = _radiation_duration * 60 ;							    // time in seconds.
   
    _radiation_interval = 5;
    _radiation_end_time = time + _radiation_duration;
    _radiation_range = missionNamespace getVariable "ICBM_RADIATION_RADIUS";

    // Create radiation markers on map for both sides
    _RADZONE_markerPosition = position _target;
    _RADZONE_markerType = "mil_warning";
    _RADZONE_markerText = "RADIOACTIVE ZONE";
    _RADZONE_markerColor = "ColorGreen";
    _RADZONE_markerRadius = _radiation_range;

    // Marker names have a random suffix in order to avoid duplicate marker names.
    _RADZONE_marker_name_west = format ["RADZONE_west_%1_%2", round time, round (random 10000)];
    _RADZONE_marker_name_east = format ["RADZONE_east_%1_%2", round time, round (random 10000)];

    _RADZONE_marker_elipse_name_west = format ["Elipse_%1", _RADZONE_marker_name_west];
    _RADZONE_marker_elipse_name_east = format ["Elipse_%1", _RADZONE_marker_name_east];

    // Marker for WEST side
    [
        _RADZONE_marker_name_west,
        _RADZONE_markerPosition,
        _RADZONE_markerType,
        _RADZONE_markerText,
        _RADZONE_markerColor,
        west,
        _RADZONE_marker_elipse_name_west,
        _RADZONE_markerRadius
    ] call WF_createMarker;

    // Marker for EAST side
    [
        _RADZONE_marker_name_east,
        _RADZONE_markerPosition,
        _RADZONE_markerType,
        _RADZONE_markerText,
        _RADZONE_markerColor,
        east,
        _RADZONE_marker_elipse_name_east,
        _RADZONE_markerRadius
    ] call WF_createMarker;
 
    // Apply radiation effects during the defined duration
    while {time < _radiation_end_time} do {

        _array = _target nearEntities [["Man","Car","Motorcycle","Tank","Ship","Air","StaticWeapon"], _radiation_range];

        {
            //--- LOCALITY: setDammage takes LOCAL arguments - executed server-side (radzone
            //--- runs on the server) against a client- or HC-local unit it silently no-ops
            //--- (this codebase's own convention: AI_Commander_Wildcard.sqf ":859" /
            //--- Common_AICOMServiceTick.sqf ":13"). A player unit is local to that player's
            //--- OWN client, so the old server-side setDammage on players never landed - the
            //--- radiation zone dealt ZERO damage to players (they only heard the geiger cue).
            //--- Apply each dose where the unit is local: directly for server-owned units, and
            //--- for players route the dose to the owning client via the existing PLAYER_RADIATED
            //--- channel (its OnEventHandler runs on that owner, where the player is local).
            _radHull = _x;
            {
                _radDose = if (_forEachIndex == 0) then {0.03} else {0.05};
                if (isPlayer _x) then
                {
                    //--- targeted publicVariableClient to the radiated player only; per-owner
                    //--- write immediately before the send (the old plain publicVariable spammed
                    //--- ALL clients every tick and raced on the shared global name).
                    missionNamespace setVariable ["PLAYER_RADIATED", [_x, _radDose]];
                    (owner _x) publicVariableClient "PLAYER_RADIATED";
                }
                else
                {
                    if (local _x) then {_x setDammage (getDammage _x + _radDose)};
                };
            } forEach ([_radHull] + crew _radHull);

        } forEach _array;

        sleep _radiation_interval;
    };

    deleteVehicle _target;

    /*
        Delete both radiation markers after radiation duration has elapsed.
        Since the while loop has already waited for the full duration,
        the delete delay should be 0 here in order to remove marker immediately after
        the elapsed time.
    */
    //--- markersync-20260725 (Trello #171 class): radzone runs SERVER-side and these RADZONE markers are
    //--- GLOBAL (WF_createMarker uses createMarker), so deleteMarkerLocal (WFBE_CL_FNC_Delete_Marker)
    //--- removed them only on the server and orphaned them on every client. Delete globally instead.
    deleteMarker _RADZONE_marker_name_west;
    deleteMarker _RADZONE_marker_elipse_name_west;

    deleteMarker _RADZONE_marker_name_east;
    deleteMarker _RADZONE_marker_elipse_name_east;
};