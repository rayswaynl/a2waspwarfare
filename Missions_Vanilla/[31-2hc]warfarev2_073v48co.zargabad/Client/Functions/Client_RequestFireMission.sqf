// Marty: Track artillery ammo locals used in the team notification payload.
Private ["_ammoIndex","_ammoName","_ammoOption","_ammoOptions","_ammoSelection","_arty_countdown","_arty_radius","_count","_destination","_i","_index","_type","_units"];

_destination 	= _this select 0;
_index 			= _this select 1;
_arty_countdown = _this select 2;
_arty_radius    = _this select 3;

_units = [group player, false, _index, WFBE_Client_SideJoinedText] Call GetTeamArtillery;
_type = ((missionNamespace getVariable Format ['WFBE_%1_ARTILLERY_CLASSNAMES', WFBE_Client_SideJoinedText]) select _index) find (typeOf (_units select 0));

if (count _units < 1 || _type < 0) exitWith {};

{[_x, _destination, WFBE_Client_SideJoined, artyRange] Spawn WFBE_CO_FNC_FireArtillery} forEach _units;

//Keep weapons reloaded.
// _units = [Group player,true,_index,sideJoinedText] Call GetTeamArtillery;
// {if (!someAmmo _x) then {[_x, sideJoined] Call RearmVehicle}} forEach _units;

//Marty : add artillery marker on map with the player name who call it
_marker_name 	    = format["ARTY_%1", diag_tickTime];
_markerPosition     = _destination;
_markerType		    = "Destroy";
_markerText 	    = format["ARTY [%1]", name player];
_markerColor	    = "ColorRed";
_markerSide		    = playerSide;
_markerRadius       = _arty_radius;
_marker_ellipse_name= format["Elipse_%1", _marker_name];

[_marker_name, _markerPosition, _markerType, _markerText, _markerColor, _markerSide, _marker_ellipse_name,_markerRadius ] call WF_createMarker ;
[_marker_name, 80] call WFBE_CL_FNC_Delete_Marker ; // marker is removed after some time in seconds. Predifined time prevent weird exitwith condition in the arty script that could make the marker never removed!
[_marker_ellipse_name, 80] call WFBE_CL_FNC_Delete_Marker ; 

//Send audio + text message to the team side to warn them
_playerName 	= name player;

// Marty: Add the selected artillery ammunition display name to the team warning.
_ammoOptions = [WFBE_Client_SideJoinedText, _index] Call WFBE_CO_FNC_GetArtilleryAmmoOptions;
_ammoSelection = (_units select 0) getVariable ["WFBE_A_ArtilleryAmmoSelection", []];
if (typeName _ammoSelection != "ARRAY") then {_ammoSelection = []};
if (count _ammoSelection < 2) then {_ammoSelection = [_index, 0]};
if ((_ammoSelection select 0) != _index) then {_ammoSelection = [_index, 0]};

_ammoIndex = _ammoSelection select 1;
_ammoName = if (count _ammoOptions > 0) then {(_ammoOptions select 0) select 0} else {"artillery ammunition"};

for "_i" from 0 to (count _ammoOptions) - 1 do {
	_ammoOption = _ammoOptions select _i;
	if ((_ammoOption select 3) == _ammoIndex) exitWith {_ammoName = _ammoOption select 0};
};

_Compile_Multi_language_message	= format [" format[localize ""STR_WF_INFO_Arty_called_message"", %1, %2 ];", str(_playerName), str(_ammoName)];

_audio_message 	= "ARTY_message_to_friendly_players_v2"; //In case of failure in conditions below, faction is considered as american by default to determine the audio message.
if (IS_Takistan_Faction_On_This_Map  && playerSide == east) then {_audio_message 	= "ARTY_message_to_friendly_takistanish_v1"	};
if (IS_Russian_Faction_On_This_Map   && playerSide == east) then {_audio_message 	= "ARTY_message_to_friendly_russian_v1"		};
if (IS_American_Faction_on_this_map  && playerSide == west) then {_audio_message 	= "ARTY_message_to_friendly_players_v2"		};

_side = playerSide ;

_is_multi_language_message = true ;

[_Compile_Multi_language_message, _audio_message, _side, _is_multi_language_message ] call WF_sendMessage ;
//Marty.

// Marty arty cooldown
[] spawn 
{
    _side = playerSide ;
    _currentUpgrades = (_side) Call WFBE_CO_FNC_GetSideUpgrades;

	_startTime = time;

    // Marty : The missionNamespace artillery timeout is used directly in the while condition in order to retrieve the real countdown arty in case when a reloading upgrade artillery has been made.
    while {(_startTime + ((missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS") select (_currentUpgrades select WFBE_UP_ARTYTIMEOUT))) > time} do {
        
        _currentUpgrades = (_side) call WFBE_CO_FNC_GetSideUpgrades;
        //_currentTime = floor((_startTime + ((missionNamespace getVariable "WFBE_C_ARTILLERY_INTERVALS") select (_currentUpgrades select WFBE_UP_ARTYTIMEOUT))) - time);  
        //systemChat format ["Temps restant : %1 secondes", _currentTime];
        
        sleep 1;
    };

    _text_when_arty_ready_again = localize "STR_WF_INFO_Arty_cool_down_over";
    //hint _text_when_arty_ready_again ;
    titleText [_text_when_arty_ready_again, "PLAIN DOWN", 2];
    playSound ["ARTY_cooldown_over",true];

};
