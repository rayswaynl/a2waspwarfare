/*
	Creator : Marty. 
	Function that handle the bomb restriction above a specific altitude to avoid exploit when players drop guided bomb above the limit range missile.
	For good result, altitude should be set at limit range (usually 3000 meters) minus 500 meters to avoid abuse if players drop at the edge of the missile range limit.
*/

Private ["_unit_targeted","_unit_who_shot", "_weapon", "_ammo", "_magazine","_projectile"];

_unit_who_shot 	= _this select 0; 	// example : O Juliet:1 (Marty)
_weapon 		= _this select 1; 	// example : 2A42.
_ammo 			= _this select 4;	// example : B_30mm_AP 
_magazine 		= _this select 5;	// example : 250Rnd_30mmAP_2A42
_projectile 	= _this select 6;	// Object of the projectile that was shot. Example : 1057951: tracer_green.p3d

if (!(_ammo in ["Bo_FAB_250","Bo_Mk82"])) exitWith {}; // if ammo have not the specified bombs, we quit.

_player_name = name player ;
_unit_who_shot_name = name _unit_who_shot; 
if (_player_name !=  _unit_who_shot_name) exitWith {}; // we want to monitor only the local client (player). If the unit who shot is not the local player, we quit. This is not necesarely required considering the eventhandler is supposed to work on client side, but this verification give 100% garantee in case of sqf weird moment.

_limit_distance = missionNamespace getVariable "WFBE_C_GAMEPLAY_BOMBS_DISTANCE_RESTRICTION";
_unit_targeted =  cursorTarget; //the cursorTarget only work this way. We can't specify a player object as parameter, that's why it is necessary the local player.
if (isNull _unit_targeted) exitWith {}; // if there is no lock on target, we quit.

_distance_target_player = player distance _unit_targeted; 
if (_distance_target_player < _limit_distance) exitWith {}; // if distance between player and the target is NOT restrictive, we have nothing to do then we quit.

_vehicle = vehicle _unit_who_shot; 
hint localize "STR_WF_MESSAGE_BombDistanceRestriction"; 
deleteVehicle _projectile ;  

/*
_objPosition = getPos _unit_who_shot;
_objAltitude = _objPosition select 2;
_limit = missionNamespace getVariable "WFBE_C_GAMEPLAY_BOMBS_ALTITUDE";


if (_objAltitude < _limit) exitWith {}; // if altitude is NOT restrictive, we have nothing to do then we quit.

_vehicle = vehicle _unit_who_shot; 
//_vehicle vehicleChat "you can't shot this ammo at this altitude"; localize
_vehicle vehicleChat localize "STR_WF_MESSAGE_BombAltitudeRestriction"; 
deleteVehicle _projectile ;
*/

