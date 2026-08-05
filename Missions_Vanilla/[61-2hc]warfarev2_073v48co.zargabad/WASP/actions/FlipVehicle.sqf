/*
Author: Marty
Description:
	On-demand vehicle flip action. Rights the targeted vehicle immediately,
	bypassing AutoFlip's stuck-timer and cooldown. Mirrors AutoFlip's exact
	righting technique (setVectorUp / setPos / setVelocity).

r74: fail-clean type/null/alive + player distance recheck. Condition paints on
vectorUp alone (no alive) so a wreck can still show the action until click;
setPos/setVectorUp on null/dead aborts. Distance recheck closes the walk-away race.
*/

private ["_vehicle","_pos"];

_vehicle = _this select 0; //--- addAction target.

if (isNil "_vehicle") exitWith {};
if (typeName _vehicle != "OBJECT") exitWith {};
if (isNull _vehicle) exitWith {};
if (!alive _vehicle) exitWith {};
if (isNil "player" || {isNull player}) exitWith {};
//--- Condition uses < 10; allow small slack for latency between paint and click.
if (player distance _vehicle > 12) exitWith {};

_pos = getPos _vehicle;
_vehicle setVectorUp [0,0,1];
_vehicle setPos [_pos select 0, _pos select 1, 0.5];
_vehicle setVelocity [0,0,-0.5];
