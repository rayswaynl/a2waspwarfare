Private ["_ammo","_irLock","_missile","_source","_unit","_indirectHit","_distance","_limit"];
_unit = _this select 0;
_ammo = _this select 1;
_source = _this select 2;

_missile = nearestObject [_source,_ammo];
if (isNull _missile) exitWith {};

_irLock = getNumber(configFile >> "CfgAmmo" >> _ammo >> "irLock"); //--- Get the ammo type.
if (_irLock == 0) then {if (_ammo in ["Bo_FAB_250","Bo_Mk82"]) then {_irLock = 1}}; //--- Dumb bomb workaround (rocket simulation).

if (_irLock == 1) then { //--- IR Lock is affected
_source = getPos _source;
_distance = _unit distance _source;

//--- r53: defaulted limit so nil missionNamespace key never makes the compare throw; 0 = disabled.
_limit = missionNamespace getVariable ["WFBE_C_GAMEPLAY_MISSILES_RANGE", 0];

if (_limit > 0 && {_distance > _limit}) then {
//--- r53: missile may detonate/despawn during wait - bare distance on null throws; delete only if still live.
//--- Yield inside this event-spawned poll so each in-range missile is not checked every frame.
waitUntil {
	sleep 0.05;
	isNull _missile || {_missile distance _source > _limit}
};
if (!isNull _missile) then {deleteVehicle _missile};
};
};

//Maverick fix
_indirectHit = getNumber(configFile >> "CfgAmmo" >> _ammo >> "indirectHit");
    if (_ammo in ["M_Maverick_AT"])
        then {
            _indirectHit = 849
            };
