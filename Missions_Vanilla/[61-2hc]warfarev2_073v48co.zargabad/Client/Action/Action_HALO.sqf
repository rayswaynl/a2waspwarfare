Private ["_act","_caller","_vehicle"];

_vehicle = _this select 0;
_caller = _this select 1;
_act = _this select 2;

//--- r54: action can fire after the airframe despawns or caller dies mid-menu; bare eject/getout throws.
if (isNil "_vehicle" || {isNull _vehicle} || {!alive _vehicle}) exitWith {};
if (isNil "_caller" || {isNull _caller} || {!alive _caller}) exitWith {};
if (vehicle _caller != _vehicle) exitWith {};

_caller action ["EJECT",_vehicle];
_caller setVelocity [0,0,0];
[_caller] Exec "ca\air2\Halo\data\Scripts\HALO_getout.sqs";