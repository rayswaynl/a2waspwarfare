/*
	Author: Marty
	Description:
		On-demand vehicle flip action. Rights the targeted vehicle immediately,
		bypassing AutoFlip's stuck-timer and cooldown. Mirrors AutoFlip's exact
		righting technique (setVectorUp / setPos / setVelocity).
*/

private ["_vehicle","_pos"];

_vehicle = _this select 0; //--- addAction target.

if (isNull _vehicle) exitWith {};
if (!alive _vehicle) exitWith {};

_pos = getPos _vehicle;
_vehicle setVectorUp [0,0,1];
_vehicle setPos [_pos select 0, _pos select 1, 0.5];
_vehicle setVelocity [0,0,-0.5];
