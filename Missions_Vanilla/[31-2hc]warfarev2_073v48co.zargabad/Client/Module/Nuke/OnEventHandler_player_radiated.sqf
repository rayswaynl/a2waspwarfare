/* 
	Author: Marty
	Name: OnEventHandler_player_radiated.sqf
	Parameters:
	0 - the name of the publicvalue montitored by the EH : PLAYER_RADIATED
	1 - the value of the publicvalue montitored by the EH set in the namespace. Here the player object who is radiated.
	
	Description: This function responds to the "PLAYER_RADIATED" variable, in order to play the script on the player's side.
	When a player is in the radiated area (see radzone.sqf), this broadcast a public variable PLAYER_RADIATED and trigger the eventHandler, playing this script here.
		    
*/
private["_PLAYER_radiated"];

_PLAYER_radiated = _this select 1;

if (player == _PLAYER_radiated) then 
{
	playSound ["radiationSound",true];
};
