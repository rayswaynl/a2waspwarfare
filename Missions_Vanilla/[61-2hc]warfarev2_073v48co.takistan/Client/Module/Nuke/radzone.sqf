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
            _x setDammage (getDammage _x + 0.03);
            {_x setDammage (getDammage _x + 0.05)} forEach crew _x;

            // Playing radiation sound on client when object is a player:
            if (isPlayer _x) then 
            {
                //--- LOCALITY/PV: targeted publicVariableClient to the radiated player only.
                //--- Old publicVariable spammed ALL clients every tick and only the last write
                //--- in a multi-player loop was reliable (shared global name collision).
                _PLAYER_Radiated = _x;
                missionNamespace setVariable ["PLAYER_RADIATED", _PLAYER_Radiated];
                (owner _x) publicVariableClient "PLAYER_RADIATED";
            };

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