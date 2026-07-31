/* ILLUM Handler, Battlefield light bringer */
Private ['_deployPos','_destination','_flare','_force','_shell','_targetToHit','_velocity'];
_shell = _this select 0;
_destination = _this select 1;
_velocity = _this select 2;

//--- 1KM Above.
_destination set [2, 1000];

//--- Positionate the shell in the air.
_shell setPos _destination;
_targetToHit = objNull;

//--- Fall straigh.
_shell setVelocity [0,0,-_velocity];

//--- Wait before deploying. Shell can be deleted/cleaned mid-fall — bare getPos is crash class.
waitUntil {isNull _shell || {(getPos _shell select 2) < 310}};
if (isNull _shell) exitWith {};

//--- Retrieve the shell position.
_deployPos = getPos _shell;
deleteVehicle _shell;

//--- Deploy a Flare.
_flare = "ARTY_Flare_Medium" createVehicle _deployPos;
if (isNull _flare) exitWith {
	["WARNING", Format ["ARTY_HandleILLUM.sqf: flare create failed at %1 class ARTY_Flare_Medium.", _deployPos]] Call WFBE_CO_FNC_LogContent;
};
_flare setPos _deployPos;