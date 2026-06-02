/* 
	Author: Marty
	Name: Client_onEventHandler_MARKER_CREATION.sqf
	Parameters:
	Parameters are given by the EH "MARKER_CREATION" addPublicVariableEventHandler
	0 - string - correspond to the name of the public variable braodcasted, here it is "MARKER_CREATION"
	1 - _MARKER_infos : array containing all the value given by the addPublicVariableEventHandler, here it the infos about the marker to be created.


	Description: This function is meant to create a marker only visible for specific side (west or east).
	    
*/
private ["_MARKER_infos","_marker_name", "_markerPosition","_markerType","_markerText","_markerColor","_side_who_see_marker","_markerNameElipse","_markerRadius"];

_MARKER_infos = _this select 1; // select 1 not 0 to get the value !

// Extract the value from the array to get specific infos for the marker creation :
_markerName 			= _MARKER_infos select 0;
_markerPosition			= _MARKER_infos select 1;
_markerType				= _MARKER_infos select 2;
_markerText				= _MARKER_infos select 3;
_markerColor			= _MARKER_infos select 4;
_side_who_see_marker 	= _MARKER_infos select 5;

//optional parameters
if (count _MARKER_infos > 6) then 
{
	_markerNameElipse 	= _MARKER_infos select 6;
	_markerRadius		= _MARKER_infos select 7;
};

if (playerSide == _side_who_see_marker) then 
{
	// Construction of the marker : 
	////_markerName = createMarkerLocal [_markerName, _markerPosition];
	_markerName setMarkerTypeLocal _markerType;
	_markerName setMarkerTextLocal _markerText;
	_markerName setMarkerColorLocal _markerColor;	

	// Drawing a circle marker on the map with the corresponding radius in case the optional parameter _markerNameElipse is send when calling the create marker function.
	if (!isNil {_markerNameElipse}) then 
	{
		//_markerNameElipse = createMarker [_markerNameElipse, _markerPosition];
		_markerNameElipse setMarkerShapeLocal "ELLIPSE";
		_markerNameElipse setMarkerSizeLocal [_markerRadius, _markerRadius];
		_markerNameElipse setMarkerColorLocal _markerColor; 
		_markerNameElipse setMarkerAlphaLocal 0.5; // 50% de transparancy
		_markerNameElipse setMarkerBrushLocal "Solid"; 
	};
};
