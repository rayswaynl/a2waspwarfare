/* 
	Author: Marty
	Name: OnEventHandler_player_radiated.sqf
	Parameters:
	0 - the name of the publicvalue montitored by the EH : PLAYER_RADIATED
	1 - the value of the publicvalue montitored by the EH set in the namespace. Here the player object who is radiated.
	
	Description: This function responds to the "PLAYER_RADIATED" variable, in order to play the script on the player's side.
	When a player is in the radiated area (see radzone.sqf), this broadcast a public variable PLAYER_RADIATED and trigger the eventHandler, playing this script here.
		    
*/
private ["_radData", "_radUnit", "_radDose"];

//--- Payload is [unit, dose]. radzone.sqf routes each player's radiation dose here because
//--- setDammage is a LOCAL-argument command: the server (where radzone runs) cannot damage a
//--- player unit that is local to the player's OWN client. This handler runs on that owning
//--- client, so applying the dose to 'player' here is where it actually lands.
_radData = _this select 1;
_radUnit = _radData select 0;
_radDose = _radData select 1;

if (player == _radUnit) then 
{
	player setDammage ((getDammage player) + _radDose);
	playSound ["radiationSound",true];
};
