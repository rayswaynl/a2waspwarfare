/*
	Server_ProvisionAirfieldHangar.sqf

	Spawns (or re-spawns) the aircraft-buy hangar for an airfield town's owning side and
	links it via wfbe_hangar so Client_GetClosestAirport / GUI_Menu_BuyUnits can find it.
	Deletes any prior hangar first. Shared by:
	  - server_town.sqf's Task 12 capture block (real ownership flip, mid-match).
	  - server_town.sqf's boot bootstrap (airfields that start pre-owned via Init_Town.sqf's
	    sideID default never fire a capture event, so they'd otherwise never get a hangar).

	Parameters:
		0: OBJECT - the airfield town/depot logic (wfbe_is_airfield = true)
		1: OBJECT - the nearest LocationLogicAirport for this airfield
		2: SIDE   - the side to record as the new hangar owner

	Returns: nothing
*/
Private ["_location","_airfieldLogic","_newSide","_newHangar","_oldHangar"];
_location      = _this select 0;
_airfieldLogic = _this select 1;
_newSide       = _this select 2;

//--- Delete old hangar (previous owner's) and its link on the airport logic. Matches the
//--- original inline block exactly: this always runs when an old hangar exists, even if
//--- _airfieldLogic itself came back null (malformed mission data - defensive, not expected).
_oldHangar = _location getVariable ["wfbe_airfield_hangar_obj", objNull];
if !(isNull _oldHangar) then {
	deleteVehicle _oldHangar;
	if !(isNull _airfieldLogic) then { _airfieldLogic setVariable ["wfbe_hangar", nil, true] };
};

//--- Spawn new hangar on the airport logic so GetClosestAirport can find it.
if !(isNull _airfieldLogic) then {
	_newHangar = (missionNamespace getVariable "WFBE_C_HANGAR") createVehicle (getPos _airfieldLogic);
	_newHangar setDir ((getDir _airfieldLogic) + (missionNamespace getVariable "WFBE_C_HANGAR_RDIR"));
	_newHangar setPos (getPos _airfieldLogic);
	_newHangar setVariable ["wfbe_is_airfield_hangar", true, true];
	_airfieldLogic setVariable ["wfbe_hangar", _newHangar, true];
	_airfieldLogic setVariable ["wfbe_airfield_side", _newSide, true]; //--- C-1: GUER airfield ownership gate
	_location setVariable ["wfbe_airfield_hangar_obj", _newHangar, true];
};
